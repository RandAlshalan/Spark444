// --- IMPORTS ---
import 'dart:async';
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

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce; // Timer for search input delay

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
    'In Progress', // This maps to 'Reviewed' status
    'Accepted',
    'Rejected',
    'Withdrawn',
    'Draft'
  ];

  // --- 2. Lifecycle Methods ---

  @override
  void initState() {
    super.initState();
    _loadApplications(); // Load initial data when the screen starts
    _searchController.addListener(_onSearchChanged); // Listen for search text changes
  }

  @override
  void dispose() {
    // Clean up controllers and timers when the widget is removed
    _searchController.dispose();
    _debounce?.cancel();
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

      // 2. Get unique Opportunity IDs from the applications
      if (applications.isNotEmpty) {
        final opportunityIds =
            applications.map((app) => app.opportunityId).toSet().toList();
        
        // 3. Fetch all required opportunities in one batch
        final oppDocs = await FirebaseFirestore.instance
            .collection('opportunities')
            .where(FieldPath.documentId, whereIn: opportunityIds)
            .get();
        // 4. Store opportunities in the cache
        _opportunityDetailsCache = {
          for (var doc in oppDocs.docs) doc.id: Opportunity.fromFirestore(doc)
        };
      }

      // 5. Get unique Company IDs from the cached opportunities
      if (_opportunityDetailsCache.isNotEmpty) {
        final companyIds = _opportunityDetailsCache.values
            .map((opp) => opp.companyId)
            .toSet()
            .toList();
            
        if (companyIds.isNotEmpty) {
          // 6. Fetch all required companies in one batch
          final companyDocs = await FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: companyIds)
              .get();
          // 7. Store companies in the cache
          _companyDetailsCache = {
            for (var doc in companyDocs.docs) doc.id: Company.fromFirestore(doc)
          };
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

  /// Called when search text changes. Uses a debounce to wait 500ms
  /// after the user stops typing before starting the filter.
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _filterApplications);
  }

  /// Filters the `_allApplications` list based on the active status filter
  /// and the search query, then updates `_filteredApplications`.
  void _filterApplications() {
    List<Application> results = List.from(_allApplications);
    final query = _searchController.text.toLowerCase();

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

    // 2. Apply Search Query Filter
    if (query.isNotEmpty) {
      results = results.where((app) {
        // Get data from cache
        final opportunity = _opportunityDetailsCache[app.opportunityId];
        if (opportunity == null) return false;
        
        final company = _companyDetailsCache[opportunity.companyId];
        
        // Check for matches in role or company name
        final bool roleMatch = opportunity.role.toLowerCase().contains(query);
        final bool companyMatch =
            company?.companyName.toLowerCase().contains(query) ?? false;

        return roleMatch || companyMatch;
      }).toList();
    }

    // 3. Update the UI state
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
              icon: const Icon(Icons.arrow_back),
              onPressed: _showApplicationList)
          : null,
      // Use default back button only on list view
      automaticallyImplyLeading: _selectedApplication == null,
      title: Text(
          _selectedApplication == null
              ? 'My Applications'
              : 'Application Details',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
      backgroundColor: _profileBackgroundColor,
      elevation: 0,
      foregroundColor: _profileTextColor,
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

  /// Builds the main list view with search, filters, and the list of cards.
  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _loadApplications, // Enable pull-to-refresh
      color: _sparkPrimaryPurple,
      child: Column(
        children: [
          _buildSearchBar(),
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

  /// Builds the search bar widget.
  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by role or company...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
      );

  /// Builds the horizontal scrolling list of filter buttons.
  Widget _buildFilterButtons() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isSelected = _activeStatusFilter == status;
          final color = _getFilterColor(status); // Get color for this status

          return ElevatedButton(
            onPressed: () {
              // Set the active filter and re-filter the list
              setState(() => _activeStatusFilter = status);
              _filterApplications();
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: isSelected ? Colors.white : color,
              backgroundColor: isSelected ? color : color.withOpacity(0.1),
              elevation: isSelected ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : Colors.transparent,
                ),
              ),
            ),
            child: Text(status),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }

  // --- 9, 10: Detail View Components ---
  // (All helper methods that were here have been moved to
  // opportunity_details_content.dart and are no longer needed)

  // --- 11. Helper Utilities ---

  /// Returns a specific color for each filter button.
  Color _getFilterColor(String filter) {
    // We still need this for the filter buttons in _buildFilterButtons
    switch (filter) {
      case 'All':
        return _sparkPrimaryPurple;
      case 'Pending':
        return Colors.orange.shade700; // Hardcoded status color
      case 'In Progress':
        return Colors.blue.shade600; // Hardcoded status color
      case 'Accepted':
        return Colors.green.shade600; // Hardcoded status color
      case 'Rejected':
        return Colors.red.shade600; // Hardcoded status color
      case 'Withdrawn':
        return Colors.grey.shade600; // Hardcoded status color
      case 'Draft':
        return Colors.blueGrey;
      default:
        return _sparkPrimaryPurple;
    }
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

    return Card(
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
                _buildDateInfo(
                    Icons.calendar_today_outlined,
                    'Duration',
                    '${formatDate(opportunity.startDate?.toDate())} - ${formatDate(opportunity.endDate?.toDate())}'),
                const SizedBox(width: 16),
                _buildDateInfo(Icons.event_note_outlined, 'Applied On',
                    formattedAppliedDate),
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
                  TextButton(
                    onPressed: onViewMore,
                    child: const Text('View More',
                        style: TextStyle(
                            color: _sparkPrimaryPurple,
                            fontWeight: FontWeight.bold)),
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
                  ? NetworkImage(snapshot.data!.logoUrl!)
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