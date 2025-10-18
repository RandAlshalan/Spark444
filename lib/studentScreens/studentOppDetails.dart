// lib/studentScreens/studentOppPage.dart

// --- IMPORTS ---
import 'dart:async'; // Used for the Timer to create a "debounce" for searching
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For custom fonts
import 'package:intl/intl.dart'; // For formatting dates (e.g., "MMM d, yyyy")
import 'package:my_app/models/application.dart'; // Data model for Application
import 'package:my_app/models/company.dart'; // Data model for Company
import 'package:my_app/models/opportunity.dart'; // Data model for Opportunity
import 'package:my_app/services/applicationService.dart'; // Handles application logic (submit, withdraw)
import 'package:my_app/services/authService.dart'; // Handles user authentication and data
import 'package:my_app/services/bookmarkService.dart'; // Handles bookmarking logic
import 'package:my_app/services/opportunityService.dart'; // Handles fetching opportunities
import '../studentScreens/studentViewProfile.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentSavedOpp.dart';

// This Enum defines the possible states of the screen for loading data.
// It helps in showing the correct UI (e.g., loading indicator, error message, or data).
enum ScreenState { initialLoading, loading, success, error, empty }

// --- WIDGET DEFINITION ---
class studentOppPgae extends StatefulWidget {
  const studentOppPgae({super.key});
  @override
  State<studentOppPgae> createState() => _studentOppPgaeState();
}

class _studentOppPgaeState extends State<studentOppPgae> {
  // --- 1. STATE VARIABLES & SERVICES ---

  // Services
  // These are instances of our service classes that talk to the database.
  final OpportunityService _opportunityService = OpportunityService();
  final AuthService _authService = AuthService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ApplicationService _applicationService = ApplicationService();

  // Data State
  // These variables hold the data fetched from the services.
  List<Opportunity> _opportunities = []; // The list of opportunities to display
  String? _studentId; // The ID of the currently logged-in student

  // UI State
  // These variables control what the user sees on the screen.
  ScreenState _state = ScreenState.initialLoading; // The current loading state
  String? _errorMessage; // Stores any error message to show to the user
  int _currentIndex = 2; // The active tab index for the bottom navigation bar

  // In-Page Detail View State
  // These control the "detail" view when a user taps on an opportunity.
  Opportunity? _selectedOpportunity; // The opportunity currently being viewed
  Application? _currentApplication; // The student's application for this opportunity
  bool _isApplying = false; // Tracks if the "Apply Now" button is loading

  // Controllers
  // These manage the text input fields.
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  Timer? _debounce; // Used to delay searching until the user stops typing

  // Filter State
  // These store the user's selected filter options.
  String _activeTypeFilter = 'All';
  String? _selectedCity;
  String? _selectedLocationType;
  bool? _isPaid;
  String? _selectedDuration;

  // --- 2. LIFECYCLE METHODS ---

  @override
  void initState() {
    super.initState();
    // This method is called once when the widget is first created.
    _loadInitialData(); // Load the student's ID and initial opportunities
    // Add a listener to the search controller to fetch opportunities when text changes.
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // This method is called when the widget is permanently removed.
    // It's crucial to dispose of controllers to prevent memory leaks.
    _searchController.dispose();
    _cityController.dispose();
    _debounce?.cancel(); // Cancel any active timer
    super.dispose();
  }

  // --- 3. MAIN BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    // This is the main method that builds the UI.
    return WillPopScope(
      onWillPop: _onBackPressed, // Handle the physical back button press
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(), // Builds the top app bar
        body: _buildPageContent(), // Builds the main content area
        // Only show the BottomNavBar if we are on the list view
        bottomNavigationBar: _selectedOpportunity == null
            ? CustomBottomNavBar(
                currentIndex: _currentIndex, onTap: _onNavigationTap)
            : null,
        // Only show the "Apply" button if we are on the detail view
        bottomSheet:
            _selectedOpportunity != null ? _buildActionBottomSheet() : null,
      ),
    );
  }

  // --- 4. CORE UI BUILDERS ---

  // Builds the AppBar. It changes based on whether we are in list or detail view.
  PreferredSizeWidget _buildAppBar() {
    if (_selectedOpportunity == null) {
      // --- List View AppBar ---
      return AppBar(
        automaticallyImplyLeading: false, // No back arrow
        title: Text('Opportunities',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          // Filter button
          IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterSheet,
              tooltip: 'Filter'),
          // Saved opportunities button
          IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: _navigateToSaved,
              tooltip: 'Saved'),
        ],
      );
    } else {
      // --- Detail View AppBar ---
      return AppBar(
        // Back arrow to return to the list
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showOpportunityList,
        ),
        title: Text('Opportunity Details', style: GoogleFonts.lato()),
        backgroundColor: Colors.white,
        elevation: 1,
      );
    }
  }

  // Determines whether to show the list of opportunities or the details of one.
  Widget _buildPageContent() {
    if (_selectedOpportunity == null) {
      // If no opportunity is selected, show the list view.
      return _buildListView();
    } else {
      // If an opportunity is selected, show its details.
      return _buildOpportunityDetailsView(_selectedOpportunity!);
    }
  }

  // Builds the bottom sheet (the bar with the "Apply Now" or "Withdraw" button).
  Widget _buildActionBottomSheet() {
    return Container(
      // Add padding for the phone's bottom "safe area" (like the home bar)
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      // Check if the student has already applied
      child: _currentApplication != null
          ? _buildStatusAndWithdrawView() // If yes, show status and withdraw
          : _buildApplyNowView(), // If no, show "Apply Now"
    );
  }

  // --- 5. LIST VIEW WIDGETS ---

  // Builds the main list view (search bar, filters, and the list itself).
  Widget _buildListView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildTypeFilterChips(),
        _buildActiveFiltersBar(),
        // Expanded makes the content list take all remaining vertical space.
        Expanded(child: _buildContent()),
      ],
    );
  }

  // This widget decides what to show based on the ScreenState (loading, error, empty, success).
  Widget _buildContent() {
    switch (_state) {
      case ScreenState.initialLoading:
      case ScreenState.loading:
        // Show a loading spinner while data is being fetched.
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF422F5D)));
      case ScreenState.error:
        // Show an error message if fetching failed.
        return _buildErrorWidget();
      case ScreenState.empty:
        // Show a message if no opportunities match the filters.
        return _buildEmptyState();
      case ScreenState.success:
        // Show the list of opportunities.
        return RefreshIndicator(
          onRefresh: _fetchOpportunities, // Allows pull-to-refresh
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: _opportunities.length,
            itemBuilder: (context, index) =>
                _buildOpportunityCard(_opportunities[index]),
          ),
        );
    }
  }

  // Builds a single opportunity card for the list.
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
        onTap: () =>
            _viewOpportunityDetails(opportunity), // Go to detail view on tap
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use FutureBuilder to fetch company data "lazily" for each card.
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
                            Text(opportunity.role,
                                style: GoogleFonts.lato(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            // Company Name
                            Text(snapshot.data?.companyName ?? "...",
                                style: GoogleFonts.lato(
                                    fontSize: 14,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      // Bookmark Icon
                      if (_studentId != null)
                        // Use StreamBuilder to show the real-time bookmark status.
                        StreamBuilder<bool>(
                          stream: _bookmarkService.isBookmarkedStream(
                              studentId: _studentId!,
                              opportunityId: opportunity.id),
                          builder: (context, snapshot) => IconButton(
                            icon: Icon(
                                snapshot.data == true
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: const Color(0xFF422F5D)),
                            onPressed: () => _toggleBookmark(
                                opportunity, snapshot.data ?? false),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Date Information
              Row(
                children: [
                  _buildDateInfo(Icons.calendar_today_outlined, 'Duration',
                      '${formatDate(opportunity.startDate?.toDate())} - ${formatDate(opportunity.endDate?.toDate())}'),
                  const SizedBox(width: 16),
                  _buildDateInfo(Icons.event_available_outlined, 'Apply By',
                      formatDate(opportunity.applicationDeadline?.toDate())),
                ],
              ),
              const SizedBox(height: 12),
              // Description Snippet
              if (opportunity.description != null &&
                  opportunity.description!.isNotEmpty)
                Text(
                  opportunity.description!,
                  maxLines: 3, // Show only 3 lines
                  overflow: TextOverflow.ellipsis, // Add "..." if text is long
                  style: GoogleFonts.lato(
                      color: Colors.black.withOpacity(0.65), height: 1.5),
                ),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider()),
              // "View More" Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _viewOpportunityDetails(opportunity),
                    child: const Text('View More',
                        style: TextStyle(
                            color: Color(0xFF422F5D),
                            fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 6. DETAIL VIEW WIDGETS ---

  // Builds the scrollable detail view for a selected opportunity.
  Widget _buildOpportunityDetailsView(Opportunity opportunity) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Logo, Role, Company Name
            _buildDetailHeader(opportunity),
            const SizedBox(height: 24),
            // Key Info: Location, Duration, Deadline
            _buildDetailKeyInfoSection(opportunity),
            const SizedBox(height: 24),
            // Description
            if (opportunity.description != null &&
                opportunity.description!.isNotEmpty)
              _buildDetailSection(
                  title: 'Description',
                  content: Text(opportunity.description!,
                      style: GoogleFonts.lato(
                          height: 1.6, fontSize: 15, color: Colors.black87))),
            // Skills
            if (opportunity.skills != null && opportunity.skills!.isNotEmpty)
              _buildDetailSection(
                  title: 'Key Skills',
                  content: _buildChipList(opportunity.skills!)),
            // Requirements
            if (opportunity.requirements != null &&
                opportunity.requirements!.isNotEmpty)
              _buildDetailSection(
                  title: 'Requirements',
                  content: _buildRequirementList(opportunity.requirements!)),
            // More Info: Type, Major, Payment
            _buildDetailSection(
                title: 'More Info', content: _buildMoreInfo(opportunity)),
            // Add space at the bottom so the bottom sheet doesn't cover content.
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // Builds the header of the detail page (logo, role, company name).
  Widget _buildDetailHeader(Opportunity opportunity) {
    return FutureBuilder<Company?>(
      future: _authService.getCompany(opportunity.companyId),
      builder: (context, snapshot) {
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
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
                      Text(opportunity.role,
                          style: GoogleFonts.lato(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF422F5D))),
                      const SizedBox(height: 6),
                      Text(snapshot.data?.companyName ?? 'Loading...',
                          style: GoogleFonts.lato(
                              fontSize: 16, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Builds the key info section (Location, Duration, Deadline).
  Widget _buildDetailKeyInfoSection(Opportunity opportunity) {
    String formatDate(DateTime? date) =>
        date == null ? 'N/A' : DateFormat('MMMM d, yyyy').format(date);
    return Column(
      children: [
        _buildInfoTile(
            icon: Icons.apartment_outlined,
            title: 'Location / Work Mode',
            value:
                '${opportunity.workMode?.capitalize() ?? ''} · ${opportunity.location ?? 'Remote'}'),
        _buildInfoTile(
            icon: Icons.calendar_today_outlined,
            title: 'Duration',
            value:
                '${formatDate(opportunity.startDate?.toDate())} - ${formatDate(opportunity.endDate?.toDate())}'),
        _buildInfoTile(
            icon: Icons.event_available_outlined,
            title: 'Apply Before',
            value: formatDate(opportunity.applicationDeadline?.toDate()),
            valueColor: Colors.red.shade700),
      ],
    );
  }

  // Builds the "Apply Now" button for the bottom sheet.
  Widget _buildApplyNowView() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        // Disable the button if _isApplying is true
        onPressed: _isApplying ? null : _applyNow,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF422F5D),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isApplying
            // Show a loading indicator inside the button when applying
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3))
            : Text("Apply Now",
                style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
      ),
    );
  }

  // Builds the view for the bottom sheet when the user has already applied.
  Widget _buildStatusAndWithdrawView() {
    final status = _currentApplication!.status;
    // The student can only withdraw if the application is still "pending" or "reviewed".
    final canWithdraw =
        status.toLowerCase() == 'pending' || status.toLowerCase() == 'reviewed';

    return Row(
      children: [
        // Show the current application status
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Status:',
                style: GoogleFonts.lato(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            _buildStatusChip(status),
          ],
        ),
        const SizedBox(width: 16),
        // Show the "Withdraw" button
        Expanded(
          child: ElevatedButton(
            // Disable the button if canWithdraw is false
            onPressed: canWithdraw ? _withdrawApplication : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canWithdraw ? Colors.red.shade700 : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            // Change text based on whether the student can withdraw
            child: Text(canWithdraw ? 'Withdraw' : 'Finalized',
                style: GoogleFonts.lato(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- 7. HELPER WIDGETS (REUSABLE UI COMPONENTS) ---

  // Builds the search bar.
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
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // Builds the horizontal list of "Type" filters (All, Internship, Co-op, etc.).
  Widget _buildTypeFilterChips() {
    final types = ['All', 'Internship', 'Co-op', 'Graduate Program', 'Bootcamp'];
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
              labelStyle:
                  TextStyle(color: isSelected ? Colors.white : Colors.black87),
              backgroundColor: Colors.white,
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
        ),
      ),
    );
  }

  // Shows the small chips for active filters (e.g., "City: Riyadh", "Paid").
  Widget _buildActiveFiltersBar() {
    final hasActiveFilters = _selectedCity != null ||
        _selectedLocationType != null ||
        _isPaid != null ||
        _selectedDuration != null;
    // If no filters are active, show nothing.
    if (!hasActiveFilters) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          if (_selectedCity != null && _selectedCity!.isNotEmpty)
            Chip(
                label: Text('City: $_selectedCity'),
                onDeleted: () {
                  setState(() => _selectedCity = null);
                  _cityController.clear();
                  _fetchOpportunities();
                }),
          if (_selectedLocationType != null)
            Chip(
                label: Text(_selectedLocationType!.capitalize()),
                onDeleted: () {
                  setState(() => _selectedLocationType = null);
                  _fetchOpportunities();
                }),
          if (_isPaid != null)
            Chip(
                label: Text(_isPaid! ? 'Paid' : 'Unpaid'),
                backgroundColor:
                    _isPaid! ? Colors.green.shade100 : Colors.orange.shade100,
                onDeleted: () {
                  setState(() => _isPaid = null);
                  _fetchOpportunities();
                }),
          if (_selectedDuration != null)
            Chip(
                label: Text(_selectedDuration!),
                onDeleted: () {
                  setState(() => _selectedDuration = null);
                  _fetchOpportunities();
                }),
        ],
      ),
    );
  }

  // A helper widget for showing date info in the opportunity card.
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

  // A helper widget for building info tiles in the detail view.
  Widget _buildInfoTile(
      {required IconData icon,
      required String title,
      required String value,
      Color? valueColor}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF422F5D)),
        title: Text(title,
            style: GoogleFonts.lato(
                fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        subtitle: Text(value,
            style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ??
                    Theme.of(context).textTheme.bodyLarge!.color)),
      ),
    );
  }

  // A generic builder for sections in the detail view (e.g., "Description", "Skills").
  Widget _buildDetailSection({required String title, required Widget content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF422F5D))),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  // Helper to display a list of strings as chips (for skills).
  Widget _buildChipList(List<String> items) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: items
          .map((item) => Chip(
                label: Text(item),
                backgroundColor: const Color(0xFF422F5D).withOpacity(0.1),
                labelStyle: const TextStyle(
                    color: Color(0xFF422F5D), fontWeight: FontWeight.w600),
              ))
          .toList(),
    );
  }

  // Helper to display a list of strings as a bulleted list (for requirements).
  Widget _buildRequirementList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((req) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(req,
                            style: GoogleFonts.lato(fontSize: 15, height: 1.5))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // Builds the "More Info" card in the detail view.
  Widget _buildMoreInfo(Opportunity opportunity) {
    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Column(children: [
          _buildMoreInfoRow(Icons.badge_outlined, 'Type', opportunity.type),
          if (opportunity.preferredMajor != null)
            _buildMoreInfoRow(Icons.school_outlined, 'Preferred Major',
                opportunity.preferredMajor!),
          _buildMoreInfoRow(Icons.attach_money_outlined, 'Payment',
              opportunity.isPaid ? 'Paid' : 'Unpaid'),
        ]));
  }

  // Helper for _buildMoreInfo.
  Widget _buildMoreInfoRow(IconData icon, String title, String value) =>
      ListTile(
        leading: Icon(icon, color: Colors.grey.shade600),
        title: Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
        trailing: Text(value,
            style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w500)),
      );

  // Helper to get the correct color for each application status.
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

  // Helper to build the status chip with the correct color.
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

  // Widget to show when the list is empty.
  Widget _buildEmptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.search_off, size: 80, color: Colors.grey),
      const SizedBox(height: 16),
      Text('No Opportunities Found',
          style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Try adjusting your search or filters.',
          style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      ElevatedButton(
          onPressed: _resetAllFilters,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF422F5D),
              foregroundColor: Colors.white),
          child: const Text('Clear All Filters'))
    ]));
  }

  // Widget to show when an error occurs.
  Widget _buildErrorWidget() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        Text('Something Went Wrong',
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_errorMessage ?? "We couldn't load opportunities.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: _loadInitialData, child: const Text('Try Again'))
      ]),
    ));
  }

  // --- 8. DATA FETCHING & STATE LOGIC ---

  // Loads the student's ID first, then fetches opportunities.
  Future<void> _loadInitialData() async {
    setState(() => _state = ScreenState.initialLoading);
    try {
      // Get the current student's data from the auth service.
      final student = await _authService.getCurrentStudent();
      if (!mounted) return; // Check if the widget is still on screen
      if (student != null) {
        setState(() => _studentId = student.id); // Save the student ID
        await _fetchOpportunities(); // Now, fetch the opportunities
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

  // This is called every time the text in the search bar changes.
  void _onSearchChanged() {
    // Use a "debounce" to wait 500ms after the user stops typing
    // This prevents searching on every single keystroke, saving resources.
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchOpportunities);
  }

  // Main function to fetch opportunities from the service and apply filters.
  Future<void> _fetchOpportunities() async {
    // Set state to loading, unless it's the very first load.
    if (_state != ScreenState.initialLoading) {
      setState(() => _state = ScreenState.loading);
    }
    try {
      // 1. Fetch ALL opportunities from the service.
      // We pass 'null' to get all of them and filter on the app side.
      final opportunities = await _opportunityService.getOpportunities(
          searchQuery: null,
          type: null,
          city: null,
          locationType: null,
          isPaid: null);

      // 2. Apply local filters (search, type, city, etc.)
      final query = _searchController.text.toLowerCase();
      final filtered = opportunities.where((opp) {
        // Check Type Filter
        final matchesType =
            _activeTypeFilter == 'All' || opp.type == _activeTypeFilter;
        // Check Search Query (matches role or name)
        final matchesSearch = query.isEmpty ||
            opp.role.toLowerCase().contains(query) ||
            opp.name.toLowerCase().contains(query);
        // Check City Filter
        final matchesCity = _selectedCity == null ||
            (opp.location?.toLowerCase() == _selectedCity?.toLowerCase());
        // Check Location Type Filter
        final matchesLocation = _selectedLocationType == null ||
            (opp.workMode?.toLowerCase() ==
                _selectedLocationType?.toLowerCase());
        // Check Payment Filter
        final matchesPaid = _isPaid == null || (opp.isPaid == _isPaid);
        // Check Duration Filter
        final durationCategory =
            getDurationCategory(opp.startDate, opp.endDate);
        final matchesDuration =
            _selectedDuration == null || durationCategory == _selectedDuration;

        // Return true only if ALL filters match
        return matchesType &&
            matchesSearch &&
            matchesCity &&
            matchesLocation &&
            matchesPaid &&
            matchesDuration;
      }).toList();

      // 3. Update the UI with the filtered list
      if (mounted) {
        setState(() {
          _opportunities = filtered;
          // Set state to 'empty' if the list is empty, otherwise 'success'.
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

  // Helper function to categorize opportunity duration for filtering.
  String getDurationCategory(dynamic start, dynamic end) {
    if (start == null || end == null) return "Unknown";
    // Convert Firestore Timestamp or DateTime to DateTime
    final DateTime startDate =
        start is DateTime ? start : (start as dynamic).toDate();
    final DateTime endDate = end is DateTime ? end : (end as dynamic).toDate();
    final durationDays = endDate.difference(startDate).inDays;

    if (durationDays < 30) return "less than a month";
    if (durationDays >= 30 && durationDays < 90) return "1-3 months";
    if (durationDays >= 90 && durationDays < 180) return "3-6 months";
    return "more than 6 months";
  }

  // Resets all filters and re-fetches the list.
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

  // --- 9. USER ACTIONS & NAVIGATION ---

  // Switches the view to show details for a specific opportunity.
  void _viewOpportunityDetails(Opportunity opportunity) async {
    setState(() {
      _selectedOpportunity = opportunity; // Set the selected opportunity
      _currentApplication = null; // Clear old application data
      _isApplying = false; // Reset applying state
    });

    // After switching, fetch the application status for this specific opportunity.
    final app = await _applicationService.getApplicationForOpportunity(
      studentId: _studentId!,
      opportunityId: opportunity.id,
    );

    // Update the state with the fetched application
    if (mounted) {
      setState(() {
        _currentApplication = app;
      });
    }
  }

  // Switches the view back to the main list.
  void _showOpportunityList() {
    setState(() {
      _selectedOpportunity = null; // Clear the selected opportunity
    });
  }

  // Handles the phone's physical back button press.
  Future<bool> _onBackPressed() {
    if (_selectedOpportunity != null) {
      // If on the detail view, go back to the list view.
      _showOpportunityList();
      return Future.value(false); // Do not pop the page (exit the app)
    }
    // If on the list view, allow the page to be popped (exit the app).
    return Future.value(true);
  }

  // Handles the "Apply Now" button press, including the confirmation dialog.
  Future<void> _applyNow() async {
    if (_selectedOpportunity == null || _studentId == null) return;

    // Show a confirmation dialog first.
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Application'),
        content: Text(
            'Are you sure you want to apply for the role of ${_selectedOpportunity!.role}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF422F5D)),
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return; // User pressed "Cancel"

    setState(() => _isApplying = true); // Show loading indicator on button
    try {
      // Call the service to submit the application
      await _applicationService.submitApplication(
        studentId: _studentId!,
        opportunityId: _selectedOpportunity!.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green));
        // Refresh the detail view to show the new "Withdraw" button
        _viewOpportunityDetails(_selectedOpportunity!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red));
        setState(() => _isApplying = false); // Stop loading
      }
    }
  }

  // Handles the "Withdraw" button press, including the confirmation dialog.
  Future<void> _withdrawApplication() async {
    if (_currentApplication == null) return;

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
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
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Call the service to withdraw the application
        await _applicationService.withdrawApplication(
            applicationId: _currentApplication!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Application withdrawn.'),
              backgroundColor: Colors.green));
          // Refresh the view to show the updated status
          _viewOpportunityDetails(_selectedOpportunity!);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  // Toggles the bookmark status for an opportunity.
  Future<void> _toggleBookmark(
      Opportunity opportunity, bool isCurrentlyBookmarked) async {
    if (_studentId == null || _studentId!.isEmpty) return;
    try {
      if (isCurrentlyBookmarked) {
        // If already bookmarked, remove it.
        await _bookmarkService.removeBookmark(
            studentId: _studentId!, opportunityId: opportunity.id);
      } else {
        // If not bookmarked, add it.
        await _bookmarkService.addBookmark(
            studentId: _studentId!, opportunityId: opportunity.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update bookmark.')));
      }
    }
  }

  // Navigates to the "Saved Opportunities" page.
  void _navigateToSaved() {
    if (_studentId != null)
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SavedstudentOppPgae(studentId: _studentId!)));
  }

  // Shows the filter bottom sheet.
  void _showFilterSheet() {
    _cityController.text = _selectedCity ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be tall
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // Use StatefulBuilder to manage the state *inside* the bottom sheet
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
                  labelStyle:
                      TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            );
          }

          // UI of the filter sheet
          return Padding(
            // Move padding up when keyboard appears
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters',
                    style: GoogleFonts.lato(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                // City Filter
                Text('City',
                    style: GoogleFonts.lato(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                        hintText: 'e.g., Riyadh',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 24),
                // Location Type Filter
                Text('Location Type',
                    style: GoogleFonts.lato(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildModalChips<String>(
                    options: ['remote', 'in-person', 'hybrid'],
                    selectedValue: _selectedLocationType,
                    labelBuilder: (s) => s.capitalize(),
                    onSelected: (value) =>
                        setModalState(() => _selectedLocationType = value)),
                const SizedBox(height: 24),
                // Payment Filter
                Text('Payment',
                    style: GoogleFonts.lato(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildModalChips<bool>(
                    options: [true, false],
                    selectedValue: _isPaid,
                    labelBuilder: (p) => p ? 'Paid' : 'Unpaid',
                    onSelected: (value) => setModalState(() => _isPaid = value)),
                const SizedBox(height: 24),
                // Duration Filter
                Text('Duration',
                    style: GoogleFonts.lato(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                buildModalChips<String>(
                    options: [
                      "less than a month",
                      "1-3 months",
                      "3-6 months",
                      "more than 6 months"
                    ],
                    selectedValue: _selectedDuration,
                    labelBuilder: (d) => d,
                    onSelected: (value) =>
                        setModalState(() => _selectedDuration = value)),
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
                            child: const Text('Clear'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF422F5D),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        // Apply filters to the main page state
                        setState(() => _selectedCity =
                            _cityController.text.trim().isEmpty
                                ? null
                                : _cityController.text.trim());
                        _fetchOpportunities(); // Re-fetch data
                        Navigator.pop(context); // Close the modal
                      },
                      child: const Text('Apply Filters'),
                    ))
                  ],
                ),
                const SizedBox(height: 16), // Padding at the very bottom
              ],
            ),
          );
        });
      },
    );
  }

  // Handles taps on the Bottom Navigation Bar.
  void _onNavigationTap(int index) {
    if (index == _currentIndex) return; // Do nothing if tapping the same tab
    switch (index) {
      case 0: // Home (Example)
      case 1: // Companies (Example)
        // Show a "coming soon" message for tabs that are not implemented.
        _showInfoMessage('Coming soon!');
        break;
      case 3: // Profile
        // Navigate to the Profile page
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const StudentViewProfile()));
        break;
    }
  }

  // Shows a simple message at the bottom of the screen (SnackBar).
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

// --- 10. UTILITY EXTENSIONS ---

// A helper "extension" on the String class to add a .capitalize() function.
// e.g., "hello".capitalize() -> "Hello"
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}