import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/student.dart';
import '../models/company.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ------------------------------
  // Sign Up Student
  // ------------------------------
  Future<User?> signUpStudent(Student student, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: student.email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user != null) {
        // Set createdAt as server timestamp
        final studentMap = student.toMap();
        studentMap['createdAt'] = FieldValue.serverTimestamp();

        await _db.collection('student').doc(user.uid).set(studentMap);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Firebase Auth Error");
    } catch (e) {
      throw Exception("Unknown error occurred: $e");
    }
  }

  // ------------------------------
  // Sign Up Company
  // ------------------------------
  Future<User?> signUpCompany(Company company, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: company.email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user != null) {
        final companyMap = company.toMap();
        companyMap['createdAt'] = FieldValue.serverTimestamp();

        await _db.collection('companies').doc(user.uid).set(companyMap);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Firebase Auth Error");
    } catch (e) {
      throw Exception("Unknown error occurred: $e");
    }
  }

  // ------------------------------
  // Login (Student or Company)
  // Returns: 'student' or 'company'
  // ------------------------------
  Future<String> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("User not found.");

      // Check if student
      final studentDoc = await _db.collection('student').doc(user.uid).get();
      if (studentDoc.exists) return 'student';

      // Check if company
      final companyDoc = await _db.collection('companies').doc(user.uid).get();
      if (companyDoc.exists) return 'company';

      throw Exception("User type not found in system.");
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Firebase Auth Error");
    } catch (e) {
      throw Exception("Unknown error occurred: $e");
    }
  }

  // ------------------------------
  // Get Student by UID
  // ------------------------------
  Future<Student?> getStudent(String uid) async {
    final doc = await _db.collection('student').doc(uid).get();
    if (!doc.exists) return null;
    return Student.fromMap(doc.data()!);
  }

  // ------------------------------
  // Update Student
  // ------------------------------
  Future<void> updateStudent(String uid, Student student) async {
    await _db.collection('student').doc(uid).update(student.toMap());
  }

  // ------------------------------
  // Get Company by UID
  // ------------------------------
  Future<Company?> getCompany(String uid) async {
    final doc = await _db.collection('companies').doc(uid).get();
    if (!doc.exists) return null;
    return Company.fromMap(doc.data()!);
  }

  // ------------------------------
  // Update Company
  // ------------------------------
  Future<void> updateCompany(String uid, Company company) async {
    await _db.collection('companies').doc(uid).update(company.toMap());
  }

  // ------------------------------
  // Sign Out
  // ------------------------------
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ------------------------------
  // Reset Password (send OTP via Cloud Function)
  // ------------------------------
  Future<String> resetPassword(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw Exception('Email cannot be empty');
    }

    try {
      final response = await _functions
          .httpsCallable('sendPasswordOtp')
          .call(<String, dynamic>{'email': trimmedEmail});

      final data = response.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      return 'OTP sent successfully.';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send OTP.');
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  // ------------------------------
  // Confirm Password Reset using OTP
  // ------------------------------
  Future<String> confirmPasswordResetOtp(
    String email,
    String otp,
    String newPassword,
  ) async {
    final trimmedEmail = email.trim();
    final trimmedOtp = otp.trim();
    final trimmedPassword = newPassword.trim();

    if (trimmedEmail.isEmpty || trimmedOtp.isEmpty || trimmedPassword.isEmpty) {
      throw Exception('Email, OTP, and new password are required.');
    }

    try {
      final response = await _functions.httpsCallable('verifyPasswordOtp').call(
        <String, dynamic>{
          'email': trimmedEmail,
          'otp': trimmedOtp,
          'newPassword': trimmedPassword,
        },
      );

      final data = response.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      return 'Password reset successful.';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to verify OTP.');
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

 
  Future<Student?> getCurrentStudent() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null; 
    }
    final doc = await _db.collection('student').doc(user.uid).get();
    if (!doc.exists) {
      return null;
    }
    return Student.fromMap(doc.data()!);
  }
}