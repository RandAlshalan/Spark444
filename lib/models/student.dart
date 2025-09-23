import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String email; 
  String username; 
  String firstName;
  String lastName;
  String university;
  String major; 
  String phoneNumber; 
  String? level; 
  String? expectedGraduationDate;
  double? gpa; 
  List<String> skills; 
  String? profilePictureUrl; 
  String? shortSummary; 
  final String userType; 
  final DateTime? createdAt; 
  bool isVerified;
  String resumeVisibility; 
  String documentsVisibility; 
  List<String> followedCompanies; 
  String? location; 

  Student({
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.university,
    required this.major,
    required this.phoneNumber,
    this.level,
    this.expectedGraduationDate,
    this.gpa,
    this.skills = const [],
    this.profilePictureUrl,
    this.shortSummary,
    required this.userType,
    this.createdAt,
    this.isVerified = false,
    this.resumeVisibility = "private",
    this.documentsVisibility = "private",
    this.followedCompanies = const [],
    this.location, 
  });

  /// Convert Student object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'university': university,
      'major': major,
      'phoneNumber': phoneNumber,
      'level': level,
      'expectedGraduationDate': expectedGraduationDate,
      'gpa': gpa,
      'skills': skills,
      'profilePictureUrl': profilePictureUrl,
      'shortSummary': shortSummary,
      'userType': userType,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      'resumeVisibility': resumeVisibility,
      'documentsVisibility': documentsVisibility,
      'followedCompanies': followedCompanies,
      'location': location, // ✅ Added in map
    };
  }

  /// Create Student object from Firestore document (map)
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      email: map['email'],
      username: map['username'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      university: map['university'],
      major: map['major'],
      phoneNumber: map['phoneNumber'],
      level: map['level'],
      expectedGraduationDate: map['expectedGraduationDate'],
      gpa: map['gpa'] != null ? double.tryParse(map['gpa'].toString()) : null,
      skills: List<String>.from(map['skills'] ?? []),
      profilePictureUrl: map['profilePictureUrl'],
      shortSummary: map['shortSummary'],
      userType: map['userType'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isVerified: map['isVerified'] ?? false,
      resumeVisibility: map['resumeVisibility'] ?? "private",
      documentsVisibility: map['documentsVisibility'] ?? "private",
      followedCompanies: List<String>.from(map['followedCompanies'] ?? []),
      location: map['location'], 
    );
  }
}
