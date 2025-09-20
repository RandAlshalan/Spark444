import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/company.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  // Reset Password (send reset email)
  // ------------------------------ 
  Future<void> resetPassword(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw Exception('Email cannot be empty');
    }
    await _auth.sendPasswordResetEmail(email: e);
  }
}
