import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Handles saving the current user's FCM token under `users/{uid}` and keeps it
/// in sync whenever Firebase refreshes the token.
class FcmTokenManager {
  FcmTokenManager._();

  static StreamSubscription<String>? _refreshSubscription;

  /// Requests notification permission (needed on iOS), saves the current token
  /// to `users/{uid}`, and listens for future token refresh events.
  static Future<void> saveUserFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('🔕 No authenticated user. Skipping FCM token save.');
        return;
      }

      // iOS (and Android 13+) permission prompt
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ Notification permission denied. Token will not be saved.');
        return;
      }

      final token = await _obtainFcmToken();
      if (token == null) {
        debugPrint('⌛ FCM token not yet available. Waiting for refresh event.');
        _ensureTokenRefreshListener();
        return;
      }

      await _writeToken(user.uid, token);
      debugPrint('✅ Saved FCM token for ${user.uid}');

      // Also keep legacy student/companies collections in sync
      await NotificationService().syncFCMTokenWithLoggedInUser();

      _ensureTokenRefreshListener();
    } catch (e) {
      debugPrint('❌ Error while saving FCM token: $e');
      _ensureTokenRefreshListener();
    }
  }

  static Future<String?> _obtainFcmToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final apnsReady = await _waitForApnsToken();
        if (!apnsReady) {
          return null;
        }
      }

      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('⚠️ Could not obtain FCM token: $e');
      return null;
    }
  }

  static Future<bool> _waitForApnsToken({Duration timeout = const Duration(seconds: 10)}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('⚠️ APNS token not ready after waiting. Will rely on refresh callback.');
    return false;
  }

  static void _ensureTokenRefreshListener() {
    _refreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) {
        debugPrint('ℹ️ Token refreshed but no user is logged in.');
        return;
      }
      try {
        await _writeToken(current.uid, newToken);
        debugPrint('♻️ Updated refreshed FCM token for ${current.uid}');
        await NotificationService().syncFCMTokenWithLoggedInUser();
      } catch (e) {
        debugPrint('❌ Failed to update refreshed token: $e');
      }
    });
  }

  static Future<void> _writeToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
