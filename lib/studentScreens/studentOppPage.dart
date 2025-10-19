// lib/studentScreens/studentOppPage.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/Application.dart';
import 'package:my_app/models/company.dart';
import 'package:my_app/models/opportunity.dart';
import 'package:my_app/services/applicationService.dart';
import 'package:my_app/services/authService.dart';
import 'package:my_app/services/bookmarkService.dart';
import 'package:my_app/services/opportunityService.dart';
import 'package:my_app/studentScreens/studentCompaniesPage.dart';
import 'package:my_app/studentScreens/studentCompanyProfilePage.dart';
import '../studentScreens/studentViewProfile.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentSavedOpp.dart';

// Enum for clearer state management

enum ScreenState { initialLoading, loading, success, error, empty }

class studentOppPgae extends StatefulWidget {
  const studentOppPgae({super.key});
  @override
  State<studentOppPgae> createState() => _studentOppPgaeState();
}

class _studentOppPgaeState extends State<studentOppPgae> {
  // --- 1. Variables, Services & Controllers ---

  // Services
  // هنا نقوم بإنشاء نُسخ (instances) من الكلاسات  (Services)
  // التي تتعامل مع قواعد البيانات مثل جلب الفرص، المصادقة، الخ.
  final OpportunityService _opportunityService = OpportunityService();
  final AuthService _authService = AuthService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ApplicationService _applicationService = ApplicationService();

  // Data State
  // متغيرات لتخزين البيانات التي نحصل عليها من فايربيس
  List<Opportunity> _opportunities = []; // List to hold all opportunities
  Map<String, Company> _companyCache = {}; // Cache to store company data to avoid re-fetching
  String? _studentId; // Stores the logged-in student's ID

  // UI State
  // متغيرات لتتبع حالة الواجهة (UI)
  ScreenState _state = ScreenState.initialLoading; // Current state of the screen
  String? _errorMessage; // Stores error message if something goes wrong
  int _currentIndex = 2; // Current active index for the bottom navigation bar

  // In-page Detail View State

  Opportunity? _selectedOpportunity; // Holds the opportunity being viewed
  Application? _currentApplication; // Holds the student's application for the selected opportunity
  bool _isApplying = false; // Tracks if an application is currently being submitted

  // Controllers
  
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  Timer? _debounce; // Timer for search input to avoid searching on every keystroke

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
    _searchController.addListener(_onSearchChanged); // Listen for changes in the search bar
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

  // --- 3. Main Build Method ---

  @override
  Widget build(BuildContext context) {
    // This is the main method that builds the UI
    return WillPopScope(
      onWillPop: _onBackPressed, // Handle back button press
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(), // Build the app bar
        body: _buildPageContent(), // Build the main content of the page
        // Show BottomNavBar only on the list view
        bottomNavigationBar: _selectedOpportunity == null
            ? CustomBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavigationTap,
              )
            : null,
        // Show the "Apply" button only on the detail view
        bottomSheet: _selectedOpportunity != null
            ? _buildActionBottomSheet()
            : null,
      ),
    );
  }

  // --- 4. Core UI Structure Builders ---

  // Builds the AppBar. It changes based on whether we are in list or detail view.
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

  // Determines whether to show the list of opportunities or the details of one
  Widget _buildPageContent() {
    if (_selectedOpportunity == null) {
      return _buildListView(); // Show the list
    } else {
      return _buildOpportunityDetailsView(_selectedOpportunity!); // Show the details
    }
  }

  // Builds the bottom sheet (the bar with the "Apply Now" or "Withdraw" button)
  Widget _buildActionBottomSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom, // Safe area padding
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // Check if the student has already applied
      child: _currentApplication != null
          ? _buildStatusAndWithdrawView() // Show status and withdraw button
          : _buildApplyNowView(), // Show apply button
    );
  }

  // --- 5. List View Builders ---

  // Builds the main list view (search bar, filters, and list)
  Widget _buildListView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildTypeFilterChips(),
        _buildActiveFiltersBar(), // Shows currently active filters
        Expanded(child: _buildContent()), // The list itself
      ],
    );
  }

  // Builds the search bar widget
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

  // Builds the horizontal list of "Type" filters (All, Internship, Co-op, etc.)
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
              selectedColor: const Color(0xFF422F5D),
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

  // Shows the small chips for active filters (e.g., "City: Riyadh", "Paid")
  Widget _buildActiveFiltersBar() {
    final hasActiveFilters = _selectedCity != null ||
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
              label: Text(_selectedLocationType!.capitalize()),
              onDeleted: () {
                setState(() => _selectedLocationType = null);
                _fetchOpportunities();
              },
            ),
          if (_isPaid != null)
            Chip(
              label: Text(_isPaid! ? 'Paid' : 'Unpaid'),
              backgroundColor:
                  _isPaid! ? Colors.green.shade100 : Colors.orange.shade100,
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

  // This widget decides what to show based on the ScreenState (loading, error, empty, success)
  Widget _buildContent() {
    switch (_state) {
      case ScreenState.initialLoading:
      case ScreenState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF422F5D)),
        );
      case ScreenState.error:
        return _buildErrorWidget(); // Show error message
      case ScreenState.empty:
        return _buildEmptyState(); // Show "No opportunities found"
      case ScreenState.success:
        return RefreshIndicator(
          onRefresh: _fetchOpportunities, // Allow pull-to-refresh
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: _opportunities.length,
            itemBuilder: (context, index) =>
                _buildOpportunityCard(_opportunities[index]), // Build each card
          ),
        );
    }
  }

  // Builds a single opportunity card for the list
  Widget _buildOpportunityCard(Opportunity opportunity) {
    String formatDate(DateTime? date) =>
        date == null ? 'N/A' : DateFormat('MMM d, yyyy').format(date);
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _viewOpportunityDetails(opportunity), // Go to detail view on tap
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<Company?>(
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
                            // Company Name
                            Text(
                              snapshot.data?.companyName ?? "...",
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bookmark Icon
                      if (_studentId != null)
                        StreamBuilder<bool>(
                          stream: _bookmarkService.isBookmarkedStream(
                            studentId: _studentId!,
                            opportunityId: opportunity.id,
                          ),
                          builder: (context, snapshot) => IconButton(
                            icon: Icon(
                              snapshot.data == true
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: const Color(0xFF422F5D),
                            ),
                            onPressed: () => _toggleBookmark(
                              opportunity,
                              snapshot.data ?? false,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
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
                  // Show response deadline if company made it visible
                  if (opportunity.responseDeadlineVisible == true &&
                      opportunity.responseDeadline != null) ...[
                    const SizedBox(width: 16),
                    _buildDateInfo(
                      Icons.event_available_outlined,
                      'Respond By',
                      formatDate(opportunity.responseDeadline?.toDate()),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Description snippet
              if (opportunity.description != null &&
                  opportunity.description!.isNotEmpty)
                Text(
                  opportunity.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: Colors.black.withOpacity(0.65),
                    height: 1.5,
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _viewOpportunityDetails(opportunity),
                    child: const Text(
                      'View More',
                      style: TextStyle(
                        color: Color(0xFF422F5D),
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

  // Helper widget to build the date info sections in the card
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

  // --- 6. Detail View Builders ---

  // Builds the scrollable detail view for a selected opportunity
  Widget _buildOpportunityDetailsView(Opportunity opportunity) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailHeader(opportunity),
            const SizedBox(height: 24),
            _buildDetailKeyInfoSection(opportunity),
            const SizedBox(height: 24),
            // Description
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
            // Skills
            if (opportunity.skills != null && opportunity.skills!.isNotEmpty)
              _buildDetailSection(
                title: 'Key Skills',
                content: _buildChipList(opportunity.skills!),
              ),
            // Requirements
            if (opportunity.requirements != null &&
                opportunity.requirements!.isNotEmpty)
              _buildDetailSection(
                title: 'Requirements',
                content: _buildRequirementList(opportunity.requirements!),
              ),
            // More Info section
            _buildDetailSection(
              title: 'More Info',
              content: _buildMoreInfo(opportunity),
            ),
            const SizedBox(height: 100), // Padding for the bottom sheet
          ],
        ),
      ),
    );
  }

  // Builds the header of the detail page (logo, role, company name)
  Widget _buildDetailHeader(Opportunity opportunity) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Company?>(
          future: _authService.getCompany(opportunity.companyId),
          builder: (context, snapshot) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (snapshot.data?.logoUrl != null &&
                          snapshot.data!.logoUrl!.isNotEmpty)
                      ? NetworkImage(snapshot.data!.logoUrl!)
                      : null,
                  child: (snapshot.data?.logoUrl == null ||
                          snapshot.data!.logoUrl!.isEmpty)
                      ? const Icon(Icons.business, size: 30, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.role,
                        style: GoogleFonts.lato(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF422F5D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.data?.companyName ?? 'Loading...',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            _navigateToCompanyProfile(opportunity.companyId),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          foregroundColor: const Color(0xFF422F5D),
                        ),
                        child: const Text(
                          'View Company Profile',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Builds the key info section (Location, Duration, Deadline)
  Widget _buildDetailKeyInfoSection(Opportunity opportunity) {
    String formatDate(DateTime? date) =>
        date == null ? 'N/A' : DateFormat('MMMM d, yyyy').format(date);
    
    final List<Widget> tiles = [
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
    ];

    // Add response deadline tile only if visible
    if (opportunity.responseDeadlineVisible == true &&
        opportunity.responseDeadline != null) {
      tiles.add(
        _buildInfoTile(
          icon: Icons.event_available_outlined,
          title: 'Respond By',
          value: formatDate(opportunity.responseDeadline!.toDate()),
        ),
      );
    }

    return Column(children: tiles);
  }

  // Helper widget for _buildDetailKeyInfoSection
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF422F5D)),
        title: Text(
          title,
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.lato(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
      ),
    );
  }

  // A generic builder for sections like "Description", "Skills", etc.
  Widget _buildDetailSection({required String title, required Widget content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF422F5D),
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // Helper widget to display a list of strings as chips (for skills)
  Widget _buildChipList(List<String> items) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              backgroundColor: const Color(0xFF422F5D).withOpacity(0.1),
              labelStyle: const TextStyle(
                color: Color(0xFF422F5D),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }

  // Helper widget to display a list of strings as a bulleted list (for requirements)
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

  // Builds the "More Info" card (Type, Major, Payment)
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

  // Helper for _buildMoreInfo
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

  // --- 7. Action & Status Components (for Bottom Sheet) ---

  // Builds the "Apply Now" button
  Widget _buildApplyNowView() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isApplying ? null : _applyNow, // Disable button while applying
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF422F5D),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isApplying
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                "Apply Now",
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // Builds the view that shows application status and the "Withdraw" button
  Widget _buildStatusAndWithdrawView() {
    final status = _currentApplication!.status;
    // Student can only withdraw if status is pending or reviewed
    final canWithdraw =
        status.toLowerCase() == 'pending' || status.toLowerCase() == 'reviewed';

    return Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Status:',
              style: GoogleFonts.lato(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusChip(status), // Show status (e.g., "Pending")
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: canWithdraw ? _withdrawApplication : null, // Enable/disable button
            style: ElevatedButton.styleFrom(
              backgroundColor: canWithdraw ? Colors.red.shade700 : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Withdraw',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget to show the application status (Pending, Hired, etc.) with colors
  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.capitalize(),
        style: GoogleFonts.lato(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // Helper function to get the correct color for each status
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

  // --- 8. State/Error/Empty Builders ---

  // Widget to show when the list is empty
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
              backgroundColor: const Color(0xFF422F5D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Filters'),
          ),
        ],
      ),
    );
  }

  // Widget to show when an error occurs
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

  // --- 9. Data & State Logic ---

  // Loads the student's ID first, then fetches opportunities
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

  // Called when the search text changes
  void _onSearchChanged() {
    // Debounce: Wait 500ms after user stops typing to start search
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchOpportunities);
  }

  // Main function to fetch and filter opportunities
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
        final companyIds =
            opportunities.map((opp) => opp.companyId).toSet().toList();
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
        final matchesSearch = query.isEmpty ||
            opp.role.toLowerCase().contains(query) ||
            opp.name.toLowerCase().contains(query) ||
            companyNameMatch;

        // Check other filters
        final matchesCity = _selectedCity == null ||
            (opp.location?.toLowerCase() == _selectedCity?.toLowerCase());
        final matchesLocation = _selectedLocationType == null ||
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

  // --- 10. Filter Logic ---

  // Shows the filter bottom sheet
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
                    selectedColor: const Color(0xFF422F5D),
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
                    labelBuilder: (s) => s.capitalize(),
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
                    onSelected: (value) => setModalState(() => _isPaid = value),
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
                            backgroundColor: const Color(0xFF422F5D),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Resets all filters and re-fetches the list
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

  // Helper function to categorize duration for filtering
  String getDurationCategory(dynamic start, dynamic end) {
    if (start == null || end == null) return "Unknown";
    // Convert to DateTime objects
    final DateTime startDate =
        start is DateTime ? start : (start as dynamic).toDate();
    final DateTime endDate = end is DateTime ? end : (end as dynamic).toDate();
    final durationDays = endDate.difference(startDate).inDays;
    
    if (durationDays < 30) return "less than a month";
    if (durationDays >= 30 && durationDays < 90) return "1-3 months";
    if (durationDays >= 90 && durationDays < 180) return "3-6 months";
    return "more than 6 months";
  }

  // --- 11. User Actions (Apply, Withdraw, Bookmark) ---

  // Called when the "Apply Now" button is pressed
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
              backgroundColor: const Color(0xFF422F5D),
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
        setState(() => _isApplying = false); // Stop loading
      }
    }
  }

  // Called when the "Withdraw" button is pressed
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

  // Called when the bookmark icon is pressed
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

  // --- 12. Navigation & View Switching ---

  // Switches the view to show details for a specific opportunity
  void _viewOpportunityDetails(Opportunity opportunity) async {
    setState(() {
      _selectedOpportunity = opportunity;
      _currentApplication = null; // Reset application state
      _isApplying = false; // Reset applying state
    });
    // Fetch the application status for this specific opportunity
    final studentId = _studentId;
    if (studentId == null) return;

    final app = await _applicationService.getApplicationForOpportunity(
      studentId: studentId,
      opportunityId: opportunity.id,
    );
    if (!mounted) return;
    setState(() {
      _currentApplication = app; // Store the application
    });
  }

  // Switches the view back to the main list
  void _showOpportunityList() {
    setState(() {
      _selectedOpportunity = null;
    });
  }

  // Handles the phone's physical back button
  Future<bool> _onBackPressed() {
    if (_selectedOpportunity != null) {
      // If on detail view, go back to list view
      _showOpportunityList();
      return Future.value(false); // Don't pop the route (don't exit app)
    }
    // If on list view, allow app to exit
    return Future.value(true);
  }

  // Navigates to the company profile page
  void _navigateToCompanyProfile(String companyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCompanyProfilePage(companyId: companyId),
      ),
    );
  }

  // Navigates to the saved opportunities page
  void _navigateToSaved() {
    if (_studentId != null)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedstudentOppPgae(studentId: _studentId!),
        ),
      );
  }

  // Handles taps on the Bottom Navigation Bar
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
          MaterialPageRoute(builder: (context) => const StudentCompaniesPage()),
        );
        break;
      case 3:
        // Go to Profile Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewProfile()),
        );
        break;
    }
  }

  // --- 13. Utility & Helper Functions ---

  // Shows a simple message at the bottom of the screen (SnackBar)
  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: const Color(0xFF422F5D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// Extension to add a .capitalize() function to the String class
// e.g., "hello".capitalize() -> "Hello"
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
