import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import '../studentScreens/login.dart';
import '../companyScreens/companySignup.dart'; // Make sure this path is correct


void main() async {
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
      theme: ThemeData(
        // The theme has been simplified to focus on your app's design
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // This is the key change. The home property now points to your
      // StudentSignup, making it the first page that loads.
      home: const LoginScreen(),
    );
  }
}
