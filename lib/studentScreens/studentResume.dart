import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spark/models/student.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/resume.dart';
import 'studentPdfPreview.dart';
import '../studentScreens/studentResumeForm.dart';
import '../services/resume_pdf_service.dart';

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
        title: Text(
          'My Resumes',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // 3. EMPTY STATE: Show a message if the student has no resumes
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Resumes Yet',
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the "+" button to create your first resume.',
                    style: TextStyle(color: Colors.grey),
                  ),
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
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.article_outlined,
                    color: Color(0xFF8D52CC),
                  ),
                  title: Text(
                    resume.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Modified: ${DateFormat.yMMMd().format(resume.lastModifiedAt)}',
                  ),
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
                        value: 'view',
                        child: Text('View as PDF'),
                      ),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // The '+' button at the bottom right
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => _navigateToForm(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
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
            child: const Text('Cancel'),
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resume deleted.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Show a red error message if something went wrong
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting resume: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewResumeAsPdf(Resume resume) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          pdfFuture: ResumePdfService.generate(resume),
          resumeTitle: resume.title,
        ),
      ),
    );
  }
} // End of _MyResumesScreenState class
