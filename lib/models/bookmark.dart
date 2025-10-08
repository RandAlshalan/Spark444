import 'package:cloud_firestore/cloud_firestore.dart';

class Bookmark {
  final String id;
  final String studentId;
  final String opportunityId;
  final Timestamp? createdAt; // Make this nullable

  Bookmark({
    required this.id,
    required this.studentId,
    required this.opportunityId,
    this.createdAt, // Make this optional
  });

  factory Bookmark.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Bookmark(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      opportunityId: data['opportunityId'] ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'opportunityId': opportunityId,
      // If createdAt is null (i.e., new bookmark), use server timestamp.
      // Otherwise, use the existing value.
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}