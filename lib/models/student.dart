import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String university;
  final String major;
  final String phoneNumber;
  final String? level;
  final String? expectedGraduationDate;
  final double? gpa;
  final List<String> skills;
  final String? profilePictureUrl;
  final String? shortSummary;
  final String userType;
  final DateTime? createdAt;
  final bool isVerified;
  final String resumeVisibility;
  final String documentsVisibility;
  final List<String> followedCompanies;

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
  });

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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      'resumeVisibility': resumeVisibility,
      'documentsVisibility': documentsVisibility,
      'followedCompanies': followedCompanies,
    };
  }

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
      gpa: map['gpa']?.toDouble(),
      skills: List<String>.from(map['skills'] ?? []),
      profilePictureUrl: map['profilePictureUrl'],
      shortSummary: map['shortSummary'],
      userType: map['userType'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isVerified: map['isVerified'] ?? false,
      resumeVisibility: map['resumeVisibility'] ?? "private",
      documentsVisibility: map['documentsVisibility'] ?? "private",
      followedCompanies: List<String>.from(map['followedCompanies'] ?? []),
    );
  }
}
