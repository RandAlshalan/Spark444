import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// NotificationService - Singleton Class
/// ============================================================================
/// Handles all push notifications (Firebase Cloud Messaging) and local
/// notifications across Android and iOS.
///
/// Features:
/// - Requests notification permissions
/// - Handles foreground and background messages
/// - Displays notifications using flutter_local_notifications
/// - Saves FCM token to Firestore
/// - Navigates to /notifications when user taps a notification
/// ============================================================================

class NotificationService {
  // Singleton pattern - ensures only one instance exists
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Firebase Messaging instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Flutter Local Notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Navigation key for routing when notification is tapped
  static GlobalKey<NavigatorState>? navigatorKey;

  // Track if service is initialized
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentUserCollection;

  // Stream controller for notification taps
  final StreamController<String?> _notificationTapController =
      StreamController<String?>.broadcast();

  Stream<String?> get onNotificationTap => _notificationTapController.stream;

  /// ========================================================================
  /// Initialize Notification Service
  /// ========================================================================
  /// Call this in main() after Firebase initialization
  /// ========================================================================
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    try {
      // Set navigation key for routing
      if (navKey != null) {
        navigatorKey = navKey;
      }

      // Step 1: Request notification permissions
      await _requestPermissions();

      // Step 2: Initialize local notifications
      await _initializeLocalNotifications();

      // Step 3: Configure foreground notification presentation (iOS)
      await _configureForegroundNotifications();

      // Step 4: Handle foreground messages
      _handleForegroundMessages();

      // Step 5: Handle notification taps (when app is terminated/background)
      _handleNotificationTaps();

      // Step 6: Get and save FCM token
      await _getFCMToken();

      // Step 7: Listen for token refresh
      _listenForTokenRefresh();

      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// ========================================================================
  /// Step 1: Request Notification Permissions
  /// ========================================================================
  /// iOS requires explicit permission request
  /// Android 13+ (API 33+) also requires runtime permission
  /// ========================================================================
  Future<void> _requestPermissions() async {
    try {
      // Request permission for iOS and Android 13+
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permissions');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ User granted provisional notification permissions');
      } else {
        debugPrint('❌ User declined or has not accepted notification permissions');
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  /// ========================================================================
  /// Step 2: Initialize Local Notifications Plugin
  /// ========================================================================
  /// Configures Android and iOS notification channels and settings
  /// ========================================================================
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize with callback for when notification is tapped
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android notification channel (required for Android 8.0+)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'spark_channel', // id
        'Spark Notifications', // name
        description: 'Notifications for Spark app', // description
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      // Create the channel on the device
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('✅ Local notifications initialized');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  /// ========================================================================
  /// Step 3: Configure Foreground Notification Presentation (iOS)
  /// ========================================================================
  /// iOS requires explicit configuration to show notifications in foreground
  /// ========================================================================
  Future<void> _configureForegroundNotifications() async {
    try {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true, // Show notification banner
        badge: true, // Update badge count
        sound: true, // Play sound
      );
      debugPrint('✅ Foreground notifications configured');
    } catch (e) {
      debugPrint('❌ Error configuring foreground notifications: $e');
    }
  }

  /// ========================================================================
  /// Step 4: Handle Foreground Messages
  /// ========================================================================
  /// Called when app is in foreground and receives a push notification
  /// ========================================================================
  void _handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground message received: ${message.messageId}');

      // Extract notification data
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        debugPrint('Title: ${notification.title}');
        debugPrint('Body: ${notification.body}');

        // Display local notification when in foreground
        _displayLocalNotification(
          title: notification.title ?? 'Spark',
          body: notification.body ?? '',
          payload: data['route'] ?? '/notifications',
        );
      }
    });
  }

  /// ========================================================================
  /// Step 5: Handle Notification Taps
  /// ========================================================================
  /// Handles when user taps notification (from terminated or background state)
  /// ========================================================================
  void _handleNotificationTaps() {
    // Handle notification tap when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('🔔 App opened from terminated state via notification');
        _handleNotificationNavigation(message.data);
      }
    });

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 App opened from background state via notification');
      _handleNotificationNavigation(message.data);
    });
  }

  /// ========================================================================
  /// Handle Navigation from Notification Tap
  /// ========================================================================
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      // Get route from notification data, default to /notifications
      final String route = data['route'] ?? '/notifications';

      debugPrint('Navigating to: $route');

      // Navigate using the global navigation key
      if (navigatorKey?.currentState != null) {
        navigatorKey!.currentState!.pushNamed(route);
      } else {
        // If navigator not available, emit event for app to handle
        _notificationTapController.add(route);
      }
    } catch (e) {
      debugPrint('❌ Error handling notification navigation: $e');
    }
  }

  /// ========================================================================
  /// Callback when Local Notification is Tapped
  /// ========================================================================
  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    debugPrint('🔔 Local notification tapped with payload: $payload');

    if (payload != null && navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed(payload);
    } else if (payload != null) {
      _notificationTapController.add(payload);
    }
  }

  /// ========================================================================
  /// Display Local Notification
  /// ========================================================================
  /// Shows a notification using flutter_local_notifications
  /// ========================================================================
  Future<void> _displayLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Android notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'spark_channel', // Must match channel id created earlier
        'Spark Notifications',
        channelDescription: 'Notifications for Spark app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      // iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combined notification details
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique notification ID
        title,
        body,
        notificationDetails,
        payload: payload ?? '/notifications',
      );

      debugPrint('✅ Local notification displayed: $title');
    } catch (e) {
      debugPrint('❌ Error displaying local notification: $e');
    }
  }

  /// ========================================================================
  /// Step 6: Get and Save FCM Token
  /// ========================================================================
  /// Retrieves device FCM token and saves to Firestore
  /// ========================================================================
  Future<void> _getFCMToken() async {
    try {
      // Get the FCM token for this device
      final String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        debugPrint('📱 FCM Token: $token');
        // Token will be saved when user logs in (call saveFCMToken from login)
      } else {
        debugPrint('⚠️ FCM token is null');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// ========================================================================
  /// Save FCM Token to Firestore
  /// ========================================================================
  /// Call this after user logs in to save their device token
  /// userType should be 'student' or 'companies'
  /// ========================================================================
  Future<void> saveFCMToken(String userId, {String userType = 'student'}) async {
    try {
      final String? token = await _firebaseMessaging.getToken();

      if (token != null && userId.isNotEmpty) {
        await _persistFCMToken(
          userId: userId,
          collectionPath: userType,
          token: token,
        );
        debugPrint('✅ FCM token saved to Firestore for $userType: $userId');
      } else {
        debugPrint('⚠️ Cannot save FCM token: token or userId is null');
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM token to Firestore: $e');
    }
  }

  Future<void> _persistFCMToken({
    required String userId,
    required String collectionPath,
    required String token,
  }) async {
    await FirebaseFirestore.instance.collection(collectionPath).doc(userId).set({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _currentUserId = userId;
    _currentUserCollection = collectionPath;
  }

  Future<String?> _resolveUserCollection(String userId) async {
    final studentDoc =
        await FirebaseFirestore.instance.collection('student').doc(userId).get();
    if (studentDoc.exists) return 'student';

    final companyDoc =
        await FirebaseFirestore.instance.collection('companies').doc(userId).get();
    if (companyDoc.exists) return 'companies';

    return null;
  }

  Future<void> syncFCMTokenWithLoggedInUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('ℹ️ No logged in user to sync token for');
      return;
    }

    final collection = await _resolveUserCollection(user.uid);
    if (collection == null) {
      debugPrint('⚠️ Unable to determine collection for user ${user.uid}');
      return;
    }

    await saveFCMToken(user.uid, userType: collection);
  }

  /// ========================================================================
  /// Step 7: Listen for Token Refresh
  /// ========================================================================
  /// FCM tokens can be refreshed by Firebase, so we need to update Firestore
  /// ========================================================================
  void _listenForTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token refreshed: $newToken');
      if (_currentUserId != null && _currentUserCollection != null) {
        await _persistFCMToken(
          userId: _currentUserId!,
          collectionPath: _currentUserCollection!,
          token: newToken,
        );
      } else {
        await syncFCMTokenWithLoggedInUser();
      }
    });
  }

  /// ========================================================================
  /// Public Method: Show Local Notification Manually
  /// ========================================================================
  /// Use this to trigger notifications from within your app
  /// Example: NotificationService().showLocalNotification('Hello', 'World!')
  /// ========================================================================
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? route,
  }) async {
    await _displayLocalNotification(
      title: title,
      body: body,
      payload: route ?? '/notifications',
    );
  }

  /// ========================================================================
  /// Background Message Handler (Static Method)
  /// ========================================================================
  /// This must be a top-level function (not inside a class method)
  /// Handles messages when app is in background or terminated
  /// ========================================================================
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    // Initialize Firebase if not already initialized
    await Firebase.initializeApp();

    debugPrint('📩 Background message received: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');

    // Note: You cannot show local notifications directly here on iOS
    // iOS will automatically show the notification
    // On Android, you can show a notification if needed
  }

  /// ========================================================================
  /// Delete FCM Token
  /// ========================================================================
  /// Call this when user logs out to remove their device token
  /// userType should be 'student' or 'companies'
  /// ========================================================================
  Future<void> deleteFCMToken(String userId, {String userType = 'student'}) async {
    try {
      // Delete token from Firebase
      await _firebaseMessaging.deleteToken();

      // Remove token from Firestore
      if (userId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(userType)
            .doc(userId)
            .update({
          'fcmToken': FieldValue.delete(),
        });
      }

      if (_currentUserId == userId) {
        _currentUserId = null;
        _currentUserCollection = null;
      }

      debugPrint('✅ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }

  /// ========================================================================
  /// Dispose
  /// ========================================================================
  void dispose() {
    _notificationTapController.close();
  }
}
