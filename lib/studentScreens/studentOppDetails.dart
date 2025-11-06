// --- IMPORTS ---
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/authService.dart';
import '../theme/student_theme.dart';

// --- Color Constants (Use StudentTheme for consistency) ---
const Color _sparkPrimaryPurple = StudentTheme.primaryColor;
const Color _profileBackgroundColor = StudentTheme.backgroundColor;
const Color _profileTextColor = StudentTheme.textColor;

/// A flexible widget to display opportunity details.
///
/// It can optionally display application status and a context-aware
/// "Apply" or "Withdraw" button.
class OpportunityDetailsContent extends StatelessWidget {
  final Opportunity opportunity;
  final Function(String) onNavigateToCompany; // Callback to handle navigation

  // --- Optional Fields ---
  final Application? application; // If null, "Apply" button can be shown
  final VoidCallback? onApply; // Action for the "Apply" button
  final VoidCallback? onWithdraw; // Action for the "Withdraw" button

  final AuthService _authService = AuthService();

  OpportunityDetailsContent({
    super.key,
    required this.opportunity,
    required this.onNavigateToCompany,
    this.application, // Pass the existing application, if any
    this.onApply, // Pass the function to call when "Apply" is tapped
    this.onWithdraw, // Pass the function to call when "Withdraw" is tapped
  });

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
                _buildDetailHeader(context, opportunity),
                const SizedBox(height: 24),

                // 2. "Your Application" Section (Conditionally shown)
                if (application != null) ...[
                  _buildApplicationSection(application!),
                  const SizedBox(height: 24),
                ],

                // 3. Opportunity Details (Always shown)
                _buildDetailKeyInfoSection(opportunity),
                const SizedBox(height: 24),
                if (opportunity.description != null &&
                    opportunity.description!.isNotEmpty)
                  _buildDetailSection(
                    title: 'Description',
                    content: Text(
                      opportunity.description!,
                      style: GoogleFonts.lato(
                        height: 1.6,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                if (opportunity.skills != null &&
                    opportunity.skills!.isNotEmpty)
                  _buildDetailSection(
                    title: 'Key Skills',
                    content: _buildChipList(opportunity.skills!),
                  ),
                if (opportunity.requirements != null &&
                    opportunity.requirements!.isNotEmpty)
                  _buildDetailSection(
                    title: 'Requirements',
                    content: _buildRequirementList(opportunity.requirements!),
                  ),
                _buildDetailSection(
                  title: 'More Info',
                  content: _buildMoreInfo(opportunity),
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
    if (application != null && onWithdraw != null) {
      final status = application!.status.toLowerCase();
      if (status == 'pending' || status == 'reviewed') {
        return _buildActionButton(
          context: context,
          onPressed: onWithdraw!,
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
    if (application == null && onApply != null) {
      final now = DateTime.now();
      final applicationOpenDate = opportunity.applicationOpenDate?.toDate();

      // Check if application period hasn't started yet
      if (applicationOpenDate != null && now.isBefore(applicationOpenDate)) {
        return _buildUpcomingButton(context, applicationOpenDate);
      }

      // Application period is open - show Apply Now button
      return _buildActionButton(
        context: context,
        onPressed: onApply!,
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
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 20),
            ],
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
          _buildInfoTile(
            icon: Icons.event_note_outlined,
            title: 'Applied On',
            value: DateFormat('MMMM d, yyyy').format(app.appliedDate.toDate()),
          ),
        ],
      ),
    );
  }

  /// Builds the header card in the detail view.
  Widget _buildDetailHeader(BuildContext context, Opportunity opportunity) {
    return InkWell(
      onTap: () => onNavigateToCompany(opportunity.companyId),
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
                  const SizedBox(height: 12),
                  // Quick info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (opportunity.location != null && opportunity.location!.isNotEmpty)
                        _buildQuickInfoChip(
                          Icons.location_on_outlined,
                          opportunity.location!,
                        ),
                      if (opportunity.workMode != null && opportunity.workMode!.isNotEmpty)
                        _buildQuickInfoChip(
                          Icons.laptop_chromebook_outlined,
                          opportunity.workMode!,
                        ),
                      _buildQuickInfoChip(
                        opportunity.isPaid
                            ? Icons.attach_money_outlined
                            : Icons.money_off_outlined,
                        opportunity.isPaid ? 'Paid' : 'Unpaid',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds the "Key Info" section for the detail view.
  Widget _buildDetailKeyInfoSection(Opportunity opportunity) {
    String formatDate(DateTime? date) =>
        date == null ? 'N/A' : DateFormat('MMMM d, yyyy').format(date);
    return Column(
      children: [
        _buildInfoTile(
          icon: Icons.apartment_outlined,
          title: 'Location / Work Mode',
          value:
              '${opportunity.workMode?.capitalize() ?? ''} · ${opportunity.location ?? 'Remote'}',
        ),
        _buildInfoTile(
          icon: Icons.calendar_today_outlined,
          title: 'Duration',
          value:
              '${formatDate(opportunity.startDate?.toDate())} - ${formatDate(opportunity.endDate?.toDate())}',
        ),
        _buildInfoTile(
          icon: Icons.event_available_outlined,
          title: 'Apply Before',
          value: formatDate(opportunity.applicationDeadline?.toDate()),
          valueColor: Colors.red.shade700,
        ),
        // Show response deadline only if it's visible and exists
        if (opportunity.responseDeadlineVisible == true &&
            opportunity.responseDeadline != null)
          _buildInfoTile(
            icon: Icons.schedule_outlined,
            title: 'Company Response By',
            value: formatDate(opportunity.responseDeadline?.toDate()),
            valueColor: Colors.orange.shade700,
          ),
      ],
    );
  }

  // --- Reusable Helper Widgets ---

  Widget _buildQuickInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF422F5D)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF422F5D).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _sparkPrimaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildMoreInfo(Opportunity opportunity) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildMoreInfoRow(Icons.badge_outlined, 'Type', opportunity.type),
          if (opportunity.preferredMajor != null)
            _buildMoreInfoRow(
              Icons.school_outlined,
              'Preferred Major',
              opportunity.preferredMajor!,
            ),
          _buildMoreInfoRow(
            Icons.attach_money_outlined,
            'Payment',
            opportunity.isPaid ? 'Paid' : 'Unpaid',
          ),
        ],
      ),
    );
  }

  Widget _buildMoreInfoRow(IconData icon, String title, String value) =>
      ListTile(
        leading: Icon(icon, color: Colors.grey.shade600),
        title: Text(
          title,
          style: GoogleFonts.lato(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          value,
          style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      );

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
}

// --- UTILITY EXTENSION ---
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
