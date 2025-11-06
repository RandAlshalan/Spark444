import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for DocumentSnapshot and Timestamp

class Application {
  final String id; // The document ID of the application in Firestore
  final String opportunityId; // ID of the opportunity this application is for
  final String studentId; // ID of the student who submitted this application
  final String
  status; // Current status (e.g., 'Pending', 'Reviewed', 'Rejected', 'Hired')
  final Timestamp
  appliedDate; // Date and time when the application was submitted
  final String? resumeId; // Optional: Reference to student's resume document
  final String? resumeUrl; // Optional: URL to the student's resume PDF
  final String? coverLetterText; // Optional: The text of the cover letter
  final String? coverLetterUrl; // Optional: URL to a cover letter file
  final Timestamp?
  lastStatusUpdateDate; // Optional: Date and time when the status was last updated
  final String?
  companyFeedback; // Optional: Feedback from the company about the application

  Application({
    required this.id,
    required this.opportunityId,
    required this.studentId,
    required this.status,
    required this.appliedDate,
    this.resumeId,
    this.resumeUrl,
    this.coverLetterText,
    this.coverLetterUrl,
    this.lastStatusUpdateDate,
    this.companyFeedback,
  });

  // Factory constructor to create an Application object from a Firestore DocumentSnapshot
  factory Application.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Application(
      id: doc.id,
      opportunityId:
          data['opportunityId'] ?? '', // Default to empty string if missing
      studentId: data['studentId'] ?? '', // Default to empty string if missing
      status: data['status'] ?? 'Pending', // Default status
      appliedDate:
          data['appliedDate'] as Timestamp? ??
          Timestamp.now(), // Default to now if missing
      resumeId: data['resumeId'],
      resumeUrl: data['resumeUrl'],
      coverLetterText: data['coverLetterText'],
      coverLetterUrl: data['coverLetterUrl'],
      lastStatusUpdateDate: data['lastStatusUpdateDate'] as Timestamp?,
      companyFeedback: data['companyFeedback'],
    );
  }

  // Method to convert an Application object to a Map for writing to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'opportunityId': opportunityId,
      'studentId': studentId,
      'status': status,
      'appliedDate': appliedDate,
      if (resumeId != null) 'resumeId': resumeId,
      if (resumeUrl != null) 'resumeUrl': resumeUrl,
      if (coverLetterText != null) 'coverLetterText': coverLetterText,
      if (coverLetterUrl != null) 'coverLetterUrl': coverLetterUrl,
      if (lastStatusUpdateDate != null)
        'lastStatusUpdateDate': lastStatusUpdateDate,
      if (companyFeedback != null) 'companyFeedback': companyFeedback,
      // You might want a 'createdAt' timestamp for all documents, typically managed by `FieldValue.serverTimestamp()`
      // For new applications, you could set 'appliedDate' to FieldValue.serverTimestamp() directly in the service layer
      // or ensure 'appliedDate' is set before calling toFirestore.
    };
  }
}
