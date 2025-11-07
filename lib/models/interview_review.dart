import 'package:cloud_firestore/cloud_firestore.dart';

class InterviewReview {
  final String id;
  final String studentId;
  final String studentName;
  final String companyId;
  final double rating;
  final String reviewText;
  final Timestamp createdAt;
  final String? parentId;

  // Interview-specific fields
  final String? interviewDifficulty; // Easy, Medium, Hard
  final String? interviewQuestions; // Questions asked during interview
  final String? interviewAnswers; // Optional: How they answered the questions
  final String? wasAccepted; // Whether they got accepted: Yes, No, Not Sure

  // Privacy flag
  final bool authorVisible;

  InterviewReview({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.companyId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    this.parentId,
    this.interviewDifficulty,
    this.interviewQuestions,
    this.interviewAnswers,
    this.wasAccepted,
    this.authorVisible = true,
  });

  /// Creates an InterviewReview object from a Firestore document.
  factory InterviewReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InterviewReview(
      id: doc.id,
      studentId: (data['studentId'] ?? '') as String,
      studentName: (data['studentName'] ?? '') as String,
      companyId: (data['companyId'] ?? '') as String,
      rating: ((data['rating'] ?? 0) as num).toDouble(),
      reviewText: (data['reviewText'] ?? '') as String,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      parentId: data['parentId'] as String?,
      interviewDifficulty: data['interviewDifficulty'] as String?,
      interviewQuestions: data['interviewQuestions'] as String?,
      interviewAnswers: data['interviewAnswers'] as String?,
      wasAccepted: data['wasAccepted'] as String?,
      // Respect stored flag; default to true when missing
      authorVisible: data.containsKey('authorVisible') ? (data['authorVisible'] == true) : true,
    );
  }

  /// Converts the InterviewReview object to a Map for storing in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'companyId': companyId,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': createdAt,
      'parentId': parentId,
      'interviewDifficulty': interviewDifficulty,
      'interviewQuestions': interviewQuestions,
      'interviewAnswers': interviewAnswers,
      'wasAccepted': wasAccepted,
      'authorVisible': authorVisible,
    };
  }
}
