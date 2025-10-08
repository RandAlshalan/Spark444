import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/opportunity.dart';

class OpportunityService {
  // أنت تستخدم `withConverter` هنا بشكل ممتاز، وهذا يجعل الكود أفضل
  final CollectionReference<Opportunity> _opportunitiesRef = FirebaseFirestore
      .instance
      .collection('opportunities')
      .withConverter<Opportunity>(
        fromFirestore: (snapshot, _) => Opportunity.fromFirestore(snapshot),
        toFirestore: (opportunity, _) => opportunity.toFirestore(),
      );

  // ... (دالة getOpportunities تبقى كما هي لأنها صحيحة)
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

  // ... (دالة getCompanyOpportunities تبقى كما هي لأنها صحيحة)
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

  // ✨======= هذا هو الكود المصحح لدالة الإضافة =======✨
  Future<void> addOpportunity(Opportunity opportunity) async {
    try {
      // بما أن `_opportunitiesRef` معرفة بـ `withConverter`,
      // يمكننا تمرير كائن `Opportunity` مباشرةً وهو سيقوم بالتحويل تلقائيًا.
      // لكن بما أننا نريد إضافة وقت النشر من السيرفر، سنقوم بتعديل بسيط.
      
      // 1. حوّل الكائن إلى Map باستخدام دالتك
      final data = opportunity.toFirestore();
      
      // 2. أضف وقت النشر من السيرفر (Server Timestamp)
      data['postedDate'] = FieldValue.serverTimestamp(); 
      
      // 3. أضف الـ Map مباشرةً إلى Firestore (بدون تحويلات معقدة)
      await FirebaseFirestore.instance.collection('opportunities').add(data);

    } catch (e) {
      print('Error adding opportunity: $e');
      rethrow;
    }
  }
  // ✨================ نهاية الكود المصحح ================✨


  // ... (دالة updateOpportunity تبقى كما هي لأنها صحيحة)
  Future<void> updateOpportunity(Opportunity opportunity) async {
    try {
      await _opportunitiesRef.doc(opportunity.id).update(opportunity.toFirestore());
    } catch (e) {
      print('Error updating opportunity: $e');
      rethrow;
    }
  }

  // ... (دالة deleteOpportunity تبقى كما هي لأنها صحيحة)
  Future<void> deleteOpportunity(String opportunityId) async {
    try {
      await _opportunitiesRef.doc(opportunityId).delete();
    } catch (e) {
      print('Error deleting opportunity: $e');
      rethrow;
    }
  }
}