import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResumePickerSheet extends StatefulWidget {
  final String studentId;
  const ResumePickerSheet({super.key, required this.studentId});

  @override
  State<ResumePickerSheet> createState() => _ResumePickerSheetState();
}

class _ResumePickerSheetState extends State<ResumePickerSheet> {
  String? selectedResumeId;
  String? selectedTrainingType;

  final List<String> trainingTypes = [
    'Job Interview',
    'Technical Interview',
    'Behavioral Questions',
    'English Practice'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Resume & Training Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // قائمة الريزميات
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('resumes')
                .where('studentId', isEqualTo: widget.studentId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final resumes = snapshot.data!.docs;

              if (resumes.isEmpty) {
                return const Text('No resumes found.');
              }

              return DropdownButtonFormField<String>(
                value: selectedResumeId,
                decoration: const InputDecoration(labelText: 'Select Resume'),
                items: resumes.map((doc) {
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(doc['title']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedResumeId = value),
              );
            },
          ),

          const SizedBox(height: 16),

          // نوع التدريب
          DropdownButtonFormField<String>(
            value: selectedTrainingType,
            decoration: const InputDecoration(labelText: 'Training Type'),
            items: trainingTypes
                .map((type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => selectedTrainingType = value),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: selectedResumeId != null && selectedTrainingType != null
                ? () {
                    Navigator.pop(context, {
                      'resumeId': selectedResumeId,
                      'trainingType': selectedTrainingType,
                    });
                  }
                : null,
            icon: const Icon(Icons.check),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF422F5D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
