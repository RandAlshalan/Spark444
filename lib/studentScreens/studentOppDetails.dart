// --- IMPORTS ---
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/authService.dart';
import '../services/bookmarkService.dart';
import '../theme/student_theme.dart';

// --- Color Constants (Use StudentTheme for consistency) ---
const Color _sparkPrimaryPurple = StudentTheme.primaryColor;
const Color _profileBackgroundColor = StudentTheme.backgroundColor;
const Color _profileTextColor = StudentTheme.textColor;

/// A flexible widget to display opportunity details.
///
/// It can optionally display application status and a context-aware
/// "Apply" or "Withdraw" button.
class OpportunityDetailsContent extends StatefulWidget {
  final Opportunity opportunity;
  final Function(String) onNavigateToCompany; // Callback to handle navigation

  // --- Optional Fields ---
  final Application? application; // If null, "Apply" button can be shown
  final VoidCallback? onApply; // Action for the "Apply" button
  final VoidCallback? onWithdraw; // Action for the "Withdraw" button

  const OpportunityDetailsContent({
    super.key,
    required this.opportunity,
    required this.onNavigateToCompany,
    this.application, // Pass the existing application, if any
    this.onApply, // Pass the function to call when "Apply" is tapped
    this.onWithdraw, // Pass the function to call when "Withdraw" is tapped
  });

  @override
  State<OpportunityDetailsContent> createState() => _OpportunityDetailsContentState();
}

class _OpportunityDetailsContentState extends State<OpportunityDetailsContent> {
  final AuthService _authService = AuthService();
  final BookmarkService _bookmarkService = BookmarkService();
  bool _isAddingToCalendar = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Company Header (Always shown)
                _buildDetailHeader(context, widget.opportunity),
                const SizedBox(height: 24),

                // 2. "Your Application" Section (Conditionally shown)
                if (widget.application != null) ...[
                  _buildApplicationSection(widget.application!),
                  const SizedBox(height: 24),
                ],

                // 3. Core Opportunity Info (role basics)
                _buildRoleInfoSection(widget.opportunity),

                // 4. Timeline / deadlines with add-to-calendar
                _buildTimelineSection(widget.opportunity),

                // 5. Opportunity Details (Always shown if data exists)
                if (widget.opportunity.skills != null &&
                    widget.opportunity.skills!.isNotEmpty)
                  _buildDetailSection(
                    title: 'Key Skills',
                    content: _buildChipList(widget.opportunity.skills!),
                  ),
                if (widget.opportunity.requirements != null &&
                    widget.opportunity.requirements!.isNotEmpty)
                  _buildDetailSection(
                    title: 'Requirements',
                    content: _buildRequirementList(widget.opportunity.requirements!),
                  ),
                if (widget.opportunity.preferredMajor != null &&
                    widget.opportunity.preferredMajor!.trim().isNotEmpty)
                  _buildDetailSection(
                    title: 'Preferred Major',
                    content: Text(
                      widget.opportunity.preferredMajor!,
                      style: GoogleFonts.lato(fontSize: 15, height: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 4. Context-Aware Button Bar (Conditionally shown)
        _buildBottomBar(context),
      ],
    );
  }

  // --- Bottom Bar Builder ---

  /// Builds the smart button bar at the bottom.
  Widget _buildBottomBar(BuildContext context) {
    // Scenario 1: Application exists and is withdrawable
    if (widget.application != null && widget.onWithdraw != null) {
      final status = widget.application!.status.toLowerCase();
      if (status == 'pending' || status == 'reviewed') {
        return _buildActionButton(
          context: context,
          onPressed: widget.onWithdraw!,
          label: 'Withdraw Application',
          icon: Icons.delete_forever_outlined,
          color: Colors.red.shade700,
        );
      }

      // If status is 'withdrawn', treat as if no application exists (allow reapply)
      // This case is now handled by getApplicationForOpportunity returning null,
      // so this block won't be reached for withdrawn applications
    }

    // Scenario 2: No application exists (or was withdrawn), check if application period is open
    if (widget.application == null && widget.onApply != null) {
      final now = DateTime.now();
      final applicationOpenDate = widget.opportunity.applicationOpenDate?.toDate();

      // Check if application period hasn't started yet
      if (applicationOpenDate != null && now.isBefore(applicationOpenDate)) {
        return _buildUpcomingButton(context, applicationOpenDate);
      }

      // Application period is open - show Apply Now button
      return _buildActionButton(
        context: context,
        onPressed: widget.onApply!,
        label: 'Apply Now',
        icon: Icons.send_outlined,
        color: _sparkPrimaryPurple, // Use primary color for "Apply"
      );
    }

    // Scenario 3: No button (e.g., application is already accepted/rejected)
    return const SizedBox.shrink();
  }

  /// Build an upcoming button when application period hasn't started
  Widget _buildUpcomingButton(BuildContext context, DateTime openDate) {
    final daysUntil = openDate.difference(DateTime.now()).inDays;
    final hoursUntil = openDate.difference(DateTime.now()).inHours;

    String timeMessage;
    if (daysUntil > 0) {
      timeMessage = 'Opens in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}';
    } else if (hoursUntil > 0) {
      timeMessage = 'Opens in $hoursUntil ${hoursUntil == 1 ? 'hour' : 'hours'}';
    } else {
      timeMessage = 'Opens soon';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _profileBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null, // Disabled button
          icon: const Icon(Icons.schedule),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Application Not Yet Open',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeMessage,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(vertical: 16),
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  /// Generic helper to build the floating action button container.
  Widget _buildActionButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    // Use gradient for "Apply Now" button, solid color for others
    final isApplyButton = label == 'Apply Now';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: isApplyButton
                ? const LinearGradient(
                    colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isApplyButton ? null : color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(icon, size: 20, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Detail View Components ---

  /// Builds the "Your Application" status section.
  Widget _buildApplicationSection(Application app) {
    return _buildDetailSection(
      title: 'Your Application',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Status:',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(app.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.event_note_outlined, color: Colors.grey.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Applied On: ',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                DateFormat('MMMM d, yyyy').format(app.appliedDate.toDate()),
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Adds opportunity to calendar (bookmarks it)
  Future<void> _addToCalendar() async {
    final studentId = FirebaseAuth.instance.currentUser?.uid;
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add to calendar')),
      );
      return;
    }

    setState(() => _isAddingToCalendar = true);
    try {
      await _bookmarkService.addBookmark(
        studentId: studentId,
        opportunityId: widget.opportunity.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Added "${widget.opportunity.role}" to your calendar!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCalendar = false);
      }
    }
  }

  /// Builds the deadline section with "closes in N days" and "Add to Calendar" button
  Widget _buildDeadlineSection(Opportunity opportunity) {
    final deadline = opportunity.applicationDeadline!.toDate();
    final now = DateTime.now();
    final daysUntil = deadline.difference(now).inDays;
    final hoursUntil = deadline.difference(now).inHours;

    String timeRemaining;
    Color timeColor;

    if (daysUntil > 7) {
      timeRemaining = 'Closes in $daysUntil days';
      timeColor = Colors.green.shade700;
    } else if (daysUntil > 3) {
      timeRemaining = 'Closes in $daysUntil days';
      timeColor = Colors.orange.shade700;
    } else if (daysUntil > 0) {
      timeRemaining = 'Closes in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}';
      timeColor = Colors.red.shade700;
    } else if (hoursUntil > 0) {
      timeRemaining = 'Closes in $hoursUntil ${hoursUntil == 1 ? 'hour' : 'hours'}';
      timeColor = Colors.red.shade700;
    } else {
      timeRemaining = 'Closing soon!';
      timeColor = Colors.red.shade700;
    }

    final studentId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: timeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: timeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: timeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeRemaining,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: timeColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Apply before ${DateFormat('MMM d, yyyy').format(deadline)}',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (studentId != null) ...[
            const SizedBox(height: 12),
            StreamBuilder<bool>(
              stream: _bookmarkService.isBookmarkedStream(
                studentId: studentId,
                opportunityId: opportunity.id,
              ),
              builder: (context, snapshot) {
                final isBookmarked = snapshot.data == true;

                if (isBookmarked) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Added to your calendar',
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAddingToCalendar ? null : _addToCalendar,
                    icon: _isAddingToCalendar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _isAddingToCalendar ? 'Adding...' : 'Add to Calendar',
                      style: GoogleFonts.lato(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D52CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the header card in the detail view.
  Widget _buildDetailHeader(BuildContext context, Opportunity opportunity) {
    return InkWell(
      onTap: () => widget.onNavigateToCompany(opportunity.companyId),
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: FutureBuilder<Company?>(
            future: _authService.getCompany(opportunity.companyId),
            builder: (context, snapshot) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Enhanced company logo with shadow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFF422F5D).withValues(alpha: 0.08),
                          backgroundImage:
                              (snapshot.data?.logoUrl != null &&
                                  snapshot.data!.logoUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(snapshot.data!.logoUrl!)
                              : null,
                          child:
                              (snapshot.data?.logoUrl == null ||
                                  snapshot.data!.logoUrl!.isEmpty)
                              ? const Icon(
                                  Icons.business,
                                  size: 32,
                                  color: Color(0xFF422F5D),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.data?.companyName ?? 'Loading...',
                              style: GoogleFonts.lato(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF422F5D).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                opportunity.type,
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF422F5D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 28),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Job Title - Large and prominent
                  Text(
                    opportunity.role,
                    style: GoogleFonts.lato(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),
                  if (opportunity.description != null && opportunity.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      opportunity.description!,
                      style: GoogleFonts.lato(
                        height: 1.6,
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Reusable Helper Widgets ---

  Widget _buildDetailSection({required String title, required Widget content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF422F5D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildChipList(List<String> items) {
    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF422F5D).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF422F5D).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                item,
                style: GoogleFonts.lato(
                  color: const Color(0xFF422F5D),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildChipListOld(List<String> items) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              backgroundColor: _sparkPrimaryPurple.withOpacity(0.1),
              labelStyle: const TextStyle(
                color: _sparkPrimaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRequirementList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      req,
                      style: GoogleFonts.lato(fontSize: 15, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.capitalize(),
        style: GoogleFonts.lato(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hired':
      case 'accepted':
        return Colors.green.shade600;
      case 'reviewed': // "In Progress"
        return Colors.blue.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'withdrawn':
        return Colors.grey.shade600;
      case 'pending':
      default:
        return Colors.orange.shade700;
    }
  }

  Widget _buildRoleInfoSection(Opportunity opp) {
    return _buildDetailSection(
      title: 'Opportunity Info',
      content: Column(
        children: [
          _buildInfoRow('Type', opp.type),
          _buildInfoRow('Compensation', opp.isPaid ? 'Paid' : 'Unpaid'),
          _buildInfoRow('Work Mode', opp.workMode ?? 'Not specified'),
          _buildInfoRow('Location', opp.location ?? 'Not specified'),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(Opportunity opp) {
    String? formatDate(Timestamp? ts) =>
        ts != null ? DateFormat('MMM d, y').format(ts.toDate()) : null;

    final start = formatDate(opp.startDate);
    final end = formatDate(opp.endDate);
    final deadline = formatDate(opp.applicationDeadline);
    final responseDeadline = (opp.responseDeadlineVisible == true)
        ? formatDate(opp.responseDeadline)
        : null;

    return _buildDetailSection(
      title: 'Timeline',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (start != null) _buildInfoRow('Start Date', start),
          if (end != null) _buildInfoRow('End Date', end),
          if (deadline != null)
            _buildInfoRow('Apply Before', deadline, emphasize: true),
          if (responseDeadline != null)
            _buildInfoRow('Response Deadline', responseDeadline),
          const SizedBox(height: 12),
          StreamBuilder<bool>(
            stream: _bookmarkService.isBookmarkedStream(
              studentId: FirebaseAuth.instance.currentUser?.uid ?? '',
              opportunityId: opp.id,
            ),
            builder: (context, snapshot) {
              final isBookmarked = snapshot.data == true;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAddingToCalendar
                      ? null
                      : () => _toggleCalendar(isBookmarked),
                  icon: _isAddingToCalendar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isBookmarked ? Icons.check_circle : Icons.calendar_today,
                          size: 18,
                        ),
                  label: Text(
                    _isAddingToCalendar
                        ? 'Please wait...'
                        : (isBookmarked ? 'Added to Calendar' : 'Add to Calendar'),
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isBookmarked ? Colors.green.shade600 : const Color(0xFF8D52CC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.lato(
                fontSize: 14,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                color:
                    emphasize ? const Color(0xFFD54DB9) : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCalendar(bool currentlyBookmarked) async {
    final studentId = FirebaseAuth.instance.currentUser?.uid;
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to manage calendar entries')),
      );
      return;
    }

    setState(() => _isAddingToCalendar = true);
    try {
      if (currentlyBookmarked) {
        await _bookmarkService.removeBookmark(
          studentId: studentId,
          opportunityId: widget.opportunity.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from calendar')),
          );
        }
      } else {
        await _bookmarkService.addBookmark(
          studentId: studentId,
          opportunityId: widget.opportunity.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Added to your calendar'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCalendar = false);
    }
  }
}

// --- UTILITY EXTENSION ---
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
