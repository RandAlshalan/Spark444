import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/student.dart';

/// Service to check if a student's profile is complete
class ProfileCompletionService {
  static final ProfileCompletionService _instance = ProfileCompletionService._internal();
  factory ProfileCompletionService() => _instance;
  ProfileCompletionService._internal();

  /// Check if student profile is complete
  /// Returns a map with 'isComplete' boolean and 'missingFields' list
  Future<Map<String, dynamic>> checkProfileCompletion(String studentId) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        return {
          'isComplete': false,
          'missingFields': ['Profile not found'],
        };
      }

      final student = Student.fromFirestore(studentDoc);
      final missingFields = <String>[];

      // Check required fields
      if (student.firstName.trim().isEmpty) missingFields.add('First Name');
      if (student.lastName.trim().isEmpty) missingFields.add('Last Name');
      if (student.email.trim().isEmpty) missingFields.add('Email');
      if (student.phoneNumber.trim().isEmpty) missingFields.add('Phone Number');
      if (student.university.trim().isEmpty) missingFields.add('University');
      if (student.major.trim().isEmpty) missingFields.add('Major');
      
      // Important fields
      if (student.level == null || student.level!.trim().isEmpty) {
        missingFields.add('Academic Level');
      }
      if (student.expectedGraduationDate == null || student.expectedGraduationDate!.trim().isEmpty) {
        missingFields.add('Expected Graduation Date');
      }
      if (student.gpa == null) {
        missingFields.add('GPA');
      }
      if (student.skills.isEmpty) {
        missingFields.add('Skills');
      }
      
      return {
        'isComplete': missingFields.isEmpty,
        'missingFields': missingFields,
      };
    } catch (e) {
      debugPrint('❌ Error checking profile completion: $e');
      return {
        'isComplete': false,
        'missingFields': ['Error checking profile'],
      };
    }
  }

  /// Stream to monitor profile completion in real-time
  Stream<Map<String, dynamic>> profileCompletionStream(String studentId) {
    return FirebaseFirestore.instance
        .collection('student')
        .doc(studentId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) {
        return {
          'isComplete': false,
          'missingFields': ['Profile not found'],
        };
      }

      final student = Student.fromFirestore(snapshot);
      final missingFields = <String>[];

      // Check required fields
      if (student.firstName.trim().isEmpty) missingFields.add('First Name');
      if (student.lastName.trim().isEmpty) missingFields.add('Last Name');
      if (student.email.trim().isEmpty) missingFields.add('Email');
      if (student.phoneNumber.trim().isEmpty) missingFields.add('Phone Number');
      if (student.university.trim().isEmpty) missingFields.add('University');
      if (student.major.trim().isEmpty) missingFields.add('Major');
      
      if (student.level == null || student.level!.trim().isEmpty) {
        missingFields.add('Academic Level');
      }
      if (student.expectedGraduationDate == null || student.expectedGraduationDate!.trim().isEmpty) {
        missingFields.add('Expected Graduation Date');
      }
      if (student.gpa == null) {
        missingFields.add('GPA');
      }
      if (student.skills.isEmpty) {
        missingFields.add('Skills');
      }

      return {
        'isComplete': missingFields.isEmpty,
        'missingFields': missingFields,
      };
    });
  }
}