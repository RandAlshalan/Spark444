import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // Add this new function inside your AuthService class
Future<Map<String, List<String>>> getUniversitiesAndMajors() async {
  try {
    // Fetch the universities document
    DocumentSnapshot uniDoc = await _db.collection('lists').doc('universities').get();
    
    // Fetch the majors document
    DocumentSnapshot majorDoc = await _db.collection('lists').doc('majors').get();

    // Extract data from each document, handling null cases
    final List<String> universities = uniDoc.exists 
        ? List<String>.from((uniDoc.data() as Map<String, dynamic>)['names'] ?? []) 
        : [];
        
    final List<String> majors = majorDoc.exists 
        ? List<String>.from((majorDoc.data() as Map<String, dynamic>)['names'] ?? []) 
        : [];
    
    return {
      'universities': universities,
      'majors': majors,
    };
  } catch (e) {
    print("Error fetching lists: $e");
    // In case of an error, return empty lists so the app doesn't crash
    return {'universities': [], 'majors': []};
  }
}
Future<void> cancelSignUpAndDeleteUser() async {
  final User? user = _auth.currentUser;
  if (user != null && !user.emailVerified) {
    try {
      // It's good practice to delete the Firestore document first
      await _db.collection(kStudentCol).doc(user.uid).delete();
      // Then delete the auth user
      await user.delete();
    } catch (e) {
      // Handle potential errors, e.g., user needs to re-authenticate to delete
      // For a new, unverified user, this usually works without issues.
      print("Error cancelling sign-up: $e");
      throw Exception("Could not cancel sign-up. Please sign out and sign in again to resolve.");
    }
  }
}
  /// Checks if a username is unique across both students and companies.
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
  // Sign Up Student
  // ------------------------------
  Future<User?> signUpStudent(Student student, String password) async {
    try {
      // Step 1: Check if username is already taken in Firestore
      final isUnique = await isUsernameUnique(student.username);
      if (!isUnique) {
        throw Exception("This username is already taken. Please choose another one.");
      }

      // Step 2: Create user in Firebase Authentication
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

      // Step 3: Create student document in Firestore
      final studentMap = student.toMap();
      studentMap['email'] = emailNorm;
      studentMap['isVerified'] = false;
      studentMap['isAcademic'] = student.isAcademic;
      studentMap['username_lower'] = _normalizeUsername(student.username);
      studentMap['createdAt'] = FieldValue.serverTimestamp();

      await _db.collection(kStudentCol).doc(user.uid).set(studentMap);

      return user;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase authentication errors
      if (e.code == 'email-already-in-use') {
        throw Exception("This email address is already in use.");
      } else if (e.code == 'weak-password') {
        throw Exception("The password provided is too weak.");
      }
      throw Exception(e.message ?? "An unknown error occurred.");
    } catch (e) {
      // Handle other errors (like the username check)
      rethrow;
    }
  }

  // ------------------------------
  // Sign Up Company
  // ------------------------------
  Future<User?> signUpCompany(Company company, String password) async {
    try {
      // Step 1: Check if username is taken
      final isUnique = await isUsernameUnique(company.email);
      if (!isUnique) {
        throw Exception("This username is already taken. Please choose another one.");
      }

      // Step 2: Create user in Firebase Auth
      final emailNorm = _normalizeEmail(company.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to create an account. Please try again.");
      }

      // Step 3: Create company document in Firestore
      final companyMap = company.toMap();
      companyMap['email'] = emailNorm;
      companyMap['isVerified'] = false; // Companies also need verification
      companyMap['username_lower'] = _normalizeUsername(company.email);
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
  // Resolve identifier → email
  // ------------------------------
  Future<String> _resolveEmailFromIdentifier(String identifier) async {
    final raw = identifier.trim();
    if (raw.isEmpty) throw Exception("Please enter a username or email.");

    if (raw.contains('@')) {
      final email = _normalizeEmail(raw);
      if (!_emailRegex.hasMatch(email)) throw Exception("Invalid email format.");
      return email;
    }

    final uname = _normalizeUsername(raw);

    // Check student collection
    final studentSnap = await _db
        .collection(kStudentCol)
        .where('username_lower', isEqualTo: uname)
        .limit(1)
        .get();
    if (studentSnap.docs.isNotEmpty) {
      final data = studentSnap.docs.first.data();
      final email = _normalizeEmail((data['email'] as String?) ?? '');
      if (email.isEmpty || !_emailRegex.hasMatch(email)) throw Exception("User record is missing a valid email.");
      return email;
    }

    // Check company collection
    final companySnap = await _db
        .collection(kCompanyCol)
        .where('username_lower', isEqualTo: uname)
        .limit(1)
        .get();
    if (companySnap.docs.isNotEmpty) {
      final data = companySnap.docs.first.data();
      final email = _normalizeEmail((data['email'] as String?) ?? '');
      if (email.isEmpty || !_emailRegex.hasMatch(email)) throw Exception("Company record is missing a valid email.");
      return email;
    }

    throw Exception("User not found.");
  }

  // ------------------------------
  // Login
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

      await user.reload();
      if (!user.emailVerified) {
        throw Exception('Please verify your email address first.');
      }

      final studentDoc = await _db.collection(kStudentCol).doc(user.uid).get();
      if (studentDoc.exists) {
        if (studentDoc.data()?['isVerified'] != true) {
          await updateVerificationStatus(user.uid, true);
        }
        return 'student';
      }

      final companyDoc = await _db.collection(kCompanyCol).doc(user.uid).get();
      if (companyDoc.exists) {
        if (companyDoc.data()?['isVerified'] != true) {
          await _db.collection(kCompanyCol).doc(user.uid).update({'isVerified': true});
        }
        return 'company';
      }

      throw Exception("User type not found in the system.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect email or password.');
      }
      throw Exception(e.message ?? "Login failed.");
    } catch (e) {
      rethrow;
    }
  }

  // ------------------------------
  // Reset Password
  // ------------------------------
  Future<void> resetPassword(String identifier) async {
    try {
      final email = await _resolveEmailFromIdentifier(identifier);
      await _auth.sendPasswordResetEmail(email: email);
    } catch(e) {
      // Rethrow with a user-friendly message
      throw Exception("Failed to send reset link. Please ensure the email or username is correct.");
    }
  }
  
  // ------------------------------
  // Verification Status Helpers
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
    await _db.collection(kStudentCol).doc(uid).update({'isVerified': isVerified});
  }

  // ------------------------------
  // Get/Update Data
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
    return await getStudent(user.uid);
  }

  Future<Company?> getCurrentCompany() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getCompany(user.uid);
  }
}