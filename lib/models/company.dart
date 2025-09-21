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
/*import 'package:cloud_firestore/cloud_firestore.dart';

class ContactInfo {
  final String businessEmail;
  final String phoneNumber;

  ContactInfo({required this.businessEmail, required this.phoneNumber});

  Map<String, dynamic> toJson() {
    return {
      'BusinessEmail': businessEmail,
      'phoneNumber': phoneNumber,
    };
  }
}

class Company {
  final String? uid;
  final String name;
  final String sector;
  final String? logoUrl;
  final ContactInfo contactInfo; // Use the new ContactInfo class
  final String userType;
  final DateTime? createdAt;
  final List<dynamic> followedStudents;
  final String? description;
  final String? location;
  final bool isVerified;

  const Company({
    this.uid,
    required this.name,
    required this.sector,
    this.logoUrl,
    required this.contactInfo,
    required this.userType,
    this.createdAt,
    this.followedStudents = const [],
    this.description,
    this.location,
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sector': sector,
      'logoUrl': logoUrl,
      'contactInfo': contactInfo.toJson(), // Convert ContactInfo to a map
      'userType': userType,
      'createdAt': createdAt,
      'followedStudents': followedStudents,
      'description': description,
      'location': location,
      'verified': isVerified,
    };
  }

  // You will also need to adjust the fromFirestore factory constructor
  // to parse the nested map correctly.
  factory Company.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final contactInfoData = data['contactInfo'] as Map<String, dynamic>;
    return Company(
      uid: doc.id,
      name: data['name'] as String,
      sector: data['sector'] as String,
      logoUrl: data['logoUrl'] as String?,
      contactInfo: ContactInfo(
        businessEmail: contactInfoData['BusinessEmail'] as String,
        phoneNumber: contactInfoData['phoneNumber'] as String,
      ),
      userType: data['userType'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      followedStudents: data['followedStudents'] as List<dynamic>,
      description: data['description'] as String?,
      location: data['location'] as String?,
      isVerified: data['verified'] as bool,
    );
  }
}*/