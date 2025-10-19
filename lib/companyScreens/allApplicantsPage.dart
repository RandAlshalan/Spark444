import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/Application.dart' as app_model;
import '../models/company.dart';
import '../models/opportunity.dart';
import '../models/student.dart';
import '../services/applicationService.dart';
import '../services/authService.dart';
import '../services/opportunityService.dart';
import 'company_theme.dart';

const String _kNotSpecified = 'Not specified';

class AllApplicantsPage extends StatefulWidget {
  final Company company;
  final Opportunity? opportunity;

  const AllApplicantsPage({super.key, required this.company, this.opportunity});

  @override
  State<AllApplicantsPage> createState() => _AllApplicantsPageState();
}

class _AllApplicantsPageState extends State<AllApplicantsPage> {
  final OpportunityService _opportunityService = OpportunityService();
  final ApplicationService _applicationService = ApplicationService();
  final AuthService _authService = AuthService();

  late Future<_ApplicantsSnapshot> _applicantsFuture;
  static const String _kAll = 'All';

  String _selectedMajor = _kAll;
  String _selectedLevel = _kAll;
  RangeValues? _gpaRange;
  bool _gpaFilterEnabled = false;
  bool _filtersInitialized = false;

  @override
  void initState() {
    super.initState();
    _applicantsFuture = _loadApplicants();
  }

  Future<_ApplicantsSnapshot> _loadApplicants() async {
    final companyId = widget.company.uid;
    if (companyId == null || companyId.isEmpty) {
      return _ApplicantsSnapshot.empty;
    }

    final focusOpportunity = widget.opportunity;
    final List<Opportunity> opportunities;
    if (focusOpportunity != null) {
      opportunities = [focusOpportunity];
    } else {
      opportunities = await _opportunityService.getCompanyOpportunities(
        companyId,
      );
    }

    if (opportunities.isEmpty) {
      return _ApplicantsSnapshot.empty;
    }

    final acc = <_ApplicantRecord>[];
    final majorSet = <String>{};
    final levelSet = <String>{};
    double? minGpa;
    double? maxGpa;

    for (final opportunity in opportunities) {
      final applications = await _applicationService
          .getApplicationsForOpportunity(opportunity.id);

      if (applications.isEmpty) continue;

      final List<_ApplicantRecord> records = [];
      for (final app_model.Application applicationModel in applications) {
        final student =
            await _authService.getStudent(applicationModel.studentId);
        if (student == null) {
          continue;
        }
        records.add(
          _ApplicantRecord(
            application: applicationModel,
            student: student,
            opportunity: opportunity,
          ),
        );
      }

      if (records.isEmpty) continue;
      for (final record in records) {
        majorSet.add(_presentMajor(record.student));
        levelSet.add(_presentLevel(record.student));
        final gpa = record.student.gpa;
        if (gpa != null) {
          minGpa = minGpa == null ? gpa : math.min(minGpa!, gpa);
          maxGpa = maxGpa == null ? gpa : math.max(maxGpa!, gpa);
        }
      }

      acc.addAll(records);
    }

    acc.sort(
      (a, b) => b.application.appliedDate.compareTo(a.application.appliedDate),
    );

    return _ApplicantsSnapshot(
      records: acc,
      opportunityCount: opportunities.length,
      majors: _sortedOptions(majorSet),
      levels: _sortedOptions(levelSet),
      minGpa: minGpa,
      maxGpa: maxGpa,
    );
  }

  void _reload() {
    setState(() {
      _filtersInitialized = false;
      _selectedMajor = _kAll;
      _selectedLevel = _kAll;
      _gpaFilterEnabled = false;
      _gpaRange = null;
      _applicantsFuture = _loadApplicants();
    });
  }

  void _initializeFilters(_ApplicantsSnapshot data) {
    setState(() {
      _selectedMajor = _kAll;
      _selectedLevel = _kAll;
      _gpaFilterEnabled = false;
      _gpaRange = (data.minGpa != null && data.maxGpa != null)
          ? RangeValues(data.minGpa!, data.maxGpa!)
          : null;
      _filtersInitialized = true;
    });
  }

  void _resetFilters(_ApplicantsSnapshot data) {
    setState(() {
      _selectedMajor = _kAll;
      _selectedLevel = _kAll;
      _gpaFilterEnabled = false;
      _gpaRange = (data.minGpa != null && data.maxGpa != null)
          ? RangeValues(data.minGpa!, data.maxGpa!)
          : null;
    });
  }

  List<String> _sortedOptions(Set<String> source) {
    if (source.isEmpty) return const <String>[];
    final list = source.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (list.remove(_kNotSpecified)) list.add(_kNotSpecified);
    return list;
  }

  List<_ApplicantRecord> _applyFilters(_ApplicantsSnapshot data) {
    return data.records.where((record) {
      final majorDisplay = _presentMajor(record.student);
      if (_selectedMajor != _kAll && majorDisplay != _selectedMajor) {
        return false;
      }

      final levelDisplay = _presentLevel(record.student);
      if (_selectedLevel != _kAll && levelDisplay != _selectedLevel) {
        return false;
      }

      if (_gpaFilterEnabled && _gpaRange != null) {
        final gpa = record.student.gpa;
        if (gpa == null) return false;
        if (gpa < _gpaRange!.start - 1e-6 || gpa > _gpaRange!.end + 1e-6) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> _buildMajorOptions(_ApplicantsSnapshot data) {
    if (data.majors.isEmpty) return const <String>[_kAll];
    return [_kAll, ...data.majors];
  }

  List<String> _buildLevelOptions(_ApplicantsSnapshot data) {
    if (data.levels.isEmpty) return const <String>[_kAll];
    return [_kAll, ...data.levels];
  }

  bool _hasGpaRange(_ApplicantsSnapshot data) {
    if (data.minGpa == null || data.maxGpa == null) return false;
    return (data.maxGpa! - data.minGpa!).abs() > 0.01;
  }

  int _gpaDivisions(double min, double max) {
    final diff = max - min;
    if (diff <= 0) return 1;
    final divisions = (diff * 10).round();
    return divisions <= 0 ? 1 : divisions;
  }

  Widget _buildFilters({
    required _ApplicantsSnapshot data,
    required double maxWidth,
    required List<String> majorOptions,
    required List<String> levelOptions,
    required bool hasGpaRange,
    required int filteredCount,
  }) {
    final hasMajorFilter = majorOptions.length > 1;
    final hasLevelFilter = levelOptions.length > 1;
    final hasAnyFilter = hasMajorFilter || hasLevelFilter || hasGpaRange;

    if (!hasAnyFilter) return const SizedBox.shrink();

    final RangeValues? gpaValues =
        _gpaRange ??
        ((data.minGpa != null && data.maxGpa != null)
            ? RangeValues(data.minGpa!, data.maxGpa!)
            : null);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: maxWidth,
        child: Card(
          color: CompanyColors.surface,
          elevation: CompanySpacing.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: CompanySpacing.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Filters',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CompanyColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Showing $filteredCount of ${data.records.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CompanyColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => _resetFilters(data),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                if (hasMajorFilter) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedMajor,
                    items: majorOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMajor = value ?? _kAll;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Major',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (hasLevelFilter) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedLevel,
                    items: levelOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLevel = value ?? _kAll;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (hasGpaRange && gpaValues != null) ...[
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final effectiveGpa = _gpaRange ?? gpaValues;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Filter by GPA',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            value: _gpaFilterEnabled,
                            onChanged: (value) {
                              setState(() {
                                _gpaFilterEnabled = value;
                                if (value && _gpaRange == null) {
                                  _gpaRange = RangeValues(
                                    data.minGpa!,
                                    data.maxGpa!,
                                  );
                                }
                              });
                            },
                          ),
                          RangeSlider(
                            values: effectiveGpa,
                            min: data.minGpa!,
                            max: data.maxGpa!,
                            divisions: _gpaDivisions(
                              data.minGpa!,
                              data.maxGpa!,
                            ),
                            labels: RangeLabels(
                              effectiveGpa.start.toStringAsFixed(2),
                              effectiveGpa.end.toStringAsFixed(2),
                            ),
                            onChanged: _gpaFilterEnabled
                                ? (values) {
                                    setState(() {
                                      _gpaRange = RangeValues(
                                        values.start,
                                        values.end,
                                      );
                                    });
                                  }
                                : null,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Min: ${effectiveGpa.start.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CompanyColors.muted,
                                ),
                              ),
                              Text(
                                'Max: ${effectiveGpa.end.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CompanyColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSingleOpportunity = widget.opportunity != null;
    final subtitle = isSingleOpportunity
        ? '${widget.opportunity!.name} • ${widget.opportunity!.role}'
        : widget.company.companyName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: CompanyColors.surface,
        foregroundColor: CompanyColors.primary,
        elevation: 1,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSingleOpportunity ? 'Opportunity Applicants' : 'All Applicants',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
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
          child: FutureBuilder<_ApplicantsSnapshot>(
            future: _applicantsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildStateMessage(
                  icon: Icons.error_outline,
                  title: 'Could not load applicants.',
                  description: 'Please check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: _reload,
                );
              }

              final data = snapshot.data ?? _ApplicantsSnapshot.empty;

              if (data.records.isEmpty) {
                final description = isSingleOpportunity
                    ? 'Students who apply to ${widget.opportunity!.name} will appear here.'
                    : 'We will list your applicants here once students apply to your opportunities.';
                final title = isSingleOpportunity
                    ? 'No applicants yet for this opportunity'
                    : 'No applicants yet';
                return _buildStateMessage(
                  icon: Icons.people_outline,
                  title: title,
                  description: description,
                  actionLabel: 'Refresh',
                  onAction: _reload,
                );
              }

              if (!_filtersInitialized) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _initializeFilters(data);
                });
              }

              final majorOptions = _buildMajorOptions(data);
              final levelOptions = _buildLevelOptions(data);
              final hasGpaRange = _hasGpaRange(data);
              final filteredRecords = _applyFilters(data);

              if (filteredRecords.isEmpty) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = CompanySpacing.pagePadding(context);
                    final maxWidth = CompanySpacing.maxContentWidth(
                      constraints.maxWidth,
                    );
                    final filters = _buildFilters(
                      data: data,
                      maxWidth: maxWidth,
                      majorOptions: majorOptions,
                      levelOptions: levelOptions,
                      hasGpaRange: hasGpaRange,
                      filteredCount: 0,
                    );

                    return ListView(
                      padding: padding,
                      children: [
                        _OverviewHeader(
                          snapshot: data,
                          maxWidth: maxWidth,
                          opportunity: widget.opportunity,
                        ),
                        const SizedBox(height: 16),
                        filters,
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: _buildStateMessage(
                            icon: Icons.filter_list_off,
                            title: 'No applicants match your filters',
                            description:
                                'Try adjusting your filters or clear them to see all applicants.',
                            actionLabel: 'Clear filters',
                            onAction: () => _resetFilters(data),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final padding = CompanySpacing.pagePadding(context);
                  final maxWidth = CompanySpacing.maxContentWidth(
                    constraints.maxWidth,
                  );
                  final filters = _buildFilters(
                    data: data,
                    maxWidth: maxWidth,
                    majorOptions: majorOptions,
                    levelOptions: levelOptions,
                    hasGpaRange: hasGpaRange,
                    filteredCount: filteredRecords.length,
                  );

                  return ListView.builder(
                    padding: padding,
                    itemCount: filteredRecords.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _OverviewHeader(
                              snapshot: data,
                              maxWidth: maxWidth,
                              opportunity: widget.opportunity,
                            ),
                            const SizedBox(height: 16),
                            filters,
                          ],
                        );
                      }

                      final record = filteredRecords[index - 1];
                      return Padding(
                        padding: EdgeInsets.only(top: index == 1 ? 24 : 16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: maxWidth,
                            child: _ApplicantCard(record: record),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: CompanyColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: CompanyColors.muted,
                ),
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

class _OverviewHeader extends StatefulWidget {
  final _ApplicantsSnapshot snapshot;
  final double maxWidth;
  final Opportunity? opportunity;

  const _OverviewHeader({
    required this.snapshot,
    required this.maxWidth,
    this.opportunity,
  });

  @override
  State<_OverviewHeader> createState() => _OverviewHeaderState();
}

class _OverviewHeaderState extends State<_OverviewHeader> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.opportunity == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: widget.maxWidth,
        child: Card(
          color: CompanyColors.surface,
          elevation: CompanySpacing.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: CompanySpacing.cardRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.opportunity!.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CompanyColors.primary,
                  ),
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.opportunity!.role,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CompanyColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(Icons.badge_outlined, widget.opportunity!.type),
                      if (widget.opportunity!.workMode != null &&
                          widget.opportunity!.workMode!.trim().isNotEmpty)
                        _buildChip(
                          Icons.apartment_outlined,
                          widget.opportunity!.workMode!,
                        ),
                      if (widget.opportunity!.location != null &&
                          widget.opportunity!.location!.trim().isNotEmpty)
                        _buildChip(
                          Icons.location_on_outlined,
                          widget.opportunity!.location!,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'View Less' : 'View More',
                        style: const TextStyle(
                          fontSize: 14,
                          color: CompanyColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: CompanyColors.secondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16, color: CompanyColors.primary),
      label: Text(text),
      backgroundColor: CompanyColors.primary.withOpacity(0.08),
      labelStyle: const TextStyle(
        color: CompanyColors.primary,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _ApplicantCard extends StatefulWidget {
  final _ApplicantRecord record;

  const _ApplicantCard({required this.record});

  @override
  State<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<_ApplicantCard> {
  final ApplicationService _applicationService = ApplicationService();
  bool _isUpdating = false;

  Future<void> _updateStatus(String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status to $newStatus?'),
        content: SingleChildScrollView(
          child: Text(
            'Are you sure you want to change the application status to $newStatus?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: newStatus == 'Accepted'
                  ? Colors.green
                  : Colors.red,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdating = true);

    try {
      await _applicationService.updateApplicationStatus(
        applicationId: widget.record.application.id,
        status: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application status updated to $newStatus'),
          backgroundColor: newStatus == 'Accepted' ? Colors.green : Colors.red,
        ),
      );

      // Reload the page to reflect changes
      if (context.mounted) {
        final state = context.findAncestorStateOfType<_AllApplicantsPageState>();
        state?._reload();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.record.student;
    final application = widget.record.application;
    final opportunity = widget.record.opportunity;
    final majorDisplay = _presentMajor(student);
    final levelDisplay = _presentLevel(student);
    final gpaValue = student.gpa;

    final appliedLabel = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(application.appliedDate.toDate());

    final isPending = application.status.toLowerCase() == 'pending';

    return Card(
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: CompanyColors.primary.withOpacity(0.12),
                  child: Text(
                    _initials(student),
                    style: const TextStyle(
                      color: CompanyColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(student),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusChip(status: application.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.work_outline,
              label: 'Applied for',
              value: '${opportunity.name} • ${opportunity.role}',
            ),
            _InfoRow(
              icon: Icons.event_available_outlined,
              label: 'Applied on',
              value: appliedLabel,
            ),
            _InfoRow(
              icon: Icons.mail_outline,
              label: 'Email',
              value: student.email,
            ),
            if (student.phoneNumber.isNotEmpty)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: student.phoneNumber,
              ),
            _InfoRow(
              icon: Icons.school_outlined,
              label: 'Major',
              value: majorDisplay,
            ),
            _InfoRow(
              icon: Icons.timeline_outlined,
              label: 'Level',
              value: levelDisplay,
            ),
            if (gpaValue != null)
              _InfoRow(
                icon: Icons.bar_chart_outlined,
                label: 'GPA',
                value: gpaValue.toStringAsFixed(2),
              ),
            if (student.skills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: student.skills
                      .take(6)
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: CompanyColors.secondary.withOpacity(
                            0.12,
                          ),
                          labelStyle: const TextStyle(
                            color: CompanyColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (isPending) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateStatus('Accepted'),
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateStatus('Rejected'),
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayName(Student student) {
    final first = student.firstName.trim();
    final last = student.lastName.trim();
    final combined = ('$first $last').trim();
    if (combined.isNotEmpty) return combined;
    if (student.username.trim().isNotEmpty) return student.username.trim();
    return student.email;
  }

  String _initials(Student student) {
    final parts = <String>[];
    if (student.firstName.trim().isNotEmpty) {
      parts.add(student.firstName.trim()[0].toUpperCase());
    }
    if (student.lastName.trim().isNotEmpty) {
      parts.add(student.lastName.trim()[0].toUpperCase());
    }
    if (parts.isNotEmpty) return parts.join();

    final username = student.username.trim();
    if (username.isNotEmpty) return username[0].toUpperCase();
    if (student.email.isNotEmpty) return student.email[0].toUpperCase();
    return '?';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: CompanyColors.primary),
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.foreground,
        ),
      ),
    );
  }

  _StatusColors _statusColors(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const _StatusColors(
          background: Color(0xFFE7E2F7),
          foreground: CompanyColors.primary,
        );
      case 'reviewing':
      case 'in review':
      case 'under review':
        return const _StatusColors(
          background: Color(0xFFE0F2F1),
          foreground: Color(0xFF00695C),
        );
      case 'reviewed':
        return const _StatusColors(
          background: Color(0xFFFFF0D5),
          foreground: Color(0xFF8D6E00),
        );
      case 'hired':
        return const _StatusColors(
          background: Color(0xFFE6F4EA),
          foreground: Color(0xFF1B5E20),
        );
      case 'rejected':
        return const _StatusColors(
          background: Color(0xFFFFE6E9),
          foreground: Color(0xFFC62828),
        );
      case 'withdrawn':
        return const _StatusColors(
          background: Color(0xFFEDE7F6),
          foreground: Color(0xFF4527A0),
        );
      default:
        return const _StatusColors(
          background: Color(0xFFE4E6EB),
          foreground: Color(0xFF374151),
        );
    }
  }
}

class _StatusColors {
  final Color background;
  final Color foreground;

  const _StatusColors({required this.background, required this.foreground});
}

class _ApplicantRecord {
  final app_model.Application application;
  final Student student;
  final Opportunity opportunity;

  const _ApplicantRecord({
    required this.application,
    required this.student,
    required this.opportunity,
  });
}

class _ApplicantsSnapshot {
  final List<_ApplicantRecord> records;
  final int opportunityCount;
  final List<String> majors;
  final List<String> levels;
  final double? minGpa;
  final double? maxGpa;

  const _ApplicantsSnapshot({
    required this.records,
    required this.opportunityCount,
    required this.majors,
    required this.levels,
    required this.minGpa,
    required this.maxGpa,
  });

  static const _ApplicantsSnapshot empty = _ApplicantsSnapshot(
    records: const <_ApplicantRecord>[],
    opportunityCount: 0,
    majors: const <String>[],
    levels: const <String>[],
    minGpa: null,
    maxGpa: null,
  );
}

String _presentMajor(Student student) {
  final major = student.major.trim();
  return major.isEmpty ? _kNotSpecified : major;
}

String _presentLevel(Student student) {
  final level = (student.level ?? '').trim();
  return level.isEmpty ? _kNotSpecified : level;
}
