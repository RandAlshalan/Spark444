import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for DocumentSnapshot and Timestamp

class Opportunity {
  final String id;
  final String companyId; // Link to the company that posted it
  final String name;
  final String role;
  final bool isPaid;

  // --- FIELDS ADDED BELOW ---
  final String type; // e.g., Internship, Full-time, Part-time
  final String? workMode; // e.g., In-person, Remote, Hybrid
  final String? description; // Optional description
  final List<String>? requirements; // Optional list of requirements
  final List<String>? skills; // Optional list of skills
  final String? preferredMajor; // Optional preferred major
  final String? location; // Optional location string
  final Timestamp? startDate; // Start date of the opportunity
  final Timestamp? endDate; // End date of the opportunity
  final Timestamp? applicationOpenDate; // When applications begin
  final Timestamp? applicationDeadline; // When applications close
  final Timestamp?
  responseDeadline; // When company must update applicant statuses
  final bool?
  responseDeadlineVisible; // Whether students can see the response deadline
  final Timestamp? postedDate; // When the opportunity was posted
  final bool
  isActive; // Whether the opportunity is currently active/open for applications
  // --- END NEW FIELDS ---

  Opportunity({
    required this.id,
    required this.companyId,
    required this.name,
    required this.role,
    required this.isPaid,
    // --- CONSTRUCTOR UPDATES ---
    required this.type,
    this.workMode,
    this.description,
    this.requirements,
    this.skills,
    this.preferredMajor,
    this.location,
    this.startDate,
    this.endDate,
    this.applicationOpenDate,
    this.applicationDeadline,
    this.responseDeadline,
    this.responseDeadlineVisible,
    this.postedDate,
    this.isActive = true, // Default to true if not specified
    // --- END CONSTRUCTOR UPDATES ---
  });

  // Factory constructor to create an Opportunity from a Firestore DocumentSnapshot
  factory Opportunity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Opportunity(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      name: data['name'] ?? 'No Name',
      role: data['role'] ?? 'No Role',
      isPaid: data['isPaid'] ?? false,
      // --- MAPPING UPDATED FIELDS FROM FIRESTORE ---
      type: data['type'] ?? 'Unknown', // Provide a default if type is mandatory
      workMode: data['workMode'],
      description: data['description'],
      requirements: (data['requirements'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      skills: (data['skills'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      preferredMajor: data['preferredMajor'],
      location: data['location'],
      startDate: data['startDate'] as Timestamp?,
      endDate: data['endDate'] as Timestamp?,
      applicationOpenDate: data['applicationOpenDate'] as Timestamp?,
      applicationDeadline: data['applicationDeadline'] as Timestamp?,
      responseDeadline: data['responseDeadline'] as Timestamp?,
      responseDeadlineVisible: data['responseDeadlineVisible'] as bool?,
      postedDate: data['postedDate'] as Timestamp?,
      isActive: data['isActive'] ?? true, // Default to true if not present
      // --- END MAPPING UPDATED FIELDS ---
    );
  }

  // A method to convert an Opportunity object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'role': role,
      'isPaid': isPaid,
      // --- ADDING UPDATED FIELDS TO FIRESTORE MAP ---
      'type': type,
      if (workMode != null) 'workMode': workMode,
      if (description != null) 'description': description,
      if (requirements != null && requirements!.isNotEmpty)
        'requirements': requirements,
      if (skills != null && skills!.isNotEmpty) 'skills': skills,
      if (preferredMajor != null) 'preferredMajor': preferredMajor,
      if (location != null) 'location': location,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (applicationOpenDate != null)
        'applicationOpenDate': applicationOpenDate,
      if (applicationDeadline != null)
        'applicationDeadline': applicationDeadline,
      // Conditionally add responseDeadline and its visibility based on the toggle in your form
      if (responseDeadline != null) 'responseDeadline': responseDeadline,
      if (responseDeadlineVisible != null)
        'responseDeadlineVisible': responseDeadlineVisible,
      'postedDate':
          postedDate, // For updates, keep the existing date. For creation, it will be set by the service.
      'isActive': isActive,
      // --- END ADDING UPDATED FIELDS ---
    };
  }
}
