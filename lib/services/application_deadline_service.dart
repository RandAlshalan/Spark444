import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to automatically update application statuses when response deadline passes
class ApplicationDeadlineService {
  static final ApplicationDeadlineService _instance = ApplicationDeadlineService._internal();
  factory ApplicationDeadlineService() => _instance;
  ApplicationDeadlineService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _checkTimer;
  bool _isRunning = false;

  /// Start the background service to check for expired response deadlines
  /// Checks every 30 minutes
  void startMonitoring() {
    if (_isRunning) {
      debugPrint('⚠️ ApplicationDeadlineService already running');
      return;
    }

    _isRunning = true;
    debugPrint('✅ ApplicationDeadlineService started');

    // Run immediately on start
    _checkExpiredDeadlines();

    // Then check every 30 minutes
    _checkTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _checkExpiredDeadlines();
    });
  }

  /// Stop the monitoring service
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
    debugPrint('⏹️ ApplicationDeadlineService stopped');
  }

  /// Check for opportunities with expired response deadlines and update applications
  Future<void> _checkExpiredDeadlines() async {
    try {
      debugPrint('🔍 Checking for expired response deadlines...');

      final now = Timestamp.now();

      // Find all active opportunities with response deadlines that have passed
      final expiredOpportunitiesSnapshot = await _firestore
          .collection('opportunities')
          .where('isActive', isEqualTo: true)
          .where('responseDeadline', isLessThan: now)
          .get();

      if (expiredOpportunitiesSnapshot.docs.isEmpty) {
        debugPrint('✅ No expired response deadlines found');
        return;
      }

      debugPrint('📋 Found ${expiredOpportunitiesSnapshot.docs.length} opportunities with expired deadlines');

      int totalUpdated = 0;

      // Process each expired opportunity
      for (final oppDoc in expiredOpportunitiesSnapshot.docs) {
        final opportunityId = oppDoc.id;
        final oppData = oppDoc.data();
        final responseDeadline = oppData['responseDeadline'] as Timestamp?;

        if (responseDeadline == null) continue;

        debugPrint('Processing opportunity: $opportunityId');

        // Find all pending applications for this opportunity
        final pendingApplicationsSnapshot = await _firestore
            .collection('applications')
            .where('opportunityId', isEqualTo: opportunityId)
            .where('status', isEqualTo: 'Pending')
            .get();

        if (pendingApplicationsSnapshot.docs.isEmpty) {
          debugPrint('  No pending applications for this opportunity');
          continue;
        }

        // Update all pending applications to "No Response"
        final batch = _firestore.batch();
        int batchCount = 0;

        for (final appDoc in pendingApplicationsSnapshot.docs) {
          batch.update(appDoc.reference, {
            'status': 'No Response',
            'lastStatusUpdateDate': Timestamp.now(),
            'autoUpdated': true, // Flag to indicate this was automatically updated
            'autoUpdatedReason': 'Response deadline passed',
          });
          batchCount++;

          // Firestore batch limit is 500, commit if we reach that
          if (batchCount >= 500) {
            await batch.commit();
            totalUpdated += batchCount;
            batchCount = 0;
          }
        }

        // Commit remaining updates
        if (batchCount > 0) {
          await batch.commit();
          totalUpdated += batchCount;
        }

        debugPrint('  Updated $batchCount applications to "No Response"');

        // Optionally: Mark opportunity as processed to avoid checking it again
        // You can add a field like 'deadlineProcessed' to the opportunity
        await _firestore.collection('opportunities').doc(opportunityId).update({
          'deadlineProcessed': true,
          'deadlineProcessedAt': Timestamp.now(),
        });
      }

      debugPrint('✅ Total applications updated: $totalUpdated');
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking expired deadlines: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Manually trigger a check (useful for testing or on-demand updates)
  Future<void> checkNow() async {
    debugPrint('🔄 Manual deadline check triggered');
    await _checkExpiredDeadlines();
  }

  /// Check and update applications for a specific opportunity
  Future<void> checkOpportunity(String opportunityId) async {
    try {
      debugPrint('🔍 Checking opportunity: $opportunityId');

      // Get the opportunity
      final oppDoc = await _firestore.collection('opportunities').doc(opportunityId).get();

      if (!oppDoc.exists) {
        debugPrint('⚠️ Opportunity not found');
        return;
      }

      final oppData = oppDoc.data()!;
      final responseDeadline = oppData['responseDeadline'] as Timestamp?;
      final isActive = oppData['isActive'] ?? true;

      if (responseDeadline == null) {
        debugPrint('⚠️ Opportunity has no response deadline');
        return;
      }

      if (!isActive) {
        debugPrint('⚠️ Opportunity is not active');
        return;
      }

      final now = Timestamp.now();
      if (responseDeadline.toDate().isAfter(now.toDate())) {
        debugPrint('⚠️ Response deadline has not passed yet');
        return;
      }

      // Find all pending applications
      final pendingApplicationsSnapshot = await _firestore
          .collection('applications')
          .where('opportunityId', isEqualTo: opportunityId)
          .where('status', isEqualTo: 'Pending')
          .get();

      if (pendingApplicationsSnapshot.docs.isEmpty) {
        debugPrint('✅ No pending applications to update');
        return;
      }

      // Update all to "No Response"
      final batch = _firestore.batch();
      for (final appDoc in pendingApplicationsSnapshot.docs) {
        batch.update(appDoc.reference, {
          'status': 'No Response',
          'lastStatusUpdateDate': Timestamp.now(),
          'autoUpdated': true,
          'autoUpdatedReason': 'Response deadline passed',
        });
      }

      await batch.commit();

      // Mark opportunity as processed
      await _firestore.collection('opportunities').doc(opportunityId).update({
        'deadlineProcessed': true,
        'deadlineProcessedAt': Timestamp.now(),
      });

      debugPrint('✅ Updated ${pendingApplicationsSnapshot.docs.length} applications to "No Response"');
    } catch (e) {
      debugPrint('❌ Error checking opportunity deadline: $e');
    }
  }

  /// Get status of the service
  bool get isRunning => _isRunning;
}
