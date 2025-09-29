// lib/features/profile/screens/profile_edit_screens.dart
// This file contains all secondary screens for editing profile sections.

import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:intl/intl.dart';

import '../../../models/student.dart';
import '../../../services/authService.dart';
import '../../../services/storage_service.dart';

// Color constant needed by some edit screens
const Color _profilePrimaryColor = Color(0xFF422F5D);
const Color _profileSecondaryColor = Color(0xFFF99D46);
const Color _profileBackgroundColor = Color(0xFFF7F4F0);


// --- Custom formatter for phone number spacing (from signup) ---
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newText.isEmpty) {
      return const TextEditingValue();
    }
    
    final buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      if (i == 2 || i == 5) {
        buffer.write(' ');
      }
      buffer.write(newText[i]);
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

// --- 1. Personal Information Screen ---

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key, required this.student});
  final Student student;

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _summaryController;
  late TextEditingController _otherLocationController;
  
  // --- Lists from Firestore ---
  List<String> _locationsList = []; 
  late Future<void> _loadListsFuture;
  String? _selectedLocation;

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _saving = false;

  // --- Username validation state (from signup) ---
  String? _usernameError;
  Timer? _debounce;
  bool _isCheckingUsername = false;


  @override
  void initState() {
    super.initState();
    _loadListsFuture = _loadLists();
    final student = widget.student;
    _firstNameController = TextEditingController(text: student.firstName);
    _lastNameController = TextEditingController(text: student.lastName);
    _usernameController = TextEditingController(text: student.username);
    _summaryController = TextEditingController(text: student.shortSummary ?? '');
    _otherLocationController = TextEditingController();

    // Set initial location
    _selectedLocation = student.location;
    
    // Extract 9-digit number for the phone controller
    String phoneNumber = student.phoneNumber ?? '';
    if (phoneNumber.startsWith('+966')) {
        phoneNumber = phoneNumber.substring(4);
    }
    _phoneController = TextEditingController(text: phoneNumber.replaceAll(' ', ''));

    // Listener for username uniqueness check
    _usernameController.addListener(() {
      if (_usernameController.text.trim() != widget.student.username) {
        _checkUsernameUniqueness(_usernameController.text.trim());
      }
    });
  }

  Future<void> _loadLists() async {
    final lists = await _authService.getUniversitiesAndMajors();
    if (mounted) {
      setState(() {
        _locationsList = ["Other", ...lists['cities'] ?? []];
        // If current location is not in the list, set it as "Other"
        // and populate the "Other" text field.
        if (_selectedLocation != null && !_locationsList.contains(_selectedLocation)) {
            _otherLocationController.text = _selectedLocation!;
            _selectedLocation = "Other";
        }
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _summaryController.dispose();
    _otherLocationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  
  // --- Username validation logic (from signup) ---
  String? _usernameManualValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    if (value.length > 12) {
      return 'Username cannot exceed 12 characters';
    }
    if (value.contains(' ')) {
      return 'Username cannot contain spaces';
    }
    if (RegExp(r'[^a-zA-Z0-9_.-]').hasMatch(value)) {
      return 'Only letters, numbers, and symbols (_, -, .) are allowed';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Username must contain at least one letter';
    }
    if (_usernameError != null) {
      return _usernameError;
    }
    return null;
  }

  void _checkUsernameUniqueness(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (mounted) setState(() { _isCheckingUsername = true; });
      if (_usernameError != null) {
        setState(() { _usernameError = null; });
      }
      // Only check if it's different from the original and not empty
      if (value.isNotEmpty && value != widget.student.username) {
        final isUnique = await _authService.isUsernameUnique(value);
        if (!isUnique && mounted) {
          setState(() {
            _usernameError = 'This username is already taken.';
          });
        }
      }
      if (mounted) setState(() { _isCheckingUsername = false; });
    });
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _previewBytes = bytes;
      });
    }
  }

  Future<String?> _uploadProfilePicture(String uid, XFile file) async {
    final ref = firebase_storage.FirebaseStorage.instance.ref().child(
      'students/$uid/profile/profile_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );

    final bytes = await file.readAsBytes();
    await ref.putData(bytes, firebase_storage.SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_usernameError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_usernameError!)));
        return;
    }
    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');
      
      final trimmedUsername = _usernameController.text.trim();
      if (trimmedUsername.isEmpty) throw Exception('Username cannot be empty.');

      if (trimmedUsername != widget.student.username) {
        final unique = await _authService.isUsernameUnique(trimmedUsername);
        if (!unique) throw Exception('This username is already taken.');
      }

      String? profileUrl = widget.student.profilePictureUrl;
      if (_pickedImage != null) {
        profileUrl = await _uploadProfilePicture(user.uid, _pickedImage!);
      }

      final String finalLocation = _selectedLocation == 'Other'
          ? _otherLocationController.text.trim()
          : _selectedLocation!;

      final updated = widget.student.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: trimmedUsername,
        phoneNumber: "+966${_phoneController.text.trim().replaceAll(' ', '')}",
        location: finalLocation.isEmpty ? null : finalLocation,
        shortSummary: _summaryController.text.trim().isEmpty ? null : _summaryController.text.trim(),
        profilePictureUrl: profileUrl,
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
        if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? backgroundImage;
    if (_previewBytes != null) {
      backgroundImage = MemoryImage(_previewBytes!);
    } else if (widget.student.profilePictureUrl != null) {
      backgroundImage = NetworkImage(widget.student.profilePictureUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: FutureBuilder<void>(
        future: _loadListsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _profilePrimaryColor));
          }
           if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
           }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: backgroundImage,
                          backgroundColor: Colors.grey[200],
                          child: backgroundImage == null ? const Icon(Icons.person, size: 40) : null,
                        ),
                        IconButton(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: _profilePrimaryColor,
                            fixedSize: const Size(36, 36),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'First Name'),
                          inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Last Name'),
                          inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: _usernameError,
                      suffixIcon: _isCheckingUsername 
                        ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)))
                        : null,
                    ),
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    validator: _usernameManualValidator,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: UnderlineInputBorder(),
                    ),
                    child: Row(
                        children: [
                          const Text(
                            '+966',
                            style: TextStyle(fontSize: 16, color: Colors.black54),
                          ),
                          Container(height: 20, width: 1, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.grey.shade400),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(9),
                                PhoneNumberFormatter(),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter phone number';
                                final digitsOnly = value.replaceAll(' ', '');
                                if (digitsOnly.length != 9) return 'Must be 9 digits';
                                if (!digitsOnly.startsWith('5')) return 'Must start with 5';
                                return null;
                              },
                              decoration: const InputDecoration(
                                hintText: '5X XXX XXXX',
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ),
                  const SizedBox(height: 16),
                  _buildSearchableDropdown(
                    labelText: 'Location',
                    selectedValue: _selectedLocation,
                    icon: Icons.location_on_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please select a location';
                      if (value == 'Other' && _otherLocationController.text.trim().isEmpty) return 'Please specify your location';
                      return null;
                    },
                    onTap: () async {
                      await _showSearchDialog(
                        context: context,
                        items: _locationsList,
                        title: 'Location',
                        onItemSelected: (value) => setState(() {
                          _selectedLocation = value;
                          if (value != 'Other') _otherLocationController.clear();
                        }),
                      );
                    },
                  ),
                  if (_selectedLocation == 'Other')
                    TextFormField(
                        controller: _otherLocationController,
                        decoration: const InputDecoration(labelText: 'Please specify your location'),
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'This field is required';
                          if (value.length > 30) return 'Cannot exceed 30 characters';
                          return null;
                        },
                      ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _summaryController,
                    decoration: const InputDecoration(labelText: 'Short Summary'),
                    maxLines: 4,
                    inputFormatters: [LengthLimitingTextInputFormatter(250)],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


// --- 2. Academic Info Screen ---

class AcademicInfoScreen extends StatefulWidget {
  const AcademicInfoScreen({super.key, required this.student});
  final Student student;

  @override
  State<AcademicInfoScreen> createState() => _AcademicInfoScreenState();
}

class _AcademicInfoScreenState extends State<AcademicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late TextEditingController _gpaController;
  late TextEditingController _graduationController;
  late TextEditingController _otherUniversityController;
  late TextEditingController _otherMajorController;
  
  // --- Lists from Firestore & State ---
  late Future<void> _loadListsFuture;
  List<String> _universitiesList = [];
  List<String> _majorsList = [];
  String? _selectedUniversity;
  String? _selectedMajor;
  String? _selectedLevel;
  String? _gpaScale;
  bool _saving = false;
  
  final List<String> _academicLevels = [
    'Freshman (Level 1-2)', 'Sophomore (Level 3-4)', 'Junior (Level 5-6)',
    'Senior (Level 7-8)', 'Senior (Level +9)', 'Graduate Student'
  ];

  @override
  void initState() {
    super.initState();
    _loadListsFuture = _loadLists();
    final student = widget.student;

    _selectedUniversity = student.university;
    _selectedMajor = student.major;
    _selectedLevel = student.level;

    _gpaController = TextEditingController(text: student.gpa != null ? student.gpa!.toString() : '');
    _graduationController = TextEditingController(text: student.expectedGraduationDate ?? '');
    _otherUniversityController = TextEditingController();
    _otherMajorController = TextEditingController();

    if (student.gpa != null) {
      _gpaScale = student.gpa! > 4.0 ? '5.0' : '4.0';
    }
  }

  Future<void> _loadLists() async {
    final lists = await _authService.getUniversitiesAndMajors();
    if (mounted) {
      setState(() {
        _universitiesList = ["Other", ...lists['universities'] ?? []];
        _majorsList = ["Other", ...lists['majors'] ?? []];

        if (_selectedUniversity != null && !_universitiesList.contains(_selectedUniversity)) {
            _otherUniversityController.text = _selectedUniversity!;
            _selectedUniversity = "Other";
        }
        if (_selectedMajor != null && !_majorsList.contains(_selectedMajor)) {
            _otherMajorController.text = _selectedMajor!;
            _selectedMajor = "Other";
        }
      });
    }
  }

  @override
  void dispose() {
    _gpaController.dispose();
    _graduationController.dispose();
    _otherUniversityController.dispose();
    _otherMajorController.dispose();
    super.dispose();
  }
  
  Future<void> _selectGraduationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 10),
      initialDatePickerMode: DatePickerMode.year,
       builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _profilePrimaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _profileSecondaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _graduationController.text = DateFormat('MMMM yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');
      
      final String finalUniversity = _selectedUniversity == 'Other'
          ? _otherUniversityController.text.trim()
          : _selectedUniversity!;
      final String finalMajor = _selectedMajor == 'Other'
          ? _otherMajorController.text.trim()
          : _selectedMajor!;

      final updated = widget.student.copyWith(
        university: finalUniversity,
        major: finalMajor,
        level: _selectedLevel,
        expectedGraduationDate: _graduationController.text.trim().isEmpty ? null : _graduationController.text.trim(),
        gpa: _gpaController.text.trim().isEmpty ? null : double.tryParse(_gpaController.text.trim()),
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academic info updated successfully!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Academic Info')),
      body: FutureBuilder(
        future: _loadListsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _profilePrimaryColor));
          }
           if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
           }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchableDropdown(
                    labelText: 'University',
                    selectedValue: _selectedUniversity,
                    icon: Icons.school_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please select a university';
                      if (value == 'Other' && _otherUniversityController.text.trim().isEmpty) return 'Please specify your university';
                      return null;
                    },
                    onTap: () async {
                      await _showSearchDialog(
                        context: context,
                        items: _universitiesList,
                        title: 'University',
                        onItemSelected: (value) => setState(() {
                          _selectedUniversity = value;
                          if (value != 'Other') _otherUniversityController.clear();
                        }),
                      );
                    },
                  ),
                  if (_selectedUniversity == 'Other')
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextFormField(
                        controller: _otherUniversityController,
                        decoration: const InputDecoration(labelText: 'Please specify your university'),
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'This field is required';
                          if (value.length > 30) return 'Cannot exceed 30 characters';
                          return null;
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildSearchableDropdown(
                    labelText: 'Major',
                    selectedValue: _selectedMajor,
                    icon: Icons.book_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please select a major';
                      if (value == 'Other' && _otherMajorController.text.trim().isEmpty) return 'Please specify your major';
                      return null;
                    },
                    onTap: () async {
                      await _showSearchDialog(
                        context: context,
                        items: _majorsList,
                        title: 'Major',
                        onItemSelected: (value) => setState(() {
                          _selectedMajor = value;
                          if (value != 'Other') _otherMajorController.clear();
                        }),
                      );
                    },
                  ),
                  if (_selectedMajor == 'Other')
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextFormField(
                        controller: _otherMajorController,
                        decoration: const InputDecoration(labelText: 'Please specify your major'),
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'This field is required';
                          if (value.length > 30) return 'Cannot exceed 30 characters';
                          return null;
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedLevel,
                    onChanged: (value) => setState(() => _selectedLevel = value),
                    decoration: const InputDecoration(labelText: 'Academic Level'),
                    items: _academicLevels.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _graduationController,
                    decoration: const InputDecoration(labelText: 'Expected Graduation Date'),
                    readOnly: true,
                    onTap: () => _selectGraduationDate(context),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _gpaScale,
                    onChanged: (String? newValue) {
                      setState(() {
                        _gpaScale = newValue;
                        _gpaController.clear();
                      });
                    },
                    decoration: const InputDecoration(labelText: 'GPA Scale'),
                    items: ['4.0', '5.0'].map((scale) => DropdownMenuItem(value: scale, child: Text(scale))).toList(),
                  ),
                  if (_gpaScale != null) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gpaController,
                      decoration: const InputDecoration(labelText: 'GPA (e.g., 3.8)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final gpa = double.tryParse(value);
                        if (gpa == null) return 'Invalid GPA format';
                        if (_gpaScale == '4.0' && (gpa < 0 || gpa > 4.0)) return 'GPA must be between 0 and 4.0';
                        if (_gpaScale == '5.0' && (gpa < 0 || gpa > 5.0)) return 'GPA must be between 0 and 5.0';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}

// --- 3. Skills Screen ---

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key, required this.student});
  final Student student;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final AuthService _authService = AuthService();
  late List<String> _skills;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _skills = List<String>.from(widget.student.skills);
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final updated = widget.student.copyWith(skills: List<String>.from(_skills));
      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skills updated successfully.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addSkill() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Skill'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Skill name'),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Cannot be empty';
                if (value.length > 30) return 'Cannot exceed 30 characters';
                return null;
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
              if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(controller.text.trim());
              }
          }, child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && !_skills.contains(result)) {
      setState(() => _skills.add(result));
    }
  }

  Future<void> _editSkill(int index) async {
    final controller = TextEditingController(text: _skills[index]);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Skill'),
        content: Form(
            key: formKey,
            child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Skill name'),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Cannot be empty';
                if (value.length > 30) return 'Cannot exceed 30 characters';
                return null;
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
             if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(controller.text.trim());
              }
          }, child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _skills[index] = result);
    }
  }

  Future<void> _removeSkill(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Skill'),
        content: Text('Are you sure you want to remove "${_skills[index]}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _skills.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Skills'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _persist,
            child: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addSkill, child: const Icon(Icons.add)),
      body: _skills.isEmpty
          ? const Center(child: Text('No skills added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _skills.length,
              itemBuilder: (context, index) {
                final skill = _skills[index];
                return Card(
                  child: ListTile(
                    title: Text(skill),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editSkill(index);
                        else if (value == 'remove') _removeSkill(index);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'remove', child: Text('Remove')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// --- 4. Followed Companies Screen (No validation needed) ---

class FollowedCompaniesScreen extends StatefulWidget {
  const FollowedCompaniesScreen({super.key, required this.student});
  final Student student;

  @override
  State<FollowedCompaniesScreen> createState() => _FollowedCompaniesScreenState();
}

class _FollowedCompaniesScreenState extends State<FollowedCompaniesScreen> {
  final AuthService _authService = AuthService();
  late List<String> _companies;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companies = List<String>.from(widget.student.followedCompanies);
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');
      final updated = widget.student.copyWith(followedCompanies: List<String>.from(_companies));
      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeCompany(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unfollow Company'),
        content: Text('Stop following "${_companies[index]}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Unfollow')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _companies.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Followed Companies'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _persist,
            child: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: _companies.isEmpty
          ? const Center(child: Text('You are not following any companies yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _companies.length,
              itemBuilder: (context, index) {
                final company = _companies[index];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blueGrey.shade100, child: Text(company[0].toUpperCase())),
                  title: Text(company),
                  trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _removeCompany(index)),
                );
              },
              separatorBuilder: (_, __) => const Divider(),
            ),
    );
  }
}

// --- 5. Documents Screen (No validation needed) ---

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.student});
  final Student student;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final StorageService _storageService = StorageService();
  bool _loading = false;
  bool _changed = false;
  List<StoredFile> _documents = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadDocuments());
  }

  Future<void> _loadDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final docs = await _storageService.getFiles(user.uid, 'documents');
      if (!mounted) return;
      setState(() {
        _documents = docs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading documents: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadDocument() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;
    final file = result.files.single;

    setState(() => _loading = true);
    try {
      await _storageService.uploadFile(uid: user.uid, collection: 'documents', file: file);
      _changed = true;
      await _loadDocuments(); // Refresh list
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Document uploaded successfully.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _deleteDocument(StoredFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _storageService.deleteFile(uid: user.uid, collection: 'documents', file: file);
      _changed = true;
      await _loadDocuments();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Document deleted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Documents')),
        floatingActionButton: FloatingActionButton(onPressed: _uploadDocument, child: const Icon(Icons.upload_file)),
        body: RefreshIndicator(
          onRefresh: _loadDocuments,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
                  ? const Center(child: Text('No documents uploaded yet.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: _documents.length,
                      itemBuilder: (context, index) {
                        final document = _documents[index];
                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.insert_drive_file, size: 40, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(document.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 16),
                                TextButton.icon(onPressed: () => _deleteDocument(document), icon: const Icon(Icons.delete_outline), label: const Text('Remove')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

// --- 6. Generated Resumes Screen (No validation needed) ---

class GeneratedResumesScreen extends StatefulWidget {
  const GeneratedResumesScreen({super.key, required this.student});
  final Student student;

  @override
  State<GeneratedResumesScreen> createState() => _GeneratedResumesScreenState();
}

class _GeneratedResumesScreenState extends State<GeneratedResumesScreen> {
  final StorageService _storageService = StorageService();
  bool _loading = false;
  bool _changed = false;
  List<StoredFile> _resumes = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadResumes());
  }

  Future<void> _loadResumes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final items = await _storageService.getFiles(user.uid, 'resumes');
      if (!mounted) return;
      setState(() {
        _resumes = items;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading resumes: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadResume() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;
    final file = result.files.single;

    setState(() => _loading = true);
    try {
      await _storageService.uploadFile(uid: user.uid, collection: 'resumes', file: file);
      _changed = true;
      await _loadResumes(); // Refresh list
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Resume uploaded.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _deleteResume(StoredFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resume'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _storageService.deleteFile(uid: user.uid, collection: 'resumes', file: file);
      _changed = true;
      await _loadResumes();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Resume deleted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }
  
  void _openLink(String url) {
    // In a real app, you would use the url_launcher package.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open $url in browser.')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Generated Resumes')),
        floatingActionButton: FloatingActionButton(onPressed: _uploadResume, child: const Icon(Icons.upload)),
        body: RefreshIndicator(
          onRefresh: _loadResumes,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _resumes.isEmpty
                  ? const Center(child: Text('No resumes uploaded yet.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _resumes.length,
                      itemBuilder: (context, index) {
                        final resume = _resumes[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF1F3F4),
                            child: Icon(Icons.description, color: Colors.black87),
                          ),
                          title: Text(resume.name),
                          subtitle: Text(resume.uploadedAt != null ? 'Uploaded ${resume.uploadedAt!.toLocal()}' : 'Awaiting timestamp'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteResume(resume)),
                          onTap: () => _openLink(resume.url),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(),
                    ),
        ),
      ),
    );
  }
}

// --- 7. Settings & Preferences Screen (No validation needed) ---

class SettingsPreferencesScreen extends StatefulWidget {
  const SettingsPreferencesScreen({super.key, required this.student});
  final Student student;

  @override
  State<SettingsPreferencesScreen> createState() => _SettingsPreferencesScreenState();
}

class _SettingsPreferencesScreenState extends State<SettingsPreferencesScreen> {
  final AuthService _authService = AuthService();
  late bool _resumePublic;
  late bool _documentsPublic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resumePublic = widget.student.resumeVisibility == 'public';
    _documentsPublic = widget.student.documentsVisibility == 'public';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final updated = widget.student.copyWith(
        resumeVisibility: _resumePublic ? 'public' : 'private',
        documentsVisibility: _documentsPublic ? 'public' : 'private',
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Settings & Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            value: _resumePublic,
            title: const Text('Public Resumes'),
            subtitle: const Text('Allow companies to view your generated resumes.'),
            onChanged: (value) => setState(() => _resumePublic = value),
          ),
          SwitchListTile(
            value: _documentsPublic,
            title: const Text('Public Documents'),
            subtitle: const Text('Allow companies to view uploaded documents.'),
            onChanged: (value) => setState(() => _documentsPublic = value),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

// --- 8. Change Password Screen ---

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  bool _sendingReset = false;
  
  // --- Password Strength State (from signup) ---
  final FocusNode _passwordFocusNode = FocusNode();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPasswordFocused = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _is8CharsLong = false;
  bool _hasNoSpaces = true;
  bool get _isPasswordValid => _is8CharsLong && _hasUppercase && _hasLowercase && _hasNumber && _hasSymbol && _hasNoSpaces;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // --- Password Strength Logic (from signup) ---
  void _checkPasswordStrength() {
    String password = _newPasswordController.text;
    setState(() {
      _is8CharsLong = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSymbol = password.contains(RegExp(r'[!@#\$&*~]'));
      _hasNoSpaces = !password.contains(' ');
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _authService.updateStudentPassword(_currentPasswordController.text, _newPasswordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _sendResetEmail() async {
    if (_sendingReset) return;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email is associated with this account.')));
      return;
    }

    setState(() => _sendingReset = true);
    try {
      await _authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset link sent to $email.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  // --- Password UI Widgets (from signup) ---
  Widget _buildPasswordCriteriaRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.remove_circle_outline,
            color: met ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: met ? Colors.black87 : Colors.grey)),
        ],
      ),
    );
  }

  double _calculatePasswordStrength() {
    int metCriteria = 0;
    if (_is8CharsLong) metCriteria++;
    if (_hasUppercase) metCriteria++;
    if (_hasLowercase) metCriteria++;
    if (_hasNumber) metCriteria++;
    if (_hasSymbol) metCriteria++;
    if (_hasNoSpaces) metCriteria++;
    return metCriteria / 6.0;
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength < 0.5) return Colors.red;
    if (strength < 0.9) return Colors.orange;
    return Colors.green;
  }


  @override
  Widget build(BuildContext context) {
    final passwordStrength = _calculatePasswordStrength();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Change Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                focusNode: _passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter new password';
                  if (value.contains(' ')) return 'Password cannot contain spaces';
                  if (!_isPasswordValid) return 'Please meet all password requirements';
                  return null;
                },
              ),
              if ((_isPasswordFocused || _newPasswordController.text.isNotEmpty) && !_isPasswordValid)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordCriteriaRow('At least 8 characters', _is8CharsLong),
                      _buildPasswordCriteriaRow('Contains an uppercase letter', _hasUppercase),
                      _buildPasswordCriteriaRow('Contains a lowercase letter', _hasLowercase),
                      _buildPasswordCriteriaRow('Contains a number', _hasNumber),
                      _buildPasswordCriteriaRow('Contains a symbol (!@#\$&*~)', _hasSymbol),
                      _buildPasswordCriteriaRow('Does not contain spaces', _hasNoSpaces),
                      const SizedBox(height: 8),
                      if(!_isPasswordValid)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: passwordStrength,
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade300,
                          color: _getPasswordStrengthColor(passwordStrength),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                   suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) => (value != _newPasswordController.text) ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Update Password'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _sendingReset ? null : _sendResetEmail,
                icon: _sendingReset
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.email_outlined),
                label: Text(_sendingReset ? 'Sending reset email...' : 'Email me a reset link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 9. Change Email Screen (No validation needed to change) ---


// --- Reusable Helper Widgets for this file ---

Widget _buildSearchableDropdown({
  required String labelText,
  required String? selectedValue,
  required IconData icon,
  required VoidCallback onTap,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: TextEditingController(text: selectedValue),
    readOnly: true,
    onTap: onTap,
    validator: validator,
    decoration: InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: const Icon(Icons.arrow_drop_down, color: _profilePrimaryColor),
    ),
  );
}

Future<void> _showSearchDialog({
  required BuildContext context,
  required List<String> items,
  required String title,
  required Function(String) onItemSelected,
}) async {
  final TextEditingController searchController = TextEditingController();
  List<String> filteredItems = List.from(items);

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _profileBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Select $title', style: const TextStyle(color: _profilePrimaryColor, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search for a $title...',
                      prefixIcon: const Icon(Icons.search, color: _profilePrimaryColor),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _profilePrimaryColor)),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        filteredItems = items
                            .where((item) => item.toLowerCase().contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          title: Text(item, style: const TextStyle(color: Colors.black87)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () {
                            onItemSelected(item);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: _profileSecondaryColor, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      );
    },
);
}