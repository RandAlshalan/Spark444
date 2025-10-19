import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/Application.dart';
import '../models/opportunity.dart';
import '../models/student.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import 'company_theme.dart';

class OpportunityAnalyticsPage extends StatefulWidget {
  final Opportunity opportunity;

  const OpportunityAnalyticsPage({super.key, required this.opportunity});

  @override
  State<OpportunityAnalyticsPage> createState() =>
      _OpportunityAnalyticsPageState();
}

class _OpportunityAnalyticsPageState extends State<OpportunityAnalyticsPage> {
  final ApplicationService _applicationService = ApplicationService();
  final AuthService _authService = AuthService();

  late Future<List<_ApplicantSnapshot>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadApplicants();
  }

  Future<List<_ApplicantSnapshot>> _loadApplicants() async {
    final List<Application> applications = await _applicationService
        .getApplicationsForOpportunity(widget.opportunity.id);

    final results = await Future.wait(
      applications.map(
        (application) async {
          final student =
              await _authService.getStudent(application.studentId);
          if (student == null) return null;
          return _ApplicantSnapshot(
            application: application,
            student: student,
          );
        },
      ),
    );

    return results.whereType<_ApplicantSnapshot>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: CompanyColors.surface,
        foregroundColor: CompanyColors.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opportunity Analytics',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              widget.opportunity.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: CompanyColors.secondary,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: CompanyDecorations.pageBackground,
        child: SafeArea(
          child: FutureBuilder<List<_ApplicantSnapshot>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildMessage(
                  icon: Icons.error_outline,
                  title: 'Could not load analytics.',
                  description: 'Please try again later.',
                  actionLabel: 'Retry',
                  onAction: () {
                    setState(() {
                      _future = _loadApplicants();
                    });
                  },
                );
              }

              final data = snapshot.data ?? const <_ApplicantSnapshot>[];
              if (data.isEmpty) {
                return _buildMessage(
                  icon: Icons.people_outline,
                  title: 'No applicants yet',
                  description:
                      'Students who apply to this opportunity will appear here.',
                );
              }

              final statusCounts = <String, int>{};
              for (final item in data) {
                statusCounts.update(
                  item.application.status,
                  (value) => value + 1,
                  ifAbsent: () => 1,
                );
              }

              return ListView(
                padding: CompanySpacing.pagePadding(context),
                children: [
                  _SummaryCard(
                    label: 'Total Applicants',
                    value: data.length.toString(),
                    icon: Icons.people_alt_outlined,
                  ),
                  const SizedBox(height: 16),
                  _StatusBreakdown(statusCounts: statusCounts),
                  const SizedBox(height: 16),
                  ...data.map(_ApplicantTile.new),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: CompanyColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: CompanyColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: CompanyColors.primary.withOpacity(0.12),
              child: Icon(icon, color: CompanyColors.primary),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: CompanyColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(color: CompanyColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final Map<String, int> statusCounts;

  const _StatusBreakdown({required this.statusCounts});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: statusCounts.entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CompanyColors.primary,
                        ),
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CompanyColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  final _ApplicantSnapshot snapshot;

  const _ApplicantTile(this.snapshot);

  @override
  Widget build(BuildContext context) {
    final appliedLabel = DateFormat('MMM d, yyyy • h:mm a')
        .format(snapshot.application.appliedDate.toDate());
    final student = snapshot.student;

    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student.firstName} ${student.lastName}'.trim().isEmpty
                  ? student.email
                  : '${student.firstName} ${student.lastName}'.trim(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.application.status,
              style: const TextStyle(color: CompanyColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              'Applied on $appliedLabel',
              style: const TextStyle(fontSize: 12, color: CompanyColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantSnapshot {
  final Application application;
  final Student student;

  const _ApplicantSnapshot({
    required this.application,
    required this.student,
  });
}
