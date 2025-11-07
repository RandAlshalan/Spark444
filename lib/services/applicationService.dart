import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/Application.dart';
import 'notification_helper.dart';

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
  /// Returns null if no active (non-withdrawn) application exists.
  /// This allows students to reapply after withdrawing their application.
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

    // Return the first non-withdrawn application
    for (final app in applications) {
      if (app.status.toLowerCase() != 'withdrawn') {
        return app;
      }
    }

    // If all applications are withdrawn, return null to allow reapply
    return null;
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
    required String resumeId,
    String? resumePdfUrl,
    String? coverLetterText,
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
    final applicationData = {
      'studentId': studentId,
      'opportunityId': opportunityId,
      'status': 'Pending', // Default status
      'appliedDate': Timestamp.now(),
      'resumeId': resumeId,
      'resumeUrl': resumePdfUrl,
      'coverLetterText': coverLetterText,
      'lastStatusUpdateDate': null,
      'companyFeedback': null,
    };

    if (resumePdfUrl == null || resumePdfUrl.isEmpty) {
      applicationData.remove('resumeUrl');
    }
    if (coverLetterText == null || coverLetterText.trim().isEmpty) {
      applicationData.remove('coverLetterText');
    }

    await _applicationsCollection.add(applicationData);
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

    // Send notification to student about status update
    try {
      final appDoc = await _applicationsCollection.doc(applicationId).get();
      if (appDoc.exists) {
        final appData = appDoc.data() as Map<String, dynamic>;
        final studentId = appData['studentId'] as String?;
        final opportunityId = appData['opportunityId'] as String?;

        if (studentId != null && opportunityId != null) {
          // Get opportunity and company details
          final oppDoc = await _firestore.collection('opportunities').doc(opportunityId).get();
          if (oppDoc.exists) {
            final oppData = oppDoc.data() as Map<String, dynamic>;
            final companyId = oppData['companyId'] as String?;
            final role = oppData['role'] as String? ?? 'Position';

            String companyName = oppData['name'] as String? ?? 'Company';

            // Try to get company name from companies collection
            if (companyId != null) {
              final companyDoc = await _firestore.collection('companies').doc(companyId).get();
              if (companyDoc.exists) {
                companyName = (companyDoc.data()?['companyName'] as String?) ?? companyName;
              }
            }

            // Send notification
            await NotificationHelper().notifyApplicationStatusUpdate(
              studentId: studentId,
              companyName: companyName,
              opportunityRole: role,
              status: status,
              opportunityId: opportunityId,
            );
          }
        }
      }
    } catch (e) {
      // Don't fail the status update if notification fails
      print('Error sending application status notification: $e');
    }
  }
}
