import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewReply {
  final String id;
  final String companyId;
  final String companyName;
  final String replyText;
  final Timestamp createdAt;

  ReviewReply({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.replyText,
    required this.createdAt,
  });

  factory ReviewReply.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewReply(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      replyText: data['replyText'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'replyText': replyText,
      'createdAt': createdAt,
    };
  }
}
