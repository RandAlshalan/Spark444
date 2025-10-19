import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/resume.dart';
import 'package:my_app/models/student.dart';

// --- Color Constants ---
// These are defined here so we can reuse them easily
const Color _primaryColor = Color(0xFF422F5D);
const Color _backgroundColor = Color(0xFFF8F9FA);
// --- MODIFICATION: Request 1 (Save Button Color) ---
// Added a color for the save button
const Color _saveButtonColor = Colors.teal;
// --------------------------------------------------

// -------------------------------------------------------------------
// 1. THE MAIN SCREEN WIDGET
// -------------------------------------------------------------------

/// This is the main form screen. It is a "StatefulWidget"
/// because it needs to manage all the data the user enters.
///
/// It works in two modes:
/// 1. **Create Mode:** If `resume` is `null`, it shows a blank form (pre-filled from the student's profile).
/// 2. **Edit Mode:** If a `resume` is passed in, it fills the form with that resume's data.
class ResumeFormScreen extends StatefulWidget {
  final Student student;
  final Resume? resume; // This is null when creating a new resume

  const ResumeFormScreen({super.key, required this.student, this.resume});

  @override
  State<ResumeFormScreen> createState() => _ResumeFormScreenState();
}

// -------------------------------------------------------------------
// 2. THE MAIN SCREEN'S STATE AND LOGIC
// -------------------------------------------------------------------

/// This is the "brain" of the form screen. It holds all the data
/// and logic for the *entire* page.
class _ResumeFormScreenState extends State<ResumeFormScreen> {
  // --- STATE VARIABLES ---

  // A global key to identify and validate our form
  final _formKey = GlobalKey<FormState>();

  // Controllers for the main, "static" text fields
  late TextEditingController _titleController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _summaryController;

  // These lists hold the data for all the "dynamic" sections.
  // When a user adds a new "Experience", it gets added to this list.
  List<Education> _educationEntries = [];
  List<Experience> _experienceEntries = [];
  List<Award> _awardEntries = [];
  List<Language> _languageEntries = [];
  List<String> _skills = [];
  List<Project> _projectEntries = [];
  List<Extracurricular> _extracurricularEntries = [];
  List<License> _licenseEntries = [];
  List<CustomSection> _customSections = [];

  // A flag to show a loading spinner when saving to the database
  bool _isLoading = false;

  // --- MODIFICATION: Request 3 (Back Warning) ---
  // Tracks if the user has made any changes to the form.
  bool _isDirty = false;
  // ----------------------------------------------

  // --- LIFECYCLE METHODS ---

  /// This function runs *once* when the screen is first opened.
  /// Its job is to set up all the controllers and lists.
  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    final student = widget.student;

    if (resume != null) {
      // --- EDITING MODE ---
      // We are editing an existing resume, so we fill all
      // controllers and lists with the resume's data.
      _titleController = TextEditingController(text: resume.title);
      _firstNameController = TextEditingController(
        text: resume.personalDetails['firstName'] ?? '',
      );
      _lastNameController = TextEditingController(
        text: resume.personalDetails['lastName'] ?? '',
      );
      _emailController = TextEditingController(
        text: resume.personalDetails['email'] ?? '',
      );
      _phoneController = TextEditingController(
        text: resume.personalDetails['phone'] ?? '',
      );
      _summaryController = TextEditingController(
        text: resume.personalDetails['summary'] ?? '',
      );

      // We create new lists from the resume data.
      _educationEntries = List<Education>.from(resume.education);
      _experienceEntries = List<Experience>.from(resume.experiences);
      _awardEntries = List<Award>.from(resume.awards);
      _languageEntries = List<Language>.from(resume.languages);
      _skills = List<String>.from(resume.skills);
      _projectEntries = List<Project>.from(resume.projects);
      _extracurricularEntries = List<Extracurricular>.from(
        resume.extracurriculars,
      );
      _licenseEntries = List<License>.from(resume.licenses);
      _customSections = List<CustomSection>.from(resume.customSections);
    } else {
      // --- CREATING MODE ---
      // This is a new resume, so we "pre-populate" the form
      // with data from the student's profile to save them time.
      _titleController = TextEditingController(text: 'My Resume');
      _firstNameController = TextEditingController(text: student.firstName);
      _lastNameController = TextEditingController(text: student.lastName);
      _emailController = TextEditingController(text: student.email);
      _phoneController = TextEditingController(text: student.phoneNumber);
      _summaryController = TextEditingController(text: student.shortSummary);
      _skills = List<String>.from(student.skills);

      // Initialize empty lists for the other sections
      _projectEntries = [];
      _extracurricularEntries = [];
      _licenseEntries = [];
      _customSections = [];

      // Also pre-populate their main education from their profile
      if (student.university != null && student.university!.isNotEmpty) {
        String degreeText = '${student.level ?? ''} ${student.major ?? ''}'
            .trim();
        if ((student.level?.isNotEmpty ?? false) &&
            (student.major?.isNotEmpty ?? false)) {
          degreeText = '${student.level} in ${student.major}';
        }

        // 1. Create a helper variable for the date
        DateTime? expectedGraduation;
        final String gradDateString = student.expectedGraduationDate ?? '';

        // 2. Check if the string is not empty
        if (gradDateString.isNotEmpty) {
          try {
            // 3. Use DateFormat to parse "Month YYYY" (e.g., "June 2026")
            // We use 'MMMM yyyy' which means "Full Month Name" + "Year"
            final format = DateFormat('MMMM yyyy');
            expectedGraduation = format.parse(gradDateString);
          } catch (e) {
            // If parsing fails (e.g., the format is "Jun 2026" instead of "June 2026")
            // it will just stay null, which is fine.
            print('Error parsing graduation date "$gradDateString": $e');
            expectedGraduation = null;
          }
        }

        // 4. Add the education entry using the new variable
        _educationEntries.add(
          Education(
            instituteName: student.university!,
            degreeName: degreeText,
            startDate: DateTime.now(), // You might want to change this later
            endDate: expectedGraduation, // <-- Use the correctly parsed date
            isPresent: false,
          ),
        );
      }
    }

    // --- MODIFICATION: Request 3 (Back Warning) ---
    // Add listeners to all text controllers to track changes
    _titleController.addListener(_markDirty);
    _firstNameController.addListener(_markDirty);
    _lastNameController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _summaryController.addListener(_markDirty);
    // ----------------------------------------------
  }

  /// This cleans up the controllers when the screen is closed
  /// to prevent memory leaks.
  @override
  void dispose() {
    // --- MODIFICATION: Request 3 (Back Warning) ---
    // Remove listeners to prevent memory leaks
    _titleController.removeListener(_markDirty);
    _firstNameController.removeListener(_markDirty);
    _lastNameController.removeListener(_markDirty);
    _emailController.removeListener(_markDirty);
    _phoneController.removeListener(_markDirty);
    _summaryController.removeListener(_markDirty);
    // ----------------------------------------------

    _titleController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  // --- CORE LOGIC (SAVING & NAVIGATION) ---

  // --- MODIFICATION: Request 3 (Back Warning) ---
  /// Sets the `_isDirty` flag to true when any change is made.
  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }
  // ----------------------------------------------

  /// This is called when the user presses the "Save" icon in the app bar.
  Future<void> _saveResume() async {
    // First, check if all required fields (like 'First Name') are valid
    if (!_formKey.currentState!.validate()) {
      // If not, show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // --- MODIFICATION: Request 4 (Unique Title) ---
    // Check if the resume title is unique for this student
    final title = _titleController.text.trim();

    final query = FirebaseFirestore.instance
        .collection('resumes')
        .where('studentId', isEqualTo: widget.student.id)
        .where('title', isEqualTo: title);

    final snapshot = await query.get();

    bool isDuplicate = false;
    if (snapshot.docs.isNotEmpty) {
      if (widget.resume == null) {
        // CREATE MODE: Any result is a duplicate
        isDuplicate = true;
      } else {
        // EDIT MODE: It's a duplicate ONLY if the found doc ID is DIFFERENT
        // from the one we are editing.
        isDuplicate = snapshot.docs.any((doc) => doc.id != widget.resume!.id);
      }
    }

    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'A resume with this title already exists. Please use a unique title.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return; // Stop the save
    }
    // --- End of unique title check ---

    // Show the loading spinner
    setState(() => _isLoading = true);

    // Call the function that does the actual database work
    await _performSave();

    // After saving, close the form screen
    if (mounted) Navigator.of(context).pop();
  }

  /// This is called by `_onWillPop` to auto-save when the user hits 'back'.
  /// It only works if we are *editing* (the resume already has an ID).
  Future<void> _saveDraft() async {
    if (widget.resume?.id == null) return; // Don't save draft for new resumes
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving draft...'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    await _performSave();
  }

  /// This is the *real* save function that talks to Firestore.
  Future<void> _performSave() async {
    // 1. Collect all the data from controllers into a Map
    final personalDetails = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'summary': _summaryController.text.trim(),
    };

    // 2. Collect all data from state lists into a final 'resumeData' Map
    final resumeData = {
      'studentId': widget.student.id,
      'title': _titleController.text.trim(),
      'personalDetails': personalDetails,
      // We use .map() to convert our list of objects into a list of Maps,
      // which is what Firestore understands.
      'education': _educationEntries.map((e) => e.toMap()).toList(),
      'experiences': _experienceEntries.map((e) => e.toMap()).toList(),
      'skills': _skills,
      'awards': _awardEntries.map((a) => a.toMap()).toList(),
      'languages': _languageEntries.map((l) => l.toMap()).toList(),
      'projects': _projectEntries.map((p) => p.toMap()).toList(),
      'extracurriculars': _extracurricularEntries
          .map((e) => e.toMap())
          .toList(),
      'licenses': _licenseEntries.map((l) => l.toMap()).toList(),
      'customSections': _customSections.map((cs) => cs.toMap()).toList(),
      'lastModifiedAt': FieldValue.serverTimestamp(), // Update the timestamp
    };

    try {
      // 3. Save to Firestore
      if (widget.resume != null) {
        // --- UPDATE ---
        // If we are in "Edit Mode", we *update* the existing document.
        await FirebaseFirestore.instance
            .collection('resumes')
            .doc(widget.resume!.id)
            .update(resumeData);
      } else {
        // --- ADD ---
        // If we are in "Create Mode", we *add* a new document.
        await FirebaseFirestore.instance.collection('resumes').add({
          ...resumeData,
          'createdAt': FieldValue.serverTimestamp(), // Add a 'createdAt' time
        });
      }

      // --- MODIFICATION: Request 3 (Back Warning) ---
      // Mark as no longer dirty after a successful save
      if (mounted) {
        setState(() {
          _isDirty = false;
        });
      }
      // ----------------------------------------------
    } catch (e) {
      // Show an error if saving fails
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      // 4. Hide the loading spinner
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// This function is called when the user presses the phone's back button.
  Future<bool> _onWillPop() async {
    // --- MODIFICATION: Request 3 (Back Warning) ---
    // If the form isn't dirty, just let the user leave.
    if (!_isDirty) {
      return true;
    }

    // If the form IS dirty, show a confirmation dialog.
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            "You didn't save. If you go back, your changes will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Stay
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Leave
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // If shouldPop is null (e.g., dialog dismissed), default to false (stay)
    return shouldPop ?? false;
    // --- End of Modification ---
  }

  // --- MAIN BUILD METHOD (The UI) ---

  @override
  Widget build(BuildContext context) {
    // This `WillPopScope` catches the back button press
    // and calls our `_onWillPop` function (for auto-saving).
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: Text(
            widget.resume == null ? 'Create Resume' : 'Edit Resume',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              // This is a ternary operator:
              // IF `_isLoading` is true, show a spinner.
              // ELSE, show the save button.
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    )
                  // --- MODIFICATION: Request 1 (Save Button) ---
                  // Replaced IconButton with a styled ElevatedButton
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: _saveResume,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _saveButtonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
              // --- End of Modification ---
            ),
          ],
        ),
        body: Form(
          key: _formKey, // Attach the global key to the form
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Resume Title (Static Field) ---
              _buildStyledTextFormField(
                controller: _titleController,
                labelText: 'Resume Title',
                hintText: 'e.g., "Software Engineering Resume"',
                icon: Icons.title,
                // --- MODIFICATION: Request 2 (Title Length) ---
                maxLength: 40,
                // --- End of Modification ---
                validator: (value) =>
                    value!.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 8),

              // --- Personal Details (Static Fields) ---
              _buildSectionTile(
                title: 'Personal Details & Summary',
                icon: Icons.person_outline,
                initiallyExpanded: true, // This section starts open
                children: [
                  _buildStyledTextFormField(
                    controller: _firstNameController,
                    labelText: 'First Name',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  _buildStyledTextFormField(
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  _buildStyledTextFormField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  _buildStyledTextFormField(
                    controller: _phoneController,
                    labelText: 'Phone Number',
                    keyboardType: TextInputType.phone,
                  ),
                  _buildStyledTextFormField(
                    controller: _summaryController,
                    labelText: 'Professional Summary',
                    maxLines: 4,
                    hintText: 'A brief 2-3 sentence summary...',
                  ),

                  // --- Primary Education (Special case) ---
                  // We show the *first* education entry here, because it's
                  // the student's main university education.
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
                      // Tapping 'edit' opens the pop-up form
                      onEdit: () => _showEducationForm(
                        educationToEdit: _educationEntries.first,
                        index: 0,
                      ),
                      // Tapping 'delete' removes it from the list
                      onDelete: () => setState(() {
                        _educationEntries.removeAt(0);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    ),
                  ],
                ],
              ),

              // --- Additional Education (Dynamic Section) ---
              _buildSectionTile(
                title: 'Additional Education',
                icon: Icons.school_outlined,
                children: [
                  // This loop `.skip(1)` displays all education entries *except* the first one
                  ..._educationEntries.skip(1).map((edu) {
                    int index = _educationEntries.indexOf(edu);
                    return _buildEntryCard(
                      title: edu.degreeName,
                      subtitle:
                          '${edu.instituteName}\n${DateFormat.yMMMd().format(edu.startDate)} - ${edu.isPresent ? 'Present' : (edu.endDate != null ? DateFormat.yMMMd().format(edu.endDate!) : '')}',
                      onEdit: () => _showEducationForm(
                        educationToEdit: edu,
                        index: index,
                      ),
                      onDelete: () => setState(() {
                        _educationEntries.removeAt(index);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    );
                  }),
                  if (_educationEntries.length > 1) const Divider(height: 32),
                  // This is the small "Add New" form widget
                  _EducationAddForm(
                    onAdd: (newEducation) {
                      // This is the callback function!
                      // The `_EducationAddForm` sends the new item back here.
                      // We just add it to our main list and `setState`.
                      setState(() {
                        _educationEntries.add(newEducation);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),

              // --- Experience (Dynamic Section) ---
              _buildSectionTile(
                title: 'Experience',
                icon: Icons.work_outline,
                children: [
                  // Loop through all experience entries and show them
                  ..._experienceEntries.map((exp) {
                    int index = _experienceEntries.indexOf(exp);
                    return _buildEntryCard(
                      title: exp.title,
                      subtitle:
                          '${exp.organization}\n${DateFormat.yMMMd().format(exp.startDate)} - ${exp.isPresent ? 'Present' : (exp.endDate != null ? DateFormat.yMMMd().format(exp.endDate!) : '')}',
                      onEdit: () => _showExperienceForm(
                        experienceToEdit: exp,
                        index: index,
                      ),
                      onDelete: () => setState(() {
                        _experienceEntries.removeAt(index);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    );
                  }),
                  if (_experienceEntries.isNotEmpty) const Divider(height: 32),
                  // The "Add New" form
                  _ExperienceAddForm(
                    onAdd: (newExperience) {
                      setState(() {
                        _experienceEntries.add(newExperience);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),

              // --- Extracurriculars (Dynamic Section) ---
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
                        extraToEdit: extra,
                        index: index,
                      ),
                      onDelete: () => setState(
                        () {
                          _extracurricularEntries.removeAt(index);
                          // --- MODIFICATION: Request 3 (Back Warning) ---
                          _isDirty = true;
                          // ----------------------------------------------
                        },
                      ),
                    );
                  }),
                  if (_extracurricularEntries.isNotEmpty)
                    const Divider(height: 32),
                  _ExtracurricularAddForm(
                    onAdd: (newExtra) {
                      setState(() {
                        _extracurricularEntries.add(newExtra);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),

              // --- Projects (Dynamic Section) ---
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
                      onDelete: () => setState(() {
                        _projectEntries.removeAt(index);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    );
                  }),
                  if (_projectEntries.isNotEmpty) const Divider(height: 32),
                  _ProjectAddForm(
                    onAdd: (newProject) {
                      setState(() {
                        _projectEntries.add(newProject);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),

              // --- Skills (Special Dynamic Section) ---
              _buildSectionTile(
                title: 'Skills',
                icon: Icons.lightbulb_outline,
                children: [
                  _buildSkillsSectionContent(),
                ], // Uses a helper widget
              ),

              // --- Licenses (Dynamic Section) ---
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
                      onEdit: () => _showLicenseForm(
                        licenseToEdit: license,
                        index: index,
                      ),
                      onDelete: () => setState(() {
                        _licenseEntries.removeAt(index);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    );
                  }),
                  if (_licenseEntries.isNotEmpty) const Divider(height: 32),
                  _LicenseAddForm(
                    onAdd: (newLicense) {
                      setState(() {
                        _licenseEntries.add(newLicense);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),

              // --- Awards (Dynamic Section) ---
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
                      onDelete: () => setState(() {
                        _awardEntries.removeAt(index);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    );
                  }),
                  if (_awardEntries.isNotEmpty) const Divider(height: 32),
                  _AwardAddForm(
                    onAdd: (newAward) {
                      setState(() {
                        _awardEntries.add(newAward);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),

              // --- Custom Sections (Complex Dynamic Section) ---
              _buildSectionTile(
                title: 'Custom Sections',
                icon: Icons.add_circle_outline,
                children: [
                  // This is a nested loop. First, we loop through each 'section'...
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
                            // Row for the section title and edit/delete buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    section.sectionTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  // This button edits the SECTION TITLE itself
                                  onPressed: () => _showSectionTitleDialog(
                                    sectionIndex: currentSectionIndex,
                                  ),
                                  tooltip: 'Edit Title',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  // This button deletes the WHOLE section
                                  onPressed: () => setState(
                                    () {
                                      _customSections.removeAt(
                                        currentSectionIndex,
                                      );
                                      // --- MODIFICATION: Request 3 (Back Warning) ---
                                      _isDirty = true;
                                      // ----------------------------------------------
                                    },
                                  ),
                                  tooltip: 'Delete Section',
                                ),
                              ],
                            ),
                            const Divider(),
                            // ...then we loop through all 'entries' *inside* that section
                            ...section.entries.map((entry) {
                              int entryIndex = section.entries.indexOf(entry);
                              // ... (logic to build title and subtitle for the entry)
                              String title = entry.title?.trim() ?? '';
                              if (title.isEmpty) title = 'Untitled Entry';

                              List<String> subtitleParts = [];
                              if (entry.startDate != null) {
                                String startDateStr = DateFormat.yMMMd().format(
                                  entry.startDate!,
                                );
                                String endDateStr = entry.currently
                                    ? 'Present'
                                    : (entry.endDate != null
                                        ? DateFormat.yMMMd().format(
                                            entry.endDate!,
                                          )
                                        : '');
                                if (endDateStr.isNotEmpty) {
                                  subtitleParts.add(
                                    '$startDateStr - $endDateStr',
                                  );
                                } else {
                                  subtitleParts.add('Started: $startDateStr');
                                }
                              }
                              if (entry.description != null &&
                                  entry.description!.isNotEmpty) {
                                subtitleParts.add(entry.description!);
                              }
                              String subtitle = subtitleParts.join('\n');

                              // Build the card for the *entry*
                              return _buildEntryCard(
                                title: title,
                                subtitle: subtitle,
                                onEdit: () => _showCustomFieldEntryForm(
                                  sectionIndex: currentSectionIndex,
                                  entryIndex: entryIndex,
                                ),
                                onDelete: () => setState(
                                  () {
                                    _customSections[currentSectionIndex]
                                        .entries
                                        .removeAt(entryIndex);
                                    // --- MODIFICATION: Request 3 (Back Warning) ---
                                    _isDirty = true;
                                    // ----------------------------------------------
                                  },
                                ),
                              );
                            }),
                            // Button to "Add Entry" *to this specific section*
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Entry'),
                                onPressed: () => _showCustomFieldEntryForm(
                                  sectionIndex: currentSectionIndex,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  // Button to "Add New Custom Section"
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showSectionTitleDialog(), // Opens the title dialog
                      icon: const Icon(Icons.add),
                      label: const Text("Add Custom Section"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor.withOpacity(0.1),
                        foregroundColor: _primaryColor,
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              // --- Languages (Dynamic Section) ---
              _buildSectionTile(
                title: 'Languages',
                icon: Icons.language_outlined,
                children: [
                  ..._languageEntries.map((lang) {
                    int index = _languageEntries.indexOf(lang);
                    return _buildEntryCard(
                      title: lang.name,
                      subtitle: lang.proficiency,
                      onEdit: () =>
                          _showLanguageForm(languageToEdit: lang, index: index),
                      onDelete: () => setState(() {
                        _languageEntries.removeAt(index);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      }),
                    );
                  }),
                  if (_languageEntries.isNotEmpty) const Divider(height: 32),
                  _LanguageAddForm(
                    onAdd: (newLang) {
                      setState(() {
                        _languageEntries.add(newLang);
                        // --- MODIFICATION: Request 3 (Back Warning) ---
                        _isDirty = true;
                        // ----------------------------------------------
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 3. UI HELPER WIDGETS
  // -------------------------------------------------------------------

  /// This is a special helper widget just for the Skills section.
  /// It manages the 'chip' layout and the 'Add Skill' text field.
  Widget _buildSkillsSectionContent() {
    final skillController = TextEditingController(); // A temporary controller
    return Column(
      children: [
        if (_skills.isEmpty)
          const Center(
            child: Text(
              'No skills added.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        // `Wrap` lets the chips flow to the next line if they run out of space
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _skills
              .map(
                (skill) => Chip(
                  label: Text(skill),
                  // This adds the little 'x' button to delete the chip
                  onDeleted: () => setState(() {
                    _skills.remove(skill);
                    // --- MODIFICATION: Request 3 (Back Warning) ---
                    _isDirty = true;
                    // ----------------------------------------------
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        // This is the text field and '+' button to add a new skill
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
              icon: const Icon(
                Icons.add_circle,
                color: _primaryColor,
                size: 30,
              ),
              onPressed: () {
                final skill = skillController.text.trim();
                if (skill.isNotEmpty) {
                  setState(() {
                    // Check for duplicates before adding
                    if (!_skills.contains(skill)) {
                      _skills.add(skill);
                      // --- MODIFICATION: Request 3 (Back Warning) ---
                      _isDirty = true;
                      // ----------------------------------------------
                    }
                    skillController.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  /// This is a reusable helper widget to create the main collapsible cards
  /// (like "Education", "Experience").
  Widget _buildSectionTile({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      // `ExpansionTile` is the widget that provides the expand/collapse behavior.
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
            // The `children` (the content of the section) are placed here
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

  /// This is a reusable helper widget to create the small cards *inside*
  /// a section, (e.g., a single 'Education' item).
  /// It includes the title, subtitle, edit button, and delete button.
  Widget _buildEntryCard({
    required String title,
    required String subtitle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: TextStyle(color: Colors.grey.shade700))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit, // Calls the 'onEdit' function passed in
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: onDelete, // Calls the 'onDelete' function passed in
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // 4. MODAL/DIALOG "LAUNCHER" FUNCTIONS
  // -------------------------------------------------------------------
  // These functions open the pop-ups. They are called by the 'onEdit'
  // or 'Add' buttons.
  // They all use `showModalBottomSheet` or `showDialog`.

  /// Opens a dialog to add or edit a Custom Section's *title*.
  Future<void> _showSectionTitleDialog({int? sectionIndex}) async {
    final _titleController = TextEditingController(
      text: sectionIndex != null
          ? _customSections[sectionIndex].sectionTitle
          : '',
    );
    final isEditing = sectionIndex != null;

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Section Title' : 'New Section Title'),
        content: TextField(
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Section Title'),
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_titleController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // After the dialog closes, add the new section to our state list
    if (newTitle != null && newTitle.isNotEmpty) {
      setState(() {
        if (isEditing) {
          _customSections[sectionIndex].sectionTitle = newTitle;
        } else {
          _customSections.add(
            CustomSection(sectionTitle: newTitle, entries: []),
          );
        }
        // --- MODIFICATION: Request 3 (Back Warning) ---
        _isDirty = true;
        // ----------------------------------------------
      });
    }
  }

  /// Opens the pop-up form to edit a single *Education* item.
  void _showEducationForm({Education? educationToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the modal to be tall
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(
            context,
          ).viewInsets.bottom, // Moves form above keyboard
          top: 20,
          left: 20,
          right: 20,
        ),
        // It shows the `_EducationEditForm` widget (defined below)
        child: _EducationEditForm(
          education: educationToEdit,
          onSave: (updatedEducation) {
            // This is the callback! When the EditForm saves,
            // it sends the updated item back.
            setState(() {
              if (index != null) {
                // We replace the old item with the updated one
                _educationEntries[index] = updatedEducation;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop(); // Close the modal
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to edit a single *Experience* item.
  void _showExperienceForm({Experience? experienceToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _ExperienceEditForm(
          experience: experienceToEdit,
          onSave: (updatedExperience) {
            setState(() {
              if (index != null) {
                _experienceEntries[index] = updatedExperience;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to edit a single *Award* item.
  void _showAwardForm({Award? awardToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _AwardEditForm(
          award: awardToEdit,
          onSave: (updatedAward) {
            setState(() {
              if (index != null) {
                _awardEntries[index] = updatedAward;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to edit a single *Language* item.
  void _showLanguageForm({Language? languageToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _LanguageEditForm(
          language: languageToEdit,
          onSave: (updatedLanguage) {
            setState(() {
              if (index != null) {
                _languageEntries[index] = updatedLanguage;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to edit a single *Project* item.
  void _showProjectForm({Project? projectToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _ProjectEditForm(
          project: projectToEdit,
          onSave: (updatedProject) {
            setState(() {
              if (index != null) {
                _projectEntries[index] = updatedProject;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to add/edit an *entry* in a *Custom Section*.
  void _showCustomFieldEntryForm({required int sectionIndex, int? entryIndex}) {
    final isEditing = entryIndex != null;
    final entryToEdit = isEditing
        ? _customSections[sectionIndex].entries[entryIndex]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
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
              // --- MODIFICATION: Request 3 (Back Warning) ---
              _isDirty = true;
              // ----------------------------------------------
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to edit a single *Extracurricular* item.
  void _showExtracurricularForm({Extracurricular? extraToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _ExtracurricularEditForm(
          extra: extraToEdit,
          onSave: (updatedExtra) {
            setState(() {
              if (index != null) {
                _extracurricularEntries[index] = updatedExtra;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Opens the pop-up form to edit a single *License* item.
  void _showLicenseForm({License? licenseToEdit, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _LicenseEditForm(
          license: licenseToEdit,
          onSave: (updatedLicense) {
            setState(() {
              if (index != null) {
                _licenseEntries[index] = updatedLicense;
                // --- MODIFICATION: Request 3 (Back Warning) ---
                _isDirty = true;
                // ----------------------------------------------
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
} // --- End of _ResumeFormScreenState ---

// -------------------------------------------------------------------
// 5. "ADD" FORM WIDGETS
// -------------------------------------------------------------------
// These are the *small, temporary forms* that live inside the
// "ExpansionTile" sections for adding new items.
// They are all StatefulWidgets because they manage their own text controllers.

/// A small form widget for *adding* a new 'Education'.
class _EducationAddForm extends StatefulWidget {
  final Function(Education) onAdd;
  const _EducationAddForm({required this.onAdd});

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
      // This is the "callback". It sends the new item
      // back up to the main screen's state.
      widget.onAdd(newEducation);
      _resetForm(); // Clear the fields
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields, including Start Date.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is the UI for the *small add form*
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add New Education",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _instituteController,
          labelText: 'University/Institute*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _degreeController,
          labelText: 'Major/Degree Name*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _startDate == null
                    ? 'No Start Date Selected*'
                    : 'Start Date: ${DateFormat.yMMMd().format(_startDate!)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            ),
          ],
        ),
        if (!_isPresent)
          Row(
            children: [
              Expanded(
                child: Text(
                  _endDate == null
                      ? 'No Graduation Date Selected'
                      : 'Graduation: ${DateFormat.yMMMd().format(_endDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(1980),
                    lastDate: DateTime(2050),
                  );
                  if (date != null) setState(() => _endDate = date);
                },
                child: const Text('Select'),
              ),
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

/// A small form widget for *adding* a new 'Experience'.
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
      widget.onAdd(
        Experience(
          organization: _orgController.text,
          title: _titleController.text,
          type: _type,
          startDate: _startDate!,
          endDate: _endDate,
          isPresent: _isPresent,
          locationType: 'On-site', // Default value
        ),
      );
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add Experience",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _titleController,
          labelText: 'Title*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _orgController,
          labelText: 'Organization*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [
            'Internship',
            'Co-op',
            'Full-time',
            'Part-time',
            'Bootcamp',
            'Other',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _type = val ?? 'Internship'),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _startDate == null
                    ? 'No Start Date Selected*'
                    : 'Start: ${DateFormat.yMMMd().format(_startDate!)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            ),
          ],
        ),
        if (!_isPresent)
          Row(
            children: [
              Expanded(
                child: Text(
                  _endDate == null
                      ? 'No End Date Selected'
                      : 'End: ${DateFormat.yMMMd().format(_endDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(1980),
                    lastDate: DateTime(2050),
                  );
                  if (date != null) setState(() => _endDate = date);
                },
                child: const Text('Select'),
              ),
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

/// A small form widget for *adding* a new 'Extracurricular'.
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
      widget.onAdd(
        Extracurricular(
          organizationName: _orgController.text.trim(),
          eventName: _eventController.text.trim(),
          role: _roleController.text.trim(),
          description: _descController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          isPresent: _isPresent,
        ),
      );
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill Organization, Role, and Start Date.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add Extracurricular Activity",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _orgController,
          labelText: 'Organization Name*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _eventController,
          labelText: 'Event Name (Optional)',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _roleController,
          labelText: 'Role*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _descController,
          labelText: 'Description (Optional)',
          maxLines: 3,
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _startDate == null
                    ? 'No Start Date*'
                    : 'Start: ${DateFormat.yMMMd().format(_startDate!)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _startDate = date);
              },
              child: const Text('Select'),
            ),
          ],
        ),
        if (!_isPresent)
          Row(
            children: [
              Expanded(
                child: Text(
                  _endDate == null
                      ? 'No End Date'
                      : 'End: ${DateFormat.yMMMd().format(_endDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(1980),
                    lastDate: DateTime(2050),
                  );
                  if (date != null) setState(() => _endDate = date);
                },
                child: const Text('Select'),
              ),
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

/// A small form widget for *adding* a new 'Project'.
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
      widget.onAdd(
        Project(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          link: _linkController.text.trim(),
        ),
      );
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add Project",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _titleController,
          labelText: 'Project Title*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _descController,
          labelText: 'Description*',
          maxLines: 3,
        ),
        _buildStyledTextFormField(
          controller: _linkController,
          labelText: 'URL / Link (Optional)',
        ),
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

/// A small form widget for *adding* a new 'License'.
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
      widget.onAdd(
        License(
          name: _nameController.text.trim(),
          issuingOrganization: _orgController.text.trim(),
          issueDate: _issueDate!,
          expirationDate: _expDate,
        ),
      );
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add License or Certification",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _nameController,
          labelText: 'Certification Name*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _orgController,
          labelText: 'Issuing Organization*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _issueDate == null
                    ? 'No Issue Date*'
                    : 'Issued: ${DateFormat.yMMMd().format(_issueDate!)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _issueDate = date);
              },
              child: const Text('Select'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _expDate == null
                    ? 'No Expiration Date'
                    : 'Expires: ${DateFormat.yMMMd().format(_expDate!)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _issueDate ?? DateTime.now(),
                  firstDate: _issueDate ?? DateTime(1980),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _expDate = date);
              },
              child: const Text('Select'),
            ),
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

/// A small form widget for *adding* a new 'Award'.
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
      widget.onAdd(
        Award(
          title: _titleController.text,
          organization: _orgController.text,
          issueDate: _issueDate!,
          description: '', // Optional, can be added in edit
        ),
      );
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add Award",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _titleController,
          labelText: 'Title*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        _buildStyledTextFormField(
          controller: _orgController,
          labelText: 'Issuing Organization*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                _issueDate == null
                    ? 'No Issue Date Selected*'
                    : 'Date: ${DateFormat.yMMMd().format(_issueDate!)}',
              ),
            ),
            TextButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _issueDate = date);
              },
              child: const Text('Select'),
            ),
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

/// A small form widget for *adding* a new 'Language'.
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
        Language(name: _nameController.text, proficiency: _proficiency),
      );
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add Language",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStyledTextFormField(
          controller: _nameController,
          labelText: 'Language*',
          // --- MODIFICATION: Title Length ---
          maxLength: 40,
          // ----------------------------------
        ),
        DropdownButtonFormField<String>(
          value: _proficiency,
          decoration: const InputDecoration(labelText: 'Proficiency'),
          items: [
            'Beginner',
            'Conversational',
            'Fluent',
            'Native',
          ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
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

// -------------------------------------------------------------------
// 6. "EDIT" FORM WIDGETS
// -------------------------------------------------------------------
// These are the widgets that are shown in the `showModalBottomSheet`.
// They are used for *editing* an existing item.
// They are all StatefulWidgets to manage their own controllers and state.

/// A pop-up form widget for *editing* an 'Education' item.
class _EducationEditForm extends StatefulWidget {
  final Education? education; // The item to edit
  final Function(Education)
      onSave; // The callback to send the updated item back

  const _EducationEditForm({this.education, required this.onSave});

  @override
  State<_EducationEditForm> createState() => _EducationEditFormState();
}

class _EducationEditFormState extends State<_EducationEditForm> {
  // These controllers are *local* to this pop-up form
  late TextEditingController _degreeController;
  late TextEditingController _instituteController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPresent = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with the item's data
    final edu = widget.education;
    _degreeController = TextEditingController(text: edu?.degreeName ?? '');
    _instituteController = TextEditingController(
      text: edu?.instituteName ?? '',
    );
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
      // This "callback" sends the *updated* item back to the main screen
      widget.onSave(updatedEducation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields, including Start Date.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // `SingleChildScrollView` ensures the form doesn't get
    // blocked by the keyboard.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Edit Education",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _instituteController,
            labelText: 'University/Institute*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _degreeController,
            labelText: 'Major/Degree Name*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _startDate == null
                      ? 'No Start Date Selected*'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              ),
            ],
          ),
          if (!_isPresent)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _endDate == null
                        ? 'No Graduation Date'
                        : 'Graduation: ${DateFormat.yMMMd().format(_endDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                ),
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

/// A pop-up form widget for *editing* an 'Experience' item.
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
          Text(
            "Edit Experience",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _titleController,
            labelText: 'Title*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _orgController,
            labelText: 'Organization*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              'Internship',
              'Co-op',
              'Full-time',
              'Part-time',
              'Bootcamp',
              'Other',
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() => _type = val ?? 'Internship'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _startDate == null
                      ? 'No Start Date Selected*'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              ),
            ],
          ),
          if (!_isPresent)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _endDate == null
                        ? 'No End Date Selected'
                        : 'End: ${DateFormat.yMMMd().format(_endDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                ),
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

/// A pop-up form widget for *editing* an 'Extracurricular' item.
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
      widget.onSave(
        Extracurricular(
          organizationName: _orgController.text.trim(),
          eventName: _eventController.text.trim(),
          role: _roleController.text.trim(),
          description: _descController.text.trim(),
          startDate: _startDate!,
          endDate: _endDate,
          isPresent: _isPresent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Edit Extracurricular Activity",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _orgController,
            labelText: 'Organization Name*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _eventController,
            labelText: 'Event Name (Optional)',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _roleController,
            labelText: 'Role*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _descController,
            labelText: 'Description (Optional)',
            maxLines: 3,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _startDate == null
                      ? 'No Start Date*'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              ),
            ],
          ),
          if (!_isPresent)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _endDate == null
                        ? 'No End Date'
                        : 'End: ${DateFormat.yMMMd().format(_endDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                ),
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

/// A pop-up form widget for *editing* a 'License' item.
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
    _orgController = TextEditingController(
      text: license?.issuingOrganization ?? '',
    );
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
      widget.onSave(
        License(
          name: _nameController.text.trim(),
          issuingOrganization: _orgController.text.trim(),
          issueDate: _issueDate!,
          expirationDate: _expDate,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Edit License or Certification",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _nameController,
            labelText: 'Certification Name*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _orgController,
            labelText: 'Issuing Organization*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _issueDate == null
                      ? 'No Issue Date*'
                      : 'Issued: ${DateFormat.yMMMd().format(_issueDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _issueDate ?? DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _issueDate = date);
                },
                child: const Text('Select'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _expDate == null
                      ? 'No Expiration Date'
                      : 'Expires: ${DateFormat.yMMMd().format(_expDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expDate ?? _issueDate ?? DateTime.now(),
                    firstDate: _issueDate ?? DateTime(1980),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _expDate = date);
                },
                child: const Text('Select'),
              ),
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

/// A pop-up form widget for *editing* an 'Award' item.
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
          Text(
            "Edit Award",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _titleController,
            labelText: 'Title*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _orgController,
            labelText: 'Issuing Organization*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _descController,
            labelText: 'Description (Optional)',
            maxLines: 3,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _issueDate == null
                      ? 'No Issue Date Selected*'
                      : 'Date: ${DateFormat.yMMMd().format(_issueDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _issueDate ?? DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _issueDate = date);
                },
                child: const Text('Select'),
              ),
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

/// A pop-up form widget for *editing* a 'Language' item.
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
          Text(
            "Edit Language",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _nameController,
            labelText: 'Language*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          DropdownButtonFormField<String>(
            value: _proficiency,
            decoration: const InputDecoration(labelText: 'Proficiency'),
            items: [
              'Beginner',
              'Conversational',
              'Fluent',
              'Native',
            ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
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

/// A pop-up form widget for *editing* a 'Project' item.
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
          Text(
            "Edit Project",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _titleController,
            labelText: 'Project Title*',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _descController,
            labelText: 'Description*',
            maxLines: 3,
          ),
          _buildStyledTextFormField(
            controller: _linkController,
            labelText: 'URL / Link (Optional)',
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

/// A pop-up form widget for *editing* a 'CustomFieldEntry' item.
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
    // Save even if fields are empty, as the user might just want a date
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
          Text(
            widget.entry == null ? "Add Entry" : "Edit Entry",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _titleController,
            labelText: 'Title (Optional)',
            // --- MODIFICATION: Title Length ---
            maxLength: 40,
            // ----------------------------------
          ),
          _buildStyledTextFormField(
            controller: _descController,
            labelText: 'Description (Optional)',
            maxLines: 3,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _startDate == null
                      ? 'No Start Date'
                      : 'Start: ${DateFormat.yMMMd().format(_startDate!)}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _startDate = date);
                },
                child: const Text('Select'),
              ),
            ],
          ),
          if (!_currently)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _endDate == null
                        ? 'No End Date'
                        : 'End: ${DateFormat.yMMMd().format(_endDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? _startDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(1980),
                      lastDate: DateTime(2050),
                    );
                    if (date != null) setState(() => _endDate = date);
                  },
                  child: const Text('Select'),
                ),
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

// -------------------------------------------------------------------
// 7. TOP-LEVEL HELPER FUNCTION
// -------------------------------------------------------------------

/// This is a top-level function (outside of any class) that acts as a
/// reusable "template" for creating a styled `TextFormField`.
/// This is great practice because it means if you want to change the
/// style of all text fields, you only have to change it in one place.
Widget _buildStyledTextFormField({
  required TextEditingController controller,
  required String labelText,
  String? hintText,
  IconData? icon,
  int maxLines = 1,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  // --- MODIFICATION: Request 2 (Title Length) ---
  int? maxLength,
  // --- End of Modification ---
}) {
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
      validator: validator, // Used by the `_formKey` to check for errors
      // --- MODIFICATION: Request 2 (Title Length) ---
      maxLength: maxLength,
      // --- End of Modification ---
    ),
  );
}