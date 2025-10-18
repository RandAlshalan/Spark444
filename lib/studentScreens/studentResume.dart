import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/student.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

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
    );
  }

  // Deletes a resume from Firestore
  Future<void> _deleteResume(String resumeId) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resume?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('resumes')
            .doc(resumeId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Resume deleted.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error deleting resume: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }
// In lib/studentScreens/my_resumes_screen.dart

  // Generates the PDF data from a Resume object and returns it.
  Future<Uint8List> _generateResumePdf(Resume resume) async {
    final pdf = pw.Document();

    // Use MultiPage instead of a single Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // The header is built for every page
        header: (pw.Context context) {
          final personalDetails = resume.personalDetails;
          final fullName =
              "${personalDetails['firstName'] ?? ''} ${personalDetails['lastName'] ?? ''}"
                  .trim();
          final email = personalDetails['email'] ?? '';
          final phone = personalDetails['phone'] ?? '';

          // Add a header only on the first page
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(fullName,
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                if (email.isNotEmpty || phone.isNotEmpty)
                  pw.Text('$email | $phone'),
                pw.SizedBox(height: 15),
                pw.Divider(),
              ],
            );
          }
          // For subsequent pages, you can add a smaller header or just space
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10.0),
            child: pw.Text('$fullName - Page ${context.pageNumber}', style: const pw.TextStyle(color: PdfColors.grey)),
          );
        },
        // The build method returns a LIST of widgets that will flow across pages
        build: (pw.Context context) {
          final summary = resume.personalDetails['summary'] ?? '';

          return <pw.Widget>[
            // --- SUMMARY ---
            if (summary.isNotEmpty) ...[
              _buildSectionTitle('Summary'),
              pw.Text(summary,
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.justify),
            ],

            // --- EXPERIENCE ---
            if (resume.experiences.isNotEmpty) ...[
              _buildSectionTitle('Work Experience'),
              ...resume.experiences
                  .map((exp) => _buildExperienceItem(exp))
                  .toList(),
            ],

            // --- EDUCATION ---
            if (resume.education.isNotEmpty) ...[
              _buildSectionTitle('Education'),
              ...resume.education
                  .map((edu) => _buildEducationItem(edu))
                  .toList(),
            ],

            // --- EXTRACURRICULARS ---
            if (resume.extracurriculars.isNotEmpty) ...[
              _buildSectionTitle('Extracurricular Activities'),
              ...resume.extracurriculars
                  .map((extra) => _buildExtracurricularItem(extra))
                  .toList(),
            ],

            // --- PROJECTS ---
            if (resume.projects.isNotEmpty) ...[
              _buildSectionTitle('Projects'),
              ...resume.projects
                  .map((proj) => _buildProjectItem(proj))
                  .toList(),
            ],

            // --- SKILLS ---
            if (resume.skills.isNotEmpty) ...[
              _buildSectionTitle('Skills'),
              pw.Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      resume.skills.map((skill) => pw.Text('- $skill')).toList())
            ],

            // --- LICENSES ---
            if (resume.licenses.isNotEmpty) ...[
              _buildSectionTitle('Licenses & Certifications'),
              ...resume.licenses
                  .map((license) => _buildLicenseItem(license))
                  .toList(),
            ],

            // --- CUSTOM SECTIONS ---
            if (resume.customSections.isNotEmpty)
              ...resume.customSections.expand((section) {
                if (section.entries.isEmpty) return <pw.Widget>[];
                return [
                  _buildSectionTitle(section.sectionTitle),
                  ...section.entries
                      .map((entry) => _buildCustomFieldEntryItem(entry))
                      .toList(),
                ];
              }),

            // --- AWARDS ---
            if (resume.awards.isNotEmpty) ...[
              _buildSectionTitle('Awards'),
              ...resume.awards.map((award) => _buildAwardItem(award)).toList()
            ],

            // --- LANGUAGES ---
            if (resume.languages.isNotEmpty) ...[
              _buildSectionTitle('Languages'),
              ...resume.languages
                  .map((lang) => _buildLanguageItem(lang))
                  .toList()
            ]
          ];
        },
      ),
    );
    return pdf.save();
  }
  // Navigates to the preview screen.
  void _viewResumeAsPdf(Resume resume) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          pdfFuture: _generateResumePdf(resume),
          resumeTitle: resume.title,
        ),
      ),
    );
  }

  // --- PDF BUILD HELPERS ---
  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black),
          ),
          pw.Container(
              height: 2,
              color: PdfColors.grey700,
              margin: const pw.EdgeInsets.only(top: 2)),
        ],
      ),
    );
  }

  pw.Widget _buildExperienceItem(Experience exp) {
    final duration =
        '${DateFormat.yMMMd().format(exp.startDate)} - ${exp.isPresent ? 'Present' : (exp.endDate != null ? DateFormat.yMMMd().format(exp.endDate!) : 'N/A')}';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(exp.title,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(duration, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(exp.organization,
              style:
                  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
  }

  pw.Widget _buildEducationItem(Education edu) {
    final graduationDate = edu.isPresent
        ? 'Present'
        : (edu.endDate != null
            ? DateFormat.yMMMd().format(edu.endDate!)
            : 'N/A');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(edu.degreeName,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(graduationDate, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(edu.instituteName,
              style:
                  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    );
  }

  pw.Widget _buildProjectItem(Project project) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(project.title,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text(project.description, style: const pw.TextStyle(fontSize: 11)),
          if (project.link != null && project.link!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.UrlLink(
                destination: project.link!,
                child: pw.Text(project.link!,
                    style: const pw.TextStyle(
                        color: PdfColors.blue,
                        decoration: pw.TextDecoration.underline))),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildExtracurricularItem(Extracurricular extra) {
    final duration =
        '${DateFormat.yMMMd().format(extra.startDate)} - ${extra.isPresent ? 'Present' : (extra.endDate != null ? DateFormat.yMMMd().format(extra.endDate!) : 'N/A')}';

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(extra.role,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(duration, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(extra.organizationName,
              style:
                  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
          if (extra.description != null && extra.description!.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child:
                  pw.Text(extra.description!, style: const pw.TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildLicenseItem(License license) {
    String dates = 'Issued: ${DateFormat.yMMMd().format(license.issueDate)}';
    if (license.expirationDate != null) {
      dates += ' | Expires: ${DateFormat.yMMMd().format(license.expirationDate!)}';
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(license.name,
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(license.issuingOrganization,
              style:
                  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
          pw.Text(dates, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  pw.Widget _buildCustomFieldEntryItem(CustomFieldEntry entry) {
    final title = entry.title ?? '';
    final description = entry.description ?? '';
    String? duration;
    if (entry.startDate != null) {
      duration =
          '${DateFormat.yMMMd().format(entry.startDate!)} - ${entry.currently ? 'Present' : (entry.endDate != null ? DateFormat.yMMMd().format(entry.endDate!) : 'N/A')}';
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (duration != null)
                  pw.Text(duration, style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          if (description.isNotEmpty)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: title.isNotEmpty ? 2 : 0),
              child:
                  pw.Text(description, style: const pw.TextStyle(fontSize: 11)),
            ),
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
              pw.Text(award.title,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat.yMMMd().format(award.issueDate),
                  style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Text(award.organization,
              style:
                  pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic)),
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
          pw.Text(lang.name,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text(lang.proficiency, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Resumes',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resumes')
            .where('studentId', isEqualTo: widget.student.id)
            .orderBy('lastModifiedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description_outlined,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No Resumes Yet',
                      style: GoogleFonts.lato(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'Tap the "+" button to create your first resume.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final resumes = snapshot.data!.docs
              .map((doc) => Resume.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resumes.length,
            itemBuilder: (context, index) {
              final resume = resumes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.article_outlined,
                      color: Color(0xFF422F5D)),
                  title: Text(resume.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Modified: ${DateFormat.yMMMd().format(resume.lastModifiedAt)}'),
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
                      const PopupMenuItem(
                          value: 'view', child: Text('View as PDF')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red))),
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