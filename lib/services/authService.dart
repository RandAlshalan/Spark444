import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark/models/student.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Validate if the email belongs to the university domain
  bool isValidUniversityEmail(String email, String domain) {
    return email.toLowerCase().endsWith(domain.toLowerCase());
  }

  /// Sign up a new student
  Future<void> signUp(student student, String password, String domain) async {
    if (!isValidUniversityEmail(student.email, domain)) {
      throw Exception('Email is not a valid university email.');
    }

    // Create account in Firebase Auth
    UserCredential userCredential = await auth.createUserWithEmailAndPassword(
      email: student.email,
      password: password,
    );

    // Send email verification
    await userCredential.user!.sendEmailVerification();

    // Save student data in Firestore
    await firestore.collection('students').doc(userCredential.user!.uid).set(
          student.toMap(),
        );
  }

  /// Sign in using email or username
  Future<User?> signIn(String emailOrUsername, String password) async {
    String email = emailOrUsername;

    // If user entered username instead of email
    if (!emailOrUsername.contains('@')) {
      QuerySnapshot snapshot = await firestore
          .collection('students')
          .where('username', isEqualTo: emailOrUsername)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Student not found.');
      }

      email = snapshot.docs.first['email'];
    }

    UserCredential userCredential =
        await auth.signInWithEmailAndPassword(email: email, password: password);

    if (!userCredential.user!.emailVerified) {
      throw Exception('Please verify your email first.');
    }

    return userCredential.user;
  }

  /// Reset password via email
  Future<void> resetPassword(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> logout() async {
    await auth.signOut();
  }
}
