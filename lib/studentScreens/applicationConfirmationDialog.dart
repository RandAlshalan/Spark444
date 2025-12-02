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
  final String? companyName;

  const ApplicationConfirmationDialog({
    super.key,
    required this.opportunity,
    required this.resume,
    this.coverLetter,
    this.companyName,
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
    Future<void> _handleClose() async {
      final discard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x1A8D52CC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFF8D52CC)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Discard and close?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your progress will be deleted. Are you sure you want to close?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8D52CC)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            color: Color(0xFF8D52CC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D52CC),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Discard',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
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
      );

      if (discard == true) {
        Navigator.of(context).pop(null); // indicate discarded -> back to details
      }
    }

    final hasCoverLetter = coverLetter != null && coverLetter!.trim().isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      backgroundColor: Colors.white,
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
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Review Application',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please confirm your submission',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _handleClose,
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    value: companyName?.trim().isNotEmpty == true
                        ? companyName!
                        : opportunity.name,
                    icon: Icons.business_outlined,
                  ),
                  _InfoRow(
                    label: 'Type',
                    value: opportunity.type,
                    icon: Icons.category_outlined,
                  ),
                  _InfoRow(
                    label: 'Compensation',
                    value: opportunity.isPaid ? 'Paid' : 'Unpaid',
                    icon: Icons.payments_outlined,
                  ),
                  _InfoRow(
                    label: 'Work Mode',
                    value: (opportunity.workMode ?? 'Not specified').trim().isEmpty
                        ? 'Not specified'
                        : opportunity.workMode!.trim(),
                    icon: Icons.location_on_outlined,
                  ),
                  _InfoRow(
                    label: 'Location',
                    value: (opportunity.location ?? 'Not specified').trim().isEmpty
                        ? 'Not specified'
                        : opportunity.location!.trim(),
                    icon: Icons.place_outlined,
                  ),
                  if (opportunity.startDate != null)
                    _InfoRow(
                      label: 'Start Date',
                      value: DateFormat('MMM d, yyyy').format(
                        opportunity.startDate!.toDate(),
                      ),
                      icon: Icons.event_available_outlined,
                    ),
                  if (opportunity.applicationDeadline != null)
                    _InfoRow(
                      label: 'Application Deadline',
                      value: DateFormat('MMM d, yyyy').format(
                        opportunity.applicationDeadline!.toDate(),
                      ),
                      icon: Icons.calendar_today_outlined,
                    ),
                  if (opportunity.responseDeadlineVisible == true &&
                      opportunity.responseDeadline != null)
                    _InfoRow(
                      label: 'Response Deadline',
                      value: DateFormat('MMM d, yyyy').format(
                        opportunity.responseDeadline!.toDate(),
                      ),
                      icon: Icons.schedule_outlined,
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
                      valueWidget: SizedBox(
                        height: 180,
                        child: SingleChildScrollView(
                          child: Text(
                            coverLetter!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
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
                    color: const Color(0xFFF4ECFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF8D52CC).withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF8D52CC), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Review these details before sending. After submission, track or withdraw your application from the Applications tab anytime before it is reviewed.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.5,
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
                            color: Color(0xFF8D52CC),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            color: Color(0xFF8D52CC),
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
                          backgroundColor: const Color(0xFF8D52CC),
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
