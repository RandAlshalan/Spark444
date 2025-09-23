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

  // ------------------------------
  // Sign Up Student
  // ------------------------------
  Future<User?> signUpStudent(Student student, String password) async {
    try {
      final emailNorm = _normalizeEmail(student.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("Auth user was null after sign up.");
      }

      final studentMap = student.toMap();


      studentMap['email'] = emailNorm;


      final usernameRaw = (studentMap['username'] as String?) ?? '';
      studentMap['username_lower'] =
          (studentMap['username_lower'] as String?)
              ?.toString()
              .trim()
              .toLowerCase() ??
          _normalizeUsername(usernameRaw);

      studentMap['createdAt'] = FieldValue.serverTimestamp();

      await _db.collection(kStudentCol).doc(user.uid).set(studentMap);


      final written = await _db.collection(kStudentCol).doc(user.uid).get();
      if (!written.exists) {
        throw Exception("Student Firestore doc was not created.");
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
      final emailNorm = _normalizeEmail(company.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("Auth user was null after sign up.");
      }

      final companyMap = company.toMap();

      companyMap['email'] = emailNorm;
      final usernameRaw = (companyMap['username'] as String?) ?? '';
      companyMap['username_lower'] =
          (companyMap['username_lower'] as String?)
              ?.toString()
              .trim()
              .toLowerCase() ??
          _normalizeUsername(usernameRaw);

      companyMap['createdAt'] = FieldValue.serverTimestamp();

      await _db.collection(kCompanyCol).doc(user.uid).set(companyMap);

      final written = await _db.collection(kCompanyCol).doc(user.uid).get();
      if (!written.exists) {
        throw Exception("Company Firestore doc was not created.");
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Firebase Auth Error");
    } catch (e) {
      throw Exception("Unknown error occurred: $e");
    }
  }

  // ------------------------------
  // Resolve Identifier → Email (Username أو Email)
  // ------------------------------
  Future<String> _resolveEmailFromIdentifier(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) throw Exception("Please enter username/email");

    // 
    if (raw.contains('@')) {
      final email = _normalizeEmail(raw);
      if (!_emailRegex.hasMatch(email)) {
        throw Exception("Invalid email format");
      }
      return email;
    }

    // Username
    final uname = _normalizeUsername(raw);

    // DEBUG: 
    try {
      print('[LOGIN] projectId = ${Firebase.app().options.projectId}');
    } catch (_) {
      print('[LOGIN] projectId = (Firebase not initialized in this scope)');
    }
    print(
      '[LOGIN] resolving username -> email for "$raw" -> normalized "$uname"',
    );

    try {
      // 
      final studentSnap = await _db
          .collection(kStudentCol)
          .where('username_lower', isEqualTo: uname)
          .limit(1)
          .get();

      print(
        '[LOGIN] student (username_lower) hits: ${studentSnap.docs.length}',
      );
      if (studentSnap.docs.isNotEmpty) {
        final data = studentSnap.docs.first.data();
        final email = _normalizeEmail((data['email'] as String?) ?? '');
        print(
          '[LOGIN] student doc id: ${studentSnap.docs.first.id} | email: $email',
        );
        if (email.isEmpty || !_emailRegex.hasMatch(email)) {
          throw Exception("User record is missing an email");
        }
        return email;
      }

      //
      final altStudentSnap = await _db
          .collection(kStudentCol)
          .where('username', isEqualTo: raw)
          .limit(1)
          .get();
      print(
        '[LOGIN] student (username exact) hits: ${altStudentSnap.docs.length}',
      );
      if (altStudentSnap.docs.isNotEmpty) {
        final data = altStudentSnap.docs.first.data();
        final email = _normalizeEmail((data['email'] as String?) ?? '');
        print(
          '[LOGIN] student (alt) doc id: ${altStudentSnap.docs.first.id} | email: $email',
        );
        if (email.isEmpty || !_emailRegex.hasMatch(email)) {
          throw Exception("User record is missing an email");
        }
        return email;
      }

      //
      final companySnap = await _db
          .collection(kCompanyCol)
          .where('username_lower', isEqualTo: uname)
          .limit(1)
          .get();

      print(
        '[LOGIN] companies (username_lower) hits: ${companySnap.docs.length}',
      );
      if (companySnap.docs.isNotEmpty) {
        final data = companySnap.docs.first.data();
        final email = _normalizeEmail((data['email'] as String?) ?? '');
        print(
          '[LOGIN] company doc id: ${companySnap.docs.first.id} | email: $email',
        );
        if (email.isEmpty || !_emailRegex.hasMatch(email)) {
          throw Exception("User record is missing an email");
        }
        return email;
      }

      // 
      final altCompanySnap = await _db
          .collection(kCompanyCol)
          .where('username', isEqualTo: raw)
          .limit(1)
          .get();
      print(
        '[LOGIN] companies (username exact) hits: ${altCompanySnap.docs.length}',
      );
      if (altCompanySnap.docs.isNotEmpty) {
        final data = altCompanySnap.docs.first.data();
        final email = _normalizeEmail((data['email'] as String?) ?? '');
        print(
          '[LOGIN] company (alt) doc id: ${altCompanySnap.docs.first.id} | email: $email',
        );
        if (email.isEmpty || !_emailRegex.hasMatch(email)) {
          throw Exception("User record is missing an email");
        }
        return email;
      }
    } on FirebaseException catch (e) {
      print('[LOGIN][ERROR] Firestore query failed: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        //
        throw Exception(
          'Login failed: permission denied while searching username',
        );
      }
      rethrow;
    }

    print(
      '[LOGIN] no user found for username="$raw"/lower="$uname" in "$kStudentCol"/"$kCompanyCol"',
    );
    throw Exception("User not found");
  }

  // ------------------------------
  // Login (Student or Company)  → returns 'student' or 'company'
  // ------------------------------
  Future<String> login(String identifier, String password) async {
    try {
      final email = await _resolveEmailFromIdentifier(identifier);

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("User not found.");

      // حدّد النوع من الـ collections
      final studentDoc = await _db.collection(kStudentCol).doc(user.uid).get();
      if (studentDoc.exists) return 'student';

      final companyDoc = await _db.collection(kCompanyCol).doc(user.uid).get();
      if (companyDoc.exists) return 'company';

      throw Exception("User type not found in system.");
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception("User not found");
        case 'wrong-password':
          throw Exception("Incorrect password");
        case 'invalid-email':
          throw Exception("Invalid email format");
        case 'too-many-requests':
          throw Exception("Too many attempts, try again later");
        case 'network-request-failed':
          throw Exception("No internet connection");
        default:
          throw Exception(e.message ?? "Firebase Auth Error");
      }
    } catch (e) {
      throw Exception("Login failed: $e");
    }
  }

  // ------------------------------
  // Reset Password (Username أو Email)
  // ------------------------------
  Future<void> resetPassword(String identifier) async {
    final email = await _resolveEmailFromIdentifier(identifier);
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ------------------------------
  // Helpers (Get/Update)
  // ------------------------------
  Future<Student?> getStudent(String uid) async {
    final doc = await _db.collection(kStudentCol).doc(uid).get();
    if (!doc.exists) return null;
    return Student.fromMap(doc.data()!);
  }

  Future<void> updateStudent(String uid, Student student) async {
    await _db.collection(kStudentCol).doc(uid).update(student.toMap());
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
    final doc = await _db.collection(kStudentCol).doc(user.uid).get();
    if (!doc.exists) return null;
    return Student.fromMap(doc.data()!);
  }
}
