// AuthService.dart - MODIFIED FOR COMPANY EMAIL-ONLY LOGIN

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/student.dart';
import '../models/company.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String kStudentCol = 'student';
  static const String kCompanyCol = 'companies';

  // ------------------------------
  // Helpers
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
      DocumentSnapshot uniDoc = await _db.collection('lists').doc('universities').get();
      DocumentSnapshot majorDoc = await _db.collection('lists').doc('majors').get();
      DocumentSnapshot cityDoc = await _db.collection('lists').doc('city').get();

      final List<String> universities = uniDoc.exists
          ? List<String>.from((uniDoc.data() as Map<String, dynamic>)['names'] ?? [])
          : [];

      final List<String> majors = majorDoc.exists
          ? List<String>.from((majorDoc.data() as Map<String, dynamic>)['names'] ?? [])
          : [];
      final List<String> city = cityDoc.exists
          ? List<String>.from((cityDoc.data() as Map<String, dynamic>)['names'] ?? [])
          : [];

      return {'universities': universities, 'majors': majors, 'cities': city};
    } catch (e) {
      print("Error fetching lists: $e");
      return {'universities': [], 'majors': [], 'cities': []};
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
  // Sign Up Functions
  // ------------------------------
  Future<User?> signUpStudent(Student student, String password) async {
    try {
      final isUnique = await isUsernameUnique(student.username);
      if (!isUnique) throw Exception("This username is already taken. Please choose another one.");

      final emailNorm = _normalizeEmail(student.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("Failed to create an account.");

      await user.sendEmailVerification();

      final studentMap = student.toMap();
      studentMap['email'] = emailNorm;
      studentMap['isVerified'] = false;
      studentMap['isAcademic'] = student.isAcademic;
      studentMap['username_lower'] = _normalizeUsername(student.username);
      studentMap['createdAt'] = FieldValue.serverTimestamp();

      await _db.collection(kStudentCol).doc(user.uid).set(studentMap);

      final written = await _db.collection(kStudentCol).doc(user.uid).get();
      if (!written.exists) throw Exception("Student Firestore doc was not created.");

      return user;

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception("This email address is already in use.");
        case 'weak-password':
          throw Exception("The password provided is too weak.");
        default:
          throw Exception(e.message ?? e.code);
      }
    }
  }

  Future<User?> signUpCompany(Company company, String password) async {
    try {
      final isUnique = await isUsernameUnique(company.companyName);
      if (!isUnique) throw Exception("This username is already taken. Please choose another one.");

      final emailNorm = _normalizeEmail(company.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("Failed to create an account.");

      await user.sendEmailVerification();

      final companyMap = company.toMap();
      companyMap['email'] = emailNorm;
      companyMap['isVerified'] = false;
      companyMap['username_lower'] = _normalizeUsername(company.companyName);
      companyMap['createdAt'] = FieldValue.serverTimestamp();

      await _db.collection(kCompanyCol).doc(user.uid).set(companyMap);

      final written = await _db.collection(kCompanyCol).doc(user.uid).get();
      if (!written.exists) throw Exception("Company Firestore doc was not created.");

      return user;

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception("This email address is already in use.");
        case 'weak-password':
          throw Exception("The password provided is too weak.");
        default:
          throw Exception(e.message ?? e.code);
      }
    }
  }

  // ------------------------------
  // Resolve identifier → email
  // ------------------------------
  Future<String> _resolveEmailFromIdentifier(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) throw Exception("Please enter a username or email.");

    // If the identifier contains '@', it's an email. This works for both students and companies.
    if (raw.contains('@')) {
      final email = _normalizeEmail(raw);
      if (!_emailRegex.hasMatch(email)) throw Exception("Invalid email format.");
      return email;
    }

    // If it does NOT contain '@', assume it's a student's username.
    final uname = _normalizeUsername(raw);

    try {
      // Check student collection for the username
      final studentSnap = await _db.collection(kStudentCol)
          .where('username_lower', isEqualTo: uname)
          .limit(1)
          .get();

      if (studentSnap.docs.isNotEmpty) {
        final email = _normalizeEmail((studentSnap.docs.first.data()['email'] as String?) ?? '');
        if (email.isEmpty || !_emailRegex.hasMatch(email)) throw Exception("User record is missing an email");
        return email;
      }
      
      // ✅ MODIFICATION: The logic to check for a company name has been completely removed.

    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Login failed: permission denied while searching username');
      }
      rethrow;
    }
    
    // If it's not a valid email and not a student username, throw an error.
    // This will be caught by the login screen and show the generic "Wrong email/username or password" message.
    throw FirebaseAuthException(code: 'invalid-credential');
  }

  // ------------------------------
  // Login
  // ------------------------------
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final email = await _resolveEmailFromIdentifier(identifier);

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password.trim(),
    );

    final user = credential.user;
    if (user == null) throw Exception("User not found.");

    final studentDoc = await _db.collection(kStudentCol).doc(user.uid).get();
    if (studentDoc.exists) {
      await user.reload();
      if (!user.emailVerified) throw FirebaseAuthException(code: 'email-not-verified');
      if (studentDoc.data()?['isVerified'] != true) {
        await updateVerificationStatus(user.uid, true);
      }
      return {'userType': 'student', 'isVerified': true};
    }

    final companyDoc = await _db.collection(kCompanyCol).doc(user.uid).get();
    if (companyDoc.exists) {
      await user.reload();
      final bool isVerified = user.emailVerified;

      if (!isVerified) await user.sendEmailVerification();
      else if (companyDoc.data()?['isVerified'] != true) {
        await _db.collection(kCompanyCol).doc(user.uid).update({'isVerified': true});
      }

      return {'userType': 'company', 'isVerified': isVerified};
    }

    throw Exception("User type not found in the system.");
  }

  // ------------------------------
  // Reset Password
  // ------------------------------
  Future<void> resetPassword(String identifier) async {
    final email = await _resolveEmailFromIdentifier(identifier);
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ------------------------------
  // Verification Helpers
  // ------------------------------
  Future<bool> isUserEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  Future<void> updateVerificationStatus(String uid, bool isVerified) async {
    await _db.collection(kStudentCol).doc(uid).update({'isVerified': isVerified});
  }

  // ------------------------------
  // Get/Update Students & Companies 
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

  Future<void> updateStudentPassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('No authenticated user found.');

    final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword.trim());
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword.trim());
  }

  Future<void> updateStudentEmail({required String password, required String newEmail}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('No authenticated user found.');

    final normalizedEmail = _normalizeEmail(newEmail);
    final credential = EmailAuthProvider.credential(email: user.email!, password: password.trim());

    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(normalizedEmail);
    await _db.collection(kStudentCol).doc(user.uid).update({'email': normalizedEmail});
  }

  Future<Company?> getCompany(String uid) async {
    final doc = await _db.collection(kCompanyCol).doc(uid).get();
    if (!doc.exists) return null;
    return Company.fromMap(doc.data()!);
  }

  Future<Company?> getCurrentCompany() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return await getCompany(currentUser.uid);
    return null;
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
}