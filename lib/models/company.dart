import 'package:cloud_firestore/cloud_firestore.dart';
class Company {
  final String? uid;
  final String email;
  final String name;
  final String logoUrl;
  final String sector;
  final String contactInfo;
  final String? description;
  final String? location;
  final String userType;
  final DateTime? createdAt;
  final bool isVerified;

  Company({
    this.uid,
    required this.email,
    required this.name,
    required this.logoUrl,
    required this.sector,
    required this.contactInfo,
    this.description,
    this.location,
    required this.userType,
    this.createdAt,
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'logoUrl': logoUrl,
      'sector': sector,
      'contactInfo': contactInfo,
      'description': description,
      'location': location,
      'userType': userType,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isVerified': isVerified,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      email: map['email'],
      name: map['name'],
      logoUrl: map['logoUrl'],
      sector: map['sector'],
      contactInfo: map['contactInfo'],
      description: map['description'],
      location: map['location'],
      userType: map['userType'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isVerified: map['isVerified'] ?? false,
    );
  }
}
