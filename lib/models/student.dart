import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  // The document ID from Firestore.
  final String id;

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
    required this.id, // ID is now required
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
      id: id, // The ID does not change when copying
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

  /// Converts the Student object to a Map for storing in Firestore.
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

  /// Creates a Student object from a Firestore document.
  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id, // Assign the document ID
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      university: data['university'] ?? '',
      major: data['major'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      level: data['level'],
      expectedGraduationDate: data['expectedGraduationDate'],
      gpa: data['gpa'] != null ? double.tryParse(data['gpa'].toString()) : null,
      skills: List<String>.from(data['skills'] ?? []),
      profilePictureUrl: data['profilePictureUrl'],
      shortSummary: data['shortSummary'],
      userType: data['userType'] ?? 'student',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isVerified: data['isVerified'] ?? false,
      isAcademic: data['isAcademic'] ?? false,
      resumeVisibility: data['resumeVisibility'] ?? "private",
      documentsVisibility: data['documentsVisibility'] ?? "private",
      followedCompanies: List<String>.from(data['followedCompanies'] ?? []),
      location: data['location'],
    );
  }
}

