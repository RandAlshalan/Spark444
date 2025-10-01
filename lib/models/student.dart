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
  bool isAcademic;
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
    this.isAcademic = false,
    this.resumeVisibility = "private",
    this.documentsVisibility = "private",
    this.followedCompanies = const [],
    this.location,
  });

  Student copyWith({
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? university,
    String? major,
    String? phoneNumber,
    String? level,
    String? expectedGraduationDate,
    double? gpa,
    List<String>? skills,
    String? profilePictureUrl,
    String? shortSummary,
    bool? isVerified,
    bool? isAcademic,
    String? resumeVisibility,
    String? documentsVisibility,
    List<String>? followedCompanies,
    String? location,
    // Explicit null flags to differentiate between not provided and explicitly null
    bool levelSetToNull = false,
    bool expectedGraduationDateSetToNull = false,
    bool gpaSetToNull = false,
    bool profilePictureUrlSetToNull = false,
    bool shortSummarySetToNull = false,
    bool locationSetToNull = false,
  }) {
    return Student(
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      university: university ?? this.university,
      major: major ?? this.major,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      level: levelSetToNull ? null : (level ?? this.level),
      expectedGraduationDate: expectedGraduationDateSetToNull ? null : (expectedGraduationDate ?? this.expectedGraduationDate),
      gpa: gpaSetToNull ? null : (gpa ?? this.gpa),
      skills: skills ?? List<String>.from(this.skills),
      profilePictureUrl: profilePictureUrlSetToNull ? null : (profilePictureUrl ?? this.profilePictureUrl),
      shortSummary: shortSummarySetToNull ? null : (shortSummary ?? this.shortSummary),
      userType: userType,
      createdAt: createdAt,
      isVerified: isVerified ?? this.isVerified,
      isAcademic: isAcademic ?? this.isAcademic,
      resumeVisibility: resumeVisibility ?? this.resumeVisibility,
      documentsVisibility: documentsVisibility ?? this.documentsVisibility,
      followedCompanies:
          followedCompanies ?? List<String>.from(this.followedCompanies),
      location: locationSetToNull ? null : (location ?? this.location),
    );
  }

  /// لتحويل Student إلى Map (تخزين في Firestore)
  Map<String, dynamic> toMap({bool includeMetadata = true}) {
    final map = <String, dynamic>{
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
      'isVerified': isVerified,
      'isAcademic': isAcademic,
      'resumeVisibility': resumeVisibility,
      'documentsVisibility': documentsVisibility,
      'followedCompanies': followedCompanies,
      'location': location,
    };

    if (includeMetadata) {
      map['createdAt'] = createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp();
    }

    return map;
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
      gpa: map['gpa'] != null ? double.tryParse(map['gpa'].toString()) : null,
      skills: List<String>.from(map['skills'] ?? []),
      profilePictureUrl: map['profilePictureUrl'],
      shortSummary: map['shortSummary'],
      userType: map['userType'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isVerified: map['isVerified'] ?? false,
      isAcademic: map['isAcademic'] ?? false,
      resumeVisibility: map['resumeVisibility'] ?? "private",
      documentsVisibility: map['documentsVisibility'] ?? "private",
      followedCompanies: List<String>.from(map['followedCompanies'] ?? []),
      location: map['location'],
    );
  }
}
