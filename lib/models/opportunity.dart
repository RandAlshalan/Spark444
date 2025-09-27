import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for DocumentSnapshot

class Opportunity {
  final String id;
  final String companyId; // Link to the company that posted it
  final String name;
  final String role;
  final bool isPaid;
  final String location;
  final int applicants;

  Opportunity({
    required this.id,
    required this.companyId,
    required this.name,
    required this.role,
    required this.isPaid,
    // Initialize the new fields DUMMY DATA
    this.location = 'New York, NY',
    this.applicants = 57,
  });

  // Factory constructor to create an Opportunity from a Firestore DocumentSnapshot
  factory Opportunity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Opportunity(
      id: doc.id,
      companyId: data['companyId'] ?? '', // Ensure this field exists in your Firestore documents
      name: data['name'] ?? 'No Name',
      role: data['role'] ?? 'No Role',
      isPaid: data['isPaid'] ?? false,
      // Map other fields similarly
      location: data['location'] ?? 'Location Not Specified', // Retrieve if available
      applicants: data['applicants'] ?? 0, // Retrieve if available
    );
  }

  // Optional: A method to convert an Opportunity object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'role': role,
      'isPaid': isPaid,
      // Add other fields
      'timestamp': FieldValue.serverTimestamp(), // Useful for ordering
      'location': location,
      'applicants': applicants,
    };
  }
}