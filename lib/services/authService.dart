// AuthService.dart - MODIFIED FOR COMPANY EMAIL-ONLY LOGIN

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/student.dart';
import '../models/company.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
    static const String kOpportunitiesCol = 'opportunities'; // Defined for clarity

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
      DocumentSnapshot uniDoc = await _db
          .collection('lists')
          .doc('universities')
          .get();
      DocumentSnapshot majorDoc = await _db
          .collection('lists')
          .doc('majors')
          .get();
      DocumentSnapshot cityDoc = await _db
          .collection('lists')
          .doc('city')
          .get();
      DocumentSnapshot sectorDoc = await _db
          .collection('lists')
          .doc('sector') // Corrected document name from 'sectors' to 'sector'
          .get();

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

      final List<String> city = cityDoc.exists
          ? List<String>.from(
              (cityDoc.data() as Map<String, dynamic>)['names'] ?? [],
            )
          : [];

      final List<String> sectors = sectorDoc.exists
          ? List<String>.from(
              (sectorDoc.data() as Map<String, dynamic>)['names'] ?? [],
            )
          : [];

      return {
        'universities': universities,
        'majors': majors,
        'cities': city,
        'sectors': sectors,
      };
    } catch (e) {
      print("Error fetching lists: $e");
      return {'universities': [], 'majors': [], 'cities': [], 'sectors': []};
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
      if (!isUnique) throw Exception("This username is already in use. Please choose another one.");

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
      if (!written.exists)
        throw Exception("Student Firestore doc was not created.");

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

  /// Creates a user in Firebase Authentication without writing to Firestore.
  /// Returns the created user so the UID can be used for file uploads before document creation.
  Future<User?> createAuthUser({
    required String email,
    required String password,
  }) async {
    try {
      final emailNorm = _normalizeEmail(email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to create an authentication entry.");
      }
      await user.sendEmailVerification();
      return user;
    } on FirebaseAuthException catch (e) {
      // Rethrow with a more user-friendly message
      throw Exception(_mapAuthError(e));
    }
  }

  Future<User?> signUpCompany(Company company, String password) async {
    try {
      final isUnique = await isUsernameUnique(company.companyName);
      if (!isUnique)
        throw Exception(
          "This username is already taken. Please choose another one.",
        );

      final emailNorm = _normalizeEmail(company.email);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailNorm,
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("Failed to create an account.");

      final companyMap = company.toMap();
      companyMap['email'] = emailNorm;
      companyMap['isVerified'] = false;
      companyMap['username_lower'] = _normalizeUsername(company.companyName);
      companyMap['createdAt'] = FieldValue.serverTimestamp();

      // Set the initial data. We will update it with profile info later if needed.
      await _db.collection(kCompanyCol).doc(user.uid).set(companyMap);

      final written = await _db.collection(kCompanyCol).doc(user.uid).get();
      if (!written.exists)
        throw Exception("Company Firestore doc was not created.");

      // Send verification email after creating the doc, just in case.
      await user.sendEmailVerification();

      return user;
    } on FirebaseAuthException catch (e) {
      // Rethrow with a more user-friendly message
      throw Exception(_mapAuthError(e));
    } catch (e) {
      // Rethrow other exceptions
      rethrow;
    }
  }

  /// Creates the company document in Firestore after the auth user and any file uploads are complete.
  Future<void> createCompanyDocument(String uid, Company company) async {
    try {
      final companyMap = company.toMap();
      companyMap['email'] = _normalizeEmail(company.email);
      companyMap['isVerified'] = false; // Email is not verified at this point
      companyMap['username_lower'] = _normalizeUsername(company.companyName);
      companyMap['createdAt'] = FieldValue.serverTimestamp();

      await _db.collection(kCompanyCol).doc(uid).set(companyMap);

      final written = await _db.collection(kCompanyCol).doc(uid).get();
      if (!written.exists)
        throw Exception("Company Firestore document was not created.");
    } catch (e) {
      rethrow;
    }
  }

  // Helper to map Firebase Auth errors to user-friendly strings
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "This email address is already in use by another account.";
      case 'weak-password':
        return "The password provided is too weak. Please use a stronger one.";
      case 'invalid-email':
        return "The email address is not valid.";
      case 'operation-not-allowed':
        return "Email/password accounts are not enabled.";
      default:
        return e.message ?? "An unknown error occurred during sign-up.";
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
      if (!_emailRegex.hasMatch(email))
        throw Exception("Invalid email format.");
      return email;
    }

    // If it does NOT contain '@', assume it's a student's username.
    final uname = _normalizeUsername(raw);

    try {
      // Check student collection for the username
      final studentSnap = await _db
          .collection(kStudentCol)
          .where('username_lower', isEqualTo: uname)
          .limit(1)
          .get();

      if (studentSnap.docs.isNotEmpty) {
        final email = _normalizeEmail(
          (studentSnap.docs.first.data()['email'] as String?) ?? '',
        );
        if (email.isEmpty || !_emailRegex.hasMatch(email))
          throw Exception("User record is missing an email");
        return email;
      }

      // ✅ MODIFICATION: The logic to check for a company name has been completely removed.
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Login failed: permission denied while searching username',
        );
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
      if (!user.emailVerified)
        throw FirebaseAuthException(code: 'email-not-verified');
      if (studentDoc.data()?['isVerified'] != true) {
        await updateVerificationStatus(user.uid, true);
      }
      return {'userType': 'student', 'isVerified': true};
    }

    final companyDoc = await _db.collection(kCompanyCol).doc(user.uid).get();
    if (companyDoc.exists) {
      await user.reload();
      final bool isVerified = user.emailVerified;

      if (!isVerified)
        await user.sendEmailVerification();
      else if (companyDoc.data()?['isVerified'] != true) {
        await _db.collection(kCompanyCol).doc(user.uid).update({
          'isVerified': true,
        });
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
    await _db.collection(kStudentCol).doc(uid).update({
      'isVerified': isVerified,
    });
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

  Future<void> updateStudentPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null)
      throw Exception('No authenticated user found.');

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
    if (user == null || user.email == null)
      throw Exception('No authenticated user found.');

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

  /// --- ADDED: Method to permanently delete a student account ---
  ///
  /// This is a destructive operation that requires the user's current password for security.
  /// It re-authenticates the user, then deletes their Firestore document and their auth record.
  Future<void> deleteStudentAccount(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found to delete.');
    }

    try {
      // Step 1: Re-authenticate the user to confirm their identity.
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;

      // Step 2: Delete user's Firestore document.
      await _db.collection(kStudentCol).doc(uid).delete();

      // Step 3 (Crucial): Delete all associated files from Firebase Storage.
      // This typically requires a Cloud Function for reliability, as client-side
      // deletion of entire directories is not directly supported.
      // You would call a service here, for example:
      // await StorageService().deleteAllUserData(uid);
      // For now, this serves as a placeholder for that logic.

      // Step 4: Delete the user from Firebase Authentication.
      await user.delete();

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.code == 'requires-recent-login') {
        throw Exception(
            'This is a sensitive action and requires a recent login. Please sign out and sign in again to proceed.');
      }
      // Re-throw other specific Firebase auth errors.
      throw Exception(_mapAuthError(e));
    } catch (e) {
      // Catch any other errors (e.g., from Firestore)
      throw Exception('An unexpected error occurred while deleting your account. Please try again.');
    }
  }

  /// --- ADDED: Method to permanently delete a student account ---
  ///
  /// This is a destructive operation that requires the user's current password for security.
  /// It re-authenticates the user, then deletes their Firestore document and their auth record.
 /* Future<void> deleteStudentAccount(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found to delete.');
    }

    try {
      // Step 1: Re-authenticate the user to confirm their identity.
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      final uid = user.uid;

      // Step 2: Delete user's Firestore document.
      await _db.collection(kStudentCol).doc(uid).delete();

      // Step 3 (Crucial): Delete all associated files from Firebase Storage.
      // This typically requires a Cloud Function for reliability, as client-side
      // deletion of entire directories is not directly supported.
      // You would call a service here, for example:
      // await StorageService().deleteAllUserData(uid);
      // For now, this serves as a placeholder for that logic.

      // Step 4: Delete the user from Firebase Authentication.
      await user.delete();

    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.code == 'requires-recent-login') {
        throw Exception(
            'This is a sensitive action and requires a recent login. Please sign out and sign in again to proceed.');
      }
      // Re-throw other specific Firebase auth errors.
      throw Exception(_mapAuthError(e));
    } catch (e) {
      // Catch any other errors (e.g., from Firestore)
      throw Exception('An unexpected error occurred while deleting your account. Please try again.');
    }
  }*/

  Future<Company?> getCompany(String uid) async {
    // Ensure you get a snapshot of the correct type.
    final doc = await _db.collection(kCompanyCol).doc(uid).get();

    if (!doc.exists) return null;

    // Use a constructor that accepts the DocumentSnapshot to get the ID.
    return Company.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  Future<Company?> getCurrentCompany() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return await getCompany(currentUser.uid);
    return null;
  }

  Future<void> updateCompany(String uid, Company company) async {
    await _db.collection(kCompanyCol).doc(uid).update(company.toMap());
  }

  Future<void> deleteCompanyAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      print('DEBUG: deleteCompanyAccount [Start]: No authenticated user found. Throwing exception.');
      throw Exception('No authenticated user found to delete.');
    }

    final String userUid = user.uid;
    final String userEmail = user.email!; // Get user's current email

    print('DEBUG: deleteCompanyAccount [Start]: Attempting to delete account for UID: $userUid, Email: $userEmail');

    try {
      // Step 1: Re-authenticate the user for security.
      print('DEBUG: deleteCompanyAccount [Reauth]: Attempting to re-authenticate with email: $userEmail');
      final credential = EmailAuthProvider.credential(
        email: userEmail,
        password: password.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      print('DEBUG: deleteCompanyAccount [Reauth]: User re-authenticated successfully.');

      // Step 2: Delete all opportunities posted by the company.
      // HYPOTHESIS: 'companyId' in 'opportunities' collection stores company email, not UID.
      print('DEBUG: deleteCompanyAccount [Opportunities]: Attempting to delete opportunities associated with email: $userEmail');

      final opportunitiesSnapshot = await _db
          .collection(kOpportunitiesCol)
          .where('companyId', isEqualTo: userEmail) // <-- CRITICAL CHANGE: Query by email
          .get();

      if (opportunitiesSnapshot.docs.isEmpty) {
        print('DEBUG: deleteCompanyAccount [Opportunities]: No opportunities found using email "$userEmail".');
        // You might want to add a fallback here to check by UID if you're unsure,
        // or just log this if it's expected behavior for a company without posts.
        // For now, let's stick with the email as the identifier based on your print statements.
      } else {
        print('DEBUG: deleteCompanyAccount [Opportunities]: Found ${opportunitiesSnapshot.docs.length} opportunities for email "$userEmail".');
      }

      final batch = _db.batch();
      for (final doc in opportunitiesSnapshot.docs) {
        batch.delete(doc.reference);
        print('DEBUG: deleteCompanyAccount [Opportunities]: Adding opportunity "${doc.id}" to batch.');
      }
      await batch.commit();
      print('DEBUG: deleteCompanyAccount [Opportunities]: Opportunities batch committed. Total deleted: ${opportunitiesSnapshot.docs.length}.');


      // Step 3: Delete the company's document from Firestore.
      print('DEBUG: deleteCompanyAccount [Firestore Doc]: Deleting company document for UID: $userUid');
      await _db.collection(kCompanyCol).doc(userUid).delete();
      print('DEBUG: deleteCompanyAccount [Firestore Doc]: Company document deleted successfully.');

      // Step 4: Delete the user from Firebase Authentication. This should be the last step.
      print('DEBUG: deleteCompanyAccount [Auth User]: Deleting Firebase Auth user: $userEmail (UID: $userUid)');
      await user.delete();
      print('DEBUG: deleteCompanyAccount [Auth User]: Firebase Auth user deleted successfully.');

      print('DEBUG: deleteCompanyAccount [End]: Account deletion process completed successfully.');

    } on FirebaseAuthException catch (e) {
      print('DEBUG: deleteCompanyAccount [FirebaseAuthException]: Caught Firebase Auth Exception: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-mismatch':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'requires-recent-login':
          errorMessage = 'This is a sensitive action and requires a recent login. Please sign out and sign in again.';
          break;
        case 'user-not-found':
          errorMessage = 'The user account could not be found.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/Password sign-in is not enabled or account deletion is not allowed.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = e.message ?? 'An unknown authentication error occurred (Code: ${e.code}).';
          break;
      }
      print('DEBUG: deleteCompanyAccount [FirebaseAuthException]: Throwing descriptive error: "$errorMessage"');
      throw Exception(errorMessage); // Throw a descriptive exception
    } catch (e) {
      print('DEBUG: deleteCompanyAccount [General Exception]: Caught general exception: $e');
      print('DEBUG: deleteCompanyAccount [General Exception]: Throwing descriptive error: "${e.toString()}"');
      throw Exception('An unexpected error occurred during account deletion: ${e.toString().replaceFirst('Exception: ', '')}.');
    }
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