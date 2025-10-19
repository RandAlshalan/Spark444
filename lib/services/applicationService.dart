import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/Application.dart';

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference _applicationsCollection = _firestore
      .collection('applications');

  /// Checks if a student has already applied for a specific opportunity.
  Future<bool> hasStudentApplied({
    required String studentId,
    required String opportunityId,
  }) async {
    final query = await _applicationsCollection
        .where('studentId', isEqualTo: studentId)
        .where('opportunityId', isEqualTo: opportunityId)
        .get();
    if (query.docs.isEmpty) return false;

    for (final doc in query.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final status =
          (data['status']?.toString() ?? '').trim().toLowerCase();
      if (status != 'withdrawn') return true;
    }
    return false;
  }

  /// Fetches the specific application document for a given student and opportunity.
  Future<Application?> getApplicationForOpportunity({
    required String studentId,
    required String opportunityId,
  }) async {
    final query = await _applicationsCollection
        .where('studentId', isEqualTo: studentId)
        .where('opportunityId', isEqualTo: opportunityId)
        .get();

    if (query.docs.isEmpty) return null;

    final applications = query.docs
        .map((doc) => Application.fromFirestore(doc))
        .toList()
      ..sort(
        (a, b) => b.appliedDate.compareTo(a.appliedDate),
      );

    for (final app in applications) {
      if (app.status.toLowerCase() != 'withdrawn') {
        return app;
      }
    }

    return applications.first;
  }

  /// Loads all applications submitted to the given opportunity ordered by most recent.
  Future<List<Application>> getApplicationsForOpportunity(
      String opportunityId) async {
    final query = await _applicationsCollection
        .where('opportunityId', isEqualTo: opportunityId)
        .get();

    final applications = query.docs
        .map((doc) => Application.fromFirestore(doc))
        .toList();

    applications.sort(
      (a, b) => b.appliedDate.compareTo(a.appliedDate),
    );

    return applications;
  }

  /// Submits a new application for a student to an opportunity.
  Future<void> submitApplication({
    required String studentId,
    required String opportunityId,
  }) async {
    // Prevent duplicate submissions from rapid clicks.
    final alreadyApplied = await hasStudentApplied(
      studentId: studentId,
      opportunityId: opportunityId,
    );
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

  /// Updates an application's status (for company to accept/reject applicants).
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? feedback,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'lastStatusUpdateDate': Timestamp.now(),
    };

    if (feedback != null) {
      updateData['companyFeedback'] = feedback;
    }

    await _applicationsCollection.doc(applicationId).update(updateData);
  }
}
