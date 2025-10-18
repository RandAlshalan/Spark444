import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/student.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // 'pw' is a prefix for PDF widgets
import 'package:url_launcher/url_launcher.dart';

import '../models/resume.dart';
import '../studentScreens/studentPdfReview.dart';
import '../studentScreens/studentResumeForm.dart';

// --- WIDGET DEFINITION ---

/// This class is the main screen widget.
/// It's a "StatefulWidget" because the list of resumes can change.
/// It needs to know *which* student is logged in, so it requires a [Student] object.
class MyResumesScreen extends StatefulWidget {
  final Student student;
  const MyResumesScreen({super.key, required this.student});

  @override
  State<MyResumesScreen> createState() => _MyResumesScreenState();
}

// --- STATE & LOGIC ---

/// This class holds all the logic and the UI for the `MyResumesScreen`.
class _MyResumesScreenState extends State<MyResumesScreen> {
  // -------------------------------------------------------------------
  // 1. MAIN BUILD METHOD (The UI)
  // This is the most important method. It builds the visual part of the screen.
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The bar at the top of the screen
      appBar: AppBar(
        title: Text('My Resumes',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
      ),
      // The main content of the screen
      body: StreamBuilder<QuerySnapshot>(
        // This widget automatically listens for changes in the database (Firestore)
        stream: FirebaseFirestore.instance
            .collection('resumes')
            // We only get resumes where the 'studentId' matches our current student's ID
            .where('studentId', isEqualTo: widget.student.id)
            // Show the newest resumes first
            .orderBy('lastModifiedAt', descending: true)
            .snapshots(),

        // The 'builder' function runs every time new data comes from the stream
        builder: (context, snapshot) {
          // 1. LOADING STATE: Show a spinner while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. ERROR STATE: Show an error message if something went wrong
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          // 3. EMPTY STATE: Show a message if the student has no resumes
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

          // 4. SUCCESS STATE: We have data, so we format it
          // Convert the raw Firestore documents into a list of 'Resume' objects
          final resumes = snapshot.data!.docs
              .map((doc) => Resume.fromFirestore(doc))
              .toList();

          // Display the resumes in a scrollable list
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resumes.length,
            itemBuilder: (context, index) {
              final resume = resumes[index];
              // Each list item is a 'Card'
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.article_outlined,
                      color: Color(0xFF422F5D)),
                  title: Text(resume.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Modified: ${DateFormat.yMMMd().format(resume.lastModifiedAt)}'),
                  // This is the 'three-dot' menu on the right
                  trailing: PopupMenuButton<String>(
                    // This 'onSelected' function runs when the user taps an option
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToForm(resume: resume);
                      } else if (value == 'delete') {
                        _deleteResume(resume.id);
                      } else if (value == 'view') {
                        _viewResumeAsPdf(resume);
                      }
                    },
                    // These are the items in the menu
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

      // The '+' button at the bottom right
      floatingActionButton: FloatingActionButton(
        // When pressed, navigate to the form to create a *new* resume (no 'resume' object is passed)
        onPressed: () => _navigateToForm(),
        backgroundColor: const Color(0xFF422F5D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 2. UI ACTIONS (Functions called by buttons)
  // These functions handle user taps for navigation and database changes.
  // -------------------------------------------------------------------

  /// This function opens the 'ResumeFormScreen'.
  /// If a [resume] is provided, it opens the form in 'Edit Mode'.
  /// If [resume] is null, it opens the form in 'Create Mode'.
  void _navigateToForm({Resume? resume}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResumeFormScreen(
          student: widget.student,
          resume: resume, // This will be null if it's a new resume
        ),
      ),
    );
  }

  /// This function deletes a resume from Firestore.
  Future<void> _deleteResume(String resumeId) async {
    // First, show a popup dialog to ask the user "Are you sure?"
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resume?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          // Cancel button
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          // Delete button
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Only delete if the user clicked the 'Delete' button
    if (confirm == true) {
      try {
        // The command to delete the document from the database
        await FirebaseFirestore.instance
            .collection('resumes')
            .doc(resumeId)
            .delete();

        // Show a green success message at the bottom
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Resume deleted.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        // Show a red error message if something went wrong
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error deleting resume: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  /// This function opens the 'PdfPreviewScreen'.
  /// It passes the [_generateResumePdf] function (a 'Future') to the
  /// preview screen, which will run it and show a loading spinner while it works.
  void _viewResumeAsPdf(Resume resume) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          // Pass the function that *will* create the PDF
          pdfFuture: _generateResumePdf(resume),
          resumeTitle: resume.title,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 3. PDF GENERATION LOGIC
  // These functions are ONLY for creating the PDF document.
  // -------------------------------------------------------------------

  /// This is the main function that builds the entire PDF.
  /// It takes a [Resume] object and returns the PDF file as [Uint8List] (a list of bytes).
  Future<Uint8List> _generateResumePdf(Resume resume) async {
    // Create a new, blank PDF document
    final pdf = pw.Document();

    // Add a page to the document. We use 'MultiPage' because a
    // resume might be longer than one page.
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        
        // --- PDF Header ---
        // This 'header' function runs for *every* new page
        header: (pw.Context context) {
          final personalDetails = resume.personalDetails;
          final fullName =
              "${personalDetails['firstName'] ?? ''} ${personalDetails['lastName'] ?? ''}"
                  .trim();
          final email = personalDetails['email'] ?? '';
          final phone = personalDetails['phone'] ?? '';

          // Only show the big header on the FIRST page
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
          // Show a smaller header on all other pages
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10.0),
            child: pw.Text('$fullName - Page ${context.pageNumber}',
                style: const pw.TextStyle(color: PdfColors.grey)),
          );
        },
        
        // --- PDF Body ---
        // This 'build' function returns a LIST of PDF widgets
        // that will flow across multiple pages.
        build: (pw.Context context) {
          final summary = resume.personalDetails['summary'] ?? '';

          // We return a list of all the sections
          return <pw.Widget>[
            // --- SUMMARY Section ---
            if (summary.isNotEmpty) ...[
              _buildSectionTitle('Summary'),
              pw.Text(summary,
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.justify),
            ],

            // --- EXPERIENCE Section ---
            if (resume.experiences.isNotEmpty) ...[
              _buildSectionTitle('Work Experience'),
              // We 'map' (convert) each 'exp' object into a widget
              ...resume.experiences
                  .map((exp) => _buildExperienceItem(exp))
                  .toList(),
            ],

            // --- EDUCATION Section ---
            if (resume.education.isNotEmpty) ...[
              _buildSectionTitle('Education'),
              ...resume.education
                  .map((edu) => _buildEducationItem(edu))
                  .toList(),
            ],

            // --- EXTRACURRICULARS Section ---
            if (resume.extracurriculars.isNotEmpty) ...[
              _buildSectionTitle('Extracurricular Activities'),
              ...resume.extracurriculars
                  .map((extra) => _buildExtracurricularItem(extra))
                  .toList(),
            ],

            // --- PROJECTS Section ---
            if (resume.projects.isNotEmpty) ...[
              _buildSectionTitle('Projects'),
              ...resume.projects
                  .map((proj) => _buildProjectItem(proj))
                  .toList(),
            ],

            // --- SKILLS Section ---
            if (resume.skills.isNotEmpty) ...[
              _buildSectionTitle('Skills'),
              pw.Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      resume.skills.map((skill) => pw.Text('- $skill')).toList())
            ],

            // --- LICENSES Section ---
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

            // --- AWARDS Section ---
            if (resume.awards.isNotEmpty) ...[
              _buildSectionTitle('Awards'),
              ...resume.awards.map((award) => _buildAwardItem(award)).toList()
            ],

            // --- LANGUAGES Section ---
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
    
    // Finally, save the PDF document and return the data
    return pdf.save();
  }

  // -------------------------------------------------------------------
  // 4. PDF HELPER WIDGETS
  // These are small, private functions to help build the PDF.
  // Each one creates a small part of the PDF.
  // -------------------------------------------------------------------

  /// Helper to create a standard, uppercase title with a line under it.
  /// e.g., "WORK EXPERIENCE"
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

  /// Helper to format one 'Experience' item for the PDF.
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

  /// Helper to format one 'Education' item for the PDF.
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

  /// Helper to format one 'Project' item for the PDF.
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
          // Only show the link if it exists
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

  /// Helper to format one 'Extracurricular' item for the PDF.
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

  /// Helper to format one 'License' item for the PDF.
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
          pw.Text(dates,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  /// Helper to format one 'CustomFieldEntry' item for the PDF.
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

  /// Helper to format one 'Award' item for the PDF.
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

  /// Helper to format one 'Language' item for the PDF.
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
} // End of _MyResumesScreenState class