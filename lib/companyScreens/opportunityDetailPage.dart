import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/Application.dart';
import '../models/company.dart';
import '../models/opportunity.dart';
import '../models/student.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import 'EditOpportunityPage.dart';
import 'allApplicantsPage.dart';
import 'company_theme.dart';

class OpportunityDetailPage extends StatefulWidget {
  final Opportunity opportunity;
  final VoidCallback onDelete;
  final VoidCallback? onUpdate;

  const OpportunityDetailPage({
    super.key,
    required this.opportunity,
    required this.onDelete,
    this.onUpdate,
  });

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _AcceptedApplicant {
  const _AcceptedApplicant({
    required this.application,
    required this.student,
  });

  final Application application;
  final Student student;
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  final ApplicationService _applicationService = ApplicationService();
  final AuthService _authService = AuthService();
  final OpportunityService _opportunityService = OpportunityService();
  Company? _company;
  bool _loadingAccepted = true;
  String? _acceptedError;
  List<_AcceptedApplicant> _acceptedApplicants = [];
  int _totalApplicants = 0;
  int _pendingApplicants = 0;
  Opportunity? _currentOpportunity;

  @override
  void initState() {
    super.initState();
    _currentOpportunity = widget.opportunity;
    _loadCompany();
    _loadAcceptedApplicants();
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CompanyColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStatCard(
                  icon: Icons.people_alt_outlined,
                  label: 'Total Applicants',
                  value: _totalApplicants.toString(),
                  backgroundColor: CompanyColors.primary.withOpacity(0.1),
                  iconColor: CompanyColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryStatCard(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Pending Applicants',
                  value: _pendingApplicants.toString(),
                  backgroundColor: CompanyColors.secondary.withOpacity(0.12),
                  iconColor: CompanyColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadCompany() async {
    final company = await _authService.getCurrentCompany();
    if (mounted) {
      setState(() {
        _company = company;
      });
    }
  }

  Future<void> _reloadOpportunity() async {
    try {
      final opportunities = await _opportunityService.getCompanyOpportunities(
        widget.opportunity.companyId,
      );
      final updatedOpportunity = opportunities.firstWhere(
        (opp) => opp.id == widget.opportunity.id,
        orElse: () => widget.opportunity,
      );

      if (mounted) {
        setState(() {
          _currentOpportunity = updatedOpportunity;
        });
      }
    } catch (e) {
      debugPrint('Error reloading opportunity: $e');
    }
  }

  Future<void> _loadAcceptedApplicants() async {
    if (mounted) {
      setState(() {
        _loadingAccepted = true;
        _acceptedError = null;
      });
    }
    try {
      final opportunityId = _currentOpportunity?.id ?? widget.opportunity.id;
      final applications = await _applicationService
          .getApplicationsForOpportunity(opportunityId);
      if (mounted) {
        setState(() {
          // Exclude withdrawn applicants from total count
          _totalApplicants = applications
              .where((application) =>
                  application.status.toLowerCase() != 'withdrawn')
              .length;
          _pendingApplicants = applications
              .where((application) =>
                  application.status.toLowerCase() == 'pending')
              .length;
        });
      }
      final relevant = applications.where((application) {
        final status = application.status.toLowerCase();
        return status == 'accepted' || status == 'hired';
      }).toList();

      if (relevant.isEmpty) {
        if (!mounted) return;
        setState(() {
          _acceptedApplicants = <_AcceptedApplicant>[];
          _loadingAccepted = false;
        });
        return;
      }

      final results = await Future.wait(
        relevant.map((_application) async {
          final student = await _authService.getStudent(_application.studentId);
          if (student == null) return null;
          return _AcceptedApplicant(
            application: _application,
            student: student,
          );
        }),
      );

      final accepted = results.whereType<_AcceptedApplicant>().toList()
        ..sort(
          (a, b) => _acceptedDate(b.application)
              .compareTo(_acceptedDate(a.application)),
        );

      if (!mounted) return;
      setState(() {
        _acceptedApplicants = accepted;
        _loadingAccepted = false;
      });
    } catch (e) {
      debugPrint('Error loading accepted applicants: $e');
      if (!mounted) return;
      setState(() {
        _acceptedError = 'Could not load accepted applicants.';
        _acceptedApplicants = <_AcceptedApplicant>[];
        _loadingAccepted = false;
      });
    }
  }

  DateTime _acceptedDate(Application application) {
    final timestamp =
        application.lastStatusUpdateDate ?? application.appliedDate;
    return timestamp.toDate();
  }

  @override
  Widget build(BuildContext context) {
    final opportunity = _currentOpportunity ?? widget.opportunity;
    final postedDate = opportunity.postedDate?.toDate();
    final postedLabel = postedDate != null
        ? DateFormat('MMM d, yyyy').format(postedDate)
        : 'Date not available';

    return Scaffold(
      backgroundColor: CompanyColors.background,
      appBar: AppBar(
        backgroundColor: CompanyColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Opportunity Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Opportunity',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditOpportunityPage(opportunity: _currentOpportunity ?? opportunity),
                ),
              );

              // Only update if the edit was successful
              if (result == true) {
                await _reloadOpportunity();
                if (widget.onUpdate != null) {
                  widget.onUpdate!();
                }
                _loadAcceptedApplicants();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Opportunity',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(opportunity, postedLabel),
            _buildSummaryCard(),
            _buildDetailsSection(opportunity),
            _buildAcceptedApplicantsSection(),
            _buildApplicantsButton(context, opportunity),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Opportunity opportunity, String postedLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: CompanyColors.heroGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Posted $postedLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            opportunity.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            opportunity.role,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(opportunity.type, Icons.work_outline),
              if (opportunity.workMode != null && opportunity.workMode!.isNotEmpty)
                _buildChip(opportunity.workMode!, Icons.apartment_outlined),
              if (opportunity.location != null && opportunity.location!.isNotEmpty)
                _buildChip(opportunity.location!, Icons.location_on_outlined),
              _buildChip(
                opportunity.isPaid ? 'Paid' : 'Unpaid',
                opportunity.isPaid
                    ? Icons.payments_outlined
                    : Icons.volunteer_activism_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Opportunity opportunity) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CompanyColors.surface,
        borderRadius: CompanySpacing.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: CompanyColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Preferred Major
          if (opportunity.preferredMajor != null && opportunity.preferredMajor!.isNotEmpty) ...[
            _buildDetailRow(
              'Preferred Major',
              opportunity.preferredMajor!,
              Icons.school_outlined,
            ),
            const SizedBox(height: 12),
          ],

          // Opportunity Duration
          if (opportunity.startDate != null && opportunity.endDate != null) ...[
            _buildDetailRow(
              'Opportunity Duration',
              '${DateFormat('MMM d, yyyy').format(opportunity.startDate!.toDate())} - ${DateFormat('MMM d, yyyy').format(opportunity.endDate!.toDate())}',
              Icons.date_range,
            ),
            const SizedBox(height: 12),
          ],

          // Application Period
          if (opportunity.applicationOpenDate != null && opportunity.applicationDeadline != null) ...[
            _buildDetailRow(
              'Application Period',
              '${DateFormat('MMM d, yyyy').format(opportunity.applicationOpenDate!.toDate())} - ${DateFormat('MMM d, yyyy').format(opportunity.applicationDeadline!.toDate())}',
              Icons.app_registration,
            ),
            const SizedBox(height: 12),
          ],

          // Response Deadline
          if (opportunity.responseDeadline != null) ...[
            _buildDetailRow(
              'Response Deadline',
              DateFormat('MMM d, yyyy').format(opportunity.responseDeadline!.toDate()),
              Icons.schedule,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                opportunity.responseDeadlineVisible == true
                    ? 'Visible to students'
                    : 'Hidden from students',
                style: TextStyle(
                  fontSize: 12,
                  color: CompanyColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (opportunity.description != null && opportunity.description!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CompanyColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              opportunity.description!,
              style: const TextStyle(
                fontSize: 14,
                color: CompanyColors.muted,
                height: 1.5,
              ),
            ),
          ],
          if (opportunity.skills != null && opportunity.skills!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Required Skills',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CompanyColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: opportunity.skills!
                  .map((skill) => Chip(
                        label: Text(
                          skill,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CompanyColors.primary,
                          ),
                        ),
                        backgroundColor: CompanyColors.primary.withOpacity(0.12),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],
          if (opportunity.requirements != null && opportunity.requirements!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Requirements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CompanyColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...opportunity.requirements!.map((req) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: CompanyColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          req,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CompanyColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: CompanyColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: CompanyColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: CompanyColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptedApplicantsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CompanyColors.surface,
        borderRadius: CompanySpacing.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Accepted Applicants',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CompanyColors.primary,
                ),
              ),
              if (!_loadingAccepted && _acceptedError == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CompanyColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_acceptedApplicants.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: CompanyColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingAccepted)
            const Center(child: CircularProgressIndicator())
          else if (_acceptedError != null)
            Text(
              _acceptedError!,
              style: const TextStyle(color: Colors.redAccent),
            )
          else if (_acceptedApplicants.isEmpty)
            const Text(
              'No applicants have been accepted yet.',
              style: TextStyle(
                fontSize: 14,
                color: CompanyColors.muted,
              ),
            )
          else
            Column(
              children:
                  _acceptedApplicants.map(_buildAcceptedApplicantTile).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAcceptedApplicantTile(_AcceptedApplicant applicant) {
    final student = applicant.student;
    final fullName = '${student.firstName} ${student.lastName}'.trim();
    final displayName =
        fullName.isEmpty ? student.email : fullName.replaceAll(RegExp(r'\s+'), ' ');
    final acceptedOn = DateFormat('MMM d, yyyy')
        .format(_acceptedDate(applicant.application));
    final initials = _initialsForStudent(student);

    final phone = student.phoneNumber.trim();
    final university = student.university.trim();
    final major = student.major.trim();
    final level = (student.level ?? '').trim();

    final details = <Widget>[
      _buildInfoRow('Email', student.email, Icons.email_outlined),
      if (phone.isNotEmpty)
        _buildInfoRow('Phone', phone, Icons.phone_outlined),
      if (university.isNotEmpty)
        _buildInfoRow('University', university, Icons.school_outlined),
      if (major.isNotEmpty)
        _buildInfoRow('Major', major, Icons.badge_outlined),
      if (level.isNotEmpty)
        _buildInfoRow('Level', level, Icons.layers_outlined),
      if (student.gpa != null)
        _buildInfoRow(
          'GPA',
          student.gpa!.toStringAsFixed(2),
          Icons.assessment_outlined,
        ),
      _buildInfoRow('Accepted On', acceptedOn, Icons.calendar_today_outlined),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: CompanyColors.primary.withOpacity(0.12),
            foregroundColor: CompanyColors.primary,
            child: Text(initials.isEmpty ? '?' : initials),
          ),
          title: Text(
            displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: CompanyColors.primary,
            ),
          ),
          subtitle: Text(
            'Accepted on $acceptedOn',
            style: const TextStyle(
              fontSize: 12,
              color: CompanyColors.muted,
            ),
          ),
          children: details,
        ),
      ),
    );
  }

  String _initialsForStudent(Student student) {
    String initials = '';
    final first = student.firstName.trim();
    final last = student.lastName.trim();

    if (first.isNotEmpty) {
      initials += first[0].toUpperCase();
    }
    if (last.isNotEmpty) {
      initials += last[0].toUpperCase();
    }
    if (initials.isEmpty && student.email.isNotEmpty) {
      initials = student.email[0].toUpperCase();
    }
    return initials;
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: CompanyColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CompanyColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CompanyColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantsButton(BuildContext context, Opportunity opportunity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _company == null
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllApplicantsPage(
                      company: _company!,
                      opportunity: opportunity,
                    ),
                  ),
                );
                _loadAcceptedApplicants();
              },
        icon: const Icon(Icons.people_outline),
        label: const Text('View All Applicants'),
        style: ElevatedButton.styleFrom(
          backgroundColor: CompanyColors.secondary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    // Call the onDelete callback which handles confirmation in CompanyHomePage
    widget.onDelete();
    // Pop back to the previous screen after deletion
    // Note: Navigation happens in CompanyHomePage after successful deletion
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.iconColor,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: CompanyColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
