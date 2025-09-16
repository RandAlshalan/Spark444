import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id; // document ID 
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phoneNumber;
  final String university;
  final String major;
  final String level;
  final DateTime? expectedGraduation;
  final double? gpa;
  final List<String> skills;
  final String? profilePicture;
  final String? shortSummary;

  // embedded
  final List<Map<String, dynamic>> supportingDocuments;
  final Map<String, dynamic> resume;

  final List<String> followedCompanies;
  final List<String> bookmarkedOpportunities;
  final List<Map<String, dynamic>> applications;
  final List<Map<String, dynamic>> notifications;



  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.university,
    required this.major,
    required this.level,
    this.expectedGraduation,
    this.gpa,
    required this.skills,
    this.profilePicture,
    this.shortSummary,
    required this.supportingDocuments,
    required this.resume,
    required this.followedCompanies,
    required this.bookmarkedOpportunities,
    required this.applications,
    required this.notifications,
  });

  /// from Firestore
  factory Student.fromMap(String id, Map<String, dynamic> data) {
    return Student(
      id: id,
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phone_number'] ?? '',
      university: data['university'] ?? '',
      major: data['major'] ?? '',
      level: data['level'] ?? '',
      expectedGraduation: data['expected_graduation'] != null
          ? (data['expected_graduation'] as Timestamp).toDate()
          : null,
      gpa: (data['GPA'] != null) ? data['GPA'].toDouble() : null,
      skills: List<String>.from(data['skills'] ?? []),
      profilePicture: data['profile_picture'],
      shortSummary: data['short_summary'],
      supportingDocuments:
          List<Map<String, dynamic>>.from(data['supporting_documents'] ?? []),
      resume: Map<String, dynamic>.from(data['resume'] ?? {}),
      followedCompanies: List<String>.from(data['followed_companies'] ?? []),
      bookmarkedOpportunities:
          List<String>.from(data['bookmarked_opportunities'] ?? []),
      applications:
          List<Map<String, dynamic>>.from(data['applications'] ?? []),
      notifications:
          List<Map<String, dynamic>>.from(data['notifications'] ?? []),
    );
  }

  /// to Firestore
  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'university': university,
      'major': major,
      'level': level,
      'expected_graduation': expectedGraduation,
      'GPA': gpa,
      'skills': skills,
      'profile_picture': profilePicture,
      'short_summary': shortSummary,
      'supporting_documents': supportingDocuments,
      'resume': resume,
      'followed_companies': followedCompanies,
      'bookmarked_opportunities': bookmarkedOpportunities,
      'applications': applications,
      'notifications': notifications,
    };
  }
}
