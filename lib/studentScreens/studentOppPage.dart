// lib/studentScreens/studentOppPage.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/application.dart';
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
  // Services
  final OpportunityService _opportunityService = OpportunityService();
  final AuthService _authService = AuthService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ApplicationService _applicationService = ApplicationService();

  // State variables
  List<Opportunity> _opportunities = [];
  Map<String, Company> _companyCache = {};
  ScreenState _state = ScreenState.initialLoading;
  String? _errorMessage;
  String? _studentId;
  int _currentIndex = 2;

  // In-page detail view state
  Opportunity? _selectedOpportunity;
  Application? _currentApplication;
  bool _isApplying = false;

  // Controllers
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  Timer? _debounce;

  // Filter state variables
  String _activeTypeFilter = 'All';
  String? _selectedCity;
  String? _selectedLocationType;
  bool? _isPaid;
  String? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- Data Fetching & State Logic ---

  Future<void> _loadInitialData() async {
    setState(() => _state = ScreenState.initialLoading);
    try {
      final student = await _authService.getCurrentStudent();
      if (!mounted) return;
      if (student != null) {
        setState(() => _studentId = student.id);
        await _fetchOpportunities();
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

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetchOpportunities);
  }

  Future<void> _fetchOpportunities() async {
    if (_state != ScreenState.initialLoading) {
      setState(() => _state = ScreenState.loading);
    }
    try {
      final opportunities = await _opportunityService.getOpportunities(
        searchQuery: null,
        type: null,
        city: null,
        locationType: null,
        isPaid: null,
      );

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
          _companyCache = {
            for (var doc in companyDocs.docs)
              doc.id: Company.fromFirestore(doc),
          };
        }
      }

      final query = _searchController.text.toLowerCase();
      final filtered = opportunities.where((opp) {
        final matchesType =
            _activeTypeFilter == 'All' || opp.type == _activeTypeFilter;

        final company = _companyCache[opp.companyId];
        final companyNameMatch =
            company?.companyName.toLowerCase().contains(query) ?? false;
        final matchesSearch =
            query.isEmpty ||
            opp.role.toLowerCase().contains(query) ||
            opp.name.toLowerCase().contains(query) ||
            companyNameMatch;

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

        return matchesType &&
            matchesSearch &&
            matchesCity &&
            matchesLocation &&
            matchesPaid &&
            matchesDuration;
      }).toList();

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

  String getDurationCategory(dynamic start, dynamic end) {
    if (start == null || end == null) return "Unknown";
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

  // --- In-Page View Switching & Navigation ---

  void _viewOpportunityDetails(Opportunity opportunity) async {
    setState(() {
      _selectedOpportunity = opportunity;
      _currentApplication = null;
      _isApplying = false;
    });
    final app = await _applicationService.getApplicationForOpportunity(
      studentId: _studentId!,
      opportunityId: opportunity.id,
    );
    if (mounted) {
      setState(() {
        _currentApplication = app;
      });
    }
  }

  void _showOpportunityList() {
    setState(() {
      _selectedOpportunity = null;
    });
  }

  Future<bool> _onBackPressed() {
    if (_selectedOpportunity != null) {
      _showOpportunityList();
      return Future.value(false);
    }
    return Future.value(true);
  }

  void _navigateToCompanyProfile(String companyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCompanyProfilePage(companyId: companyId),
      ),
    );
  }

  // --- Application Logic ---

  Future<void> _applyNow() async {
    if (_selectedOpportunity == null || _studentId == null) return;

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

    if (confirm != true) return;

    setState(() => _isApplying = true);
    try {
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
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _withdrawApplication() async {
    if (_currentApplication == null) return;

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

  // --- Main Build Method & UI ---

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: _buildPageContent(),
        bottomNavigationBar: _selectedOpportunity == null
            ? CustomBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onNavigationTap,
              )
            : null,
        bottomSheet: _selectedOpportunity != null
            ? _buildActionBottomSheet()
            : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectedOpportunity == null) {
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
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: _navigateToSaved,
            tooltip: 'Saved',
          ),
        ],
      );
    } else {
      return AppBar(
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

  Widget _buildPageContent() {
    if (_selectedOpportunity == null) {
      return _buildListView();
    } else {
      return _buildOpportunityDetailsView(_selectedOpportunity!);
    }
  }

  Widget _buildListView() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildTypeFilterChips(),
        _buildActiveFiltersBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

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
        onTap: () => _viewOpportunityDetails(opportunity),
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            (snapshot.data?.logoUrl != null &&
                                snapshot.data!.logoUrl!.isNotEmpty)
                            ? NetworkImage(snapshot.data!.logoUrl!)
                            : null,
                        child:
                            (snapshot.data?.logoUrl == null ||
                                snapshot.data!.logoUrl!.isEmpty)
                            ? const Icon(Icons.business, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opportunity.role,
                              style: GoogleFonts.lato(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                  // Show response deadline in the card when company enabled visibility
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
            if (opportunity.skills != null && opportunity.skills!.isNotEmpty)
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
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBottomSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
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
      child: _currentApplication != null
          ? _buildStatusAndWithdrawView()
          : _buildApplyNowView(),
    );
  }

  Widget _buildApplyNowView() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isApplying ? null : _applyNow,
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

  Widget _buildStatusAndWithdrawView() {
    final status = _currentApplication!.status;
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
            _buildStatusChip(status),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: canWithdraw ? _withdrawApplication : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canWithdraw ? Colors.red.shade700 : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              canWithdraw ? 'Withdraw' : 'Finalized',
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
                  backgroundImage:
                      (snapshot.data?.logoUrl != null &&
                          snapshot.data!.logoUrl!.isNotEmpty)
                      ? NetworkImage(snapshot.data!.logoUrl!)
                      : null,
                  child:
                      (snapshot.data?.logoUrl == null ||
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
                _fetchOpportunities();
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

  Widget _buildActiveFiltersBar() {
    final hasActiveFilters =
        _selectedCity != null ||
        _selectedLocationType != null ||
        _isPaid != null ||
        _selectedDuration != null;
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

  Widget _buildContent() {
    switch (_state) {
      case ScreenState.initialLoading:
      case ScreenState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF422F5D)),
        );
      case ScreenState.error:
        return _buildErrorWidget();
      case ScreenState.empty:
        return _buildEmptyState();
      case ScreenState.success:
        return RefreshIndicator(
          onRefresh: _fetchOpportunities,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: _opportunities.length,
            itemBuilder: (context, index) =>
                _buildOpportunityCard(_opportunities[index]),
          ),
        );
    }
  }

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

  void _navigateToSaved() {
    if (_studentId != null)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedstudentOppPgae(studentId: _studentId!),
        ),
      );
  }

  void _showFilterSheet() {
    _cityController.text = _selectedCity ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModalState(() {
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
                            setState(
                              () => _selectedCity =
                                  _cityController.text.trim().isEmpty
                                  ? null
                                  : _cityController.text.trim(),
                            );
                            _fetchOpportunities();
                            Navigator.pop(context);
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

  Future<void> _toggleBookmark(
    Opportunity opportunity,
    bool isCurrentlyBookmarked,
  ) async {
    if (_studentId == null || _studentId!.isEmpty) return;
    try {
      if (isCurrentlyBookmarked) {
        await _bookmarkService.removeBookmark(
          studentId: _studentId!,
          opportunityId: opportunity.id,
        );
      } else {
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

  void _onNavigationTap(int index) {
    if (index == _currentIndex) return;
    switch (index) {
      case 0:
        _showInfoMessage('Coming soon!');
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentCompaniesPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewProfile()),
        );
        break;
    }
  }

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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
