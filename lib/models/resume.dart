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
  final String? description;

  Experience({
    required this.organization,
    required this.title,
    required this.type,
    required this.startDate,
    this.endDate,
    this.isPresent = false,
    this.city,
    required this.locationType,
    this.description,
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
        'description': description,
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
        description: map['description'],
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

class Project {
  final String title;
  final String description;
  final String? link;

  Project({required this.title, required this.description, this.link});

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'link': link,
      };

  factory Project.fromMap(Map<String, dynamic> map) => Project(
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        link: map['link'],
      );
}

class Extracurricular {
  final String organizationName;
  final String? eventName;
  final String role;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isPresent;

  Extracurricular({
    required this.organizationName,
    this.eventName,
    required this.role,
    this.description,
    required this.startDate,
    this.endDate,
    this.isPresent = false,
  });

  Map<String, dynamic> toMap() => {
        'organizationName': organizationName,
        'eventName': eventName,
        'role': role,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'isPresent': isPresent,
      };

  factory Extracurricular.fromMap(Map<String, dynamic> map) => Extracurricular(
        organizationName: map['organizationName'] ?? '',
        eventName: map['eventName'],
        role: map['role'] ?? '',
        description: map['description'],
        startDate: (map['startDate'] as Timestamp? ?? Timestamp.now()).toDate(),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
        isPresent: map['isPresent'] ?? false,
      );
}

class License {
  final String name;
  final String issuingOrganization;
  final DateTime issueDate;
  final DateTime? expirationDate;

  License({
    required this.name,
    required this.issuingOrganization,
    required this.issueDate,
    this.expirationDate,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'issuingOrganization': issuingOrganization,
        'issueDate': Timestamp.fromDate(issueDate),
        'expirationDate':
            expirationDate != null ? Timestamp.fromDate(expirationDate!) : null,
      };

  factory License.fromMap(Map<String, dynamic> map) => License(
        name: map['name'] ?? '',
        issuingOrganization: map['issuingOrganization'] ?? '',
        issueDate: (map['issueDate'] as Timestamp? ?? Timestamp.now()).toDate(),
        expirationDate: (map['expirationDate'] as Timestamp?)?.toDate(),
      );
}

class CustomFieldEntry {
  final String? title;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool currently;

  CustomFieldEntry({
    this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.currently = false,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'currently': currently,
      };

  factory CustomFieldEntry.fromMap(Map<String, dynamic> map) =>
      CustomFieldEntry(
        title: map['title'],
        description: map['description'],
        startDate: (map['startDate'] as Timestamp?)?.toDate(),
        endDate: (map['endDate'] as Timestamp?)?.toDate(),
        currently: map['currently'] ?? false,
      );
}

class CustomSection {
  String sectionTitle;
  List<CustomFieldEntry> entries;

  CustomSection({
    required this.sectionTitle,
    this.entries = const [],
  });

  Map<String, dynamic> toMap() => {
        'sectionTitle': sectionTitle,
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory CustomSection.fromMap(Map<String, dynamic> map) => CustomSection(
        sectionTitle: map['sectionTitle'] ?? 'Untitled Section',
        entries: (map['entries'] as List? ?? [])
            .map((e) => CustomFieldEntry.fromMap(e))
            .toList(),
      );
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
  final List<Project> projects;
  final List<Extracurricular> extracurriculars;
  final List<License> licenses;
  final List<CustomSection> customSections;

  final String? pdfUrl;
  final DateTime createdAt;
  final DateTime lastModifiedAt;

  Resume({
    required this.id,
    required this.studentId,
    required this.title,
    required this.personalDetails,
    required this.createdAt,
    required this.lastModifiedAt,
    this.education = const [],
    this.experiences = const [],
    this.skills = const [],
    this.awards = const [],
    this.languages = const [],
    this.projects = const [],
    this.extracurriculars = const [],
    this.licenses = const [],
    this.customSections = const [],
    this.pdfUrl,
  });

  factory Resume.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return Resume(
      id: doc.id,
      studentId: map['studentId'] ?? '',
      title: map['title'] ?? 'Untitled Resume',
      personalDetails: Map<String, dynamic>.from(map['personalDetails'] ?? {}),
      education: (map['education'] as List? ?? [])
          .map((e) => Education.fromMap(e))
          .toList(),
      experiences: (map['experiences'] as List? ?? [])
          .map((e) => Experience.fromMap(e))
          .toList(),
      skills: List<String>.from(map['skills'] ?? []),
      awards:
          (map['awards'] as List? ?? []).map((a) => Award.fromMap(a)).toList(),
      languages: (map['languages'] as List? ?? [])
          .map((l) => Language.fromMap(l))
          .toList(),
      projects: (map['projects'] as List? ?? [])
          .map((p) => Project.fromMap(p))
          .toList(),
      extracurriculars: (map['extracurriculars'] as List? ?? [])
          .map((e) => Extracurricular.fromMap(e))
          .toList(),
      licenses: (map['licenses'] as List? ?? [])
          .map((l) => License.fromMap(l))
          .toList(),
      customSections: (map['customSections'] as List? ?? [])
          .map((cs) => CustomSection.fromMap(cs))
          .toList(),
      pdfUrl: map['pdfUrl'],
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      lastModifiedAt: (map['lastModifiedAt'] as Timestamp? ??
              map['createdAt'] as Timestamp? ??
              Timestamp.now())
          .toDate(),
    );
  }
}