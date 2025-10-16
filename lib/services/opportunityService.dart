import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/opportunity.dart';

class OpportunityService {
  //`withConverter` 
  final CollectionReference<Opportunity> _opportunitiesRef = FirebaseFirestore
      .instance
      .collection('opportunities')
      .withConverter<Opportunity>(
        fromFirestore: (snapshot, _) => Opportunity.fromFirestore(snapshot),
        toFirestore: (opportunity, _) => opportunity.toFirestore(),
      );

  
  Future<List<Opportunity>> getOpportunities({
    String? searchQuery,
    String? type,
    String? city,
    String? duration,
    String? locationType,
    bool? isPaid,
  }) async {
    Query<Opportunity> query = _opportunitiesRef;

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('role', isGreaterThanOrEqualTo: searchQuery)
          .where('role', isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }
    if (type != null && type != 'all') {
      query = query.where('type', isEqualTo: type);
    }
    if (city != null && city.isNotEmpty) {
      query = query.where('location', isEqualTo: city);
    }
    if (locationType != null && locationType.isNotEmpty) {
      query = query.where('workMode', isEqualTo: locationType);
    }
    if (isPaid != null) {
      query = query.where('isPaid', isEqualTo: isPaid);
    }

    query = query.orderBy('postedDate', descending: true);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }


  Future<List<Opportunity>> getCompanyOpportunities(String companyId) async {
    if (companyId.isEmpty) {
      return [];
    }
    try {
      final querySnapshot = await _opportunitiesRef
          .where('companyId', isEqualTo: companyId)
          .orderBy('postedDate', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching opportunities: $e');
      rethrow;
    }
  }


  Future<void> addOpportunity(Opportunity opportunity) async {
    try {

      final data = opportunity.toFirestore();
      

      data['postedDate'] = FieldValue.serverTimestamp(); 
      
 
      await FirebaseFirestore.instance.collection('opportunities').add(data);

    } catch (e) {
      print('Error adding opportunity: $e');
      rethrow;
    }
  }




  Future<void> updateOpportunity(Opportunity opportunity) async {
    try {
      await _opportunitiesRef.doc(opportunity.id).update(opportunity.toFirestore());
    } catch (e) {
      print('Error updating opportunity: $e');
      rethrow;
    }
  }


  Future<void> deleteOpportunity(String opportunityId) async {
    try {
      await _opportunitiesRef.doc(opportunityId).delete();
    } catch (e) {
      print('Error deleting opportunity: $e');
      rethrow;
    }
  }
}