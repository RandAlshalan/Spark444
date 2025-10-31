import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String studentId;
  final String studentName;
  final String companyId;
  final double rating;
  final String reviewText;
  final Timestamp createdAt;

  Review({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.companyId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
  });

  /// Creates a Review object from a Firestore document.
  factory Review.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Anonymous',
      companyId: data['companyId'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewText: data['reviewText'] ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
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
    };
  }
}
