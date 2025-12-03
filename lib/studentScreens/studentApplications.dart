// --- IMPORTS ---
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import '../studentScreens/studentCompanyProfilePage.dart'; // Import for navigation
import '../studentScreens/studentOppDetails.dart';
// --- IMPORT YOUR NEW WIDGET ---


// --- Color Constants ---
const Color _sparkPrimaryPurple = Color(0xFF422F5D);
const Color _profileBackgroundColor = Color(0xFFF8F9FA);
const Color _profileTextColor = Color(0xFF1E1E1E);

// --- WIDGET DEFINITION ---
class StudentApplicationsScreen extends StatefulWidget {
  final String studentId;

  const StudentApplicationsScreen({super.key, required this.studentId});

  @override
  State<StudentApplicationsScreen> createState() =>
      _StudentApplicationsScreenState();
}

class _StudentApplicationsScreenState extends State<StudentApplicationsScreen> {
  // --- 1. State Variables & Services ---

  // Services
  final ApplicationService _applicationService = ApplicationService();
  final AuthService _authService = AuthService();

  // UI State
  bool _isLoading = true;
  Application? _selectedApplication; // Holds the application being viewed
  String _activeStatusFilter = 'All'; // Current active status filter

  // Data State
  List<Application> _allApplications = []; // Stores all applications from Firestore
  List<Application> _filteredApplications = []; // Stores the visible applications after filtering
  // Caches to store details and avoid re-fetching from Firestore
  Map<String, Opportunity> _opportunityDetailsCache = {};
  Map<String, Company> _companyDetailsCache = {};

  // Static list of filter options
  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Interviewing',
    'Accepted',
    'Rejected',
    'No Response',
    'Withdrawn',
  ];

  // --- 2. Lifecycle Methods ---

  @override
  void initState() {
    super.initState();
    _loadApplications(); // Load initial data when the screen starts
  }

  @override
  void dispose() {
    super.dispose();
  }

  // --- 3. Data & State Logic ---

  /// Fetches all applications for the student from Firestore.
  /// It also pre-fetches and caches all related opportunity and company data
  /// to avoid multiple database calls while building the list.
  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Fetch all applications for this student
      final querySnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('studentId', isEqualTo: widget.studentId)
          .orderBy('appliedDate', descending: true)
          .get();

      final applications = querySnapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();

      // 2. Get unique Opportunity IDs and load in batches (Firestore whereIn limit)
      if (applications.isNotEmpty) {
        final opportunityIds =
            applications.map((app) => app.opportunityId).toSet().toList();
        _opportunityDetailsCache = await _fetchDocumentsInChunks<Opportunity>(
          collectionPath: 'opportunities',
          ids: opportunityIds,
          parser: (doc) => Opportunity.fromFirestore(doc),
        );
      }

      // 3. Get unique Company IDs from cached opportunities and load in batches
      if (_opportunityDetailsCache.isNotEmpty) {
        final companyIds = _opportunityDetailsCache.values
            .map((opp) => opp.companyId)
            .toSet()
            .toList();

        if (companyIds.isNotEmpty) {
          _companyDetailsCache = await _fetchDocumentsInChunks<Company>(
            collectionPath: 'companies',
            ids: companyIds,
            parser: (doc) =>
                Company.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>),
          );
        }
      }

      // 8. Update the state with all fetched data
      if (mounted) {
        setState(() {
          _allApplications = applications;
          _isLoading = false;
        });
        _filterApplications(); // Apply default filters
      }
    } catch (e) {
      debugPrint("Error fetching applications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Helper to fetch documents in chunks to respect Firestore whereIn limits.
  Future<Map<String, T>> _fetchDocumentsInChunks<T>({
    required String collectionPath,
    required List<String> ids,
    required T Function(DocumentSnapshot<Map<String, dynamic>> doc) parser,
  }) async {
    const chunkSize = 10; // Firestore whereIn limit per query
    final collection =
        FirebaseFirestore.instance.collection(collectionPath);
    final results = <String, T>{};

    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, math.min(i + chunkSize, ids.length));
      final snapshot = await collection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        results[doc.id] = parser(doc);
      }
    }
    return results;
  }

  /// Filters the `_allApplications` list based on the active status filter
  /// then updates `_filteredApplications`.
  void _filterApplications() {
    List<Application> results = List.from(_allApplications);

    // 1. Apply Status Filter
    if (_activeStatusFilter != 'All') {
      results = results.where((app) {
        final status = app.status.toLowerCase();
        final filter = _activeStatusFilter.toLowerCase();

        // Handle special case where "In Progress" button maps to "Reviewed" status
        if (filter == 'in progress') {
          return status == 'reviewed';
        }
        if (filter == 'accepted') {
          // Show both 'Accepted' (by student) and 'Hired' (by company)
          return status == 'accepted' || status == 'hired';
        }
        // Handle all other statuses
        return status == filter;
      }).toList();
    }

    // 2. Update the UI state
    setState(() => _filteredApplications = results);
  }

  // --- 4. User Actions ---

  /// Withdraws an application after user confirmation.
  Future<void> _withdrawApplication(Application application) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application?'),
        content: const Text(
            'This will update your application status to "Withdrawn". You cannot undo this.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _applicationService.withdrawApplication(
            applicationId: application.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application withdrawn.'),
            backgroundColor: Colors.green));
        _showApplicationList(); // Go back to the list view
        _loadApplications(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  /// Permanently deletes an application (only available for 'Withdrawn' apps).
  Future<void> _deleteApplicationPermanently(Application application) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text(
            'This action is irreversible and will permanently remove this application record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Delete from Firestore
        await _applicationService.deleteApplication(
            applicationId: application.id);

        // 2. Remove from local state to update UI immediately
        setState(() {
          _allApplications.removeWhere((app) => app.id == application.id);
          _filteredApplications
              .removeWhere((app) => app.id == application.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application permanently deleted.'),
            backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  // --- 5. Navigation & View Switching ---

  /// Switches the view to show the details of a selected application.
  void _viewApplicationDetails(Application application) {
    setState(() => _selectedApplication = application);
  }

  /// Switches the view back to the main list.
  void _showApplicationList() {
    setState(() => _selectedApplication = null);
  }

  /// Navigates to the company's profile page.
  void _navigateToCompanyProfile(String companyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCompanyProfilePage(companyId: companyId),
      ),
    );
  }

  /// Handles the physical back button press.
  Future<bool> _onBackPressed() {
    if (_selectedApplication != null) {
      // If on detail view, go back to list view
      _showApplicationList();
      return Future.value(false); // Do not pop the route (exit app)
    }
    // If on list view, allow app to exit
    return Future.value(true);
  }

  // --- 6. Main Build Methods ---

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed, // Intercept back button
      child: Scaffold(
        backgroundColor: _profileBackgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  /// Builds the AppBar, which changes title based on the view.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // Show custom back button only on detail view
      leading: _selectedApplication != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _showApplicationList)
          : null,
      // Use default back button only on list view
      automaticallyImplyLeading: _selectedApplication == null,
      title: Text(
          _selectedApplication == null
              ? 'My Applications'
              : 'Application Details',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          )),
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
      centerTitle: true,
    );
  }

  /// Builds the main body, switching between loading, empty, list, and detail views.
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _sparkPrimaryPurple));
    }

    if (_allApplications.isEmpty) {
      return _buildEmptyState();
    }

    // Switch between detail and list view
    if (_selectedApplication != null) {
      // --- THIS IS THE MODIFIED PART ---

      // 1. Get the required data from the cache
      final opportunity =
          _opportunityDetailsCache[_selectedApplication!.opportunityId];

      // 2. Handle cases where data might be missing (e.g., opportunity was deleted)
      if (opportunity == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load opportunity details.'),
              TextButton(
                  onPressed: _showApplicationList,
                  child: const Text('Go Back')),
            ],
          ),
        );
      }

      // 3. Return the new reusable widget
      return OpportunityDetailsContent(
        opportunity: opportunity,
        application: _selectedApplication!, // Pass the application
        onNavigateToCompany: _navigateToCompanyProfile, // Pass navigation callback
        onWithdraw: () => _withdrawApplication(_selectedApplication!), // Pass withdraw callback
        // 'onApply' is omitted, so the "Apply" button will not show
      );
      // --- END OF MODIFIED PART ---
    } else {
      return _buildListView();
    }
  }

  // --- 7. Core View Builders ---

  /// Builds the main list view with filters and the list of cards.
  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _loadApplications, // Enable pull-to-refresh
      color: _sparkPrimaryPurple,
      child: Column(
        children: [
          _buildFilterButtons(),
          Expanded(
            child: _filteredApplications.isEmpty
                // Show message if filters result in no applications
                ? const Center(
                    child: Text('No applications match your criteria.'))
                // Otherwise, build the list
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredApplications.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApplications[index];
                      final opp = _opportunityDetailsCache[app.opportunityId];
                      
                      // If opportunity data is not found (e.g., deleted), show nothing
                      if (opp == null) return const SizedBox.shrink();

                      // Use the custom _ApplicationCard widget
                      return _ApplicationCard(
                        application: app,
                        opportunity: opp,
                        onViewMore: () => _viewApplicationDetails(app),
                        onWithdraw: () => _withdrawApplication(app),
                        onDelete: () => _deleteApplicationPermanently(app),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds the UI for when the student has no applications at all.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No Applications Yet',
              style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Your submitted applications will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- 8. List View Components ---

  /// Builds the horizontal scrolling list of filter buttons.
  Widget _buildFilterButtons() {
    const purple = Color(0xFF8D52CC);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isSelected = _activeStatusFilter == status;
          final color = purple;

          return ElevatedButton(
            onPressed: () {
              // Set the active filter and re-filter the list
              setState(() => _activeStatusFilter = status);
              _filterApplications();
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: isSelected ? Colors.white : color,
              backgroundColor: isSelected ? color : Colors.white,
              elevation: isSelected ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: color,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
      ),
    );
  }

  // --- 9, 10: Detail View Components ---
  // (All helper methods that were here have been moved to
  // opportunity_details_content.dart and are no longer needed)

  // --- 11. Helper Utilities ---

  /// Returns a specific color for each filter button.
  Color _getFilterColor(String filter) {
    // Deprecated per unified design; keep primary for legacy use
    return _sparkPrimaryPurple;
  }

  // _getStatusColor() was removed as it's no longer used in this file.
  // _ApplicationCard has its own internal copy.
}

// --- SEPARATE CARD WIDGET ---
// (This remains unchanged in the same file)

/// A dedicated widget to display a single application card in the list.
class _ApplicationCard extends StatelessWidget {
  final Application application;
  final Opportunity opportunity;
  final VoidCallback onViewMore;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;
  final bool isDetailView;
  final AuthService _authService = AuthService(); // To get company data

  _ApplicationCard({
    required this.application,
    required this.opportunity,
    required this.onViewMore,
    required this.onWithdraw,
    required this.onDelete,
    this.isDetailView = false,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAppliedDate =
        DateFormat('MMM d, yyyy').format(application.appliedDate.toDate());
    final lastUpdateText = formatDate(
        application.lastStatusUpdateDate?.toDate() ??
            application.appliedDate.toDate());

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with company logo, role, and status
            _buildHeader(context, opportunity),
            const SizedBox(height: 12),
            // Date info
            Row(
              children: [
                _buildDateInfo(Icons.event_note_outlined, 'Applied On:',
                    formattedAppliedDate),
                const SizedBox(width: 16),
                _buildDateInfo(Icons.update, 'Status Updated On:',
                    lastUpdateText),
              ],
            ),
            // Action buttons (Withdraw, View More)
            if (!isDetailView) ...[
              const Padding(
                  padding: EdgeInsets.only(top: 12.0), child: Divider()),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Show "Withdraw" button only if status allows
                  if (application.status.toLowerCase() == 'pending' ||
                      application.status.toLowerCase() == 'reviewed')
                    TextButton(
                      onPressed: onWithdraw,
                      child: const Text('Withdraw',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onViewMore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D52CC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('View Details'),
                  )
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  /// Builds the header of the card (Logo, Role, Status, Delete button).
  Widget _buildHeader(BuildContext context, Opportunity opportunity) {
    return FutureBuilder<Company?>(
      future: _authService.getCompany(opportunity.companyId),
      builder: (context, snapshot) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Logo
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: (snapshot.data?.logoUrl != null &&
                      snapshot.data!.logoUrl!.isNotEmpty)
                  ? CachedNetworkImageProvider(snapshot.data!.logoUrl!)
                  : null,
              child: (snapshot.data?.logoUrl == null ||
                      snapshot.data!.logoUrl!.isEmpty)
                  ? const Icon(Icons.business, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // Role and Company Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opportunity.role,
                      style: GoogleFonts.lato(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(snapshot.data?.companyName ?? "...",
                      style: GoogleFonts.lato(
                          fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ),
            // Status Chip and Delete Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusChip(application.status),
                // Show delete 'x' button only for withdrawn applications
                if (application.status.toLowerCase() == 'withdrawn')
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(24),
                      child: Tooltip(
                        message: 'Delete Permanently',
                        child: Icon(
                          Icons.close,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- Helper methods for _ApplicationCard ---
  // These are duplicated from the main state for component encapsulation.

  Widget _buildDateInfo(IconData icon, String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(title,
                  style: GoogleFonts.lato(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style:
                  GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String formatDate(DateTime? date) =>
      date == null ? 'N/A' : DateFormat('MMM d, yyyy').format(date);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hired':
      case 'accepted':
        return Colors.green.shade600;
      case 'reviewed':
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

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.lato(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// --- UTILITY EXTENSION ---
// (This is still needed by _ApplicationCard)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
