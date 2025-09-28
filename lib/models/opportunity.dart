import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for DocumentSnapshot and Timestamp

class Opportunity {
  final String id;
  final String companyId; // Link to the company that posted it
  final String name;
  final String role;
  final bool isPaid;

  // --- NEW FIELDS ADDED BELOW ---
  final String type; // e.g., Internship, Full-time, Part-time
  final String? description; // Optional description
  final List<String>? requirements; // Optional list of requirements
  final String? location; // Optional location string
  final Timestamp? startDate; // Start date of the opportunity
  final Timestamp? endDate; // End date of the opportunity
  final Timestamp? applicationOpenDate; // When applications begin
  final Timestamp? applicationDeadline; // When applications close
  final Timestamp?
  responseDeadline; // When company must update applicant statuses
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
    // --- NEW FIELDS IN CONSTRUCTOR ---
    required this.type,
    this.description,
    this.requirements,
    this.location,
    this.startDate,
    this.endDate,
    this.applicationOpenDate,
    this.applicationDeadline,
    this.responseDeadline,
    this.postedDate,
    this.isActive = true, // Default to true if not specified
    // --- END NEW FIELDS ---
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
      // --- MAPPING NEW FIELDS FROM FIRESTORE ---
      type: data['type'] ?? 'Unknown', // Provide a default if type is mandatory
      description: data['description'],
      requirements: (data['requirements'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      location: data['location'],
      startDate: data['startDate'] as Timestamp?,
      endDate: data['endDate'] as Timestamp?,
      applicationOpenDate: data['applicationOpenDate'] as Timestamp?,
      applicationDeadline: data['applicationDeadline'] as Timestamp?,
      responseDeadline: data['responseDeadline'] as Timestamp?,
      postedDate: data['postedDate'] as Timestamp?,
      isActive: data['isActive'] ?? true, // Default to true if not present
      // --- END MAPPING NEW FIELDS ---
    );
  }

  // A method to convert an Opportunity object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'role': role,
      'isPaid': isPaid,
      // --- ADDING NEW FIELDS TO FIRESTORE MAP ---
      'type': type,
      if (description != null) 'description': description,
      if (requirements != null && requirements!.isNotEmpty)
        'requirements': requirements,
      if (location != null) 'location': location,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (applicationOpenDate != null)
        'applicationOpenDate': applicationOpenDate,
      if (applicationDeadline != null)
        'applicationDeadline': applicationDeadline,
      if (responseDeadline != null) 'responseDeadline': responseDeadline,
      'postedDate':
          postedDate ??
          FieldValue.serverTimestamp(), // Set on creation if not already set
      'isActive': isActive,
      // --- END ADDING NEW FIELDS ---
    };
  }
}
