import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/opportunity.dart';
import 'notification_helper.dart';

/// Service to manage deadline notifications for applications and bookmarks
class DeadlineNotificationService {
  static final DeadlineNotificationService _instance = DeadlineNotificationService._internal();
  factory DeadlineNotificationService() => _instance;
  DeadlineNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _reminderCheckTimer;
  bool _isMonitoring = false;

  /// Start monitoring for upcoming deadlines (24 hours before)
  void startMonitoring() {
    if (_isMonitoring) {
      debugPrint('⚠️ DeadlineNotificationService already monitoring');
      return;
    }

    _isMonitoring = true;
    debugPrint('✅ DeadlineNotificationService started monitoring');

    // Check immediately on start
    _checkUpcomingDeadlines();

    // Check every hour for upcoming deadlines
    _reminderCheckTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkUpcomingDeadlines();
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _reminderCheckTimer?.cancel();
    _reminderCheckTimer = null;
    _isMonitoring = false;
    debugPrint('⏹️ DeadlineNotificationService stopped');
  }

  /// Check for deadlines that are 24 hours away and send reminders
  Future<void> _checkUpcomingDeadlines() async {
    try {
      debugPrint('🔍 Checking for upcoming deadlines...');
      
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(hours: 24));
      final dayAfterTomorrow = now.add(const Duration(hours: 25));
      
      // Find opportunities with deadlines in the next 24-25 hours
      final opportunitiesSnapshot = await _firestore
          .collection('opportunities')
          .where('applicationDeadline', isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrow))
          .where('applicationDeadline', isLessThan: Timestamp.fromDate(dayAfterTomorrow))
          .where('isActive', isEqualTo: true)
          .get();

      if (opportunitiesSnapshot.docs.isEmpty) {
        debugPrint('✅ No upcoming deadlines found');
        return;
      }

      debugPrint('📋 Found ${opportunitiesSnapshot.docs.length} opportunities with upcoming deadlines');

      for (final oppDoc in opportunitiesSnapshot.docs) {
        final opportunity = Opportunity.fromFirestore(oppDoc);
        await _sendDeadlineReminders(opportunity);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking upcoming deadlines: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Send deadline reminders to students who bookmarked or applied
  Future<void> _sendDeadlineReminders(Opportunity opportunity) async {
    try {
      final Set<String> studentIds = {};

      // Get students who bookmarked this opportunity
      final bookmarksSnapshot = await _firestore
          .collection('bookmarks')
          .where('opportunityId', isEqualTo: opportunity.id)
          .get();

      for (final doc in bookmarksSnapshot.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        if (studentId != null) studentIds.add(studentId);
      }

      // Get students who applied to this opportunity (pending status)
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('opportunityId', isEqualTo: opportunity.id)
          .where('status', isEqualTo: 'Pending')
          .get();

      for (final doc in applicationsSnapshot.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        if (studentId != null) studentIds.add(studentId);
      }

      if (studentIds.isEmpty) {
        debugPrint('  No students to notify for opportunity ${opportunity.id}');
        return;
      }

      // Get company name
      String companyName = 'Company';
      if (opportunity.companyId.isNotEmpty) {
        final companyDoc = await _firestore
            .collection('companies')
            .doc(opportunity.companyId)
            .get();
        if (companyDoc.exists) {
          final companyData = companyDoc.data();
          companyName = companyData?['companyName'] ?? companyData?['name'] ?? 'Company';
        }
      }

      // Send notification to each student
      final batch = _firestore.batch();
      final notificationsRef = _firestore.collection('notifications');
      final tokens = <String>[];

      for (final studentId in studentIds) {
        // Check if we already sent this reminder
        final existingReminder = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: studentId)
            .where('type', isEqualTo: 'deadline_reminder')
            .where('data.opportunityId', isEqualTo: opportunity.id)
            .get();

        if (existingReminder.docs.isNotEmpty) {
          continue; // Skip if already sent
        }

        // Get student's FCM token
        final studentDoc = await _firestore.collection('student').doc(studentId).get();
        if (studentDoc.exists) {
          final studentData = studentDoc.data();
          final fcmToken = studentData?['fcmToken'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            tokens.add(fcmToken);
          }
        }

        // Create in-app notification
        final notificationData = {
          'userId': studentId,
          'type': 'deadline_reminder',
          'title': '⏰ Deadline Reminder',
          'body': 'Reminder: ${opportunity.role} at $companyName deadline is tomorrow!',
          'data': {
            'opportunityId': opportunity.id,
            'opportunityRole': opportunity.role,
            'companyName': companyName,
            'companyId': opportunity.companyId,
            'route': '/opportunities',
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        };

        batch.set(notificationsRef.doc(), notificationData);
      }

      await batch.commit();

      debugPrint('✅ Sent deadline reminders for ${opportunity.role} to ${studentIds.length} students');
    } catch (e) {
      debugPrint('❌ Error sending deadline reminders: $e');
    }
  }

  /// Send immediate notification when student applies or bookmarks
  Future<void> sendImmediateDeadlineNotification({
    required String studentId,
    required String opportunityId,
    required String action, // 'applied' or 'bookmarked'
  }) async {
    try {
      // Get opportunity details
      final oppDoc = await _firestore.collection('opportunities').doc(opportunityId).get();
      if (!oppDoc.exists) {
        debugPrint('❌ Opportunity not found: $opportunityId');
        return;
      }

      final opportunity = Opportunity.fromFirestore(oppDoc);
      
      if (opportunity.applicationDeadline == null) {
        debugPrint('ℹ️ Opportunity has no deadline');
        return;
      }

      // Get company name
      String companyName = 'Company';
      if (opportunity.companyId.isNotEmpty) {
        final companyDoc = await _firestore
            .collection('companies')
            .doc(opportunity.companyId)
            .get();
        if (companyDoc.exists) {
          final companyData = companyDoc.data();
          companyName = companyData?['companyName'] ?? companyData?['name'] ?? 'Company';
        }
      }

      // Format deadline
      final deadlineDate = opportunity.applicationDeadline!.toDate();
      final daysUntil = deadlineDate.difference(DateTime.now()).inDays;
      
      String deadlineText;
      if (daysUntil == 0) {
        deadlineText = 'today';
      } else if (daysUntil == 1) {
        deadlineText = 'tomorrow';
      } else {
        deadlineText = 'in $daysUntil days';
      }

      final title = action == 'applied' 
          ? '📅 Application Deadline' 
          : '📌 Bookmark Reminder';
      
      final body = 'The deadline for ${opportunity.role} at $companyName is $deadlineText';

      // Create in-app notification
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'type': 'deadline_info',
        'title': title,
        'body': body,
        'data': {
          'opportunityId': opportunity.id,
          'opportunityRole': opportunity.role,
          'companyName': companyName,
          'companyId': opportunity.companyId,
          'deadline': opportunity.applicationDeadline,
          'route': '/opportunities',
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Sent immediate deadline notification to student $studentId');
    } catch (e) {
      debugPrint('❌ Error sending immediate deadline notification: $e');
    }
  }

  bool get isMonitoring => _isMonitoring;
}