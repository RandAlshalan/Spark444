import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/resume.dart';

/// A dialog that allows students to select a resume and optionally add a cover letter
/// when applying for an opportunity.
///
/// Returns a Map with keys:
/// - 'resume': The selected Resume object
/// - 'coverLetter': An optional cover letter string
class ResumeSelectionDialog extends StatefulWidget {
  final String studentId;

  const ResumeSelectionDialog({
    super.key,
    required this.studentId,
  });

  @override
  State<ResumeSelectionDialog> createState() => _ResumeSelectionDialogState();
}

class _ResumeSelectionDialogState extends State<ResumeSelectionDialog> {
  Resume? _selectedResume;
  final TextEditingController _coverLetterController = TextEditingController();
  bool _isLoading = true;
  List<Resume> _resumes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResumes();
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  Future<void> _loadResumes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final querySnapshot = await FirebaseFirestore.instance
          .collection('resumes')
          .where('studentId', isEqualTo: widget.studentId)
          .orderBy('lastModifiedAt', descending: true)
          .get();

      final resumes = querySnapshot.docs
          .map((doc) => Resume.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _resumes = resumes;
          _isLoading = false;
          // Auto-select the first resume if available
          if (_resumes.isNotEmpty) {
            _selectedResume = _resumes.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load resumes: $e';
        });
      }
    }
  }

  void _submit() {
    if (_selectedResume == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a resume to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'resume': _selectedResume,
      'coverLetter': _coverLetterController.text.trim(),
    });
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF422F5D),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Resume',
                      style: GoogleFonts.lato(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF422F5D),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancel,
                    tooltip: 'Cancel',
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _loadResumes,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_resumes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: Colors.grey,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Resumes Available',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a resume first before applying.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _cancel,
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Resume Selection Section
                        Row(
                          children: [
                            const Icon(
                              Icons.description,
                              size: 20,
                              color: Color(0xFF422F5D),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Choose a resume to attach',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF422F5D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select the resume that best highlights your qualifications for this opportunity',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._resumes.map((resume) => _buildResumeCard(resume)),

                        const SizedBox(height: 28),

                        // Cover Letter Section
                        Row(
                          children: [
                            const Icon(
                              Icons.edit_note,
                              size: 20,
                              color: Color(0xFF422F5D),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cover Letter',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF422F5D),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Optional',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stand out by explaining why you\'re interested in this opportunity',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _coverLetterController,
                          maxLines: 6,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            hintText:
                                'Dear Hiring Manager,\n\nI am excited to apply for this position because...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF422F5D),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            counterStyle: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Action Buttons
              if (!_isLoading && _errorMessage == null && _resumes.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF422F5D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeCard(Resume resume) {
    final isSelected = _selectedResume?.id == resume.id;
    final dateFormat = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedResume = resume;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF422F5D).withValues(alpha: 0.08)
              : Colors.grey[100],
          border: Border.all(
            color: isSelected
                ? const Color(0xFF422F5D)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF422F5D)
                      : Colors.grey[400]!,
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF422F5D)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Resume details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resume.title,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF422F5D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last modified: ${dateFormat.format(resume.lastModifiedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
