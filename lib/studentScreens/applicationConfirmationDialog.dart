import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/opportunity.dart';
import '../models/resume.dart';
import '../theme/student_theme.dart';

/// Enhanced confirmation dialog for application submission
///
/// Shows a detailed review of the application before final submission
class ApplicationConfirmationDialog extends StatelessWidget {
  final Opportunity opportunity;
  final Resume resume;
  final String? coverLetter;

  const ApplicationConfirmationDialog({
    super.key,
    required this.opportunity,
    required this.resume,
    this.coverLetter,
  });

  // Cache text styles for performance
  static final _titleStyle = GoogleFonts.lato(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF422F5D),
  );

  static final _sectionHeaderStyle = GoogleFonts.lato(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF422F5D),
  );

  @override
  Widget build(BuildContext context) {
    final hasCoverLetter = coverLetter != null && coverLetter!.trim().isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 600 ? 550 : screenWidth * 0.9,
          maxHeight: screenHeight * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF422F5D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Color(0xFF422F5D),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review Application',
                            style: _titleStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please confirm your submission',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Opportunity Details
                _buildSectionHeader('Opportunity Details', Icons.work_outline),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _InfoRow(
                    label: 'Position',
                    value: opportunity.role,
                    icon: Icons.badge_outlined,
                  ),
                  _InfoRow(
                    label: 'Company/Organization',
                    value: opportunity.name,
                    icon: Icons.business_outlined,
                  ),
                  _InfoRow(
                    label: 'Type',
                    value: opportunity.type,
                    icon: Icons.category_outlined,
                  ),
                  if (opportunity.workMode != null && opportunity.workMode!.isNotEmpty)
                    _InfoRow(
                      label: 'Work Mode',
                      value: opportunity.workMode!,
                      icon: Icons.location_on_outlined,
                    ),
                  if (opportunity.applicationDeadline != null)
                    _InfoRow(
                      label: 'Application Deadline',
                      value: DateFormat('MMM d, yyyy').format(
                        opportunity.applicationDeadline!.toDate(),
                      ),
                      icon: Icons.calendar_today_outlined,
                    ),
                ]),

                const SizedBox(height: 24),

                // Application Materials
                _buildSectionHeader('Your Application', Icons.folder_outlined),
                const SizedBox(height: 12),
                _buildInfoCard([
                  _InfoRow(
                    label: 'Resume',
                    value: resume.title,
                    icon: Icons.description_outlined,
                    valueWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resume.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last updated: ${DateFormat('MMM d, yyyy').format(resume.lastModifiedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCoverLetter)
                    _InfoRow(
                      label: 'Cover Letter',
                      value: '${coverLetter!.trim().length} characters',
                      icon: Icons.edit_note_outlined,
                      valueWidget: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            coverLetter!.trim(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[900],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),

                const SizedBox(height: 24),

                // Important Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Once submitted, you can track your application status in the Applications section. You may withdraw your application at any time before it is reviewed.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[900],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: Color(0xFF422F5D),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            color: Color(0xFF422F5D),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF422F5D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.send_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF422F5D)),
        const SizedBox(width: 8),
        Text(
          title,
          style: _sectionHeaderStyle,
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.map((row) {
          final index = rows.indexOf(row);
          return Column(
            children: [
              if (index > 0) const Divider(height: 24),
              _buildInfoRow(row),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoRow(_InfoRow row) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(row.icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              row.valueWidget ??
                  Text(
                    row.value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final IconData icon;
  final Widget? valueWidget;

  _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueWidget,
  });
}
