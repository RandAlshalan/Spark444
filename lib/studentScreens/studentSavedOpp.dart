import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:spark/models/Application.dart';
import 'package:spark/models/company.dart';
import 'package:spark/models/opportunity.dart';
import 'package:spark/models/resume.dart';
import 'package:spark/services/applicationService.dart';
import 'package:spark/services/authService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark/services/bookmarkService.dart';
import 'package:spark/studentScreens/applicationConfirmationDialog.dart';
import 'package:spark/studentScreens/resumeSelectionDialog.dart';
import 'package:spark/studentScreens/studentApplications.dart';
import 'package:spark/studentScreens/studentCompanyProfilePage.dart';
import 'package:spark/widgets/application_success_dialog.dart';
import '../studentScreens/studentOppDetails.dart';
import '../theme/student_theme.dart';

class SavedstudentOppPgae extends StatefulWidget {
  final String studentId;
  const SavedstudentOppPgae({super.key, required this.studentId});

  @override
  State<SavedstudentOppPgae> createState() => _SavedstudentOppPgaeState();
}

class _SavedstudentOppPgaeState extends State<SavedstudentOppPgae> {
  // --- Services ---
  final BookmarkService _bookmarkService = BookmarkService();
  final AuthService _authService = AuthService();
  final ApplicationService _applicationService = ApplicationService();

  // --- State Variables ---
  Opportunity? _selectedOpportunity; // Selected opportunity for detail view
  Application? _currentApplication; // Holds application for the selected opportunity
  bool _isApplying = false; // Tracks if an application is being submitted/fetched
  Map<String, Company> _companyCache = const {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedOpportunity == null
              ? 'Saved Opportunities'
              : 'Opportunity Details',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: StudentTheme.textColor,
          ),
        ),
        backgroundColor: StudentTheme.cardColor,
        elevation: 0,
        surfaceTintColor: StudentTheme.cardColor,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        leading: _selectedOpportunity != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  // Go back to the list
                  setState(() {
                    _selectedOpportunity = null;
                    _currentApplication = null;
                    _isApplying = false;
                  });
                },
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  /// --- Main body builder ---
  Widget _buildBody() {
    // If an opportunity is selected
    if (_selectedOpportunity != null) {
      // If we are fetching the application status
      if (_isApplying) {
        return Center(
            child: CircularProgressIndicator(color: StudentTheme.primaryColor));
      }

      // If loading is complete, show details
      return OpportunityDetailsContent(
        opportunity: _selectedOpportunity!,
        application: _currentApplication, // Pass the current application (or null)
        onNavigateToCompany: _navigateToCompanyProfile, // Pass navigation function
        onApply: _handleApplyToOpportunity, // Pass apply function
        onWithdraw: _handleWithdrawApplication, // Pass withdraw function
      );
    }

    // Otherwise → show the saved opportunities list
    return StreamBuilder<List<Opportunity>>(
      stream: _bookmarkService.getBookmarkedOpportunitiesStream(
        studentId: widget.studentId,
      ),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: StudentTheme.primaryColor));
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading saved opportunities.',
              style: GoogleFonts.lato(color: StudentTheme.errorColor),
            ),
          );
        }

        final savedOpportunities = snapshot.data ?? [];

        if (savedOpportunities.isEmpty) {
          return _buildEmptyState();
        }

        return FutureBuilder<Map<String, Company>>(
          future: _loadCompanies(savedOpportunities),
          builder: (context, companySnapshot) {
            if (companySnapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: StudentTheme.primaryColor,
                ),
              );
            }
            if (companySnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading companies.',
                  style: GoogleFonts.lato(color: StudentTheme.errorColor),
                ),
              );
            }

            _companyCache = companySnapshot.data ?? _companyCache;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedOpportunities.length,
              itemBuilder: (context, index) {
                return _buildOpportunityCard(savedOpportunities[index]);
              },
            );
          },
        );
      },
    );
  }

  /// --- Empty state widget ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_remove_outlined,
              size: 60, color: StudentTheme.textColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No Saved Opportunities',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: StudentTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved items will appear here.',
            style: GoogleFonts.lato(
              color: StudentTheme.textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// --- Build single opportunity card ---
  Widget _buildOpportunityCard(Opportunity opportunity) {
    final company = _companyCache[opportunity.companyId];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: StudentTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Card Header: logo, role, name, bookmark ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company logo
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        StudentTheme.primaryColor.withValues(alpha: 0.08),
                    backgroundImage: () {
                      final logoUrl = company?.logoUrl ?? '';
                      return logoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(logoUrl)
                          : null;
                    }(),
                    child: () {
                      final logoUrl = company?.logoUrl ?? '';
                      return logoUrl.isEmpty
                          ? Icon(Icons.business, color: StudentTheme.primaryColor)
                          : null;
                    }(),
                  ),
                ),
                const SizedBox(width: 12),
                // Role and name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.role,
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: StudentTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        company?.companyName ?? opportunity.name,
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          color: StudentTheme.textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bookmark icon (remove)
                IconButton(
                  icon: Icon(Icons.bookmark, color: StudentTheme.primaryColor),
                  onPressed: () => _toggleBookmark(opportunity),
                  tooltip: 'Remove Bookmark',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // --- Info Chips ---
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                if (opportunity.location != null)
                  _buildInfoChip(Icons.location_on_outlined, opportunity.location!),
                if (opportunity.workMode != null)
                  _buildInfoChip(Icons.work_outline, opportunity.workMode!),
                _buildInfoChip(
                  Icons.attach_money,
                  opportunity.isPaid ? 'Paid' : 'Unpaid',
                  color: opportunity.isPaid ? StudentTheme.successColor : StudentTheme.warningColor,
                ),
                if (opportunity.responseDeadlineVisible == true &&
                    opportunity.responseDeadline != null)
                  _buildInfoChip(
                    Icons.event_available,
                    'Respond by ${DateFormat('MMM d, yyyy').format(opportunity.responseDeadline!.toDate())}',
                    color: StudentTheme.infoColor,
                  ),
              ],
            ),
            const Padding(padding: EdgeInsets.only(top: 12.0), child: Divider(color: StudentTheme.dividerColor)),
            // --- View More button ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Call the function that fetches status and shows details
                    _viewOpportunityDetails(opportunity);
                  },
                  child: Text(
                    'View More',
                    style: GoogleFonts.lato(
                      color: StudentTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// --- Info Chip Widget ---
  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    final chipColor = color ?? StudentTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(StudentTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(color: chipColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// --- Toggle bookmark (remove) ---
  Future<void> _toggleBookmark(Opportunity opportunity) async {
    try {
      await _bookmarkService.removeBookmark(
        studentId: widget.studentId,
        opportunityId: opportunity.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved opportunities.'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update bookmark.')),
        );
      }
    }
  }

  Future<Map<String, Company>> _loadCompanies(
    List<Opportunity> opportunities,
  ) async {
    final missingIds = opportunities
        .map((opp) => opp.companyId)
        .where((id) => id.isNotEmpty && !_companyCache.containsKey(id))
        .toSet()
        .toList();

    if (missingIds.isEmpty) {
      return _companyCache;
    }

    const chunkSize = 10;
    final collection = FirebaseFirestore.instance.collection('companies');
    final updated = Map<String, Company>.from(_companyCache);

    for (var i = 0; i < missingIds.length; i += chunkSize) {
      final chunk = missingIds.sublist(
        i,
        math.min(i + chunkSize, missingIds.length),
      );
      final snapshot = await collection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        updated[doc.id] =
            Company.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }
    }

    return updated;
  }

  /// --- Navigation Function ---
  /// Navigate to the company profile page
  void _navigateToCompanyProfile(String companyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCompanyProfilePage(companyId: companyId),
      ),
    );
  }

  /// --- Application Logic Functions ---

  /// Switch to detail view and fetch application status
  Future<void> _viewOpportunityDetails(Opportunity opportunity) async {
    // 1. Update state to show loading screen
    setState(() {
      _selectedOpportunity = opportunity;
      _currentApplication = null; // Reset application
      _isApplying = true; // Show loading indicator
    });

    try {
      // 2. Fetch application status
      final app = await _applicationService.getApplicationForOpportunity(
        studentId: widget.studentId,
        opportunityId: opportunity.id,
      );
      if (!mounted) return;

      // 3. Update state with the new application and stop loading
      setState(() {
        _currentApplication = app as Application?; // Store the application (or null)
        _isApplying = false; // Stop loading indicator
      });
    } catch (e) {
      debugPrint("Error fetching application: $e");
      if (mounted) {
        setState(() => _isApplying = false); // Stop loading on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load application status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Called when "Apply Now" is pressed
  Future<void> _handleApplyToOpportunity() async {
    if (_selectedOpportunity == null) return;

    final selection = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResumeSelectionDialog(studentId: widget.studentId),
    );

    if (selection == null) return;

    final resume = selection['resume'] as Resume?;
    final coverLetter = selection['coverLetter'] as String?;

    if (resume == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a resume to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ApplicationConfirmationDialog(
        opportunity: _selectedOpportunity!,
        resume: resume,
        coverLetter: coverLetter,
      ),
    );

    if (confirm != true) return;

    setState(() => _isApplying = true);
    try {
      await _applicationService.submitApplication(
        studentId: widget.studentId,
        opportunityId: _selectedOpportunity!.id,
        resumeId: resume.id,
        resumePdfUrl: resume.pdfUrl,
        coverLetterText: coverLetter,
      );

      if (!mounted) return;

      final includeCoverLetter =
          coverLetter != null && coverLetter.trim().isNotEmpty;
      final company =
          await _authService.getCompany(_selectedOpportunity!.companyId);
      final companyName = company?.companyName ?? 'the hiring team';

      await _viewOpportunityDetails(_selectedOpportunity!);
      if (!mounted) return;

      setState(() => _isApplying = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ApplicationSuccessDialog(
          opportunityTitle: _selectedOpportunity!.role,
          companyName: companyName,
          resumeTitle: resume.title,
          includeCoverLetter: includeCoverLetter,
          onViewApplications: () {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentApplicationsScreen(
                  studentId: widget.studentId,
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Called when "Withdraw" is pressed
  Future<void> _handleWithdrawApplication() async {
    if (_currentApplication == null) return;

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application?'),
        content: const Text(
          'This will update your application status to "Withdrawn". You cannot undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Call service to withdraw application
        await _applicationService.withdrawApplication(
          applicationId: _currentApplication!.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application withdrawn.'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload application status to show "Apply" button
          _viewOpportunityDetails(_selectedOpportunity!);
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
      }
    }
  }
}
