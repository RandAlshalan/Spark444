import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/models/bookmark.dart';
import 'package:my_app/models/opportunity.dart';

class BookmarkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final CollectionReference<Bookmark> _bookmarksRef;
  late final CollectionReference<Opportunity> _opportunitiesRef;

  BookmarkService() {
    _bookmarksRef = _firestore.collection('bookmarks').withConverter<Bookmark>(
      fromFirestore: (snapshot, _) => Bookmark.fromFirestore(snapshot),
      toFirestore: (bookmark, _) => bookmark.toFirestore(),
    );

    _opportunitiesRef = _firestore.collection('opportunities').withConverter<Opportunity>(
      fromFirestore: (snapshot, _) => Opportunity.fromFirestore(snapshot),
      toFirestore: (opportunity, _) => opportunity.toFirestore(),
    );
  }

  /// Adds a bookmark for a given student and opportunity.
  Future<void> addBookmark({required String studentId, required String opportunityId}) async {
    final newBookmark = Bookmark(
      id: '', // Placeholder; Firestore will generate the ID
      studentId: studentId,
      opportunityId: opportunityId,
      createdAt: null, // serverTimestamp will be used
    );

    await _bookmarksRef.add(newBookmark);
  }

  /// Removes a bookmark for a given student and opportunity.
  Future<void> removeBookmark({required String studentId, required String opportunityId}) async {
    final querySnapshot = await _bookmarksRef
        .where('studentId', isEqualTo: studentId)
        .where('opportunityId', isEqualTo: opportunityId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.delete();
    }
  }

  /// Checks if an opportunity is already bookmarked by a student in real-time.
  Stream<bool> isBookmarkedStream({required String studentId, required String opportunityId}) {
    return _bookmarksRef
        .where('studentId', isEqualTo: studentId)
        .where('opportunityId', isEqualTo: opportunityId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Fetches the list of all opportunities bookmarked by a student, ordered by saved date.
  Stream<List<Opportunity>> getBookmarkedOpportunitiesStream({required String studentId}) {
    return _bookmarksRef
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true) // latest saved first
        .snapshots()
        .asyncMap((snapshot) async {
      final opportunityIds = snapshot.docs.map((doc) => doc.data().opportunityId).toList();

      if (opportunityIds.isEmpty) return [];

      // Firestore limits whereIn queries to 10 items per query, so split into batches
      const batchSize = 10;
      List<Opportunity> allOpportunities = [];

      for (var i = 0; i < opportunityIds.length; i += batchSize) {
        final batchIds = opportunityIds.sublist(
          i,
          i + batchSize > opportunityIds.length ? opportunityIds.length : i + batchSize,
        );

        final opportunitiesSnapshot = await _opportunitiesRef
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        allOpportunities.addAll(opportunitiesSnapshot.docs.map((doc) => doc.data()));
      }

      // Optionally: sort the opportunities to match bookmark order
      allOpportunities.sort((a, b) {
        final indexA = opportunityIds.indexOf(a.id);
        final indexB = opportunityIds.indexOf(b.id);
        return indexA.compareTo(indexB);
      });

      return allOpportunities;
    });
  }
}
