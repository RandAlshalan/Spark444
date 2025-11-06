import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/opportunity.dart';
import '../models/resume.dart';

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

  @override
  Widget build(BuildContext context) {
    final hasCoverLetter = coverLetter != null && coverLetter!.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF422F5D),
                            ),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          coverLetter!.trim().length > 200
                              ? '${coverLetter!.trim().substring(0, 200)}...'
                              : coverLetter!.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
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
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF422F5D)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            color: Color(0xFF422F5D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF422F5D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        label: const Text(
                          'Submit Application',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          style: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF422F5D),
          ),
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
