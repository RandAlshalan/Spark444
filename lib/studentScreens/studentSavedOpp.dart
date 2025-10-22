import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/company.dart';
import 'package:my_app/models/opportunity.dart';
import 'package:my_app/models/Application.dart';
import 'package:my_app/services/applicationService.dart';
import 'package:my_app/services/authService.dart';
import 'package:my_app/services/bookmarkService.dart';
import '../studentScreens/studentOppDetails.dart'; // Contains OpportunityDetailsContent
import 'package:my_app/studentScreens/studentCompanyProfilePage.dart'; // For company profile page

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedOpportunity == null
              ? 'Saved Opportunities'
              : 'Opportunity Details',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
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
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF422F5D)));
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
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF422F5D)));
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading saved opportunities.',
              style: GoogleFonts.lato(color: Colors.red),
            ),
          );
        }

        final savedOpportunities = snapshot.data ?? [];

        // Empty state
        if (savedOpportunities.isEmpty) {
          return _buildEmptyState();
        }

        // Success → build list
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedOpportunities.length,
          itemBuilder: (context, index) {
            return _buildOpportunityCard(savedOpportunities[index]);
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
          const Icon(Icons.bookmark_remove_outlined,
              size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Saved Opportunities',
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your saved items will appear here.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// --- Build single opportunity card ---
  Widget _buildOpportunityCard(Opportunity opportunity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                FutureBuilder<Company?>(
                  future: _authService.getCompany(opportunity.companyId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey,
                      );
                    }
                    final company = snapshot.data!;
                    return CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: (company.logoUrl != null &&
                              company.logoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(company.logoUrl!)
                          : null,
                      child: (company.logoUrl == null ||
                              company.logoUrl!.isEmpty)
                          ? const Icon(Icons.business, color: Colors.grey)
                          : null,
                    );
                  },
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
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opportunity.name,
                        style: GoogleFonts.lato(
                            fontSize: 15, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                // Bookmark icon (remove)
                IconButton(
                  icon: const Icon(Icons.bookmark, color: Color(0xFF422F5D)),
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
                  color: opportunity.isPaid ? Colors.green : Colors.orange,
                ),
                if (opportunity.responseDeadlineVisible == true &&
                    opportunity.responseDeadline != null)
                  _buildInfoChip(
                    Icons.event_available,
                    'Respond by ${DateFormat('MMM d, yyyy').format(opportunity.responseDeadline!.toDate())}',
                    color: Colors.blueGrey,
                  ),
              ],
            ),
            const Padding(padding: EdgeInsets.only(top: 12.0), child: Divider()),
            // --- View More button ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Call the function that fetches status and shows details
                    _viewOpportunityDetails(opportunity);
                  },
                  child: const Text(
                    'View More',
                    style: TextStyle(
                        color: Color(0xFF422F5D), fontWeight: FontWeight.bold),
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
    final chipColor = color ?? const Color(0xFF422F5D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
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
  void _viewOpportunityDetails(Opportunity opportunity) async {
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

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Application'),
        content: Text(
          'Are you sure you want to apply for the role of ${_selectedOpportunity!.role}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF422F5D),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return; // User pressed "Cancel"

    setState(() => _isApplying = true); // Show loading
    try {
      // Call service to submit application
      await _applicationService.submitApplication(
        studentId: widget.studentId,
        opportunityId: _selectedOpportunity!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload application status to show "Withdraw" button
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
      // Stop loading only on failure
      setState(() => _isApplying = false);
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