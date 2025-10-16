import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/application.dart'; // Make sure the path to your Application model is correct

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _applicationsCollection = _firestore.collection('applications');

  /// Checks if a student has already applied for a specific opportunity.
  Future<bool> hasStudentApplied({required String studentId, required String opportunityId}) async {
    final query = await _applicationsCollection
        .where('studentId', isEqualTo: studentId)
        .where('opportunityId', isEqualTo: opportunityId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Fetches the specific application document for a given student and opportunity.
  Future<Application?> getApplicationForOpportunity({
    required String studentId,
    required String opportunityId,
  }) async {
    final query = await _applicationsCollection
        .where('studentId', isEqualTo: studentId)
        .where('opportunityId', isEqualTo: opportunityId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Application.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Submits a new application for a student to an opportunity.
  Future<void> submitApplication({required String studentId, required String opportunityId}) async {
    // Prevent duplicate submissions from rapid clicks.
    final alreadyApplied = await hasStudentApplied(studentId: studentId, opportunityId: opportunityId);
    if (alreadyApplied) {
      throw Exception("You have already applied for this opportunity.");
    }
    
    // Creates a new document in the 'applications' collection.
    await _applicationsCollection.add({
      'studentId': studentId,
      'opportunityId': opportunityId,
      'status': 'Pending', // Default status
      'appliedDate': Timestamp.now(),
      'resumeUrl': null, 
      'coverLetterText': null,
      'lastStatusUpdateDate': null,
      'companyFeedback': null,
    });
  }
  
Future<void> deleteApplication({required String applicationId}) async {
    try {
      await _firestore.collection('applications').doc(applicationId).delete();
    } catch (e) {
      // Re-throw the error to be caught by the UI layer
      print('Error deleting application: $e');
      throw Exception('Could not delete the application record.');
    }
  }
  /// Updates an application's status to 'Withdrawn' instead of deleting it.
  Future<void> withdrawApplication({required String applicationId}) async {
    await _applicationsCollection.doc(applicationId).update({
      'status': 'Withdrawn',
      'lastStatusUpdateDate': Timestamp.now(), // Good practice to track this
    });
  }
}