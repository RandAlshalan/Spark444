import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/applicationService.dart';
import 'StudentCompanyProfilePage.dart';

class StudentApplicationsScreen extends StatefulWidget {
  const StudentApplicationsScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentApplicationsScreen> createState() =>
      _StudentApplicationsScreenState();
}

class _StudentApplicationsScreenState
    extends State<StudentApplicationsScreen> {
  final ApplicationService _applicationService = ApplicationService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  String _activeStatus = 'All';

  final List<String> _statusFilters = <String>[
    'All',
    'Pending',
    'Reviewed',
    'Accepted',
    'Hired',
    'Rejected',
    'Withdrawn',
  ];

  List<Application> _applications = <Application>[];
  List<Application> _filteredApplications = <Application>[];

  final Map<String, Opportunity> _opportunityCache = <String, Opportunity>{};
  final Map<String, Company> _companyCache = <String, Company>{};

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('studentId', isEqualTo: widget.studentId)
          .orderBy('appliedDate', descending: true)
          .get();

      final applications = snapshot.docs
          .map((doc) => Application.fromFirestore(doc))
          .toList();

      await _populateCaches(applications);

      setState(() {
        _applications = applications;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showMessage('Failed to load applications: $e');
    }
  }

  Future<void> _populateCaches(List<Application> applications) async {
    final opportunityIds = applications
        .map((app) => app.opportunityId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    _opportunityCache.clear();
    _companyCache.clear();

    const batchSize = 10;
    for (var i = 0; i < opportunityIds.length; i += batchSize) {
      final batch = opportunityIds.sublist(
        i,
        i + batchSize > opportunityIds.length
            ? opportunityIds.length
            : i + batchSize,
      );

      final oppSnapshot = await FirebaseFirestore.instance
          .collection('opportunities')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in oppSnapshot.docs) {
        _opportunityCache[doc.id] = Opportunity.fromFirestore(doc);
      }
    }

    final companyIds = _opportunityCache.values
        .map((opp) => opp.companyId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    for (var i = 0; i < companyIds.length; i += batchSize) {
      final batch = companyIds.sublist(
        i,
        i + batchSize > companyIds.length
            ? companyIds.length
            : i + batchSize,
      );

      final companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in companySnapshot.docs) {
        _companyCache[doc.id] = Company.fromFirestore(doc);
      }
    }
  }

  void _handleSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final statusFilter = _activeStatus.toLowerCase();

    final results = _applications.where((app) {
      final opportunity = _opportunityCache[app.opportunityId];
      final company =
          opportunity != null ? _companyCache[opportunity.companyId] : null;

      final matchesStatus = statusFilter == 'all'
          ? true
          : app.status.toLowerCase() == statusFilter;

      if (!matchesStatus) return false;

      if (query.isEmpty) return true;

      final role = opportunity?.role.toLowerCase() ?? '';
      final name = opportunity?.name.toLowerCase() ?? '';
      final companyName = company?.companyName.toLowerCase() ?? '';

      return role.contains(query) ||
          name.contains(query) ||
          companyName.contains(query);
    }).toList();

    setState(() => _filteredApplications = results);
  }

  Future<void> _withdrawApplication(Application application) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: const Text(
          'This will update the application status to "Withdrawn". '
          'You cannot undo this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _applicationService.withdrawApplication(
        applicationId: application.id,
      );
      _showMessage('Application withdrawn.');
      await _loadApplications();
    } catch (e) {
      _showMessage('Failed to withdraw application: $e');
    }
  }

  Future<void> _deleteApplication(Application application) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text(
          'This will permanently remove the application record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _applicationService.deleteApplication(
        applicationId: application.id,
      );
      _showMessage('Application deleted.');
      await _loadApplications();
    } catch (e) {
      _showMessage('Failed to delete application: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadApplications,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _applications.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildSearchBar(),
                      _buildStatusChips(),
                      Expanded(
                        child: _filteredApplications.isEmpty
                            ? _buildNoResultsState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                itemCount: _filteredApplications.length,
                                itemBuilder: (context, index) {
                                  final application =
                                      _filteredApplications[index];
                                  final opportunity = _opportunityCache[
                                      application.opportunityId];
                                  final company = opportunity == null
                                      ? null
                                      : _companyCache[opportunity.companyId];

                                  return _ApplicationCard(
                                    application: application,
                                    opportunity: opportunity,
                                    company: company,
                                    onViewCompany: company == null
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    StudentCompanyProfilePage(
                                                  companyId:
                                                      company.uid ?? opportunity?.companyId ?? '',
                                                ),
                                              ),
                                            ),
                                    onWithdraw: () =>
                                        _withdrawApplication(application),
                                    onDelete: () =>
                                        _deleteApplication(application),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by role or company…',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isSelected = status == _activeStatus;
          return ChoiceChip(
            label: Text(status),
            selected: isSelected,
            onSelected: (_) {
              setState(() => _activeStatus = status);
              _applyFilters();
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _statusFilters.length,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('No applications yet.'),
          SizedBox(height: 8),
          Text('Start applying to opportunities to see them here.'),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No applications match your filters.'),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.opportunity,
    required this.company,
    required this.onViewCompany,
    required this.onWithdraw,
    required this.onDelete,
  });

  final Application application;
  final Opportunity? opportunity;
  final Company? company;
  final VoidCallback? onViewCompany;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final role = opportunity?.role ?? 'Opportunity';
    final companyName = company?.companyName ?? 'Unknown company';
    final location = opportunity?.location ?? 'Location not specified';
    final appliedDate = DateFormat('MMM d, yyyy')
        .format(application.appliedDate.toDate());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role,
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyName,
                        style: GoogleFonts.lato(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: application.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event_available_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Applied on $appliedDate'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 6),
                Text(location),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (onViewCompany != null)
                  OutlinedButton.icon(
                    onPressed: onViewCompany,
                    icon: const Icon(Icons.business),
                    label: const Text('View company'),
                  ),
                if (_canWithdraw(application.status))
                  ElevatedButton.icon(
                    onPressed: onWithdraw,
                    icon: const Icon(Icons.undo),
                    label: const Text('Withdraw'),
                  ),
                if (_canDelete(application.status))
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canWithdraw(String status) {
    final lower = status.toLowerCase();
    return lower == 'pending' || lower == 'reviewed';
  }

  bool _canDelete(String status) {
    return status.toLowerCase() == 'withdrawn';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.capitalize(),
        style: GoogleFonts.lato(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  static Color _colorForStatus(String status) {
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
}

extension _StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
