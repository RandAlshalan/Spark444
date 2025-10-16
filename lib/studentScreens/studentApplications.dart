import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import '../studentScreens/studentCompanyProfilePage.dart'; // Import for navigation

// --- Color Constants ---
const Color _sparkPrimaryPurple = Color(0xFF422F5D);
const Color _profileBackgroundColor = Color(0xFFF8F9FA);
const Color _profileTextColor = Color(0xFF1E1E1E);

class StudentApplicationsScreen extends StatefulWidget {
  final String studentId;

  const StudentApplicationsScreen({super.key, required this.studentId});

  @override
  State<StudentApplicationsScreen> createState() =>
      _StudentApplicationsScreenState();
}

class _StudentApplicationsScreenState extends State<StudentApplicationsScreen> {
  final ApplicationService _applicationService = ApplicationService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // State variables for managing UI and data
  bool _isLoading = true;
  List<Application> _allApplications = [];
  List<Application> _filteredApplications = [];
  Map<String, Opportunity> _opportunityDetailsCache = {};
  Map<String, Company> _companyDetailsCache = {};

  Application? _selectedApplication;
  String _activeStatusFilter = 'All';

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'In Progress',
    'Accepted',
    'Rejected',
    'Withdrawn',
    'Draft'
  ];

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('studentId', isEqualTo: widget.studentId)
          .orderBy('appliedDate', descending: true)
          .get();

      final applications = querySnapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();

      if (applications.isNotEmpty) {
        final opportunityIds =
            applications.map((app) => app.opportunityId).toSet().toList();
        final oppDocs = await FirebaseFirestore.instance
            .collection('opportunities')
            .where(FieldPath.documentId, whereIn: opportunityIds)
            .get();
        _opportunityDetailsCache = {
          for (var doc in oppDocs.docs) doc.id: Opportunity.fromFirestore(doc)
        };
      }

      if (_opportunityDetailsCache.isNotEmpty) {
        final companyIds = _opportunityDetailsCache.values
            .map((opp) => opp.companyId)
            .toSet()
            .toList();
        if (companyIds.isNotEmpty) {
          final companyDocs = await FirebaseFirestore.instance
              .collection('companies')
              .where(FieldPath.documentId, whereIn: companyIds)
              .get();
          _companyDetailsCache = {
            for (var doc in companyDocs.docs) doc.id: Company.fromFirestore(doc)
          };
        }
      }

      if (mounted) {
        setState(() {
          _allApplications = applications;
          _isLoading = false;
        });
        _filterApplications();
      }
    } catch (e) {
      debugPrint("Error fetching applications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _filterApplications);
  }

  void _filterApplications() {
    List<Application> results = List.from(_allApplications);
    final query = _searchController.text.toLowerCase();

    if (_activeStatusFilter != 'All') {
      results = results.where((app) {
        final status = app.status.toLowerCase();
        final filter = _activeStatusFilter.toLowerCase();

        if (filter == 'pending') {
          return status == 'pending';
        }
        if (filter == 'in progress') {
          return status == 'reviewed';
        }
        if (filter == 'accepted') {
          return status == 'accepted';
        }
        return status == filter;
      }).toList();
    }

    if (query.isNotEmpty) {
      results = results.where((app) {
        final opportunity = _opportunityDetailsCache[app.opportunityId];
        if (opportunity == null) return false;
        
        final company = _companyDetailsCache[opportunity.companyId];
        final bool roleMatch = opportunity.role.toLowerCase().contains(query);
        final bool companyMatch =
            company?.companyName.toLowerCase().contains(query) ?? false;

        return roleMatch || companyMatch;
      }).toList();
    }

    setState(() => _filteredApplications = results);
  }

  void _viewApplicationDetails(Application application) {
    setState(() => _selectedApplication = application);
  }

  void _showApplicationList() {
    setState(() => _selectedApplication = null);
  }
  
  void _navigateToCompanyProfile(String companyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCompanyProfilePage(companyId: companyId),
      ),
    );
  }

  Future<void> _withdrawApplication(Application application) async {
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
        _showApplicationList();
        _loadApplications();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteApplicationPermanently(Application application) async {
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
        await _applicationService.deleteApplication(
            applicationId: application.id);

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

  Future<bool> _onBackPressed() {
    if (_selectedApplication != null) {
      _showApplicationList();
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        backgroundColor: _profileBackgroundColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: _selectedApplication != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _showApplicationList)
          : null,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _sparkPrimaryPurple));
    }

    if (_allApplications.isEmpty) return _buildEmptyState();

    if (_selectedApplication != null) {
      return _buildDetailView(_selectedApplication!);
    } else {
      return _buildListView();
    }
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _loadApplications,
      color: _sparkPrimaryPurple,
      child: Column(
        children: [
          _buildSearchBar(),
          _buildFilterButtons(),
          Expanded(
            child: _filteredApplications.isEmpty
                ? const Center(
                    child: Text('No applications match your criteria.'))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredApplications.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApplications[index];
                      final opp = _opportunityDetailsCache[app.opportunityId];
                      if (opp == null) return const SizedBox.shrink();

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
          final color = _getFilterColor(status);

          return ElevatedButton(
            onPressed: () {
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

  Widget _buildDetailView(Application application) {
    final opportunity = _opportunityDetailsCache[application.opportunityId];
    if (opportunity == null) {
      return const Center(child: Text('Could not load opportunity details.'));
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailHeader(opportunity),
                const SizedBox(height: 24),
                _buildDetailSection(
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
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(application.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoTile(
                        icon: Icons.event_note_outlined,
                        title: 'Applied On',
                        value: DateFormat('MMMM d, yyyy')
                            .format(application.appliedDate.toDate()),
                      ),
                    ],
                  ),
                ),
                _buildDetailKeyInfoSection(opportunity),
                const SizedBox(height: 24),
                if (opportunity.description != null &&
                    opportunity.description!.isNotEmpty)
                  _buildDetailSection(
                      title: 'Description',
                      content: Text(opportunity.description!,
                          style: GoogleFonts.lato(
                              height: 1.6,
                              fontSize: 15,
                              color: Colors.black87))),
                if (opportunity.skills != null && opportunity.skills!.isNotEmpty)
                  _buildDetailSection(
                      title: 'Key Skills',
                      content: _buildChipList(opportunity.skills!)),
                if (opportunity.requirements != null &&
                    opportunity.requirements!.isNotEmpty)
                  _buildDetailSection(
                      title: 'Requirements',
                      content: _buildRequirementList(opportunity.requirements!)),
                _buildDetailSection(
                    title: 'More Info', content: _buildMoreInfo(opportunity)),
              ],
            ),
          ),
        ),
        if (application.status.toLowerCase() == 'pending' ||
            application.status.toLowerCase() == 'reviewed')
          _buildWithdrawButton(application),
      ],
    );
  }

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

  Widget _buildDetailHeader(Opportunity opportunity) {
    return InkWell(
      onTap: () => _navigateToCompanyProfile(opportunity.companyId),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<Company?>(
            future: _authService.getCompany(opportunity.companyId),
            builder: (context, snapshot) {
              return Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: (snapshot.data?.logoUrl != null && snapshot.data!.logoUrl!.isNotEmpty)
                        ? NetworkImage(snapshot.data!.logoUrl!)
                        : null,
                    child: (snapshot.data?.logoUrl == null || snapshot.data!.logoUrl!.isEmpty)
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
                              color: _sparkPrimaryPurple),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          snapshot.data?.companyName ?? 'Loading...',
                          style: GoogleFonts.lato(
                              fontSize: 16, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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
        leading: Icon(icon, color: _sparkPrimaryPurple),
        title: Text(title,
            style: GoogleFonts.lato(
                fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        subtitle: Text(value,
            style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? _profileTextColor)),
      ),
    );
  }

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
                  color: _sparkPrimaryPurple)),
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
          .map((item) => Chip(
                label: Text(item),
                backgroundColor: _sparkPrimaryPurple.withOpacity(0.1),
                labelStyle: const TextStyle(
                    color: _sparkPrimaryPurple, fontWeight: FontWeight.w600),
              ))
          .toList(),
    );
  }

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

  Widget _buildMoreInfoRow(IconData icon, String title, String value) =>
      ListTile(
        leading: Icon(icon, color: Colors.grey.shade600),
        title: Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
        trailing: Text(value,
            style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w500)),
      );

  Widget _buildWithdrawButton(Application application) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _profileBackgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _withdrawApplication(application),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Withdraw Application'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'All':
        return _sparkPrimaryPurple;
      case 'Pending':
        return _getStatusColor('pending');
      case 'In Progress':
        return _getStatusColor('reviewed');
      case 'Accepted':
        return _getStatusColor('accepted');
      case 'Rejected':
        return _getStatusColor('rejected');
      case 'Withdrawn':
        return _getStatusColor('withdrawn');
      case 'Draft':
        return Colors.blueGrey;
      default:
        return _sparkPrimaryPurple;
    }
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
}

class _ApplicationCard extends StatelessWidget {
  final Application application;
  final Opportunity opportunity;
  final VoidCallback onViewMore;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;
  final bool isDetailView;
  final AuthService _authService = AuthService();

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
            _buildHeader(context, opportunity),
            const SizedBox(height: 12),
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
            if (!isDetailView) ...[
              const Padding(
                  padding: EdgeInsets.only(top: 12.0), child: Divider()),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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

  Widget _buildHeader(BuildContext context, Opportunity opportunity) {
    return FutureBuilder<Company?>(
      future: _authService.getCompany(opportunity.companyId),
      builder: (context, snapshot) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusChip(application.status),
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
        status.capitalize(),
        style: GoogleFonts.lato(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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