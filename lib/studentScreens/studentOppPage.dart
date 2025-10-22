// lib/studentScreens/studentOppPage.dart

// --- IMPORTS ---
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Note: Ensure your import paths are correct for your project
import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import '../utils/page_transitions.dart';
import '../studentScreens/studentCompanyProfilePage.dart'; // Import for navigation
import '../studentScreens/studentOppDetails.dart';
import 'package:my_app/services/bookmarkService.dart';
import 'package:my_app/services/opportunityService.dart';
import 'package:my_app/studentScreens/studentCompaniesPage.dart';

import '../studentScreens/studentViewProfile.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentSavedOpp.dart';

// --- COLOR CONSTANTS ---
const Color _sparkPrimaryPurple = Color(0xFF422F5D);
const Color _pageBackgroundColor = Color(0xFFF8F9FA);

// Enum for clearer state management
enum ScreenState { initialLoading, loading, success, error, empty }

// --- WIDGET DEFINITION ---
class studentOppPgae extends StatefulWidget {
  const studentOppPgae({super.key});
  @override
  State<studentOppPgae> createState() => _studentOppPgaeState();
}

class _studentOppPgaeState extends State<studentOppPgae> {
  // --- 1. State Variables & Services ---

  // Services
  final OpportunityService _opportunityService = OpportunityService();
  final AuthService _authService = AuthService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ApplicationService _applicationService = ApplicationService();

  // Data State
  List<Opportunity> _opportunities = []; // List to hold all opportunities
  Map<String, Company> _companyCache = {}; // Cache to store company data
  String? _studentId; // Stores the logged-in student's ID

  // UI State
  ScreenState _state =
      ScreenState.initialLoading; // Current state of the screen
  String? _errorMessage; // Stores error message if something goes wrong
  int _currentIndex = 2; // Current active index for the bottom navigation bar

  // In-page Detail View State
  Opportunity? _selectedOpportunity; // Holds the opportunity being viewed
  Application?
  _currentApplication; // Holds application for the selected opportunity
  bool _isApplying = false; // Tracks if an application is being submitted

  // Controllers
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  Timer?
  _debounce; // Timer for search input to avoid searching on every keystroke

  // Filter State
  String _activeTypeFilter = 'All'; // Filter by type (e.g., Internship, Co-op)
  String? _selectedCity; // Filter by city
  String? _selectedLocationType; // Filter by work mode (remote, in-person)
  bool? _isPaid; // Filter by paid/unpaid
  String? _selectedDuration; // Filter by duration

  // --- 2. Lifecycle Methods ---

  @override
  void initState() {
    super.initState();
    // This method is called once when the widget is first created
    _loadInitialData(); // Load the initial data needed for the page
    _searchController.addListener(
      _onSearchChanged,
    ); // Listen for changes in the search bar
  }

  @override
  void dispose() {
    // This method is called when the widget is permanently removed
    // It's important to dispose controllers to free up resources
    _searchController.dispose();
    _cityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- 3. Data & State Logic ---

  /// Loads the student's ID first, then fetches opportunities
  Future<void> _loadInitialData() async {
    setState(() => _state = ScreenState.initialLoading);
    try {
      final student = await _authService.getCurrentStudent();
      if (!mounted) return;
      if (student != null) {
        setState(() => _studentId = student.id);
        await _fetchOpportunities(); // Now fetch opportunities
      } else {
        throw Exception("Could not find logged in student.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error: ${e.toString()}";
          _state = ScreenState.error;
        });
      }
    }
  }

  /// Called when the search text changes. Uses a debounce.
  void _onSearchChanged() {
    // Debounce: Wait 500ms after user stops typing to start search
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchOpportunities);
  }

  /// Main function to fetch and filter opportunities
  Future<void> _fetchOpportunities() async {
    if (_state != ScreenState.initialLoading) {
      setState(() => _state = ScreenState.loading);
    }
    try {
      // 1. Fetch all opportunities from the service
      final opportunities = await _opportunityService.getOpportunities(
        searchQuery: null,
        type: null,
        city: null,
        locationType: null,
        isPaid: null,
      );

      // 2. Fetch company data for all unique company IDs (Caching)
      if (opportunities.isNotEmpty) {
        final companyIds = opportunities
            .map((opp) => opp.companyId)
            .toSet()
            .toList();
        if (companyIds.isNotEmpty) {
          final companyDocs = await FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: companyIds)
              .get();
          // Store company data in the cache
          _companyCache = {
            for (var doc in companyDocs.docs)
              doc.id: Company.fromFirestore(doc),
          };
        }
      }

      // 3. Apply client-side filtering (search and filters)
      final query = _searchController.text.toLowerCase();
      final filtered = opportunities.where((opp) {
        // Check Type Filter
        final matchesType =
            _activeTypeFilter == 'All' || opp.type == _activeTypeFilter;

        // Check Search Query (Role, Name, or Company Name)
        final company = _companyCache[opp.companyId];
        final companyNameMatch =
            company?.companyName.toLowerCase().contains(query) ?? false;
        final matchesSearch =
            query.isEmpty ||
            opp.role.toLowerCase().contains(query) ||
            opp.name.toLowerCase().contains(query) ||
            companyNameMatch;

        // Check other filters
        final matchesCity =
            _selectedCity == null ||
            (opp.location?.toLowerCase() == _selectedCity?.toLowerCase());
        final matchesLocation =
            _selectedLocationType == null ||
            (opp.workMode?.toLowerCase() ==
                _selectedLocationType?.toLowerCase());
        final matchesPaid = _isPaid == null || (opp.isPaid == _isPaid);
        final durationCategory = getDurationCategory(
          opp.startDate,
          opp.endDate,
        );
        final matchesDuration =
            _selectedDuration == null || durationCategory == _selectedDuration;

        // Return true only if all conditions match
        return matchesType &&
            matchesSearch &&
            matchesCity &&
            matchesLocation &&
            matchesPaid &&
            matchesDuration;
      }).toList();

      // 4. Update the UI with the filtered list
      if (mounted) {
        setState(() {
          _opportunities = filtered;
          _state = filtered.isEmpty ? ScreenState.empty : ScreenState.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load opportunities.';
          _state = ScreenState.error;
        });
      }
    }
  }

  // --- 4. User Actions (Apply, Withdraw, Bookmark) ---

  /// Called when the "Apply Now" button is pressed
  Future<void> _applyNow() async {
    if (_selectedOpportunity == null || _studentId == null) return;

    // Show a confirmation dialog first
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
              backgroundColor: _sparkPrimaryPurple,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return; // User pressed "Cancel"

    setState(() => _isApplying = true); // Show loading indicator
    try {
      // Call the service to submit the application
      await _applicationService.submitApplication(
        studentId: _studentId!,
        opportunityId: _selectedOpportunity!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the detail view to show the new "Withdraw" button
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
    } finally {
      if (mounted) {
        setState(() => _isApplying = false); // Stop loading
      }
    }
  }

  /// Called when the "Withdraw" button is pressed
  Future<void> _withdrawApplication() async {
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
        // Call the service to withdraw
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
          // Refresh the view to show the updated status
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

  /// Called when the bookmark icon is pressed
  Future<void> _toggleBookmark(
    Opportunity opportunity,
    bool isCurrentlyBookmarked,
  ) async {
    if (_studentId == null || _studentId!.isEmpty) return;
    try {
      if (isCurrentlyBookmarked) {
        // Remove bookmark
        await _bookmarkService.removeBookmark(
          studentId: _studentId!,
          opportunityId: opportunity.id,
        );
      } else {
        // Add bookmark
        await _bookmarkService.addBookmark(
          studentId: _studentId!,
          opportunityId: opportunity.id,
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

  // --- 5. Navigation & View Switching ---

  /// Switches the view to show details for a specific opportunity
  /// Switches the view to show details for a specific opportunity
  void _viewOpportunityDetails(Opportunity opportunity) async {
    setState(() {
      _selectedOpportunity = opportunity;
      _currentApplication = null; // Reset application state
      _isApplying = true; // <-- (1) SET TO TRUE HERE to show loading spinner
    });

    final studentId = _studentId;
    if (studentId == null) {
      if (mounted) setState(() => _isApplying = false); // Stop loading if no ID
      return;
    }

    // (2) No need for a separate setState to start loading

    try {
      // (3) Fetch the application
      final app = await _applicationService.getApplicationForOpportunity(
        studentId: studentId,
        opportunityId: opportunity.id,
      );
      if (!mounted) return;

      // (4) Now set the application and stop loading
      setState(() {
        _currentApplication =
            app as Application?; // Store the application (or null)
        _isApplying = false; // Stop loading
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

  /// Switches the view back to the main list
  void _showOpportunityList() {
    setState(() {
      _selectedOpportunity = null;
    });
  }

  /// Handles the phone's physical back button
  Future<bool> _onBackPressed() {
    if (_selectedOpportunity != null) {
      // If on detail view, go back to list view
      _showOpportunityList();
      return Future.value(false); // Don't pop the route (don't exit app)
    }
    // If on list view, allow app to exit
    return Future.value(true);
  }

  /// Navigates to the company profile page
  void _navigateToCompanyProfile(String companyId) {
    Navigator.push(
      context,
      SmoothPageRoute(
        page: StudentCompanyProfilePage(companyId: companyId),
      ),
    );
  }

  /// Navigates to the saved opportunities page
  void _navigateToSaved() {
    if (_studentId != null)
      Navigator.push(
        context,
        SmoothPageRoute(
          page: SavedstudentOppPgae(studentId: _studentId!),
        ),
      );
  }

  /// Handles taps on the Bottom Navigation Bar
  void _onNavigationTap(int index) {
    if (index == _currentIndex) return; // Do nothing if tapping the same tab
    switch (index) {
      case 0:
        _showInfoMessage('Coming soon!');
        break;
      case 1:
        // Go to Companies Page
        Navigator.pushReplacement(
          context,
          NoTransitionRoute(page: const StudentCompaniesPage()),
        );
        break;
      case 3:
        // Go to Profile Page
        Navigator.pushReplacement(
          context,
          NoTransitionRoute(page: const StudentViewProfile()),
        );
        break;
    }
  }

  // --- 6. Main Build Methods ---

  @override
  Widget build(BuildContext context) {
    // This is the main method that builds the UI
    return WillPopScope(
      onWillPop: _onBackPressed, // Handle back button press
      child: Scaffold(
        backgroundColor: _pageBackgroundColor,
        appBar: _buildAppBar(), // Build the app bar
        body: _buildPageContent(), // Build the main content of the page
        // Show BottomNavBar only on the list view
        bottomNavigationBar: _selectedOpportunity == null
            ? CustomBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavigationTap,
              )
            : null,
        // --- REMOVED: bottomSheet is no longer needed ---
        // The OpportunityDetailsContent widget handles its own button bar.
      ),
    );
  }

  /// Builds the AppBar. It changes based on whether we are in list or detail view.
  PreferredSizeWidget _buildAppBar() {
    if (_selectedOpportunity == null) {
      // AppBar for the List View
      return AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Opportunities',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet, // Open filters
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: _navigateToSaved, // Open saved opportunities
            tooltip: 'Saved',
          ),
        ],
      );
    } else {
      // AppBar for the Detail View
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showOpportunityList, // Go back to the list
        ),
        title: Text('Opportunity Details', style: GoogleFonts.lato()),
        backgroundColor: Colors.white,
        elevation: 1,
      );
    }
  }

  /// Determines whether to show the list of opportunities or the details of one
  Widget _buildPageContent() {
    if (_selectedOpportunity == null) {
      return _buildListView(); // Show the list
    } else {
      // --- (MODIFIED) ---
      // Show a loading spinner while fetching the application status
      if (_isApplying) {
        return const Center(
          child: CircularProgressIndicator(color: _sparkPrimaryPurple),
        );
      }
      return _buildDetailView(_selectedOpportunity!); // Show the details
    }
  }

  // --- 7. Core View Builders ---

  /// Builds the main list view (search bar, filters, and list)
  Widget _buildListView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildTypeFilterChips(),
        _buildActiveFiltersBar(), // Shows currently active filters
        Expanded(child: _buildListContent()), // The list itself
      ],
    );
  }

  /// This widget decides what to show based on the ScreenState
  Widget _buildListContent() {
    switch (_state) {
      case ScreenState.initialLoading:
      case ScreenState.loading:
        return const Center(
          child: CircularProgressIndicator(color: _sparkPrimaryPurple),
        );
      case ScreenState.error:
        return _buildErrorWidget(); // Show error message
      case ScreenState.empty:
        return _buildEmptyState(); // Show "No opportunities found"
      case ScreenState.success:
        return RefreshIndicator(
          onRefresh: _fetchOpportunities, // Allow pull-to-refresh
          child: ListView.builder(
            key: const PageStorageKey<String>('studentOppList'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: _opportunities.length,
            itemBuilder: (context, index) {
              final opp = _opportunities[index];
              return _OpportunityCard(
                opportunity: opp,
                company: _companyCache[opp.companyId],
                studentId: _studentId,
                onViewMore: () => _viewOpportunityDetails(opp),
                onToggleBookmark: (isBookmarked) =>
                    _toggleBookmark(opp, isBookmarked),
              );
            },
          ),
        );
    }
  }

  /// --- (MODIFIED) ---
  /// Builds the scrollable detail view using the new reusable widget.
  Widget _buildDetailView(Opportunity opportunity) {
    return OpportunityDetailsContent(
      opportunity: opportunity,
      application: _currentApplication, // Pass the application (if it exists)
      onNavigateToCompany:
          _navigateToCompanyProfile, // Pass navigation function
      onApply: _applyNow, // Pass apply function
      onWithdraw: _withdrawApplication, // Pass withdraw function
    );
  }

  // --- 8. List View Components ---

  /// Builds the search bar widget
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by role or company...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Builds the horizontal list of "Type" filters (All, Internship, Co-op, etc.)
  Widget _buildTypeFilterChips() {
    final types = [
      'All',
      'Internship',
      'Co-op',
      'Graduate Program',
      'Bootcamp',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            final isSelected = _activeTypeFilter == type;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _activeTypeFilter = type);
                _fetchOpportunities(); // Re-fetch data with the new filter
              },
              selectedColor: _sparkPrimaryPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              backgroundColor: Colors.white,
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
        ),
      ),
    );
  }

  /// Shows the small chips for active filters (e.g., "City: Riyadh", "Paid")
  Widget _buildActiveFiltersBar() {
    final hasActiveFilters =
        _selectedCity != null ||
        _selectedLocationType != null ||
        _isPaid != null ||
        _selectedDuration != null;
    if (!hasActiveFilters) return const SizedBox.shrink(); // Hide if no filters

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          // Add a chip for each active filter
          if (_selectedCity != null && _selectedCity!.isNotEmpty)
            Chip(
              label: Text('City: $_selectedCity'),
              onDeleted: () {
                setState(() => _selectedCity = null);
                _cityController.clear();
                _fetchOpportunities();
              },
            ),
          if (_selectedLocationType != null)
            Chip(
              label: Text(_selectedLocationType!),
              onDeleted: () {
                setState(() => _selectedLocationType = null);
                _fetchOpportunities();
              },
            ),
          if (_isPaid != null)
            Chip(
              label: Text(_isPaid! ? 'Paid' : 'Unpaid'),
              backgroundColor: _isPaid!
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              onDeleted: () {
                setState(() => _isPaid = null);
                _fetchOpportunities();
              },
            ),
          if (_selectedDuration != null)
            Chip(
              label: Text(_selectedDuration!),
              onDeleted: () {
                setState(() => _selectedDuration = null);
                _fetchOpportunities();
              },
            ),
        ],
      ),
    );
  }

  // --- 9, 10, 11: Detail View Components & Helpers ---
  //
  // --- ALL METHODS BELOW ARE REMOVED ---
  //
  // _buildDetailHeader()
  // _buildDetailKeyInfoSection()
  // _buildDetailDatesSection()
  // _buildInfoTile()
  // _buildDetailSection()
  // _buildChipList()
  // _buildRequirementList()
  // _buildMoreInfoRow()
  // _buildActionBottomSheet()
  // _buildApplyNowView()
  // _buildStatusAndWithdrawView()
  // _buildStatusChip()
  // _getStatusColor()
  // _formatDate()
  // _formatDateRange()
  //
  // All this logic is now inside 'opportunity_details_content.dart'

  // --- 12. State/Error/Empty Builders ---

  /// Widget to show when the list is empty
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Opportunities Found',
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _resetAllFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: _sparkPrimaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  /// Widget to show when an error occurs
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.red, size: 80),
            const SizedBox(height: 16),
            Text(
              'Something Went Wrong',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "We couldn't load opportunities.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 13. Filter Logic ---

  /// Shows the filter bottom sheet
  void _showFilterSheet() {
    _cityController.text = _selectedCity ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Use StatefulBuilder to manage the state inside the modal
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Helper to build chip lists inside the modal
            Widget buildModalChips<T>({
              required List<T> options,
              required T? selectedValue,
              required String Function(T) labelBuilder,
              required Function(T?) onSelected,
            }) {
              return Wrap(
                spacing: 8.0,
                children: options.map((option) {
                  final isSelected = selectedValue == option;
                  return ChoiceChip(
                    label: Text(labelBuilder(option)),
                    selected: isSelected,
                    onSelected: (selected) =>
                        onSelected(selected ? option : null),
                    selectedColor: _sparkPrimaryPurple,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    backgroundColor: Colors.grey[200],
                  );
                }).toList(),
              );
            }

            // UI of the filter sheet
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: GoogleFonts.lato(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // City Filter
                    Text(
                      'City',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Riyadh',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Location Type Filter
                    Text(
                      'Location Type',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildModalChips<String>(
                      options: ['remote', 'in-person', 'hybrid'],
                      selectedValue: _selectedLocationType,
                      labelBuilder: (s) => s,
                      onSelected: (value) =>
                          setModalState(() => _selectedLocationType = value),
                    ),
                    const SizedBox(height: 24),
                    // Payment Filter
                    Text(
                      'Payment',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildModalChips<bool>(
                      options: [true, false],
                      selectedValue: _isPaid,
                      labelBuilder: (p) => p ? 'Paid' : 'Unpaid',
                      onSelected: (value) =>
                          setModalState(() => _isPaid = value),
                    ),
                    const SizedBox(height: 24),
                    // Duration Filter
                    Text(
                      'Duration',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildModalChips<String>(
                      options: [
                        "less than a month",
                        "1-3 months",
                        "3-6 months",
                        "more than 6 months",
                      ],
                      selectedValue: _selectedDuration,
                      labelBuilder: (d) => d,
                      onSelected: (value) =>
                          setModalState(() => _selectedDuration = value),
                    ),
                    const SizedBox(height: 32),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setModalState(() {
                              // Clear filters inside the modal
                              _cityController.clear();
                              _selectedLocationType = null;
                              _isPaid = null;
                              _selectedDuration = null;
                            }),
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _sparkPrimaryPurple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              // Apply filters to the main page state
                              setState(
                                () => _selectedCity =
                                    _cityController.text.trim().isEmpty
                                    ? null
                                    : _cityController.text.trim(),
                              );
                              _fetchOpportunities(); // Re-fetch data
                              Navigator.pop(context); // Close the modal
                            },
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20), // Padding at the bottom
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Resets all filters and re-fetches the list
  void _resetAllFilters() {
    setState(() {
      _cityController.clear();
      _selectedCity = null;
      _selectedLocationType = null;
      _isPaid = null;
      _selectedDuration = null;
      _activeTypeFilter = 'All';
      _searchController.clear();
    });
    _fetchOpportunities();
  }

  /// Helper function to categorize duration for filtering
  String getDurationCategory(dynamic start, dynamic end) {
    if (start == null || end == null) return "Unknown";
    // Convert to DateTime objects
    final DateTime startDate = start is DateTime
        ? start
        : (start as dynamic).toDate();
    final DateTime endDate = end is DateTime ? end : (end as dynamic).toDate();
    final durationDays = endDate.difference(startDate).inDays;

    if (durationDays < 30) return "less than a month";
    if (durationDays >= 30 && durationDays < 90) return "1-3 months";
    if (durationDays >= 90 && durationDays < 180) return "3-6 months";
    return "more than 6 months";
  }

  // --- 14. Utility & Helper Functions ---

  /// Shows a simple message at the bottom of the screen (SnackBar)
  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: _sparkPrimaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// --- SEPARATE CARD WIDGET ---
// (This widget remains unchanged)
class _OpportunityCard extends StatelessWidget {
  final Opportunity opportunity;
  final Company? company;
  final String? studentId;
  final VoidCallback onViewMore;
  final Function(bool) onToggleBookmark;
  final BookmarkService _bookmarkService = BookmarkService();

  _OpportunityCard({
    required this.opportunity,
    required this.company,
    required this.studentId,
    required this.onViewMore,
    required this.onToggleBookmark,
  });

  String formatDate(DateTime? date) =>
      date == null ? 'N/A' : DateFormat('MMM d, yyyy').format(date);

  // --- (NEW) HELPER FOR INFO CHIPS ---
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onViewMore, // Go to detail view on tap
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Logo
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        (company?.logoUrl != null &&
                            company!.logoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(company!.logoUrl!)
                        : null,
                    child:
                        (company?.logoUrl == null || company!.logoUrl!.isEmpty)
                        ? const Icon(Icons.business, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Role Title
                        Text(
                          opportunity.role,
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Opportunity Name
                        Text(
                          opportunity.name,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF422F5D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Company Name
                        Text(
                          company?.companyName ?? "...",
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bookmark Icon
                  if (studentId != null)
                    StreamBuilder<bool>(
                      stream: _bookmarkService.isBookmarkedStream(
                        studentId: studentId!,
                        opportunityId: opportunity.id,
                      ),
                      builder: (context, snapshot) => IconButton(
                        icon: Icon(
                          snapshot.data == true
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: _sparkPrimaryPurple,
                        ),
                        onPressed: () =>
                            onToggleBookmark(snapshot.data ?? false),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    children: [
                      _buildDateInfo(
                        Icons.calendar_today_outlined,
                        'Duration',
                        '${formatDate(opportunity.startDate?.toDate())} - ${formatDate(opportunity.endDate?.toDate())}',
                      ),
                      const SizedBox(width: 16),
                      _buildDateInfo(
                        Icons.event_available_outlined,
                        'Apply By',
                        formatDate(opportunity.applicationDeadline?.toDate()),
                      ),
                    ],
                  ),
                  // Show response deadline if visible and exists
                  if (opportunity.responseDeadlineVisible == true &&
                      opportunity.responseDeadline != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDateInfo(
                          Icons.schedule_outlined,
                          'Response By',
                          formatDate(opportunity.responseDeadline?.toDate()),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // --- (NEW) INFO CHIPS ADDED ---
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  if (opportunity.location != null &&
                      opportunity.location!.isNotEmpty)
                    _buildInfoChip(
                      Icons.location_on_outlined,
                      opportunity.location!,
                    ),
                  if (opportunity.workMode != null &&
                      opportunity.workMode!.isNotEmpty)
                    _buildInfoChip(
                      Icons.laptop_chromebook_outlined,
                      opportunity.workMode!,
                    ),
                  _buildInfoChip(
                    opportunity.isPaid
                        ? Icons.attach_money_outlined
                        : Icons.money_off_outlined,
                    opportunity.isPaid ? 'Paid' : 'Unpaid',
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onViewMore,
                    child: const Text(
                      'View More',
                      style: TextStyle(
                        color: _sparkPrimaryPurple,
                        fontWeight: FontWeight.bold,
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
  }

  /// Helper widget to build the date info sections in the card
  Widget _buildDateInfo(IconData icon, String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// --- UTILITY EXTENSION ---
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    // Capitalize first letter, lowercase the rest
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
