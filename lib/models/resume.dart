import 'package:cloud_firestore/cloud_firestore.dart';
class Resumes {
  final String title;
  final Map<String, dynamic> personalDetails;
  final List<Map<String, dynamic>> awards;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> experiences;
  final List<Map<String, dynamic>> extracurriculars;
  final List<Map<String, dynamic>> licenses;
  final List<Map<String, dynamic>> languages;
  final List<Map<String, dynamic>> customFields;
  final String? pdfUrl;
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;

  Resumes({
    required this.title,
    required this.personalDetails,
    this.awards = const [],
    this.education = const [],
    this.experiences = const [],
    this.extracurriculars = const [],
    this.licenses = const [],
    this.languages = const [],
    this.customFields = const [],
    this.pdfUrl,
    this.createdAt,
    this.lastModifiedAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'personalDetails': personalDetails,
        'awards': awards,
        'education': education,
        'experiences': experiences,
        'extracurriculars': extracurriculars,
        'licenses': licenses,
        'languages': languages,
        'customFields': customFields,
        'pdfUrl': pdfUrl,
        'createdAt': createdAt,
        'lastModifiedAt': lastModifiedAt,
      };

  factory Resumes.fromMap(Map<String, dynamic> map) => Resumes(
        title: map['title'],
        personalDetails: Map<String, dynamic>.from(map['personalDetails'] ?? {}),
        awards: List<Map<String, dynamic>>.from(map['awards'] ?? []),
        education: List<Map<String, dynamic>>.from(map['education'] ?? []),
        experiences: List<Map<String, dynamic>>.from(map['experiences'] ?? []),
        extracurriculars:
            List<Map<String, dynamic>>.from(map['extracurriculars'] ?? []),
        licenses: List<Map<String, dynamic>>.from(map['licenses'] ?? []),
        languages: List<Map<String, dynamic>>.from(map['languages'] ?? []),
        customFields: List<Map<String, dynamic>>.from(map['customFields'] ?? []),
        pdfUrl: map['pdfUrl'],
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
        lastModifiedAt: (map['lastModifiedAt'] as Timestamp?)?.toDate(),
      );
}
