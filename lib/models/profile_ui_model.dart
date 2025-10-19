// lib/features/profile/models/profile_ui_model.dart

import '../../../models/student.dart';

/// This is a UI Model class. Its job is to take the raw `Student` data
/// and prepare it specifically for display in the UI. This helps keep formatting
/// and display logic out of the widget tree.
class ProfileUiModel {
  final String fullName;
  final String email;
  final String? username;
  final String? phoneNumber;
  final String university;
  final String major;
  final String? level;
  final String? gpa;
  final String? graduationDate;
  final List<String> skills;
  final String? shortSummary;
  final String? profilePictureUrl;
  final List<String> followedCompanies;
  final String? location;

  const ProfileUiModel({
    required this.fullName,
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.university,
    required this.major,
    required this.level,
    required this.gpa,
    required this.graduationDate,
    required this.skills,
    required this.shortSummary,
    required this.profilePictureUrl,
    required this.followedCompanies,
    required this.location,
  });

  /// A factory constructor that creates a `ProfileUiModel` from a `Student` object.
  factory ProfileUiModel.fromStudent(Student student) {
    String? safePhone = student.phoneNumber.trim().isEmpty
        ? null
        : student.phoneNumber.trim();
    return ProfileUiModel(
      fullName: '${student.firstName} ${student.lastName}'.trim(),
      email: student.email,
      username: student.username.trim().isEmpty
          ? null
          : student.username.trim(),
      phoneNumber: safePhone,
      university: student.university,
      major: student.major,
      level: _emptyToNull(student.level),
      gpa: student.gpa?.toStringAsFixed(2),
      graduationDate: _emptyToNull(student.expectedGraduationDate),
      skills: student.skills.where((skill) => skill.trim().isNotEmpty).toList(),
      shortSummary: _emptyToNull(student.shortSummary),
      profilePictureUrl: _emptyToNull(student.profilePictureUrl),
      followedCompanies: student.followedCompanies
          .where((company) => company.trim().isNotEmpty)
          .toList(),
      location: _emptyToNull(student.location),
    );
  }

  /// A helper function to convert an empty or null string to just null.
  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
