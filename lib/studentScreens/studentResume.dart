// lib/studentScreens/my_resumes_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/student.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/resume.dart';
import '../studentScreens/studentPdfReview.dart';
import '../studentScreens/studentResumeForm.dart';

class MyResumesScreen extends StatefulWidget {
  final Student student;
  const MyResumesScreen({super.key, required this.student});

  @override
  State<MyResumesScreen> createState() => _MyResumesScreenState();
}

class _MyResumesScreenState extends State<MyResumesScreen> {
  // Navigates to the form for editing or creating a resume
  void _navigateToForm({Resume? resume}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResumeFormScreen(
          student: widget.student,
          resume: resume,
        ),
      ),
    ).then((_) {
      // This makes the list refresh after coming back from the form screen
      setState(() {});
    });
  }

  // Deletes a resume from Firestore
  Future<void> _deleteResume(String resumeId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resume?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('resumes').doc(resumeId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resume deleted.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting resume: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // Generates the PDF data from a Resume object and returns it.
  Future<Uint8List> _generateResumePdf(Resume resume) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          final personalDetails = resume.personalDetails;
          final fullName = "${personalDetails['firstName'] ?? ''} ${personalDetails['lastName'] ?? ''}".trim();
          final email = personalDetails['email'] ?? '';
          final phone = personalDetails['phone'] ?? '';
          final summary = personalDetails['summary'] ?? '';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(fullName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  if (email.isNotEmpty || phone.isNotEmpty)
                    pw.Text('$email | $phone'),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Divider(),
              if (summary.isNotEmpty) ...[
                _buildSectionTitle('Summary'),
                pw.Text(summary, style: const pw.TextStyle(fontSize: 11), textAlign: pw.TextAlign.justify),
              ],
              if (resume.experiences.isNotEmpty) ...[
                _buildSectionTitle('Work Experience'),
                ...resume.experiences.map((exp) => _buildExperienceItem(exp)).toList(),
              ],
              if (resume.education.isNotEmpty) ...[
                _buildSectionTitle('Education'),
                ...resume.education.map((edu) => _buildEducationItem(edu)).toList(),
              ],
              if (resume.skills.isNotEmpty) ...[
                _buildSectionTitle('Skills'),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: resume.skills.map((skill) => pw.Text('• $skill')).toList()
                )
              ],
              if (resume.awards.isNotEmpty) ...[
                 _buildSectionTitle('Awards'),
                 ...resume.awards.map((award) => _buildAwardItem(award)).toList()
              ],
              if (resume.languages.isNotEmpty) ...[
                _buildSectionTitle('Languages'),
                 ...resume.languages.map((lang) => _buildLanguageItem(lang)).toList()
              ]
            ],
          );
        },
      ),
    );
    // Return the generated PDF data
    return pdf.save();
  }
  
  // Navigates to the preview screen.
  void _viewResumeAsPdf(Resume resume) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          // We pass the function that generates the PDF as a future
          pdfFuture: _generateResumePdf(resume),
          resumeTitle: resume.title,
        ),
      ),
    );
  }

  // Helper widgets for PDF layout
  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
          ),
          pw.Container(height: 2, color: PdfColors.grey700, margin: const pw.EdgeInsets.only(top: 2)),
        ],
      ),
    );
  }

  pw.Widget _buildExperienceItem(Experience exp) {
    final duration = '${DateFormat.yMMMd().format(exp.startDate)} - ${exp.isPresent ? 'Present' : (exp.endDate != null ? DateFormat.yMMMd().format(exp.endDate!) : 'N/A')}';
    
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(exp.title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(duration, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(exp.organization, style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
  }

  pw.Widget _buildEducationItem(Education edu) {
    final graduationDate = edu.isPresent ? 'Present' : (edu.endDate != null ? DateFormat.yMMMd().format(edu.endDate!) : 'N/A');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(edu.degreeName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(graduationDate, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(edu.instituteName, style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
  }

  pw.Widget _buildAwardItem(Award award) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(award.title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat.yMMMd().format(award.issueDate), style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(award.organization, style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
  }

  pw.Widget _buildLanguageItem(Language lang) {
     return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(lang.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text(lang.proficiency, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Resumes', style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resumes')
            .where('studentId', isEqualTo: widget.student.id)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Display the error in a user-friendly way
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No Resumes Yet', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Tap the "+" button to create your first resume.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final resumes = snapshot.data!.docs.map((doc) => Resume.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resumes.length,
            itemBuilder: (context, index) {
              final resume = resumes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.article_outlined, color: Color(0xFF422F5D)),
                  title: Text(resume.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Modified: ${DateFormat.yMMMd().format(resume.createdAt)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToForm(resume: resume);
                      } else if (value == 'delete') {
                        _deleteResume(resume.id);
                      } else if (value == 'view') {
                        _viewResumeAsPdf(resume);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Text('View as PDF')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFF422F5D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}