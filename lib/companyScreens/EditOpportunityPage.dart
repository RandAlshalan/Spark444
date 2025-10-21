import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/opportunity.dart';
import '../services/opportunityService.dart';

class EditOpportunityPage extends StatefulWidget {
  final Opportunity opportunity;

  const EditOpportunityPage({super.key, required this.opportunity});

  @override
  State<EditOpportunityPage> createState() => _EditOpportunityPageState();
}

class _EditOpportunityPageState extends State<EditOpportunityPage> {
  final _formKey = GlobalKey<FormState>();
  final OpportunityService _opportunityService = OpportunityService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _opportunityDatesController =
      TextEditingController();
  final TextEditingController _applicationDatesController =
      TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _skillController = TextEditingController();
  final TextEditingController _requirementController = TextEditingController();
  final TextEditingController _otherMajorController = TextEditingController();

  // State variables
  String? _selectedWorkMode;
  String? _selectedLocation;
  String? _displayMajor;
  String? _selectedMajor;
  String? _selectedType;
  bool _isPaid = true;
  bool _isLoading = false;
  bool _nameAtLimit = false;
  bool _roleAtLimit = false;
  bool _nameHasInvalidChars = false;
  bool _roleHasInvalidChars = false;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _applicationOpenDate;
  DateTime? _applicationDeadline;
  DateTime? _responseDeadline;
  bool _responseDeadlineVisible = false;

  final List<String> _selectedSkills = [];
  final List<String> _selectedRequirements = [];

  static const int _maxSkills = 10;
  static const int _maxRequirements = 10;
  static const int _nameMaxLength = 50;
  static const int _roleMaxLength = 40;
  static final RegExp _lettersRegExp = RegExp(r'^[A-Za-z ]+$');

  // Dropdown options
  final List<String> _workModes = ['In-person', 'Remote', 'Hybrid'];
  final List<String> _saudiCities = [
    'Riyadh',
    'Makkah',
    'Medina',
    'Qassim',
    'Eastern Province',
    'Asir',
    'Tabuk',
    'Northern Borders',
    'Hail',
    'Bahah',
    'Najran',
    'Jazan',
    'Al Jouf',
  ];

  final List<String> _opportunityTypes = [
    'Internship',
    'Co-op',
    'Graduate Program',
    'Bootcamp',
  ];

  List<String> _majorsList = [];
  bool _majorsLoading = true;
  late Future<void> _loadMajorsFuture;

  // Color constants
  static const Color primaryColor = Color(0xFF422F5D);
  static const Color backgroundColor = Color(0xFFF7F4F0);
  static const Color accentColor = Color(0xFFD64483);

  @override
  void initState() {
    super.initState();
    _loadMajorsFuture = _loadMajors();
    _populateFields();
  }

  void _populateFields() {
    // Populate controllers with existing opportunity data
    _nameController.text = widget.opportunity.name;
    _roleController.text = widget.opportunity.role;
    _descriptionController.text = widget.opportunity.description ?? '';

    _isPaid = widget.opportunity.isPaid;
    _selectedType = widget.opportunity.type;
    _selectedWorkMode = widget.opportunity.workMode;

    // Handle location based on work mode
    if (widget.opportunity.workMode == 'In-person' ||
        widget.opportunity.workMode == 'Hybrid') {
      _selectedLocation = widget.opportunity.location;
    }

    // Handle preferred major - will be set after majors list loads
    final existingMajor = widget.opportunity.preferredMajor;
    _displayMajor = existingMajor;
    _selectedMajor = existingMajor;

    // Check if it's a custom major after the majors list loads
    if (existingMajor != null && existingMajor.isNotEmpty) {
      _loadMajorsFuture.then((_) {
        if (mounted) {
          // Use WidgetsBinding to schedule the setState after the current frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (!_majorsList.contains(existingMajor)) {
              // It's a custom major, set it as "Other" and populate the text field
              setState(() {
                _selectedMajor = 'Other';
                _displayMajor = 'Other';
                _otherMajorController.text = existingMajor;
              });
            } else {
              // It's a predefined major, just ensure state is correct
              setState(() {
                _displayMajor = existingMajor;
                _selectedMajor = existingMajor;
              });
            }
          });
        }
      });
    }

    // Handle dates
    _startDate = widget.opportunity.startDate?.toDate();
    _endDate = widget.opportunity.endDate?.toDate();
    _applicationOpenDate = widget.opportunity.applicationOpenDate?.toDate();
    _applicationDeadline = widget.opportunity.applicationDeadline?.toDate();
    _responseDeadline =
        widget.opportunity.responseDeadline?.toDate() ??
        (_applicationDeadline?.add(const Duration(days: 1)) ??
            DateTime.now().add(const Duration(days: 7)));
    _responseDeadlineVisible =
        widget.opportunity.responseDeadlineVisible ?? true;

    // Populate skills and requirements
    if (widget.opportunity.skills != null) {
      _selectedSkills.addAll(widget.opportunity.skills!);
    }
    if (widget.opportunity.requirements != null) {
      _selectedRequirements.addAll(widget.opportunity.requirements!);
    }

    // Update date controllers
    _updateDateControllers();
    _calculateDuration();
  }

  void _updateDateControllers() {
    if (_startDate != null && _endDate != null) {
      _opportunityDatesController.text =
          '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
    }

    if (_applicationOpenDate != null && _applicationDeadline != null) {
      _applicationDatesController.text =
          '${DateFormat('MMM dd, yyyy').format(_applicationOpenDate!)} - ${DateFormat('MMM dd, yyyy').format(_applicationDeadline!)}';
    }
  }

  Future<void> _loadMajors() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('lists')
          .doc('majors')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _majorsList = [...List<String>.from(data?['names'] ?? []), 'Other'];
          _majorsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading majors: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _descriptionController.dispose();
    _opportunityDatesController.dispose();
    _applicationDatesController.dispose();
    _durationController.dispose();
    _skillController.dispose();
    _requirementController.dispose();
    _otherMajorController.dispose();
    super.dispose();
  }

  void _handleNameLength() {
    final text = _nameController.text;
    final atLimit = text.length >= _nameMaxLength;
    final hasInvalid =
        text.trim().isNotEmpty && !_lettersRegExp.hasMatch(text.trim());
    if (mounted &&
        (_nameAtLimit != atLimit || _nameHasInvalidChars != hasInvalid)) {
      setState(() {
        _nameAtLimit = atLimit;
        _nameHasInvalidChars = hasInvalid;
      });
    }
  }

  void _handleRoleLength() {
    final text = _roleController.text;
    final atLimit = text.length >= _roleMaxLength;
    final hasInvalid =
        text.trim().isNotEmpty && !_lettersRegExp.hasMatch(text.trim());
    if (mounted &&
        (_roleAtLimit != atLimit || _roleHasInvalidChars != hasInvalid)) {
      setState(() {
        _roleAtLimit = atLimit;
        _roleHasInvalidChars = hasInvalid;
      });
    }
  }

  void _calculateDuration() {
    if (_startDate != null && _endDate != null) {
      final difference = _endDate!.difference(_startDate!).inDays;
      final months = (difference / 30).floor();
      final days = difference % 30;

      String durationText = '';
      if (months > 0) durationText += '$months month${months > 1 ? 's' : ''}';
      if (days > 0) {
        if (durationText.isNotEmpty) durationText += ' ';
        durationText += '$days day${days > 1 ? 's' : ''}';
      }

      setState(() {
        _durationController.text = durationText.isNotEmpty
            ? durationText
            : '0 days';
      });
    }
  }

  Future<void> _updateOpportunity() async {
    if (_formKey.currentState!.validate()) {
      // Validation logic similar to post opportunity
      // Response deadline validation (now always required)
      if (_applicationDeadline != null &&
          !_responseDeadline!.isAfter(_applicationDeadline!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Response deadline must be after the application deadline.',
            ),
          ),
        );
        return;
      }
      if (_startDate != null && !_responseDeadline!.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Response deadline must be before the opportunity start date.',
            ),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final String? finalMajor = _selectedMajor == 'Other'
          ? _otherMajorController.text.trim()
          : _displayMajor;

      final Opportunity updatedOpportunity = Opportunity(
        id: widget.opportunity.id,
        companyId: widget.opportunity.companyId,
        name: _nameController.text.trim(),
        preferredMajor: finalMajor,
        role: _roleController.text.trim(),
        isPaid: _isPaid,
        type: _selectedType ?? 'Internship',
        workMode: _selectedWorkMode,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        requirements: _selectedRequirements.isNotEmpty
            ? _selectedRequirements
            : null,
        skills: _selectedSkills.isNotEmpty ? _selectedSkills : null,
        location:
            (_selectedWorkMode == 'In-person' || _selectedWorkMode == 'Hybrid')
            ? _selectedLocation
            : _selectedWorkMode,
        startDate: _startDate != null ? Timestamp.fromDate(_startDate!) : null,
        endDate: _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        applicationOpenDate: _applicationOpenDate != null
            ? Timestamp.fromDate(_applicationOpenDate!)
            : null,
        applicationDeadline: _applicationDeadline != null
            ? Timestamp.fromDate(_applicationDeadline!)
            : null,
        responseDeadline: Timestamp.fromDate(
          _responseDeadline!,
        ), // Always required now
        responseDeadlineVisible: _responseDeadlineVisible,
        postedDate: widget.opportunity.postedDate, // Keep original posted date
        isActive: widget.opportunity.isActive,
      );

      try {
        await _opportunityService.updateOpportunity(updatedOpportunity);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opportunity updated successfully!')),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } catch (e) {
        debugPrint('Error updating opportunity: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update opportunity: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _addSkill() {
    if (_selectedSkills.length >= _maxSkills) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can add a maximum of $_maxSkills skills.')),
      );
      return;
    }

    final skill = _skillController.text.trim();
    if (skill.isEmpty) return;

    final isDuplicate = _selectedSkills.any(
      (s) => s.toLowerCase() == skill.toLowerCase(),
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This skill has already been added.')),
      );
      return;
    }

    setState(() {
      _selectedSkills.add(skill);
      _skillController.clear();
    });
  }

  void _removeSkill(String skill) {
    setState(() => _selectedSkills.remove(skill));
  }

  void _addRequirement() {
    if (_selectedRequirements.length >= _maxRequirements) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can add a maximum of $_maxRequirements requirements.',
          ),
        ),
      );
      return;
    }

    final requirement = _requirementController.text.trim();
    if (requirement.isEmpty) return;

    final isDuplicate = _selectedRequirements.any(
      (r) => r.toLowerCase() == requirement.toLowerCase(),
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This requirement has already been added.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedRequirements.add(requirement);
      _requirementController.clear();
    });
  }

  void _removeRequirement(String requirement) {
    setState(() => _selectedRequirements.remove(requirement));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Edit Opportunity',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<void>(
        future: _loadMajorsFuture,
        builder: (context, snapshot) {
          if (_majorsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, backgroundColor],
            stops: [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit, color: primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Update Opportunity Details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make changes to your opportunity and they will be updated for all students in real-time.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Main Form Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader(
                      'Basic Information',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 16),

                    _buildStyledTextFormField(
                      controller: _nameController,
                      labelText: 'Opportunity Name',
                      icon: Icons.business_center,
                      maxLength: _nameMaxLength,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an opportunity name';
                        }
                        if (!_lettersRegExp.hasMatch(value.trim())) {
                          return 'Only letters and spaces are allowed';
                        }
                        return null;
                      },
                      onChanged: (value) => _handleNameLength(),
                    ),

                    _buildStyledTextFormField(
                      controller: _roleController,
                      labelText: 'Role/Position',
                      icon: Icons.work,
                      maxLength: _roleMaxLength,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a role/position';
                        }
                        if (!_lettersRegExp.hasMatch(value.trim())) {
                          return 'Only letters and spaces are allowed';
                        }
                        return null;
                      },
                      onChanged: (value) => _handleRoleLength(),
                    ),

                    _buildStyledTextFormField(
                      controller: _descriptionController,
                      labelText: 'Description (Optional)',
                      icon: Icons.description,
                      maxLines: 4,
                      inputFormatters: [LengthLimitingTextInputFormatter(500)],
                    ),

                    const SizedBox(height: 24),

                    // Opportunity Details Section
                    _buildSectionHeader(
                      'Opportunity Details',
                      Icons.work_outline,
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownFormField(
                      labelText: 'Opportunity Type',
                      items: _opportunityTypes,
                      selectedValue: _opportunityTypes.contains(_selectedType)
                          ? _selectedType
                          : null,
                      onChanged: (value) =>
                          setState(() => _selectedType = value),
                      validator: (value) => value == null
                          ? 'Please select an opportunity type'
                          : null,
                    ),

                    _buildDropdownFormField(
                      labelText: 'Work Mode',
                      items: _workModes,
                      selectedValue: _selectedWorkMode,
                      onChanged: (value) {
                        setState(() {
                          _selectedWorkMode = value;
                          if (value == 'Remote') {
                            _selectedLocation = null;
                          }
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a work mode' : null,
                    ),

                    if (_selectedWorkMode == 'In-person' ||
                        _selectedWorkMode == 'Hybrid')
                      _buildDropdownFormField(
                        labelText: 'Location',
                        items: _saudiCities,
                        selectedValue: _selectedLocation,
                        onChanged: (value) =>
                            setState(() => _selectedLocation = value),
                        validator: (value) =>
                            value == null ? 'Please select a location' : null,
                      ),

                    _buildDropdownFormField(
                      labelText: 'Preferred Major (Optional)',
                      items: _majorsList,
                      selectedValue: _majorsList.contains(_displayMajor)
                          ? _displayMajor
                          : null,
                      onChanged: (value) {
                        setState(() {
                          _displayMajor = value;
                          _selectedMajor = value;
                        });
                      },
                    ),

                    if (_selectedMajor == 'Other')
                      _buildStyledTextFormField(
                        controller: _otherMajorController,
                        labelText: 'Specify Major',
                        icon: Icons.school,
                        inputFormatters: [LengthLimitingTextInputFormatter(40)],
                        validator: (value) {
                          if (_selectedMajor == 'Other' &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please specify the major';
                          }
                          return null;
                        },
                      ),

                    const SizedBox(height: 16),

                    // Compensation Section
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Is this a paid opportunity?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Switch(
                            value: _isPaid,
                            onChanged: (v) => setState(() => _isPaid = v),
                            activeColor: accentColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Skills and Requirements Section
                    _buildSectionHeader('Skills & Requirements', Icons.build),
                    const SizedBox(height: 16),

                    _buildStyledTextFormField(
                      controller: _skillController,
                      labelText: 'Add Skills',
                      icon: Icons.star_outline,
                      onFieldSubmitted: (value) => _addSkill(),
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _addSkill,
                      ),
                    ),
                    if (_selectedSkills.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _selectedSkills
                            .map(
                              (skill) => _buildTagChip(
                                context,
                                text: skill,
                                background: accentColor.withOpacity(0.15),
                                borderColor: accentColor.withOpacity(0.3),
                                textColor: accentColor,
                                iconColor: accentColor,
                                onRemove: () => _removeSkill(skill),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 8),

                    _buildStyledTextFormField(
                      controller: _requirementController,
                      labelText: 'Add Requirements',
                      icon: Icons.checklist_outlined,
                      onFieldSubmitted: (value) => _addRequirement(),
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: _addRequirement,
                      ),
                    ),
                    if (_selectedRequirements.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _selectedRequirements
                            .map(
                              (req) => _buildTagChip(
                                context,
                                text: req,
                                background: primaryColor.withOpacity(0.12),
                                borderColor: primaryColor.withOpacity(0.25),
                                textColor: primaryColor,
                                iconColor: primaryColor,
                                onRemove: () => _removeRequirement(req),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 24),

                    // Dates Section
                    _buildSectionHeader(
                      'Important Dates',
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 16),

                    _buildDateRangeField(
                      controller: _opportunityDatesController,
                      labelText: 'Opportunity Duration',
                      icon: Icons.date_range,
                      onTap: () => _selectOpportunityDateRange(context),
                      validator: (value) {
                        if (_startDate == null || _endDate == null) {
                          return 'Please select opportunity dates';
                        }
                        if (_applicationDeadline != null &&
                            _startDate != null) {
                          if (!_applicationDeadline!.isBefore(_startDate!)) {
                            return 'Opportunity must start after application deadline';
                          }
                        }
                        return null;
                      },
                    ),

                    _buildDateRangeField(
                      controller: _applicationDatesController,
                      labelText: 'Application Period',
                      icon: Icons.app_registration,
                      onTap: () => _selectApplicationDateRange(context),
                      validator: (value) {
                        if (_applicationOpenDate == null ||
                            _applicationDeadline == null) {
                          return 'Please select application dates';
                        }
                        if (_applicationDeadline != null &&
                            _startDate != null) {
                          if (!_applicationDeadline!.isBefore(_startDate!)) {
                            return 'Application deadline must be before opportunity starts';
                          }
                        }
                        return null;
                      },
                    ),

                    _buildResponseDeadlineSection(),

                    _buildStyledTextFormField(
                      controller: _durationController,
                      labelText: 'Duration of the Opportunity',
                      icon: Icons.timelapse,
                      readOnly: true,
                      enabled: false,
                      showLabelAbove: true,
                      hintText: 'Auto-calculated',
                    ),

                    const SizedBox(height: 30),

                    _buildGradientButton(
                      text: 'Update Opportunity',
                      onPressed: _updateOpportunity,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    int maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    bool enabled = true,
    bool showLabelAbove = false,
    String? hintText,
  }) {
    final field = TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      readOnly: readOnly,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: showLabelAbove ? null : labelText,
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabelAbove) ...[
            Text(
              labelText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 6),
          ],
          field,
        ],
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String labelText,
    required List<String> items,
    String? selectedValue,
    void Function(String?)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateRangeField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: primaryColor),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildResponseDeadlineSection() {
    return Column(
      children: [
        _buildDateRangeField(
          controller: TextEditingController(
            text: _responseDeadline != null
                ? DateFormat('MMM dd, yyyy').format(_responseDeadline!)
                : '',
          ),
          labelText: 'Response Deadline (Required)',
          icon: Icons.schedule,
          onTap: () => _selectResponseDeadline(context),
          validator: (value) {
            if (_responseDeadline == null) {
              return 'Please select a response deadline';
            }
            return null;
          },
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Show response deadline to students?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              Switch(
                value: _responseDeadlineVisible,
                onChanged: (v) => setState(() => _responseDeadlineVisible = v),
                activeColor: accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildTagChip(
    BuildContext context, {
    required String text,
    required Color background,
    required Color textColor,
    Color? iconColor,
    Color? borderColor,
    VoidCallback? onRemove,
  }) {
    final maxWidth = MediaQuery.of(context).size.width - 80;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth > 0 ? maxWidth : double.infinity,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                softWrap: true,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: iconColor ?? textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectOpportunityDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _opportunityDatesController.text =
            '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
      });
      _calculateDuration();
    }
  }

  Future<void> _selectApplicationDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: _startDate ?? DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange:
          _applicationOpenDate != null && _applicationDeadline != null
          ? DateTimeRange(
              start: _applicationOpenDate!,
              end: _applicationDeadline!,
            )
          : null,
    );

    if (picked != null) {
      setState(() {
        _applicationOpenDate = picked.start;
        _applicationDeadline = picked.end;
        _applicationDatesController.text =
            '${DateFormat('MMM dd, yyyy').format(_applicationOpenDate!)} - ${DateFormat('MMM dd, yyyy').format(_applicationDeadline!)}';
      });
    }
  }

  Future<void> _selectResponseDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _responseDeadline ?? DateTime.now(),
      firstDate: _applicationDeadline ?? DateTime.now(),
      lastDate: _startDate ?? DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() {
        _responseDeadline = picked;
      });
    }
  }
}
