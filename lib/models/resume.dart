// lib/models/resume.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// --- Sub-Models for Type Safety ---

class Education {
  final String degreeName;
  final String instituteName;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isPresent;
  final double? gpa;

  Education({
    required this.degreeName,
    required this.instituteName,
    required this.startDate,
    this.endDate,
    this.isPresent = false,
    this.gpa,
  });

  Map<String, dynamic> toMap() => {
        'degreeName': degreeName,
        'instituteName': instituteName,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'isPresent': isPresent,
        'gpa': gpa,
      };

  factory Education.fromMap(Map<String, dynamic> map) => Education(
        degreeName: map['degreeName'] ?? '',
        instituteName: map['instituteName'] ?? '',
        startDate: (map['startDate'] as Timestamp? ?? Timestamp.now()).toDate(),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
        isPresent: map['isPresent'] ?? false,
        gpa: (map['gpa'] as num?)?.toDouble(),
      );
}

class Experience {
  final String organization;
  final String title;
  final String type;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isPresent;
  final String? city;
  final String locationType;

  Experience({
    required this.organization,
    required this.title,
    required this.type,
    required this.startDate,
    this.endDate,
    this.isPresent = false,
    this.city,
    required this.locationType,
  });

  Map<String, dynamic> toMap() => {
        'organization': organization,
        'title': title,
        'type': type,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'isPresent': isPresent,
        'city': city,
        'locationType': locationType,
      };

  factory Experience.fromMap(Map<String, dynamic> map) => Experience(
        organization: map['organization'] ?? '',
        title: map['title'] ?? '',
        type: map['type'] ?? '',
        startDate: (map['startDate'] as Timestamp? ?? Timestamp.now()).toDate(),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
        isPresent: map['isPresent'] ?? false,
        city: map['city'],
        locationType: map['locationType'] ?? 'On-site',
      );
}

class Award {
  final String title;
  final String organization;
  final DateTime issueDate;
  final String description;

  Award({
    required this.title,
    required this.organization,
    required this.issueDate,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'organization': organization,
        'issueDate': Timestamp.fromDate(issueDate),
        'description': description,
      };

  factory Award.fromMap(Map<String, dynamic> map) => Award(
        title: map['title'] ?? '',
        organization: map['organization'] ?? '',
        issueDate: (map['issueDate'] as Timestamp? ?? Timestamp.now()).toDate(),
        description: map['description'] ?? '',
      );
}

class Language {
  final String name;
  final String proficiency;

  Language({required this.name, required this.proficiency});

  Map<String, dynamic> toMap() => {'name': name, 'proficiency': proficiency};

  factory Language.fromMap(Map<String, dynamic> map) =>
      Language(name: map['name'] ?? '', proficiency: map['proficiency'] ?? '');
}


// --- Main Resume Model ---

class Resume {
  final String id;
  final String studentId;
  final String title;
  final Map<String, dynamic> personalDetails;
  final List<Education> education;
  final List<Experience> experiences;
  final List<String> skills;
  final List<Award> awards;
  final List<Language> languages;
  // Placeholder for other sections
  final List<Map<String, dynamic>> extracurriculars;
  final List<Map<String, dynamic>> licenses;
  final List<Map<String, dynamic>> customFields;

  final String? pdfUrl;
  final DateTime createdAt;

  Resume({
    required this.id,
    required this.studentId,
    required this.title,
    required this.personalDetails,
    required this.createdAt,
    this.education = const [],
    this.experiences = const [],
    this.skills = const [],
    this.awards = const [],
    this.languages = const [],
    this.extracurriculars = const [],
    this.licenses = const [],
    this.customFields = const [],
    this.pdfUrl,
  });

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'title': title,
        'personalDetails': personalDetails,
        'education': education.map((e) => e.toMap()).toList(),
        'experiences': experiences.map((e) => e.toMap()).toList(),
        'skills': skills,
        'awards': awards.map((a) => a.toMap()).toList(),
        'languages': languages.map((l) => l.toMap()).toList(),
        'extracurriculars': extracurriculars,
        'licenses': licenses,
        'customFields': customFields,
        'pdfUrl': pdfUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastModifiedAt': FieldValue.serverTimestamp(),
      };

  factory Resume.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return Resume(
      id: doc.id,
      studentId: map['studentId'] ?? '',
      title: map['title'] ?? 'Untitled Resume',
      personalDetails: Map<String, dynamic>.from(map['personalDetails'] ?? {}),
      education: (map['education'] as List? ?? []).map((e) => Education.fromMap(e)).toList(),
      experiences: (map['experiences'] as List? ?? []).map((e) => Experience.fromMap(e)).toList(),
      skills: List<String>.from(map['skills'] ?? []),
      awards: (map['awards'] as List? ?? []).map((a) => Award.fromMap(a)).toList(),
      languages: (map['languages'] as List? ?? []).map((l) => Language.fromMap(l)).toList(),
      extracurriculars: List<Map<String, dynamic>>.from(map['extracurriculars'] ?? []),
      licenses: List<Map<String, dynamic>>.from(map['licenses'] ?? []),
      customFields: List<Map<String, dynamic>>.from(map['customFields'] ?? []),
      pdfUrl: map['pdfUrl'],
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}