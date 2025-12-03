// lib/studentScreens/studentOppPage.dart

// --- IMPORTS ---
import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// Note: Ensure your import paths are correct for your project
import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../models/resume.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import '../utils/page_transitions.dart';
import '../studentScreens/studentCompanyProfilePage.dart'; // Import for navigation
import '../studentScreens/studentOppDetails.dart';
import '../studentScreens/studentApplications.dart';
import 'package:spark/services/bookmarkService.dart';
import 'package:spark/services/opportunityService.dart';
import 'package:spark/studentScreens/studentCompaniesPage.dart';

import '../studentScreens/studentViewProfile.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentSavedOpp.dart';
import '../studentScreens/StudentChatPage.dart';
import '../studentScreens/StudentHomePage.dart';
import 'resumeSelectionDialog.dart';
import '../widgets/application_success_dialog.dart';
import 'applicationConfirmationDialog.dart';
import '../theme/student_theme.dart';

// --- COLOR CONSTANTS (Use StudentTheme for consistency) ---
const Color _sparkPrimaryPurple = StudentTheme.primaryColor;
const Color _pageBackgroundColor = Color(0xFFF7F2FB); // light purple
String _cleanCity(String city) {
  var c = city.trim();
  if (c.contains(',')) {
    c = c.split(',').first.trim();
  }
  final lower = c.toLowerCase();
  if (lower.contains('saudi arabia')) {
    c = c.replaceAll(RegExp('saudi arabia', caseSensitive: false), '').trim();
  }
  return c.isEmpty ? city.trim() : c;
}

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
  int _currentIndex = 3; // Current active index for the bottom navigation bar

  // In-page Detail View State
  Opportunity? _selectedOpportunity; // Holds the opportunity being viewed
  Application?
  _currentApplication; // Holds application for the selected opportunity
  bool _isApplying = false; // Tracks if an application is being submitted

  // Controllers
  final _searchController = TextEditingController();
  Timer?
  _debounce; // Timer for search input to avoid searching on every keystroke

  // Filter State
  String _activeTypeFilter = 'All'; // Filter by type (e.g., Internship, Co-op)
  String? _selectedCity; // Filter by city
  String? _selectedLocationType; // Filter by work mode (remote, in-person)
  bool? _isPaid; // Filter by paid/unpaid
  String? _selectedDuration; // Filter by duration

  List<String> _cityOptions = [];

  // --- 2. Lifecycle Methods ---

  @override
  void initState() {
    super.initState();
    // This method is called once when the widget is first created
    _loadInitialData(); // Load the initial data needed for the page
    _searchController.addListener(
      _onSearchChanged,
    ); // Listen for changes in the search bar
    _loadCityOptions();
  }

  @override
  void dispose() {
    // This method is called when the widget is permanently removed
    // It's important to dispose controllers to free up resources
    _searchController.dispose();
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

  Future<void> _loadCityOptions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lists')
          .doc('city')
          .get();
      final names = List<String>.from(
        (doc.data() as Map<String, dynamic>?)?['names'] ?? [],
      );
      if (mounted) {
        setState(() {
          // Clean and dedupe
          final cleaned = names.map(_cleanCity).where((c) => c.isNotEmpty);
          _cityOptions = cleaned.toSet().toList()..sort();
        });
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
      if (mounted) {
        setState(() {
          _cityOptions = ['Riyadh', 'Jeddah', 'Dammam'];
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
      final rawSearch = _searchController.text.trim();

      // 1. Fetch opportunities from Firestore with server-side filters where possible
      // Note: City filtering is done client-side due to inconsistent data format
      final opportunities = await _opportunityService.getOpportunities(
        searchQuery: rawSearch.isEmpty ? null : rawSearch,
        type: _activeTypeFilter == 'All' ? null : _activeTypeFilter,
        city: null, // Don't filter by city on server-side
        locationType: _selectedLocationType,
        isPaid: _isPaid,
      );

      // 2. Fetch company data for all unique company IDs using chunked whereIn queries
      _companyCache = {};
      if (opportunities.isNotEmpty) {
        final companyIds = opportunities
            .map((opp) => opp.companyId)
            .toSet()
            .toList();
        if (companyIds.isNotEmpty) {
          _companyCache = await _fetchCompaniesInChunks(companyIds);
        }
      }

      // 3. Apply client-side filtering for company name search & duration
      final query = rawSearch.toLowerCase();
      final now = DateTime.now();
      final filtered = opportunities.where((opp) {
        // Check if opportunity is open (not before applicationOpenDate and not after applicationDeadline)
        final applicationOpenDate = opp.applicationOpenDate?.toDate();
        final applicationDeadline = opp.applicationDeadline?.toDate();

        // Hide if application period hasn't started yet
        if (applicationOpenDate != null && now.isBefore(applicationOpenDate)) {
          return false;
        }

        // Hide if application deadline has passed
        if (applicationDeadline != null && now.isAfter(applicationDeadline)) {
          return false;
        }

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
        // Use flexible city matching with contains for better compatibility
        final matchesCity = _selectedCity == null ||
            (opp.location != null &&
             opp.location!.toLowerCase().contains(_selectedCity!.toLowerCase()));
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

    final companyNameForDialog =
        await _getCompanyNameForDialog(_selectedOpportunity!.companyId);

    while (true) {
      final selection = await showDialog<Map<String, dynamic>?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ResumeSelectionDialog(
          studentId: _studentId!,
        ),
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
          companyName: companyNameForDialog,
        ),
      );

      if (confirm != true) {
        // If user discarded/closed, stop and return to details
        if (confirm == null) return;
        // Otherwise back to resume selection
        continue;
      }

      setState(() => _isApplying = true);
      try {
        await _applicationService.submitApplication(
          studentId: _studentId!,
          opportunityId: _selectedOpportunity!.id,
          resumeId: resume.id,
          resumePdfUrl: resume.pdfUrl,
          coverLetterText: coverLetter,
        );

        if (!mounted) return;

        final includeCoverLetter =
            coverLetter != null && coverLetter.trim().isNotEmpty;

        String companyName =
            _companyCache[_selectedOpportunity!.companyId]?.companyName ?? '';
        if (companyName.isEmpty) {
          final fetchedCompany =
              await _authService.getCompany(_selectedOpportunity!.companyId);
          companyName = fetchedCompany?.companyName ?? 'the hiring team';
        }

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
                    studentId: _studentId!,
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
      break;
    }
  }

  Future<String> _getCompanyNameForDialog(String companyId) async {
    final cached = _companyCache[companyId]?.companyName;
    if (cached != null && cached.trim().isNotEmpty) return cached;
    try {
      final company = await _authService.getCompany(companyId);
      final name = company?.companyName ?? '';
      if (company != null && name.trim().isNotEmpty) {
        _companyCache[companyId] = company!;
        return name;
      }
    } catch (_) {
      // ignore
    }
    return 'Company';
  }

  /// Called when the "Withdraw" button is pressed
  Future<void> _withdrawApplication() async {
    if (_currentApplication == null) return;

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Withdraw application?',
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
                'This will update your application status to "Withdrawn". You cannot undo this.',
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
                        'Keep',
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
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Withdraw',
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

  Future<Map<String, Company>> _fetchCompaniesInChunks(
    List<String> companyIds,
  ) async {
    const chunkSize = 10;
    final collection = FirebaseFirestore.instance.collection('companies');
    final results = <String, Company>{};

    for (var i = 0; i < companyIds.length; i += chunkSize) {
      final chunk = companyIds.sublist(
        i,
        math.min(i + chunkSize, companyIds.length),
      );
      final snapshot = await collection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        results[doc.id] =
            Company.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }
    }
    return results;
  }

  // --- 5. Navigation & View Switching ---

  /// Switches the view to show details for a specific opportunity
  /// Switches the view to show details for a specific opportunity
  Future<void> _viewOpportunityDetails(Opportunity opportunity) async {
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
        Navigator.pushReplacement(
          context,
          NoTransitionRoute(page: const StudentHomePage()),
        );
        break;
      case 1:
        // Go to Companies Page
        Navigator.pushReplacement(
          context,
          NoTransitionRoute(page: const StudentCompaniesPage()),
        );
        break;
              case 2: 

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StudentChatPage()),
        );
        break;
      case 4:
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
        leading: IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: _showFilterSheet, // Open filters
          tooltip: 'Filter',
        ),
        title: Text(
          'Opportunities',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
            onPressed: _navigateToSaved, // Open saved opportunities
            tooltip: 'Saved',
          ),
        ],
      );
    } else {
      // AppBar for the Detail View
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _showOpportunityList, // Go back to the list
        ),
        title: Text('Opportunity Details', style: GoogleFonts.lato(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
            return Container(
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8D52CC) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _activeTypeFilter = type);
                    _fetchOpportunities(); // Re-fetch data with the new filter
                  },
                  borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
        _selectedDuration != null ||
        (_activeTypeFilter != null && _activeTypeFilter != 'All');
    if (!hasActiveFilters) return const SizedBox.shrink(); // Hide if no filters

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          if (_activeTypeFilter != null && _activeTypeFilter != 'All')
            Chip(
              label: Text('Type: $_activeTypeFilter'),
              onDeleted: () {
                setState(() => _activeTypeFilter = 'All');
                _fetchOpportunities();
              },
            ),
          // Add a chip for each active filter
          if (_selectedCity != null && _selectedCity!.isNotEmpty)
            Chip(
              label: Text('City: $_selectedCity'),
              onDeleted: () {
                setState(() => _selectedCity = null);
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
    String? selectedCityLocal = _selectedCity;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        const purple = Color(0xFF8D52CC);
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
                runSpacing: 8.0,
                children: options.map((option) {
                  final isSelected = selectedValue == option;
                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF8D52CC) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelected(isSelected ? null : option),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? null : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            labelBuilder(option),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // City Filter
                    Text(
                      'City',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: (_cityOptions.isNotEmpty
                              ? _cityOptions
                              : <String>['Riyadh', 'Jeddah', 'Dammam'])
                          .map((city) {
                        final display = _cleanCity(city);
                        final isSelected = selectedCityLocal == display;
                        return ChoiceChip(
                          label: Text(display),
                          selected: isSelected,
                          selectedColor: purple,
                          backgroundColor: Colors.grey.shade200,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) {
                            setModalState(() {
                              selectedCityLocal =
                                  isSelected ? null : display;
                            });
                          },
                        );
                      }).toList(),
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
                    // Opportunity Type Filter
                    Text(
                      'Opportunity Type',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildModalChips<String>(
                      options: const [
                        'Internship',
                        'Co-op',
                        'Graduate Program',
                        'Bootcamp',
                      ],
                      selectedValue:
                          _activeTypeFilter == 'All' ? null : _activeTypeFilter,
                      labelBuilder: (s) => s,
                      onSelected: (value) => setModalState(
                        () => _activeTypeFilter = value ?? 'All',
                      ),
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
                _selectedLocationType = null;
                _isPaid = null;
                _selectedDuration = null;
                selectedCityLocal = null;
              }),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: purple, width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              // Apply filters to the main page state
                              setState(() => _selectedCity = selectedCityLocal);
                              _fetchOpportunities(); // Re-fetch data
                              Navigator.pop(context); // Close the modal
                            },
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

  // Simple info display without container background
  Widget _buildSimpleInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.lato(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Opportunity type info
  Widget _buildTypeInfo(String type) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.business_center_outlined, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          type,
          style: GoogleFonts.lato(
            color: Colors.grey.shade700,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company Logo
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
                    radius: 24,
                    backgroundColor: const Color(0xFF422F5D).withValues(alpha: 0.08),
                    backgroundImage: (company?.logoUrl != null && company!.logoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(company!.logoUrl!)
                        : null,
                    child: (company?.logoUrl == null || company!.logoUrl!.isEmpty)
                        ? Icon(Icons.business, color: const Color(0xFF422F5D), size: 22)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Name
                      Text(
                        company?.companyName ?? "...",
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Role Title
                      Text(
                        opportunity.role,
                        style: GoogleFonts.lato(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Opportunity Name in dark pink
                      if (opportunity.name.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          opportunity.name,
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: const Color(0xFFD54DB9),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                    builder: (context, snapshot) {
                      final isBookmarked = snapshot.data == true;
                      return IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: const Color(0xFF8D52CC),
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => onToggleBookmark(snapshot.data ?? false),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row - opportunity type, work mode, paid status
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              children: [
                _buildTypeInfo(opportunity.type),
                if (opportunity.workMode != null && opportunity.workMode!.isNotEmpty)
                  _buildSimpleInfo(
                    Icons.laptop_chromebook_outlined,
                    opportunity.workMode!,
                  ),
                if (opportunity.location != null &&
                    opportunity.location!.trim().isNotEmpty)
                  _buildSimpleInfo(
                    Icons.location_on_outlined,
                    opportunity.location!.trim(),
                  ),
                _buildSimpleInfo(
                  opportunity.isPaid ? Icons.attach_money : Icons.money_off_outlined,
                  opportunity.isPaid ? 'Paid' : 'Unpaid',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // View Button aligned right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D52CC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onViewMore,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                        child: Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

}

// --- UTILITY EXTENSION ---
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    // Capitalize first letter, lowercase the rest
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
