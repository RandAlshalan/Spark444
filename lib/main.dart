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
    // This must be set before runApp() is called
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('Background message handler registered');
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
  // Global navigation key for routing from notifications
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Step 3: Initialize services after app starts
    _initializeServices();
  }

  /// ========================================================================
  /// Initialize Services
  /// ========================================================================
  /// This sets up notifications and application deadline monitoring
  /// ========================================================================
  Future<void> _initializeServices() async {
    try {
      // Initialize notification service
      await NotificationService().initialize(navKey: _navigatorKey);
      await NotificationService().syncFCMTokenWithLoggedInUser();
      await FcmTokenManager.saveUserFcmToken();
      print('NotificationService initialized in MyApp');

      // Start application deadline monitoring service
      ApplicationDeadlineService().startMonitoring();
      print('ApplicationDeadlineService started');
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  @override
  void dispose() {
    // Stop the deadline monitoring service when app is disposed
    ApplicationDeadlineService().stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Set the navigation key so NotificationService can navigate
      navigatorKey: _navigatorKey,
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
        // Add route for notifications page (you'll need to create this)
        // '/notifications': (_) => const NotificationsPage(),
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }
}
