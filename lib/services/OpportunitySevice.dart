/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/models/opportunity.dart';

class OpportunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches opportunities with optional filters.
  Future<List<Opportunity>> getOpportunities({
    String? searchQuery,
    String? type,
    String? city,
    String? duration,
    String? locationType,
    bool? isPaid,
  }) async {
    try {
      Query query = _firestore.collection('opportunities');

      // Filter by type
      if (type != null && type != 'all') {
        query = query.where('type', isEqualTo: type);
      }

      // Filter by city
      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      // Filter by duration
      if (duration != null && duration.isNotEmpty) {
        query = query.where('duration', isEqualTo: duration);
      }

      // Filter by locationType
      if (locationType != null && locationType.isNotEmpty) {
        query = query.where('locationType', isEqualTo: locationType);
      }

      // Filter by isPaid
      if (isPaid != null) {
        query = query.where('isPaid', isEqualTo: isPaid);
      }

      // Order by createdAt descending
      query = query.orderBy('createdAt', descending: true);

      // Fetch snapshot
      QuerySnapshot snapshot = await query.get();

      // Map to Opportunity objects
      List<Opportunity> opportunities = snapshot.docs
          .map((doc) => Opportunity.fromFirestore(doc))
          .toList();

      // Apply searchQuery in memory (role or company)
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        opportunities = opportunities.where((o) {
          return o.role.toLowerCase().contains(lowerQuery) ||
              o.name.toLowerCase().contains(lowerQuery);
        }).toList();
      }

      return opportunities;
    } catch (e) {
      print('Error fetching opportunities: $e');
      rethrow;
    }
  }
}
*/