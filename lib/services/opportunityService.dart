import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/opportunity.dart';
import 'authService.dart';
import 'notification_helper.dart';
import 'notification_service.dart';
import '../models/company.dart';

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

      // Add the opportunity to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('opportunities')
          .add(data);

      // Get company name for notification
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(opportunity.companyId)
          .get();

      final companyName = companyDoc.exists
          ? (companyDoc.data()?['companyName'] as String?) ?? opportunity.name
          : opportunity.name;

      // Notify all students following this company
      await NotificationHelper().notifyFollowersOfNewOpportunity(
        companyId: opportunity.companyId,
        companyName: companyName,
        opportunityId: docRef.id,
        opportunityRole: opportunity.role,
      );

      // Also send local notification banner for immediate visibility
      await NotificationService().showLocalNotification(
        title: '🎉 New Opportunity from $companyName',
        body: 'Check out the ${opportunity.role} position!',
        route: '/opportunities',
      );
    } catch (e) {
      print('Error adding opportunity: $e');
      rethrow;
    }
  }

  Future<void> updateOpportunity(Opportunity opportunity) async {
    try {
      await _opportunitiesRef
          .doc(opportunity.id)
          .update(opportunity.toFirestore());
    } catch (e) {
      print('Error updating opportunity: $e');
      rethrow;
    }
  }

  Future<void> deleteOpportunity(String opportunityId) async {
    if (opportunityId.isEmpty) {
      throw Exception('Invalid opportunity ID');
    }

    final firestore = FirebaseFirestore.instance;
    final oppDocRef = firestore.collection('opportunities').doc(opportunityId);

    try {
      final snapshot = await oppDocRef.get();
      if (!snapshot.exists) {
        throw Exception('Opportunity no longer exists.');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final companyId = (data['companyId'] as String?) ?? '';

      // Prepare batch for deleting related application documents
      final batch = firestore.batch();

      // Delete opportunity document
      batch.delete(oppDocRef);

      // Remove opportunityId from company's opportunitiesPosted array if present
      if (companyId.isNotEmpty) {
        final companyDoc = firestore
            .collection(AuthService.kCompanyCol)
            .doc(companyId);
        batch.update(companyDoc, {
          'opportunitiesPosted': FieldValue.arrayRemove([opportunityId]),
        });
      }

      // Collect related applications
      final applicationsSnapshot = await firestore
          .collection('applications')
          .where('opportunityId', isEqualTo: opportunityId)
          .get();

      for (final doc in applicationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete opportunity: $e');
    }
  }
}
