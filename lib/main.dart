import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/studentScreens/studentViewProfile.dart';

import 'firebase_options.dart';
import 'companyScreens/companySignup.dart';
import 'studentScreens/login.dart';
import 'studentScreens/studentSignup.dart';
import 'studentScreens/StudentProfilePage.dart';
import 'studentScreens/welcomeScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPARK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A4EA5)),
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        //'/login': (_) => const LoginScreen(),
        '/signup': (_) => const StudentSignup(),
        '/companySignup': (_) => const CompanySignup(),
        '/profile': (_) => const StudentViewProfile(),
      },
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }
}
