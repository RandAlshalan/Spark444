import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String studentId;
  final String studentName;
  final String companyId;
  final double rating;
  final String reviewText;
  final Timestamp createdAt;
  final String? parentId;

  // ADDED: per-review privacy flag
  final bool authorVisible;

  Review({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.companyId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    this.parentId,
    this.authorVisible = true,
  });

  /// Creates a Review object from a Firestore document.
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Review(
      id: doc.id,
      studentId: (data['studentId'] ?? '') as String,
      studentName: (data['studentName'] ?? '') as String,
      companyId: (data['companyId'] ?? '') as String,
      rating: ((data['rating'] ?? 0) as num).toDouble(),
      reviewText: (data['reviewText'] ?? '') as String,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      parentId: data['parentId'] as String?,
      // Respect stored flag; default to true when missing
      authorVisible: data.containsKey('authorVisible') ? (data['authorVisible'] == true) : true,
    );
  }

  /// Converts the Review object to a Map for storing in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'companyId': companyId,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': createdAt,
      'parentId': parentId,
      'authorVisible': authorVisible,
    };
  }
}
