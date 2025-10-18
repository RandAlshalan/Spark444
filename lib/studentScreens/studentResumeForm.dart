import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/resume.dart';
import 'package:my_app/models/student.dart';

// --- Color Constants ---
const Color _primaryColor = Color(0xFF422F5D);
const Color _backgroundColor = Color(0xFFF8F9FA);

class ResumeFormScreen extends StatefulWidget {
  final Student student;
  final Resume? resume;

  const ResumeFormScreen({super.key, required this.student, this.resume});

  @override
  State<ResumeFormScreen> createState() => _ResumeFormScreenState();
}

class _ResumeFormScreenState extends State<ResumeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers for static fields ---
  late TextEditingController _titleController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _summaryController;

  // --- State for dynamic lists ---
  List<Education> _educationEntries = [];
  List<Experience> _experienceEntries = [];
  List<Award> _awardEntries = [];
  List<Language> _languageEntries = [];
  List<String> _skills = [];
  List<Project> _projectEntries = [];
  List<Extracurricular> _extracurricularEntries = [];
  List<License> _licenseEntries = [];
  List<CustomSection> _customSections = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    final student = widget.student;

    if (resume != null) {
      // --- Editing mode ---
      _titleController = TextEditingController(text: resume.title);
      _firstNameController =
          TextEditingController(text: resume.personalDetails['firstName'] ?? '');
      _lastNameController =
          TextEditingController(text: resume.personalDetails['lastName'] ?? '');
      _emailController =
          TextEditingController(text: resume.personalDetails['email'] ?? '');
      _phoneController =
          TextEditingController(text: resume.personalDetails['phone'] ?? '');
      _summaryController =
          TextEditingController(text: resume.personalDetails['summary'] ?? '');
      _educationEntries = List<Education>.from(resume.education);
      _experienceEntries = List<Experience>.from(resume.experiences);
      _awardEntries = List<Award>.from(resume.awards);
      _languageEntries = List<Language>.from(resume.languages);
      _skills = List<String>.from(resume.skills);
      _projectEntries = List<Project>.from(resume.projects);
      _extracurricularEntries =
          List<Extracurricular>.from(resume.extracurriculars);
      _licenseEntries = List<License>.from(resume.licenses);
      _customSections = List<CustomSection>.from(resume.customSections);
    } else {
      // --- Creating mode ---
      _titleController = TextEditingController(text: 'My Resume');
      _firstNameController = TextEditingController(text: student.firstName);
      _lastNameController = TextEditingController(text: student.lastName);
      _emailController = TextEditingController(text: student.email);
      _phoneController = TextEditingController(text: student.phoneNumber);
      _summaryController = TextEditingController(text: student.shortSummary);
      _skills = List<String>.from(student.skills);
      _projectEntries = [];
      _extracurricularEntries = [];
      _licenseEntries = [];
      _customSections = [];

      // Pre-populate education
      if (student.university != null && student.university!.isNotEmpty) {
        String degreeText =
            '${student.level ?? ''} ${student.major ?? ''}'.trim();
        if ((student.level?.isNotEmpty ?? false) &&
            (student.major?.isNotEmpty ?? false)) {
          degreeText = '${student.level} in ${student.major}';
        }
        _educationEntries.add(Education(
          instituteName: student.university!,
          degreeName: degreeText,
          startDate: DateTime.now(),
          endDate: DateTime.tryParse(student.expectedGraduationDate ?? ''),
          isPresent: false,
        ));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _saveResume() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fix the errors in the form.'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    await _performSave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveDraft() async {
    if (widget.resume?.id == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saving draft...'), duration: Duration(seconds: 1)),
      );
    }
    await _performSave();
  }

  Future<void> _performSave() async {
    final personalDetails = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'summary': _summaryController.text.trim(),
    };

    final resumeData = {
      'studentId': widget.student.id,
      'title': _titleController.text.trim(),
      'personalDetails': personalDetails,
      'education': _educationEntries.map((e) => e.toMap()).toList(),
      'experiences': _experienceEntries.map((e) => e.toMap()).toList(),
      'skills': _skills,
      'awards': _awardEntries.map((a) => a.toMap()).toList(),
      'languages': _languageEntries.map((l) => l.toMap()).toList(),
      'projects': _projectEntries.map((p) => p.toMap()).toList(),
      'extracurriculars':
          _extracurricularEntries.map((e) => e.toMap()).toList(),
      'licenses': _licenseEntries.map((l) => l.toMap()).toList(),
      'customSections': _customSections.map((cs) => cs.toMap()).toList(),
      'lastModifiedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.resume != null) {
        await FirebaseFirestore.instance
            .collection('resumes')
            .doc(widget.resume!.id)
            .update(resumeData);
      } else {
        await FirebaseFirestore.instance.collection('resumes').add({
          ...resumeData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _onWillPop() async {
    await _saveDraft();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(widget.resume == null ? 'Create Resume' : 'Edit Resume',
              style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3)),
                    ))
                  : IconButton(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _saveResume,
                      tooltip: 'Save Resume'),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStyledTextFormField(
                controller: _titleController,
                labelText: 'Resume Title',
                hintText: 'e.g., "Software Engineering Resume"',
                icon: Icons.title,
                validator: (value) =>
                    value!.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 8),
              _buildSectionTile(
                title: 'Personal Details & Summary',
                icon: Icons.person_outline,
                initiallyExpanded: true,
                children: [
                  _buildStyledTextFormField(
                      controller: _firstNameController,
                      labelText: 'First Name',
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  _buildStyledTextFormField(
                      controller: _lastNameController,
                      labelText: 'Last Name',
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  _buildStyledTextFormField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  _buildStyledTextFormField(
                      controller: _phoneController,
                      labelText: 'Phone Number',
                      keyboardType: TextInputType.phone),
                  _buildStyledTextFormField(
                      controller: _summaryController,
                      labelText: 'Professional Summary',
                      maxLines: 4,
                      hintText: 'A brief 2-3 sentence summary...'),
                  if (_educationEntries.isNotEmpty) ...[
                    const Divider(height: 32, thickness: 1),
                    Text(
                      "Primary Education",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _primaryColor.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 8),
                    _buildEntryCard(
                      title: _educationEntries.first.degreeName,
                      subtitle:
                          '${_educationEntries.first.instituteName}\n${DateFormat.yMMMd().format(_educationEntries.first.startDate)} - ${_educationEntries.first.isPresent ? 'Present' : (_educationEntries.first.endDate != null ? DateFormat.yMMMd().format(_educationEntries.first.endDate!) : 'N/A')}',
                      onEdit: () => _showEducationForm(
                          educationToEdit: _educationEntries.first, index: 0),
                      onDelete: () =>
                          setState(() => _educationEntries.removeAt(0)),
                    ),
                  ]
                ],
              ),
              _buildSectionTile(
                title: 'Additional Education',
                icon: Icons.school_outlined,
                children: [
                  ..._educationEntries.skip(1).map((edu) {
                    int index = _educationEntries.indexOf(edu);
                    return _buildEntryCard(
                      title: edu.degreeName,
                      subtitle:
                          '${edu.instituteName}\n${DateFormat.yMMMd().format(edu.startDate)} - ${edu.isPresent ? 'Present' : (edu.endDate != null ? DateFormat.yMMMd().format(edu.endDate!) : '')}',
                      onEdit: () =>
                          _showEducationForm(educationToEdit: edu, index: index),
                      onDelete: () =>
                          setState(() => _educationEntries.removeAt(index)),
                    );
                  }),
                  if (_educationEntries.length > 1) const Divider(height: 32),
                  _EducationAddForm(
                    onAdd: (newEducation) {
                      setState(() => _educationEntries.add(newEducation));
                    },
                  ),
                ],
              ),
              _buildSectionTile(
                title: 'Experience',
                icon: Icons.work_outline,
                children: [
                  ..._experienceEntries.map((exp) {
                    int index = _experienceEntries.indexOf(exp);
                    return _buildEntryCard(
                      title: exp.title,
                      subtitle:
                          '${exp.organization}\n${DateFormat.yMMMd().format(exp.startDate)} - ${exp.isPresent ? 'Present' : (exp.endDate != null ? DateFormat.yMMMd().format(exp.endDate!) : '')}',
                      onEdit: () => _showExperienceForm(
                          experienceToEdit: exp, index: index),
                      onDelete: () =>
                          setState(() => _experienceEntries.removeAt(index)),
                    );
                  }),
                  if (_experienceEntries.isNotEmpty) const Divider(height: 32),
                  _ExperienceAddForm(onAdd: (newExperience) {
                    setState(() => _experienceEntries.add(newExperience));
                  }),
                ],
              ),
              _buildSectionTile(
                title: 'Extracurriculars',
                icon: Icons.groups_outlined,
                children: [
                  ..._extracurricularEntries.map((extra) {
                    int index = _extracurricularEntries.indexOf(extra);
                    String duration =
                        '${DateFormat.yMMMd().format(extra.startDate)} - ${extra.isPresent ? 'Present' : (extra.endDate != null ? DateFormat.yMMMd().format(extra.endDate!) : '')}';
                    String title = extra.role;
                    String subtitle = '${extra.organizationName}\n$duration';
                    return _buildEntryCard(
                      title: title,
                      subtitle: subtitle,
                      onEdit: () => _showExtracurricularForm(
                          extraToEdit: extra, index: index),
                      onDelete: () =>
                          setState(() => _extracurricularEntries.removeAt(index)),
                    );
                  }),
                  if (_extracurricularEntries.isNotEmpty)
                    const Divider(height: 32),
                  _ExtracurricularAddForm(onAdd: (newExtra) {
                    setState(() => _extracurricularEntries.add(newExtra));
                  }),
                ],
              ),
              _buildSectionTile(
                title: 'Projects',
                icon: Icons.code_outlined,
                children: [
                  ..._projectEntries.map((proj) {
                    int index = _projectEntries.indexOf(proj);
                    String subtitle = proj.description;
                    if (proj.link != null && proj.link!.isNotEmpty) {
                      subtitle += '\nLink: ${proj.link}';
                    }
                    return _buildEntryCard(
                      title: proj.title,
                      subtitle: subtitle,
                      onEdit: () =>
                          _showProjectForm(projectToEdit: proj, index: index),
                      onDelete: () =>
                          setState(() => _projectEntries.removeAt(index)),
                    );
                  }),
                  if (_projectEntries.isNotEmpty) const Divider(height: 32),
                  _ProjectAddForm(onAdd: (newProject) {
                    setState(() => _projectEntries.add(newProject));
                  }),
                ],
              ),
              _buildSectionTile(
                title: 'Skills',
                icon: Icons.lightbulb_outline,
                children: [_buildSkillsSectionContent()],
              ),
              _buildSectionTile(
                title: 'Licenses & Certifications',
                icon: Icons.badge_outlined,
                children: [
                  ..._licenseEntries.map((license) {
                    int index = _licenseEntries.indexOf(license);
                    String dates =
                        'Issued: ${DateFormat.yMMMd().format(license.issueDate)}';
                    if (license.expirationDate != null) {
                      dates +=
                          ' | Expires: ${DateFormat.yMMMd().format(license.expirationDate!)}';
                    }
                    return _buildEntryCard(
                      title: license.name,
                      subtitle: '${license.issuingOrganization}\n$dates',
                      onEdit: () =>
                          _showLicenseForm(licenseToEdit: license, index: index),
                      onDelete: () =>
                          setState(() => _licenseEntries.removeAt(index)),
                    );
                  }),
                  if (_licenseEntries.isNotEmpty) const Divider(height: 32),
                  _LicenseAddForm(onAdd: (newLicense) {
                    setState(() => _licenseEntries.add(newLicense));
                  }),
                ],
              ),
              _buildSectionTile(
                title: 'Awards',
                icon: Icons.emoji_events_outlined,
                children: [
                  ..._awardEntries.map((award) {
                    int index = _awardEntries.indexOf(award);
                    return _buildEntryCard(
                      title: award.title,
                      subtitle:
                          '${award.organization}\n${DateFormat.yMMMd().format(award.issueDate)}',
                      onEdit: () =>
                          _showAwardForm(awardToEdit: award, index: index),
                      onDelete: () =>
                          setState(() => _awardEntries.removeAt(index)),
                    );
                  }),
                  if (_awardEntries.isNotEmpty) const Divider(height: 32),
                  _AwardAddForm(onAdd: (newAward) {
                    setState(() => _awardEntries.add(newAward));
                  })
                ],
              ),
              _buildSectionTile(
                title: 'Custom Sections',
                icon: Icons.add_circle_outline,
                children: [
                  ..._customSections.map((section) {
                    int currentSectionIndex = _customSections.indexOf(section);
                    return Card(
                      elevation: 1.0,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(section.sectionTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                    icon:
                                        const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _showSectionTitleDialog(
                                        sectionIndex: currentSectionIndex),
                                    tooltip: 'Edit Title'),
                                IconButton(
                                    icon: const Icon(
                                        Icons.delete_forever_outlined,
                                        color: Colors.red,
                                        size: 20),
                                    onPressed: () => setState(() =>
                                        _customSections
                                            .removeAt(currentSectionIndex)),
                                    tooltip: 'Delete Section'),
                              ],
                            ),
                            const Divider(),
                            ...section.entries.map((entry) {
                              int entryIndex = section.entries.indexOf(entry);
                              String title = entry.title?.trim() ?? '';
                              if (title.isEmpty) title = 'Untitled Entry';

                              List<String> subtitleParts = [];
                              if (entry.startDate != null) {
                                String startDateStr = DateFormat.yMMMd()
                                    .format(entry.startDate!);
                                String endDateStr = entry.currently
                                    ? 'Present'
                                    : (entry.endDate != null
                                        ? DateFormat.yMMMd()
                                            .format(entry.endDate!)
                                        : '');
                                if (endDateStr.isNotEmpty) {
                                  subtitleParts
                                      .add('$startDateStr - $endDateStr');
                                } else {
                                  subtitleParts
                                      .add('Started: $startDateStr');
                                }
                              }
                              if (entry.description != null &&
                                  entry.description!.isNotEmpty) {
                                subtitleParts.add(entry.description!);
                              }
                              String subtitle = subtitleParts.join('\n');

                              return _buildEntryCard(
                                title: title,
                                subtitle: subtitle,
                                onEdit: () => _showCustomFieldEntryForm(
                                    sectionIndex: currentSectionIndex,
                                    entryIndex: entryIndex),
                                onDelete: () => setState(() =>
                                    _customSections[currentSectionIndex]
                                        .entries
                                        .removeAt(entryIndex)),
                              );
                            }),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Entry'),
                                onPressed: () => _showCustomFieldEntryForm(
                                    sectionIndex: currentSectionIndex),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showSectionTitleDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text("Add Custom Section"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor.withOpacity(0.1),
                          foregroundColor: _primaryColor,
                          elevation: 0),
                    ),
                  ),
                ],
              ),
              _buildSectionTile(
                title: 'Languages',
                icon: Icons.language_outlined,
                children: [
                  ..._languageEntries.map((lang) {
                    int index = _languageEntries.indexOf(lang);
                    return _buildEntryCard(
                      title: lang.name,
                      subtitle: lang.proficiency,
                      onEdit: () => _showLanguageForm(
                          languageToEdit: lang, index: index),
                      onDelete: () =>
                          setState(() => _languageEntries.removeAt(index)),
                    );
                  }),
                  if (_languageEntries.isNotEmpty) const Divider(height: 32),
                  _LanguageAddForm(onAdd: (newLang) {
                    setState(() => _languageEntries.add(newLang));
                  })
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSectionContent() {
    final skillController = TextEditingController();
    return Column(
      children: [
        if (_skills.isEmpty)
          const Center(
              child: Text('No skills added.',
                  style: TextStyle(color: Colors.grey))),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _skills
              .map((skill) => Chip(
                    label: Text(skill),
                    onDeleted: () => setState(() => _skills.remove(skill)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStyledTextFormField(
                controller: skillController,
                labelText: 'Add Skill',
                hintText: 'e.g., Python',
              ),
            ),
            IconButton(
              icon:
                  const Icon(Icons.add_circle, color: _primaryColor, size: 30),
              onPressed: () {
                if (skillController.text.trim().isNotEmpty) {
                  setState(() {
                    if (!_skills.contains(skillController.text.trim())) {
                      _skills.add(skillController.text.trim());
                    }
                    skillController.clear();
                  });
                }
              },
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTile(
      {required String title,
      required IconData icon,
      required List<Widget> children,
      bool initiallyExpanded = false}) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: _primaryColor),
        title: Text(
          title,
          style: GoogleFonts.lato(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        collapsedBackgroundColor: Colors.white,
        backgroundColor: const Color(0xFFFDFCFE),
        initiallyExpanded: initiallyExpanded,
        children: [
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
        childrenPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildEntryCard(
      {required String title,
      required String subtitle,
      required VoidCallback onEdit,
      required VoidCallback onDelete}) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: TextStyle(color: Colors.grey.shade700))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit'),
            IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete'),
          ],
        ),
      ),
    );
  }

  // --- MODAL FORM LAUNCHERS ---
  Future<void> _showSectionTitleDialog({int? sectionIndex}) async {
    final _titleController = TextEditingController(
        text: sectionIndex != null
            ? _customSections[sectionIndex].sectionTitle
            : '');
    final isEditing = sectionIndex != null;

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Section Title' : 'New Section Title'),
        content: TextField(
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Section Title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_titleController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() {
        if (isEditing) {
          _customSections[sectionIndex].sectionTitle = newTitle;
        } else {
          _customSections
              .add(CustomSection(sectionTitle: newTitle, entries: []));
        }
      });
    }
  }

  void _showEducationForm({Education? educationToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _EducationEditForm(
          education: educationToEdit,
          onSave: (updatedEducation) {
            setState(() {
              if (index != null) {
                _educationEntries[index] = updatedEducation;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showExperienceForm({Experience? experienceToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _ExperienceEditForm(
          experience: experienceToEdit,
          onSave: (updatedExperience) {
            setState(() {
              if (index != null) {
                _experienceEntries[index] = updatedExperience;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showAwardForm({Award? awardToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _AwardEditForm(
          award: awardToEdit,
          onSave: (updatedAward) {
            setState(() {
              if (index != null) {
                _awardEntries[index] = updatedAward;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showLanguageForm({Language? languageToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _LanguageEditForm(
          language: languageToEdit,
          onSave: (updatedLanguage) {
            setState(() {
              if (index != null) {
                _languageEntries[index] = updatedLanguage;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showProjectForm({Project? projectToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _ProjectEditForm(
          project: projectToEdit,
          onSave: (updatedProject) {
            setState(() {
              if (index != null) {
                _projectEntries[index] = updatedProject;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showCustomFieldEntryForm({required int sectionIndex, int? entryIndex}) {
    final isEditing = entryIndex != null;
    final entryToEdit =
        isEditing ? _customSections[sectionIndex].entries[entryIndex] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _CustomFieldEntryForm(
          entry: entryToEdit,
          onSave: (updatedEntry) {
            setState(() {
              if (isEditing) {
                _customSections[sectionIndex].entries[entryIndex] =
                    updatedEntry;
              } else {
                _customSections[sectionIndex].entries.add(updatedEntry);
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showExtracurricularForm({Extracurricular? extraToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _ExtracurricularEditForm(
          extra: extraToEdit,
          onSave: (updatedExtra) {
            setState(() {
              if (index != null) {
                _extracurricularEntries[index] = updatedExtra;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showLicenseForm({License? licenseToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: _LicenseEditForm(
          license: licenseToEdit,
          onSave: (updatedLicense) {
            setState(() {
              if (index != null) {
                _licenseEntries[index] = updatedLicense;
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

// --- ADD FORMS ---

class _EducationAddForm extends StatefulWidget {
  final Function(Education) onAdd;
  const _EducationAddForm({super.key, required this.onAdd});

  @override
  State<_EducationAddForm> createState() => _EducationAddFormState();
}

class _EducationAddFormState extends State<_EducationAddForm> {
  final _degreeController = TextEditingController();
  final _instituteController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;

  @override
  void dispose() {
    _degreeController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _degreeController.clear();
      _instituteController.clear();
      _startDate = null;
      _endDate = null;
      _isPresent = false;
    });
  }

  void _handleAdd() {
    if (_degreeController.text.isNotEmpty &&
        _instituteController.text.isNotEmpty &&
        _startDate != null) {
      final newEducation = Education(
        degreeName: _degreeController.text,
        instituteName: _instituteController.text,
        startDate: _startDate!,
        endDate: _endDate,
        isPresent: _isPresent,
      );
      widget.onAdd(newEducation);
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all required fields, including Start Date.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add New Education",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _instituteController,
            labelText: 'University/Institute*'),
        _buildStyledTextFormField(
            controller: _degreeController, labelText: 'Major/Degree Name*'),
        Row(
          children: [
            Expanded(
                child: Text(_startDate == null
                    ? 'No Start Date Selected*'
                    : 'Start Date: ${DateFormat.yMMMd().format(_startDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now());
                if (date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        if (!_isPresent)
          Row(
            children: [
              Expanded(
                  child: Text(_endDate == null
                      ? 'No Graduation Date Selected'
                      : 'Graduation: ${DateFormat.yMMMd().format(_endDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050));
                  if (date != null) setState(() => _endDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text("I am currently studying here"),
          value: _isPresent,
          onChanged: (val) {
            setState(() {
              _isPresent = val ?? false;
              if (_isPresent) {
                _endDate = null;
              }
            });
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add Education"),
          ),
        ),
      ],
    );
  }
}

class _ExperienceAddForm extends StatefulWidget {
  final Function(Experience) onAdd;
  const _ExperienceAddForm({required this.onAdd});

  @override
  State<_ExperienceAddForm> createState() => _ExperienceAddFormState();
}

class _ExperienceAddFormState extends State<_ExperienceAddForm> {
  final _titleController = TextEditingController();
  final _orgController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;
  String _type = 'Internship';

  @override
  void dispose() {
    _titleController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleController.clear();
    _orgController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _isPresent = false;
      _type = 'Internship';
    });
  }

  void _handleAdd() {
    if (_titleController.text.isNotEmpty &&
        _orgController.text.isNotEmpty &&
        _startDate != null) {
      widget.onAdd(Experience(
          organization: _orgController.text,
          title: _titleController.text,
          type: _type,
          startDate: _startDate!,
          endDate: _endDate,
          isPresent: _isPresent,
          locationType: 'On-site' // Default value
          ));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Experience",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _titleController, labelText: 'Title*'),
        _buildStyledTextFormField(
            controller: _orgController, labelText: 'Organization*'),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            'Internship',
            'Co-op',
            'Full-time',
            'Part-time',
            'Bootcamp',
            'Other'
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _type = val ?? 'Internship'),
        ),
        Row(
          children: [
            Expanded(
                child: Text(_startDate == null
                    ? 'No Start Date Selected*'
                    : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now());
                if (date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        if (!_isPresent)
          Row(
            children: [
              Expanded(
                  child: Text(_endDate == null
                      ? 'No End Date Selected'
                      : 'End: ${DateFormat.yMMMd().format(_endDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050));
                  if (date != null) setState(() => _endDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text("I currently work here"),
          value: _isPresent,
          onChanged: (val) {
            setState(() {
              _isPresent = val ?? false;
              if (_isPresent) _endDate = null;
            });
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add Experience"),
          ),
        ),
      ],
    );
  }
}

class _ExtracurricularAddForm extends StatefulWidget {
  final Function(Extracurricular) onAdd;
  const _ExtracurricularAddForm({super.key, required this.onAdd});

  @override
  State<_ExtracurricularAddForm> createState() =>
      _ExtracurricularAddFormState();
}

class _ExtracurricularAddFormState extends State<_ExtracurricularAddForm> {
  final _orgController = TextEditingController();
  final _eventController = TextEditingController();
  final _roleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;

  @override
  void dispose() {
    _orgController.dispose();
    _eventController.dispose();
    _roleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _orgController.clear();
      _eventController.clear();
      _roleController.clear();
      _descController.clear();
      _startDate = null;
      _endDate = null;
      _isPresent = false;
    });
  }

  void _handleAdd() {
    if (_orgController.text.isNotEmpty &&
        _roleController.text.isNotEmpty &&
        _startDate != null) {
      widget.onAdd(Extracurricular(
        organizationName: _orgController.text.trim(),
        eventName: _eventController.text.trim(),
        role: _roleController.text.trim(),
        description: _descController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        isPresent: _isPresent,
      ));
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill Organization, Role, and Start Date.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Extracurricular Activity",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _orgController, labelText: 'Organization Name*'),
        _buildStyledTextFormField(
            controller: _eventController, labelText: 'Event Name (Optional)'),
        _buildStyledTextFormField(
            controller: _roleController, labelText: 'Role*'),
        _buildStyledTextFormField(
            controller: _descController,
            labelText: 'Description (Optional)',
            maxLines: 3),
        Row(
          children: [
            Expanded(
                child: Text(_startDate == null
                    ? 'No Start Date*'
                    : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now());
                if (date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        if (!_isPresent)
          Row(
            children: [
              Expanded(
                  child: Text(_endDate == null
                      ? 'No End Date'
                      : 'End: ${DateFormat.yMMMd().format(_endDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050));
                  if (date != null) setState(() => _endDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text("I am currently active here"),
          value: _isPresent,
          onChanged: (val) {
            setState(() {
              _isPresent = val ?? false;
              if (_isPresent) _endDate = null;
            });
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add Activity"),
          ),
        ),
      ],
    );
  }
}

class _ProjectAddForm extends StatefulWidget {
  final Function(Project) onAdd;
  const _ProjectAddForm({super.key, required this.onAdd});

  @override
  State<_ProjectAddForm> createState() => _ProjectAddFormState();
}

class _ProjectAddFormState extends State<_ProjectAddForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _linkController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleController.clear();
    _descController.clear();
    _linkController.clear();
  }

  void _handleAdd() {
    if (_titleController.text.isNotEmpty && _descController.text.isNotEmpty) {
      widget.onAdd(Project(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        link: _linkController.text.trim(),
      ));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Project",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _titleController, labelText: 'Project Title*'),
        _buildStyledTextFormField(
            controller: _descController,
            labelText: 'Description*',
            maxLines: 3),
        _buildStyledTextFormField(
            controller: _linkController, labelText: 'URL / Link (Optional)'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add Project"),
          ),
        ),
      ],
    );
  }
}

class _LicenseAddForm extends StatefulWidget {
  final Function(License) onAdd;
  const _LicenseAddForm({super.key, required this.onAdd});

  @override
  State<_LicenseAddForm> createState() => _LicenseAddFormState();
}

class _LicenseAddFormState extends State<_LicenseAddForm> {
  final _nameController = TextEditingController();
  final _orgController = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expDate;

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _orgController.clear();
      _issueDate = null;
      _expDate = null;
    });
  }

  void _handleAdd() {
    if (_nameController.text.isNotEmpty &&
        _orgController.text.isNotEmpty &&
        _issueDate != null) {
      widget.onAdd(License(
        name: _nameController.text.trim(),
        issuingOrganization: _orgController.text.trim(),
        issueDate: _issueDate!,
        expirationDate: _expDate,
      ));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add License or Certification",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _nameController, labelText: 'Certification Name*'),
        _buildStyledTextFormField(
            controller: _orgController, labelText: 'Issuing Organization*'),
        Row(
          children: [
            Expanded(
                child: Text(_issueDate == null
                    ? 'No Issue Date*'
                    : 'Issued: ${DateFormat.yMMMd().format(_issueDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now());
                if (date != null) setState(() => _issueDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        Row(
          children: [
            Expanded(
                child: Text(_expDate == null
                    ? 'No Expiration Date'
                    : 'Expires: ${DateFormat.yMMMd().format(_expDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: _issueDate ?? DateTime.now(),
                    firstDate: _issueDate ?? DateTime(1980),
                    lastDate: DateTime(2100));
                if (date != null) setState(() => _expDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add License"),
          ),
        ),
      ],
    );
  }
}

class _AwardAddForm extends StatefulWidget {
  final Function(Award) onAdd;
  const _AwardAddForm({required this.onAdd});

  @override
  State<_AwardAddForm> createState() => _AwardAddFormState();
}

class _AwardAddFormState extends State<_AwardAddForm> {
  final _titleController = TextEditingController();
  final _orgController = TextEditingController();
  DateTime? _issueDate;

  @override
  void dispose() {
    _titleController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _titleController.clear();
    _orgController.clear();
    setState(() => _issueDate = null);
  }

  void _handleAdd() {
    if (_titleController.text.isNotEmpty &&
        _orgController.text.isNotEmpty &&
        _issueDate != null) {
      widget.onAdd(Award(
          title: _titleController.text,
          organization: _orgController.text,
          issueDate: _issueDate!,
          description: '' // Optional, can be added in edit
          ));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Award",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _titleController, labelText: 'Title*'),
        _buildStyledTextFormField(
            controller: _orgController, labelText: 'Issuing Organization*'),
        Row(
          children: [
            Expanded(
                child: Text(_issueDate == null
                    ? 'No Issue Date Selected*'
                    : 'Date: ${DateFormat.yMMMd().format(_issueDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now());
                if (date != null) setState(() => _issueDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add Award"),
          ),
        ),
      ],
    );
  }
}

class _LanguageAddForm extends StatefulWidget {
  final Function(Language) onAdd;
  const _LanguageAddForm({required this.onAdd});

  @override
  State<_LanguageAddForm> createState() => _LanguageAddFormState();
}

class _LanguageAddFormState extends State<_LanguageAddForm> {
  final _nameController = TextEditingController();
  String _proficiency = 'Conversational';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    setState(() => _proficiency = 'Conversational');
  }

  void _handleAdd() {
    if (_nameController.text.isNotEmpty) {
      widget.onAdd(
          Language(name: _nameController.text, proficiency: _proficiency));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Language",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _nameController, labelText: 'Language*'),
        DropdownButtonFormField<String>(
          value: _proficiency,
          decoration: const InputDecoration(labelText: 'Proficiency'),
          items: ['Beginner', 'Conversational', 'Fluent', 'Native']
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (val) =>
              setState(() => _proficiency = val ?? 'Conversational'),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _handleAdd,
            icon: const Icon(Icons.add),
            label: const Text("Add Language"),
          ),
        ),
      ],
    );
  }
}

// --- EDIT FORMS ---

class _EducationEditForm extends StatefulWidget {
  final Education? education;
  final Function(Education) onSave;

  const _EducationEditForm({this.education, required this.onSave});

  @override
  State<_EducationEditForm> createState() => _EducationEditFormState();
}

class _EducationEditFormState extends State<_EducationEditForm> {
  late TextEditingController _degreeController;
  late TextEditingController _instituteController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;

  @override
  void initState() {
    super.initState();
    final edu = widget.education;
    _degreeController = TextEditingController(text: edu?.degreeName ?? '');
    _instituteController =
        TextEditingController(text: edu?.instituteName ?? '');
    _startDate = edu?.startDate;
    _endDate = edu?.endDate;
    _isPresent = edu?.isPresent ?? false;
  }

  @override
  void dispose() {
    _degreeController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_degreeController.text.isNotEmpty &&
        _instituteController.text.isNotEmpty &&
        _startDate != null) {
      final updatedEducation = Education(
        degreeName: _degreeController.text,
        instituteName: _instituteController.text,
        startDate: _startDate!,
        endDate: _endDate,
        isPresent: _isPresent,
      );
      widget.onSave(updatedEducation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all required fields, including Start Date.'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Education",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _instituteController,
              labelText: 'University/Institute*'),
          _buildStyledTextFormField(
              controller: _degreeController, labelText: 'Major/Degree Name*'),
          Row(
            children: [
              Expanded(
                  child: Text(_startDate == null
                      ? 'No Start Date Selected*'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          if (!_isPresent)
            Row(
              children: [
                Expanded(
                    child: Text(_endDate == null
                        ? 'No Graduation Date'
                        : 'Graduation: ${DateFormat.yMMMd().format(_endDate!)}')),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(1980),
                        lastDate: DateTime(2050));
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                )
              ],
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I am currently studying here"),
            value: _isPresent,
            onChanged: (val) {
              setState(() {
                _isPresent = val ?? false;
                if (_isPresent) _endDate = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExperienceEditForm extends StatefulWidget {
  final Experience? experience;
  final Function(Experience) onSave;

  const _ExperienceEditForm({this.experience, required this.onSave});

  @override
  State<_ExperienceEditForm> createState() => _ExperienceEditFormState();
}

class _ExperienceEditFormState extends State<_ExperienceEditForm> {
  late TextEditingController _titleController;
  late TextEditingController _orgController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;
  late String _type;

  @override
  void initState() {
    super.initState();
    final exp = widget.experience;
    _titleController = TextEditingController(text: exp?.title ?? '');
    _orgController = TextEditingController(text: exp?.organization ?? '');
    _startDate = exp?.startDate;
    _endDate = exp?.endDate;
    _isPresent = exp?.isPresent ?? false;
    _type = exp?.type ?? 'Internship';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_titleController.text.isNotEmpty &&
        _orgController.text.isNotEmpty &&
        _startDate != null) {
      final updatedExperience = Experience(
        title: _titleController.text,
        organization: _orgController.text,
        startDate: _startDate!,
        endDate: _endDate,
        isPresent: _isPresent,
        type: _type,
        locationType: widget.experience?.locationType ?? 'On-site',
      );
      widget.onSave(updatedExperience);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Experience",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _titleController, labelText: 'Title*'),
          _buildStyledTextFormField(
              controller: _orgController, labelText: 'Organization*'),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              'Internship',
              'Co-op',
              'Full-time',
              'Part-time',
              'Bootcamp',
              'Other'
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() => _type = val ?? 'Internship'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: Text(_startDate == null
                      ? 'No Start Date Selected*'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          if (!_isPresent)
            Row(
              children: [
                Expanded(
                    child: Text(_endDate == null
                        ? 'No End Date Selected'
                        : 'End: ${DateFormat.yMMMd().format(_endDate!)}')),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(1980),
                        lastDate: DateTime(2050));
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                )
              ],
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I currently work here"),
            value: _isPresent,
            onChanged: (val) {
              setState(() {
                _isPresent = val ?? false;
                if (_isPresent) _endDate = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExtracurricularEditForm extends StatefulWidget {
  final Extracurricular? extra;
  final Function(Extracurricular) onSave;
  const _ExtracurricularEditForm({this.extra, required this.onSave});

  @override
  State<_ExtracurricularEditForm> createState() =>
      _ExtracurricularEditFormState();
}

class _ExtracurricularEditFormState extends State<_ExtracurricularEditForm> {
  late TextEditingController _orgController;
  late TextEditingController _eventController;
  late TextEditingController _roleController;
  late TextEditingController _descController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;

  @override
  void initState() {
    super.initState();
    final extra = widget.extra;
    _orgController = TextEditingController(text: extra?.organizationName ?? '');
    _eventController = TextEditingController(text: extra?.eventName ?? '');
    _roleController = TextEditingController(text: extra?.role ?? '');
    _descController = TextEditingController(text: extra?.description ?? '');
    _startDate = extra?.startDate;
    _endDate = extra?.endDate;
    _isPresent = extra?.isPresent ?? false;
  }

  @override
  void dispose() {
    _orgController.dispose();
    _eventController.dispose();
    _roleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_orgController.text.isNotEmpty &&
        _roleController.text.isNotEmpty &&
        _startDate != null) {
      widget.onSave(Extracurricular(
        organizationName: _orgController.text.trim(),
        eventName: _eventController.text.trim(),
        role: _roleController.text.trim(),
        description: _descController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate,
        isPresent: _isPresent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Extracurricular Activity",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _orgController, labelText: 'Organization Name*'),
          _buildStyledTextFormField(
              controller: _eventController,
              labelText: 'Event Name (Optional)'),
          _buildStyledTextFormField(
              controller: _roleController, labelText: 'Role*'),
          _buildStyledTextFormField(
              controller: _descController,
              labelText: 'Description (Optional)',
              maxLines: 3),
          Row(
            children: [
              Expanded(
                  child: Text(_startDate == null
                      ? 'No Start Date*'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          if (!_isPresent)
            Row(
              children: [
                Expanded(
                    child: Text(_endDate == null
                        ? 'No End Date'
                        : 'End: ${DateFormat.yMMMd().format(_endDate!)}')),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(1980),
                        lastDate: DateTime(2050));
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                )
              ],
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I am currently active here"),
            value: _isPresent,
            onChanged: (val) {
              setState(() {
                _isPresent = val ?? false;
                if (_isPresent) _endDate = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LicenseEditForm extends StatefulWidget {
  final License? license;
  final Function(License) onSave;
  const _LicenseEditForm({this.license, required this.onSave});
  @override
  State<_LicenseEditForm> createState() => _LicenseEditFormState();
}

class _LicenseEditFormState extends State<_LicenseEditForm> {
  late TextEditingController _nameController;
  late TextEditingController _orgController;
  DateTime? _issueDate;
  DateTime? _expDate;

  @override
  void initState() {
    super.initState();
    final license = widget.license;
    _nameController = TextEditingController(text: license?.name ?? '');
    _orgController =
        TextEditingController(text: license?.issuingOrganization ?? '');
    _issueDate = license?.issueDate;
    _expDate = license?.expirationDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_nameController.text.isNotEmpty &&
        _orgController.text.isNotEmpty &&
        _issueDate != null) {
      widget.onSave(License(
        name: _nameController.text.trim(),
        issuingOrganization: _orgController.text.trim(),
        issueDate: _issueDate!,
        expirationDate: _expDate,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit License or Certification",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _nameController, labelText: 'Certification Name*'),
          _buildStyledTextFormField(
              controller: _orgController, labelText: 'Issuing Organization*'),
          Row(
            children: [
              Expanded(
                  child: Text(_issueDate == null
                      ? 'No Issue Date*'
                      : 'Issued: ${DateFormat.yMMMd().format(_issueDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _issueDate ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (date != null) setState(() => _issueDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: Text(_expDate == null
                      ? 'No Expiration Date'
                      : 'Expires: ${DateFormat.yMMMd().format(_expDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _expDate ?? _issueDate ?? DateTime.now(),
                      firstDate: _issueDate ?? DateTime(1980),
                      lastDate: DateTime(2100));
                  if (date != null) setState(() => _expDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AwardEditForm extends StatefulWidget {
  final Award? award;
  final Function(Award) onSave;

  const _AwardEditForm({this.award, required this.onSave});

  @override
  State<_AwardEditForm> createState() => _AwardEditFormState();
}

class _AwardEditFormState extends State<_AwardEditForm> {
  late TextEditingController _titleController;
  late TextEditingController _orgController;
  late TextEditingController _descController;
  DateTime? _issueDate;

  @override
  void initState() {
    super.initState();
    final award = widget.award;
    _titleController = TextEditingController(text: award?.title ?? '');
    _orgController = TextEditingController(text: award?.organization ?? '');
    _descController = TextEditingController(text: award?.description ?? '');
    _issueDate = award?.issueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _orgController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_titleController.text.isNotEmpty &&
        _orgController.text.isNotEmpty &&
        _issueDate != null) {
      final updatedAward = Award(
        title: _titleController.text,
        organization: _orgController.text,
        issueDate: _issueDate!,
        description: _descController.text,
      );
      widget.onSave(updatedAward);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Award",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _titleController, labelText: 'Title*'),
          _buildStyledTextFormField(
              controller: _orgController, labelText: 'Issuing Organization*'),
          _buildStyledTextFormField(
              controller: _descController,
              labelText: 'Description (Optional)',
              maxLines: 3),
          Row(
            children: [
              Expanded(
                  child: Text(_issueDate == null
                      ? 'No Issue Date Selected*'
                      : 'Date: ${DateFormat.yMMMd().format(_issueDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _issueDate ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (date != null) setState(() => _issueDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _LanguageEditForm extends StatefulWidget {
  final Language? language;
  final Function(Language) onSave;

  const _LanguageEditForm({this.language, required this.onSave});

  @override
  State<_LanguageEditForm> createState() => _LanguageEditFormState();
}

class _LanguageEditFormState extends State<_LanguageEditForm> {
  late TextEditingController _nameController;
  late String _proficiency;

  @override
  void initState() {
    super.initState();
    final lang = widget.language;
    _nameController = TextEditingController(text: lang?.name ?? '');
    _proficiency = lang?.proficiency ?? 'Conversational';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_nameController.text.isNotEmpty) {
      final updatedLanguage = Language(
        name: _nameController.text,
        proficiency: _proficiency,
      );
      widget.onSave(updatedLanguage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Language",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _nameController, labelText: 'Language*'),
          DropdownButtonFormField<String>(
            value: _proficiency,
            decoration: const InputDecoration(labelText: 'Proficiency'),
            items: ['Beginner', 'Conversational', 'Fluent', 'Native']
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (val) =>
                setState(() => _proficiency = val ?? 'Conversational'),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ProjectEditForm extends StatefulWidget {
  final Project? project;
  final Function(Project) onSave;

  const _ProjectEditForm({this.project, required this.onSave});

  @override
  State<_ProjectEditForm> createState() => _ProjectEditFormState();
}

class _ProjectEditFormState extends State<_ProjectEditForm> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _linkController;

  @override
  void initState() {
    super.initState();
    final proj = widget.project;
    _titleController = TextEditingController(text: proj?.title ?? '');
    _descController = TextEditingController(text: proj?.description ?? '');
    _linkController = TextEditingController(text: proj?.link ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_titleController.text.isNotEmpty && _descController.text.isNotEmpty) {
      final updatedProject = Project(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        link: _linkController.text.trim(),
      );
      widget.onSave(updatedProject);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Project",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _titleController, labelText: 'Project Title*'),
          _buildStyledTextFormField(
              controller: _descController,
              labelText: 'Description*',
              maxLines: 3),
          _buildStyledTextFormField(
              controller: _linkController, labelText: 'URL / Link (Optional)'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CustomFieldEntryForm extends StatefulWidget {
  final CustomFieldEntry? entry;
  final Function(CustomFieldEntry) onSave;

  const _CustomFieldEntryForm({this.entry, required this.onSave});

  @override
  State<_CustomFieldEntryForm> createState() => _CustomFieldEntryFormState();
}

class _CustomFieldEntryFormState extends State<_CustomFieldEntryForm> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _currently;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _descController = TextEditingController(text: entry?.description ?? '');
    _startDate = entry?.startDate;
    _endDate = entry?.endDate;
    _currently = entry?.currently ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_titleController.text.trim().isNotEmpty ||
        _descController.text.trim().isNotEmpty ||
        _startDate != null) {
      final updatedEntry = CustomFieldEntry(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        currently: _currently,
      );
      widget.onSave(updatedEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.entry == null ? "Add Entry" : "Edit Entry",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
              controller: _titleController, labelText: 'Title (Optional)'),
          _buildStyledTextFormField(
              controller: _descController,
              labelText: 'Description (Optional)',
              maxLines: 3),
          Row(
            children: [
              Expanded(
                  child: Text(_startDate == null
                      ? 'No Start Date'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now());
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              )
            ],
          ),
          if (!_currently)
            Row(
              children: [
                Expanded(
                    child: Text(_endDate == null
                        ? 'No End Date'
                        : 'End: ${DateFormat.yMMMd().format(_endDate!)}')),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(1980),
                        lastDate: DateTime(2050));
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                )
              ],
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I am currently active here"),
            value: _currently,
            onChanged: (val) {
              setState(() {
                _currently = val ?? false;
                if (_currently) _endDate = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text("Save Changes"),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// --- Top-Level Helper Function ---
Widget _buildStyledTextFormField(
    {required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    ),
  );
}