import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'companyScreens/companySignup.dart';
import 'studentScreens/login.dart';
import 'studentScreens/studentSignup.dart';
import 'studentScreens/StudentProfilePage.dart';
import 'studentScreens/welcomeScreen.dart';
import 'studentScreens/testNotifications.dart';
import 'services/notification_service.dart';
import 'services/fcm_token_manager.dart';
import 'services/application_deadline_service.dart';
import 'services/deadline_notification_service.dart';

// ✅ ADD: Global navigation key - MUST be declared here at top level
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// ============================================================================
/// Background Message Handler
/// ============================================================================
/// This MUST be a top-level function (not inside a class)
/// Handles push notifications when app is in background or terminated
/// ============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.backgroundHandler(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Step 1: Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    // Step 2: Set background message handler for Firebase Messaging
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('Background message handler registered');

    // Step 3: Initialize notification service with global navigator key
    await NotificationService().initialize(navKey: navigatorKey);
    print('NotificationService initialized');

    // Step 4: Start deadline monitoring service
    DeadlineNotificationService().startMonitoring();
    print('DeadlineNotificationService started');
  } catch (e, s) {
    print('Firebase initialization error: $e');
    print('Stack trace: $s');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// ========================================================================
  /// Initialize Services
  /// ========================================================================
  Future<void> _initializeServices() async {
    try {
      // Sync FCM token for logged-in user
      await NotificationService().syncFCMTokenWithLoggedInUser();
      await FcmTokenManager.saveUserFcmToken();
      print('FCM token synced');

      // Start application deadline monitoring service
      ApplicationDeadlineService().startMonitoring();
      print('ApplicationDeadlineService started');
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  @override
  void dispose() {
    // Stop monitoring services when app is disposed
    ApplicationDeadlineService().stopMonitoring();
    DeadlineNotificationService().stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ✅ Use the global navigation key
      navigatorKey: navigatorKey,
      title: 'SPARK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A4EA5)),
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const StudentSignup(),
        '/companySignup': (_) => const CompanySignup(),
        '/profile': (_) => const StudentProfilePage(),
        '/testNotifications': (_) => const TestNotificationsScreen(),
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }
}
