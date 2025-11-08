import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Helper service for creating and managing in-app notifications
class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates notifications for all students following a specific company
  /// Called when a company posts a new opportunity
  Future<void> notifyFollowersOfNewOpportunity({
    required String companyId,
    required String companyName,
    required String opportunityId,
    required String opportunityRole,
  }) async {
    try {
      // Get all students following this company
      final studentsSnapshot = await _firestore
          .collection('student')
          .where('followedCompanies', arrayContains: companyId)
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        debugPrint('No students following company $companyId');
        return;
      }

      // Create batch to write all notifications at once
      final batch = _firestore.batch();
      final notificationsRef = _firestore.collection('notifications');

      // Collect FCM tokens for push notifications
      List<String> fcmTokens = [];

      for (final studentDoc in studentsSnapshot.docs) {
        final studentId = studentDoc.id;
        final studentData = studentDoc.data();

        // Get FCM token if available
        final fcmToken = studentData['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          fcmTokens.add(fcmToken);
        }

        final notification = AppNotification(
          id: '', // Will be set by Firestore
          userId: studentId,
          type: 'new_opportunity',
          title: '$companyName posted a new opportunity!',
          body: 'Check out the $opportunityRole position',
          data: {
            'companyId': companyId,
            'companyName': companyName,
            'opportunityId': opportunityId,
            'opportunityRole': opportunityRole,
            'route': '/opportunities',
          },
          read: false,
          createdAt: Timestamp.now(),
        );

        final docRef = notificationsRef.doc();
        batch.set(docRef, notification.toFirestore());
      }

      // Commit all notifications
      await batch.commit();
      debugPrint(
        '✅ Created notifications for ${studentsSnapshot.docs.length} students',
      );

      // Send push notifications to all followers with FCM tokens
      if (fcmTokens.isNotEmpty) {
        await _sendPushNotifications(
          tokens: fcmTokens,
          title: '🎉 New Opportunity from $companyName',
          body: 'Check out the $opportunityRole position!',
          data: {
            'companyId': companyId,
            'opportunityId': opportunityId,
            'route': '/opportunities',
          },
        );
        debugPrint('✅ Sent push notifications to ${fcmTokens.length} devices');
      }
    } catch (e) {
      debugPrint('❌ Error creating notifications: $e');
    }
  }

  /// Alternate lightweight notifier that mirrors the logic shared by the user.
  /// Sends both push notifications and an in-app notification document
  /// for every student that follows the provided [companyId].
  Future<void> notifyFollowersOnNewOpportunity(
    String companyId,
    String opportunityTitle,
  ) async {
    try {
      final followersSnapshot = await _firestore
          .collection('student')
          .where('followedCompanies', arrayContains: companyId)
          .get();

      if (followersSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No followers found for company $companyId');
        return;
      }

      final companyDoc =
          await _firestore.collection('companies').doc(companyId).get();
      final companyData = companyDoc.data() ?? {};
      final companyName = (companyData['companyName'] as String?) ??
          (companyData['name'] as String?) ??
          'A company';

      final notificationsRef = _firestore.collection('notifications');
      final batch = _firestore.batch();
      final tokens = <String>[];

      for (final follower in followersSnapshot.docs) {
        final data = follower.data();
        final studentId = follower.id;
        final token = (data['fcmToken'] as String?)?.trim();

        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        } else {
          debugPrint('⚠️ No FCM token for follower $studentId');
        }

        batch.set(notificationsRef.doc(), {
          'userId': studentId,
          'receiverId': studentId,
          'senderId': companyId,
          'type': 'new_opportunity',
          'title': 'New Opportunity Posted',
          'body': '$companyName just posted "$opportunityTitle"!',
          'data': {
            'companyId': companyId,
            'route': '/opportunities',
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (tokens.isNotEmpty) {
        await _sendPushNotifications(
          tokens: tokens,
          title: 'New Opportunity from $companyName',
          body: '$companyName just posted "$opportunityTitle"!',
          data: {
            'companyId': companyId,
            'route': '/opportunities',
          },
        );
        debugPrint('✅ Notification sent to ${tokens.length} followers');
      }

      debugPrint(
        '🎯 Notifications successfully prepared for all followers of $companyName.',
      );
    } catch (e, stack) {
      debugPrint('❌ Error notifying followers: $e');
      debugPrint('$stack');
    }
  }

  /// Sends push notifications via FCM (requires Firebase Cloud Functions in production)
  /// For now, this will send to FCM directly (requires server key)
  Future<void> _sendPushNotifications({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Note: For production, you should use Firebase Cloud Functions
    // This is a basic implementation that won't work without FCM server key
    // See NOTIFICATIONS_SETUP_GUIDE.md for Firebase Cloud Functions setup

    debugPrint('📱 Would send push notifications to ${tokens.length} devices');
    debugPrint('Title: $title');
    debugPrint('Body: $body');

    // TODO: Implement Firebase Cloud Functions for sending push notifications
    // For now, notifications will only appear in-app
  }

  /// Creates a notification for a student when their application status is updated
  Future<void> notifyApplicationStatusUpdate({
    required String studentId,
    required String companyName,
    required String opportunityRole,
    required String status,
    required String opportunityId,
  }) async {
    try {
      final notification = AppNotification(
        id: '',
        userId: studentId,
        type: 'application_update',
        title: 'Application update from $companyName',
        body: 'Your application for $opportunityRole has been $status',
        data: {
          'companyName': companyName,
          'opportunityId': opportunityId,
          'opportunityRole': opportunityRole,
          'status': status,
          'route': '/applications',
        },
        read: false,
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());
      debugPrint(
        '✅ Created application update notification for student $studentId',
      );
    } catch (e) {
      debugPrint('❌ Error creating application update notification: $e');
    }
  }

  /// Creates a notification when someone replies to a student's review
  Future<void> notifyReviewReply({
    required String studentId,
    required String companyName,
    required String reviewId,
  }) async {
    try {
      final notification = AppNotification(
        id: '',
        userId: studentId,
        type: 'review_reply',
        title: '$companyName replied to your review',
        body: 'Check out their response',
        data: {
          'companyName': companyName,
          'reviewId': reviewId,
          'route': '/reviews',
        },
        read: false,
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());
      debugPrint('✅ Created review reply notification for student $studentId');
    } catch (e) {
      debugPrint('❌ Error creating review reply notification: $e');
    }
  }

  /// Marks a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Marks all notifications for a user as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Deletes a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  /// Gets unread notification count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Stream of notifications for a user
  Stream<List<AppNotification>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
      notifications.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );
      if (notifications.length > 50) {
        return notifications.sublist(0, 50);
      }
      return notifications;
    });
  }

  /// Stream of unread count for a user
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Backfills legacy notifications that may have been stored without `userId`
  /// or `createdAt` fields so they appear correctly in in-app feeds.
  Future<void> syncLegacyNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return;

      int updates = 0;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final currentUserId = data['userId'] as String?;
        final createdAt = data['createdAt'];
        final legacyTimestamp = data['timestamp'];

        final updateData = <String, dynamic>{};
        if (currentUserId == null || currentUserId.isEmpty) {
          updateData['userId'] = userId;
        }
        if (createdAt == null && legacyTimestamp != null) {
          updateData['createdAt'] = legacyTimestamp;
        }

        if (updateData.isNotEmpty) {
          batch.update(doc.reference, updateData);
          updates++;
        }
      }

      if (updates > 0) {
        await batch.commit();
        debugPrint('🔁 Synced $updates legacy notifications for $userId');
      }
    } catch (e) {
      debugPrint('❌ Error syncing legacy notifications: $e');
    }
  }
}
