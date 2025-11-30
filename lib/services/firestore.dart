import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_reply.dart';
import 'notification_helper.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addCompanyReplyToReview({
    required String reviewId,
    required String companyId,
    required String companyName,
    required String replyText,
  }) async {
    await _db.collection('reviews').doc(reviewId).collection('replies').add({
      'companyId': companyId,
      'companyName': companyName,
      'replyText': replyText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    //  Notify student about company reply
    try {
      // Get the review to find the student ID
      final reviewDoc = await _db.collection('reviews').doc(reviewId).get();
      if (reviewDoc.exists) {
        final reviewData = reviewDoc.data() as Map<String, dynamic>?;
        final studentId = reviewData?['studentId'] as String?;
        
        if (studentId != null) {
          await NotificationHelper().notifyReviewReplyToStudent(
            reviewId: reviewId,
            studentId: studentId,
            replierName: companyName,
            isCompanyReply: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending company reply notification: $e');
    }
  }

  Stream<List<ReviewReply>> getRepliesForReview(String reviewId) {
    return _db
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => ReviewReply.fromFirestore(d)).toList(),
        );
  }

  Future<void> deleteCompanyReply({
    required String reviewId,
    required String replyId,
  }) async {
    await _db
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .delete();
  }
}
