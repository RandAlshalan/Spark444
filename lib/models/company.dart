
import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String? uid;
  final String email;
  final String companyName;
  final String sector;
  final String contactInfo; // Could be a contact person's name or a general contact email/phone
  final String? logoUrl;
  final String? description;
  final String userType;
  final DateTime? createdAt;
  final bool isVerified; // For business email domain verification
  final List<String> opportunitiesPosted; // To keep track of posted opportunities IDs
  final List<String> studentReviews; // To store IDs of reviews left by students

  Company({
    this.uid,
    required this.email,
    required this.companyName,
    required this.sector,
    required this.contactInfo,
    this.logoUrl,
    this.description,
    required this.userType,
    this.createdAt,
    this.isVerified = false,
    this.opportunitiesPosted = const [],
    this.studentReviews = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'companyName': companyName,
      'sector': sector,
      'contactInfo': contactInfo,
      'logoUrl': logoUrl,
      'description': description,
      'userType': userType,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      'opportunitiesPosted': opportunitiesPosted,
      'studentReviews': studentReviews,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      uid: map['uid'] as String?,
      email: map['email'],
      companyName: map['companyName'],
      sector: map['sector'],
      contactInfo: map['contactInfo'],
      logoUrl: map['logoUrl'],
      description: map['description'],
      userType: map['userType'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isVerified: map['isVerified'] ?? false,
      opportunitiesPosted: List<String>.from(map['opportunitiesPosted'] ?? []),
      studentReviews: List<String>.from(map['studentReviews'] ?? []),
    );
  }
}