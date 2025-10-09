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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    final student = widget.student;

    if (resume != null) {
      // Editing mode
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
    } else {
      // Creating mode
      _titleController = TextEditingController(text: 'My Resume');
      _firstNameController = TextEditingController(text: student.firstName);
      _lastNameController = TextEditingController(text: student.lastName);
      _emailController = TextEditingController(text: student.email);
      _phoneController = TextEditingController(text: student.phoneNumber);
      _summaryController = TextEditingController(text: student.shortSummary);
      _skills = List<String>.from(student.skills);
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

  /// Saves the resume after validating the form. Used by the main save button.
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

  /// Saves the current state as a draft without validation. Used by the back button.
  Future<void> _saveDraft() async {
    // Only save a draft if the resume already exists in the database.
    if (widget.resume?.id == null) {
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving draft...'), duration: Duration(seconds: 1)),
      );
    }
    await _performSave();
  }

  /// The core save logic used by both save and draft methods.
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

  /// Intercepts the back button press to save a draft.
  Future<bool> _onWillPop() async {
    await _saveDraft();
    return true; // Return true to allow the screen to pop.
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the Scaffold with WillPopScope to handle the back button press
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
                      icon: const Icon(Icons.save_outlined), // Classic save icon
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
                ],
              ),
              _buildSectionTile(
                title: 'Education',
                icon: Icons.school_outlined,
                children: [
                  ..._educationEntries.map((edu) {
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
                  if (_educationEntries.isNotEmpty) const Divider(height: 32),
                  _EducationAddForm(
                    student: widget.student,
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
                if(_experienceEntries.isNotEmpty) const Divider(height: 32),
                 _ExperienceAddForm(onAdd: (newExperience) {
                  setState(() => _experienceEntries.add(newExperience));
                }),
              ],
            ),
            _buildSectionTile(
              title: 'Skills',
              icon: Icons.lightbulb_outline,
              children: [_buildSkillsSectionContent()],
            ),
            _buildSectionTile(
              title: 'Awards',
              icon: Icons.emoji_events_outlined,
              children: [
                ..._awardEntries.map((award){
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
                 _AwardAddForm(onAdd: (newAward){
                   setState(() => _awardEntries.add(newAward));
                 })
              ],
            ),
            _buildSectionTile(
              title: 'Languages',
              icon: Icons.language_outlined,
              children: [
                ..._languageEntries.map((lang){
                  int index = _languageEntries.indexOf(lang);
                   return _buildEntryCard(
                    title: lang.name,
                    subtitle: lang.proficiency,
                    onEdit: () =>
                        _showLanguageForm(languageToEdit: lang, index: index),
                    onDelete: () =>
                        setState(() => _languageEntries.removeAt(index)),
                  );
                }),
                if (_languageEntries.isNotEmpty) const Divider(height: 32),
                _LanguageAddForm(onAdd: (newLang){
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
              child:
                  Text('No skills added.', style: TextStyle(color: Colors.grey))),
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
              icon: const Icon(Icons.add_circle, color: _primaryColor, size: 30),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
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

   void _showEducationForm({Education? educationToEdit, int? index}) {/* ... */}
   void _showExperienceForm({Experience? experienceToEdit, int? index}) {/* ... */}
   void _showAwardForm({Award? awardToEdit, int? index}) {/* ... */}
   void _showLanguageForm({Language? languageToEdit, int? index}) {/* ... */}
}

// --- Inline Add Forms (as separate StatefulWidget) ---

class _EducationAddForm extends StatefulWidget {
  final Function(Education) onAdd;
  final Student student;
  const _EducationAddForm({required this.onAdd, required this.student});

  @override
  State<_EducationAddForm> createState() => _EducationAddFormState();
}

class _EducationAddFormState extends State<_EducationAddForm> {
  late TextEditingController _degreeController;
  late TextEditingController _instituteController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // REFINED: Auto-fills the form using the actual student profile data.
    final level = widget.student.level ?? '';
    final major = widget.student.major ?? '';
    String degreeText = '$level $major'.trim();

    // Combine level and major into a more readable format
    if (level.isNotEmpty && major.isNotEmpty) {
      degreeText = '$level in $major';
    }

    _degreeController = TextEditingController(text: degreeText);
    _instituteController = TextEditingController(text: widget.student.university);

    // Safely parse the graduation date string from the student's profile
    if (widget.student.expectedGraduationDate != null &&
        widget.student.expectedGraduationDate!.isNotEmpty) {
      _endDate = DateTime.tryParse(widget.student.expectedGraduationDate!);
    } else {
      _endDate = null;
    }
  }

  @override
  void dispose() {
    _degreeController.dispose();
    _instituteController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _initializeFormData(); // Reset to student profile defaults
      _startDate = null;
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
        Text("Add Education",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
            controller: _instituteController, labelText: 'University/Institute*'),
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
                      ? 'No Expected Graduation Date'
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
              } else {
                 if (widget.student.expectedGraduationDate != null &&
                    widget.student.expectedGraduationDate!.isNotEmpty) {
                   _endDate = DateTime.tryParse(widget.student.expectedGraduationDate!);
                 }
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

  void _resetForm(){
    _titleController.clear();
    _orgController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _isPresent = false;
      _type = 'Internship';
    });
  }

  void _handleAdd(){
    if(_titleController.text.isNotEmpty && _orgController.text.isNotEmpty && _startDate != null){
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
        Text("Add Experience", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(controller: _titleController, labelText: 'Title*'),
        _buildStyledTextFormField(controller: _orgController, labelText: 'Organization*'),
         DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: ['Internship', 'Co-op', 'Full-time', 'Part-time', 'Bootcamp', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _type = val ?? 'Internship'),
        ),
        Row(
          children: [
            Expanded(child: Text(_startDate == null ? 'No Start Date Selected*' : 'Start: ${DateFormat.yMMMd().format(_startDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1980), lastDate: DateTime.now());
                if(date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            )
          ],
        ),
        if (!_isPresent) Row(
          children: [
            Expanded(child: Text(_endDate == null ? 'No End Date Selected' : 'End: ${DateFormat.yMMMd().format(_endDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime(1980), lastDate: DateTime(2050));
                if(date != null) setState(() => _endDate = date);
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
              if(_isPresent) _endDate = null;
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

  void _resetForm(){
    _titleController.clear();
    _orgController.clear();
    setState(() => _issueDate = null);
  }

  void _handleAdd(){
    if(_titleController.text.isNotEmpty && _orgController.text.isNotEmpty && _issueDate != null){
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
        Text("Add Award", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(controller: _titleController, labelText: 'Title*'),
        _buildStyledTextFormField(controller: _orgController, labelText: 'Issuing Organization*'),
        Row(
          children: [
            Expanded(child: Text(_issueDate == null ? 'No Issue Date Selected*' : 'Date: ${DateFormat.yMMMd().format(_issueDate!)}')),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1980), lastDate: DateTime.now());
                if(date != null) setState(() => _issueDate = date);
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

  void _resetForm(){
    _nameController.clear();
    setState(() => _proficiency = 'Conversational');
  }

  void _handleAdd(){
    if(_nameController.text.isNotEmpty){
      widget.onAdd(Language(name: _nameController.text, proficiency: _proficiency));
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Language", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildStyledTextFormField(controller: _nameController, labelText: 'Language*'),
        DropdownButtonFormField<String>(
          value: _proficiency,
          decoration: const InputDecoration(labelText: 'Proficiency'),
          items: ['Beginner', 'Conversational', 'Fluent', 'Native'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (val) => setState(() => _proficiency = val ?? 'Conversational'),
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