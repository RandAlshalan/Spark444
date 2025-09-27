// AuthService.dart - FULL MODIFIED FILE

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/company.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String kStudentCol = 'student';
  static const String kCompanyCol = 'companies';

  // ... (All other functions like _normalizeEmail, signUpStudent, etc., remain the same)
  
  // ------------------------------
  // Helpers (No changes here)
  // ------------------------------
  static final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  String _normalizeEmail(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    return t.replaceAll(' ', '').toLowerCase();
  }

  String _normalizeUsername(String raw) {
    return raw.trim().toLowerCase();
  }

  Future<Map<String, List<String>>> getUniversitiesAndMajors() async {
    try {
      DocumentSnapshot uniDoc =
          await _db.collection('lists').doc('universities').get();

      DocumentSnapshot majorDoc =
          await _db.collection('lists').doc('majors').get();

      final List<String> universities = uniDoc.exists
          ? List<String>.from(
              (uniDoc.data() as Map<String, dynamic>)['names'] ?? [],
            )
          : [];

      final List<String> majors = majorDoc.exists
          ? List<String>.from(
              (majorDoc.data() as Map<String, dynamic>)['names'] ?? [],
            )
          : [];

      return {'universities': universities, 'majors': majors};
    } catch (e) {
      print("Error fetching lists: $e");
      return {'universities': [], 'majors': []};
    }
  }

  Future<void> cancelSignUpAndDeleteUser() async {
    final User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await _db.collection(kStudentCol).doc(user.uid).delete();
        await user.delete();
      } catch (e) {
        print("Error cancelling sign-up: $e");
        throw Exception(
          "Could not cancel sign-up. Please sign out and sign in again to resolve.",
        );
      }
    }
  }

  Future<bool> isUsernameUnique(String username) async {
    if (username.trim().isEmpty) return false;
    final normalizedUsername = _normalizeUsername(username);

    final studentSnap = await _db
        .collection(kStudentCol)
        .where('username_lower', isEqualTo: normalizedUsername)
        .limit(1)
        .get();

    if (studentSnap.docs.isNotEmpty) return false;

    final companySnap = await _db
        .collection(kCompanyCol)
        .where('username_lower', isEqualTo: normalizedUsername)
        .limit(1)
        .get();

    if (companySnap.docs.isNotEmpty) return false;

    return true;
  }
  
  // ------------------------------
  // Sign Up Functions (No changes here)
  // ------------------------------
  Future<User?> signUpStudent(Student student, String password) async {
    try {
      final isUnique = await isUsernameUnique(student.username);
      if (!isUnique) {
        throw Exception(
          "This username is already taken. Please choose another one.",
        );
      }
      final emailNorm = _normalizeEmail(student.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to create an account. Please try again.");
      }
      await user.sendEmailVerification();
      final studentMap = student.toMap();
      studentMap['email'] = emailNorm;
      studentMap['isVerified'] = false;
      studentMap['isAcademic'] = student.isAcademic;
      studentMap['username_lower'] = _normalizeUsername(student.username);
      studentMap['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection(kStudentCol).doc(user.uid).set(studentMap);
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("This email address is already in use.");
      } else if (e.code == 'weak-password') {
        throw Exception("The password provided is too weak.");
      }
      throw Exception(e.message ?? "An unknown error occurred.");
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signUpCompany(Company company, String password) async {
    try {
      final isUnique = await isUsernameUnique(company.companyName);
      if (!isUnique) {
        throw Exception(
          "This username is already taken. Please choose another one.",
        );
      }
      final emailNorm = _normalizeEmail(company.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to create an account. Please try again.");
      }
      // Companies also get a verification email on signup
      await user.sendEmailVerification();
      final companyMap = company.toMap();
      companyMap['email'] = emailNorm;
      companyMap['isVerified'] = false;
      companyMap['username_lower'] = _normalizeUsername(company.companyName);
      companyMap['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection(kCompanyCol).doc(user.uid).set(companyMap);
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("This email address is already in use.");
      } else if (e.code == 'weak-password') {
        throw Exception("The password provided is too weak.");
      }
      throw Exception(e.message ?? "An unknown error occurred.");
    } catch (e) {
      rethrow;
    }
  }

  // ------------------------------
  // Resolve identifier → email (No changes here)
  // ------------------------------
  Future<String> _resolveEmailFromIdentifier(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) throw Exception("Please enter a username or email.");

    if (raw.contains('@')) {
      final email = _normalizeEmail(raw);
      if (!_emailRegex.hasMatch(email)) {
        throw Exception("Invalid email format.");
      }
      return email;
    }

    final uname = _normalizeUsername(raw);

    final studentSnap = await _db
        .collection(kStudentCol)
        .where('username_lower', isEqualTo: uname)
        .limit(1)
        .get();
    if (studentSnap.docs.isNotEmpty) {
      final data = studentSnap.docs.first.data();
      final email = _normalizeEmail((data['email'] as String?) ?? '');
      if (email.isEmpty || !_emailRegex.hasMatch(email)) {
        throw Exception("User record is missing a valid email.");
      }
      return email;
    }

    final companySnap = await _db
        .collection(kCompanyCol)
        .where('username_lower', isEqualTo: uname)
        .limit(1)
        .get();
    if (companySnap.docs.isNotEmpty) {
      final data = companySnap.docs.first.data();
      final email = _normalizeEmail((data['email'] as String?) ?? '');
      if (email.isEmpty || !_emailRegex.hasMatch(email)) {
        throw Exception("Company record is missing a valid email.");
      }
      return email;
    }

    throw Exception("User not found.");
  }

  // ------------------------------
  // Login (✅ MAJOR CHANGE HERE)
  // ------------------------------
  /// Returns a Map with 'userType' and 'isVerified' status.
  /// Throws an exception for students if not verified, but allows companies.
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final email = await _resolveEmailFromIdentifier(identifier);
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("User not found.");

      // First, determine the user type from Firestore
      final studentDoc = await _db.collection(kStudentCol).doc(user.uid).get();
      if (studentDoc.exists) {
        // It's a student, enforce verification
        await user.reload();
        if (!user.emailVerified) {
          throw Exception('Please verify your email address first.');
        }
        if (studentDoc.data()?['isVerified'] != true) {
          await updateVerificationStatus(user.uid, true);
        }
        return {'userType': 'student', 'isVerified': true};
      }

      final companyDoc = await _db.collection(kCompanyCol).doc(user.uid).get();
      if (companyDoc.exists) {
        // It's a company, allow login but return verification status
        await user.reload();
        final bool isVerified = user.emailVerified;
        
        // If not verified, resend the email as a helpful reminder
        if (!isVerified) {
            await user.sendEmailVerification();
        } else if (companyDoc.data()?['isVerified'] != true) {
            // If verified on Auth but not in Firestore, update Firestore
            await _db.collection(kCompanyCol).doc(user.uid).update({'isVerified': true});
        }
        
        return {'userType': 'company', 'isVerified': isVerified};
      }

      throw Exception("User type not found in the system.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception('Incorrect email or password.');
      }
      throw Exception(e.message ?? "Login failed.");
    } catch (e) {
      rethrow;
    }
  }

  // ... (All other functions like resetPassword, getStudent, etc., remain the same)
  
  // ------------------------------
  // Reset Password (No changes here)
  // ------------------------------
  Future<void> resetPassword(String identifier) async {
    try {
      final email = await _resolveEmailFromIdentifier(identifier);
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(
        "Failed to send reset link. Please ensure the email or username is correct.",
      );
    }
  }

  // ------------------------------
  // Verification Status Helpers (No changes here)
  // ------------------------------
  Future<bool> isUserEmailVerified() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  Future<void> updateVerificationStatus(String uid, bool isVerified) async {
    await _db.collection(kStudentCol).doc(uid).update({
      'isVerified': isVerified,
    });
  }

  // ------------------------------
  // Get/Update Data (No changes here)
  // ------------------------------
  Future<Student?> getStudent(String uid) async {
    final doc = await _db.collection(kStudentCol).doc(uid).get();
    if (!doc.exists) return null;
    return Student.fromMap(doc.data()!);
  }

  Future<void> updateStudent(String uid, Student student) async {
    final data = student.toMap(includeMetadata: false);
    data['username_lower'] = _normalizeUsername(student.username);
    await _db.collection(kStudentCol).doc(uid).update(data);
  }

  Future<void> updateStudentPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found.');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword.trim(),
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword.trim());
  }

  Future<void> updateStudentEmail({
    required String password,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found.');
    }

    final normalizedEmail = _normalizeEmail(newEmail);
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password.trim(),
    );

    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(normalizedEmail);
    await _db.collection(kStudentCol).doc(user.uid).update({
      'email': normalizedEmail,
    });
  }

  Future<Company?> getCompany(String uid) async {
    final doc = await _db.collection(kCompanyCol).doc(uid).get();
    if (!doc.exists) return null;
    return Company.fromMap(doc.data()!);
  }

  Future<void> updateCompany(String uid, Company company) async {
    await _db.collection(kCompanyCol).doc(uid).update(company.toMap());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<Student?> getCurrentStudent() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getStudent(user.uid);
  }

  Future<Company?> getCurrentCompany() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getCompany(user.uid);
  }
}