import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'companyScreens/companySignup.dart';
import 'studentScreens/login.dart';
import 'studentScreens/studentSignup.dart';
import 'studentScreens/StudentProfilePage.dart';
import 'studentScreens/welcomeScreen.dart';
import 'services/notification_service.dart';

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
    // Step 3: Initialize NotificationService after app starts
    _initializeNotifications();
  }

  /// ========================================================================
  /// Initialize NotificationService
  /// ========================================================================
  /// This sets up push notifications and local notifications
  /// ========================================================================
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService().initialize(navKey: _navigatorKey);
      print('NotificationService initialized in MyApp');
    } catch (e) {
      print('Error initializing NotificationService: $e');
    }
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
        // Add route for notifications page (you'll need to create this)
        // '/notifications': (_) => const NotificationsPage(),
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }
}
