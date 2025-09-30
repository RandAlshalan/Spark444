import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../models/opportunity.dart';
import 'dart:async'; // Keep this if you use other async operations, though not strictly needed for this specific change.

class OpportunityService {
  // Initialize Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Opportunity>> getCompanyOpportunities(String companyId) async {
    if (companyId.isEmpty) {
      // Handle cases where companyId might be empty (e.g., no company logged in)
      print('Company ID is empty, cannot fetch opportunities.');
      return [];
    }

    try {
      // Query the 'opportunities' collection in Firestore
      // Assuming each opportunity document has a 'companyId' field
      // that links it to the company that posted it.
      QuerySnapshot querySnapshot = await _firestore
          .collection('opportunities') // Your opportunities collection name
          .where('companyId', isEqualTo: companyId) // Filter by company ID
          // .orderBy('timestamp', descending: true) // Optional: order by creation date
          .orderBy('postedDate', descending: true)
          .get();

      // Convert the documents to a list of Opportunity objects
      return querySnapshot.docs
          .map((doc) => Opportunity.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching opportunities: $e');
      // Re-throw the exception so the UI can catch and display an error
      rethrow;
    }
  }

  // --- Add methods for adding, updating, and deleting opportunities ---

  // Example: Add a new opportunity
  Future<void> addOpportunity(Opportunity opportunity) async {
    try {
      /*await _firestore.collection('opportunities').add({
        'companyId': opportunity.companyId,
        'name': opportunity.name,
        'role': opportunity.role,
        'isPaid': opportunity.isPaid,
        'timestamp': FieldValue.serverTimestamp(), // Add a timestamp for ordering
        // Add other fields from your Opportunity model
      });*/
      final data = opportunity.toFirestore();
      data['postedDate'] =
          FieldValue.serverTimestamp(); // Always set on creation
      await _firestore.collection('opportunities').add(data);
    } catch (e) {
      print('Error adding opportunity: $e');
      rethrow;
    }
  }

  // Example: Update an existing opportunity
  Future<void> updateOpportunity(Opportunity opportunity) async {
    try {
      /* await _firestore.collection('opportunities').doc(opportunity.id).update({
        'name': opportunity.name,
        'role': opportunity.role,
        'isPaid': opportunity.isPaid,
        // Update other fields
      });*/
      await _firestore
          .collection('opportunities')
          .doc(opportunity.id)
          .update(opportunity.toFirestore());
    } catch (e) {
      print('Error updating opportunity: $e');
      rethrow;
    }
  }

  // Example: Delete an opportunity
  Future<void> deleteOpportunity(String opportunityId) async {
    try {
      // In PostOpportunityPage, you are calling .add() directly, not this service method.
      // Let's adjust that page to use this service.
      // For now, this method is correct as is.
      await _firestore.collection('opportunities').doc(opportunityId).delete();
    } catch (e) {
      print('Error deleting opportunity: $e');
      rethrow;
    }
  }
}

// In PostOpportunityPage.dart, you are calling Firestore directly.
// It's better practice to use your service.
// Let's modify PostOpportunityPage to use OpportunityService.

/*
  In PostOpportunityPage.dart, inside _postOpportunity():

  Replace:
    await FirebaseFirestore.instance.collection('opportunities').add(newOpportunity.toFirestore());
  With:
    await OpportunityService().addOpportunity(newOpportunity);
*/