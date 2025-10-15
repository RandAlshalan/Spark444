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

// --- ADDED: Main Edit Profile Screen ---
// This screen acts as a navigation hub to other edit screens.

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.student});
  final Student student;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Student _student;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
  }

  /// Navigates to a detail screen and triggers a data refresh upon return if changes were made.
  Future<void> _navigateAndRefresh(Widget screen) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );

    // If the popped screen returns `true`, it indicates a successful update.
    // We re-fetch the student's data to reflect the changes.
    if (result == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final updatedStudent = await AuthService().getStudent(user.uid);
        if (updatedStudent != null && mounted) {
          setState(() {
            _student = updatedStudent;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildSection(
            header: 'Profile Information',
            tiles: [
              _buildProfileTile('Personal Information', Icons.person_outline, () => _navigateAndRefresh(PersonalInformationScreen(student: _student))),
              _buildProfileTile('Academic Information', Icons.school_outlined, () => _navigateAndRefresh(AcademicInfoScreen(student: _student))),
              _buildProfileTile('Skills', Icons.lightbulb_outline, () => _navigateAndRefresh(SkillsScreen(student: _student))),
              _buildProfileTile('Followed Companies', Icons.business_center_outlined, () => _navigateAndRefresh(FollowedCompaniesScreen(student: _student))),
            ],
          ),
          _buildSection(
            header: 'Documents & Resumes',
            tiles: [
              _buildProfileTile('My Documents', Icons.folder_open_outlined, () => _navigateAndRefresh(DocumentsScreen(student: _student))),
              _buildProfileTile('Generated Resumes', Icons.description_outlined, () => _navigateAndRefresh(GeneratedResumesScreen(student: _student))),
            ],
          ),
          _buildSection(
            header: 'Account Settings',
            tiles: [
              _buildProfileTile('Settings & Preferences', Icons.settings_outlined, () => _navigateAndRefresh(SettingsPreferencesScreen(student: _student))),
              _buildProfileTile('Change Password', Icons.lock_outline, () => _navigateAndRefresh(const ChangePasswordScreen())),
              // --- ADDED: Delete Account Tile ---
              _buildProfileTile(
                'Delete Account',
                Icons.delete_forever_outlined,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DeleteAccountScreen())),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the top section with the user's profile picture and name.
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _student.profilePictureUrl != null ? NetworkImage(_student.profilePictureUrl!) : null,
            child: _student.profilePictureUrl == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
          ),
          const SizedBox(height: 12),
          Text(
            '${_student.firstName} ${_student.lastName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            '@${_student.username}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Builds a section with a header and a list of navigation tiles.
  Widget _buildSection({required String header, required List<Widget> tiles}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Text(
            header.toUpperCase(),
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: tiles),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// --- MODIFIED: Added optional color parameter for styling ---
  /// Builds a single navigation list tile.
  Widget _buildProfileTile(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF422F5D)),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// Color constant needed by some edit screens
const Color _profilePrimaryColor = Color(0xFF422F5D);
const Color _profileSecondaryColor = Color(0xFFF99D46);

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
  late TextEditingController _otherLocationController;
  String? _selectedLocation;
  late TextEditingController _summaryController;

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _saving = false;

  String? _usernameError;
  Timer? _debounce;
  bool _isCheckingUsername = false;

  // --- ADDED: Sample list for cities. In a real app, fetch this from a service. ---
  final List<String> _locationsList = [
    'Riyadh', 'Jeddah', 'Dammam', 'Khobar', 'Dhahran', 'Mecca', 'Medina', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstNameController = TextEditingController(text: student.firstName);
    _lastNameController = TextEditingController(text: student.lastName);
    _usernameController = TextEditingController(text: student.username);

    String phoneNumber = student.phoneNumber ?? '';
    if (phoneNumber.startsWith('+966')) {
      phoneNumber = phoneNumber.substring(4);
    }
    _phoneController = TextEditingController(text: phoneNumber.replaceAll(' ', ''));

    _summaryController = TextEditingController(text: student.shortSummary ?? '');
    _otherLocationController = TextEditingController();
    // Set initial location. If it's not in our predefined list, set it as 'Other'.
    if (student.location != null && _locationsList.contains(student.location)) {
      _selectedLocation = student.location;
    } else if (student.location != null) {
      _selectedLocation = 'Other';
      _otherLocationController.text = student.location!;
    }

    _usernameController.addListener(() {
      if (_usernameController.text.trim() != widget.student.username) {
        _checkUsernameUniqueness(_usernameController.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _otherLocationController.dispose();
    _summaryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildSearchableDropdown({
    required String labelText,
    required String? selectedValue,
    required VoidCallback onTap,
    String? Function(String?)? validator,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: TextEditingController(text: selectedValue),
        readOnly: true,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          suffixIcon: selectedValue != null && onClear != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: onClear,
                    ),
                    const Icon(Icons.arrow_drop_down, color: _profilePrimaryColor),
                  ],
                )
              : const Icon(Icons.arrow_drop_down, color: _profilePrimaryColor),
        ),
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
              title: Text('Select $title'),
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
                        prefixIcon: const Icon(Icons.search),
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
                            title: Text(item),
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
                  child: const Text('Close'),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- MODIFIED --- Character limit changed from 12 to 15
  String? _usernameManualValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    if (value.length > 15) {
      return 'Username cannot exceed 15 characters';
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

  // ADDED: Function to remove the profile picture.
  Future<void> _removeImage() async {
    setState(() {
      _pickedImage = null;
      _previewBytes = null;
    });
  }

  Future<String?> _uploadProfilePicture(String uid, XFile file) async {
    final firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance.ref().child(
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

      // MODIFIED: Logic to handle removing the profile picture
      String? profileUrl = widget.student.profilePictureUrl;
      bool shouldRemoveImage = _pickedImage == null && _previewBytes == null;

      if (_pickedImage != null) {
        profileUrl = await _uploadProfilePicture(user.uid, _pickedImage!);
      } else if (shouldRemoveImage) {
        if (widget.student.profilePictureUrl != null) {
          try {
            await firebase_storage.FirebaseStorage.instance.refFromURL(widget.student.profilePictureUrl!).delete();
          } catch (e) {
            debugPrint("Failed to delete old profile picture: $e");
          }
        }
        profileUrl = null;
      }

      String? finalLocation;
      if (_selectedLocation == 'Other') {
        final otherLocation = _otherLocationController.text.trim();
        finalLocation = otherLocation.isEmpty ? null : otherLocation;
      } else {
        finalLocation = _selectedLocation;
      }

      final updated = widget.student.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: trimmedUsername,
        phoneNumber: "+966${_phoneController.text.trim().replaceAll(' ', '')}",
        location: finalLocation,
        locationSetToNull: finalLocation == null,
        shortSummary: _summaryController.text.trim().isEmpty ? null : _summaryController.text.trim(),
        shortSummarySetToNull: _summaryController.text.trim().isEmpty,
        profilePictureUrl: profileUrl,
        profilePictureUrlSetToNull: profileUrl == null,
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
      body: SingleChildScrollView(
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
                    // ADDED: "Remove Photo" button appears if a photo is set
                    if (_previewBytes != null || widget.student.profilePictureUrl != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: IconButton(
                          onPressed: _removeImage,
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.8),
                            fixedSize: const Size(32, 32),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    // --- MODIFIED --- Added consistent validation for first name
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      inputFormatters: [LengthLimitingTextInputFormatter(15)],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        if (value.contains(' ')) {
                          return 'First name cannot contain spaces';
                        }
                        if (RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                          return 'Names cannot contain numbers or symbols';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // --- MODIFIED --- Added consistent validation for last name
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      inputFormatters: [LengthLimitingTextInputFormatter(15)],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        if (value.contains(' ')) {
                          return 'Last name cannot contain spaces';
                        }
                        if (RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                          return 'Names cannot contain numbers or symbols';
                        }
                        return null;
                      },
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
                // --- MODIFIED --- Character limit changed from 12 to 15
                inputFormatters: [LengthLimitingTextInputFormatter(15)],
                validator: _usernameManualValidator,
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: const Text(
                        '+966',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                    Container(height: 20, width: 1, color: Colors.grey.shade400),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSearchableDropdown(
                labelText: 'City (Optional)',
                selectedValue: _selectedLocation,
                validator: null,
                onClear: () => setState(() {
                  _selectedLocation = null;
                  _otherLocationController.clear();
                }),
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
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextFormField(
                    controller: _otherLocationController,
                    decoration: const InputDecoration(labelText: 'Please specify your location'),
                    // --- MODIFIED --- Character limit changed from 30 to 15
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    validator: null,
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(labelText: 'Short Summary (Optional)'),
                maxLines: 4,
                maxLength: 250,
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

  late TextEditingController _otherUniversityController;
  late TextEditingController _otherMajorController;
  late TextEditingController _gpaController;
  late TextEditingController _graduationController;

  String? _selectedUniversity;
  String? _selectedMajor;
  String? _selectedLevel;
  String? _gpaScale;
  bool _saving = false;

  final List<String> _universitiesList = [
    'King Saud University', 'King Fahd University of Petroleum and Minerals', 'Alfaisal University', 'Princess Nourah bint Abdulrahman University', 'Imam Abdulrahman bin Faisal University', 'Other'
  ];
  final List<String> _majorsList = [
    'Computer Science', 'Software Engineering', 'Information Technology', 'Cybersecurity', 'Electrical Engineering', 'Mechanical Engineering', 'Business Administration', 'Finance', 'Other'
  ];

  final List<String> _academicLevels = [
    'Freshman (Level 1-2)', 'Sophomore (Level 3-4)', 'Junior (Level 5-6)',
    'Senior (Level 7-8)', 'Senior (Level +9)', 'Graduate Student'
  ];

  @override
  void initState() {
    super.initState();
    final student = widget.student;

    _otherUniversityController = TextEditingController();
    _otherMajorController = TextEditingController();
    if (student.university.isNotEmpty && _universitiesList.contains(student.university)) {
      _selectedUniversity = student.university;
    } else {
      _selectedUniversity = 'Other';
      _otherUniversityController.text = student.university;
    }
    if (student.major.isNotEmpty && _majorsList.contains(student.major)) {
      _selectedMajor = student.major;
    } else {
      _selectedMajor = 'Other';
      _otherMajorController.text = student.major;
    }

    _selectedLevel = student.level;
    _gpaController = TextEditingController(text: student.gpa?.toString() ?? '');
    _graduationController = TextEditingController(text: student.expectedGraduationDate ?? '');

    if (student.gpa != null) {
      _gpaScale = student.gpa! > 4.0 ? '5.0' : '4.0';
    }
  }

  @override
  void dispose() {
    _otherUniversityController.dispose();
    _otherMajorController.dispose();
    _gpaController.dispose();
    _graduationController.dispose();
    super.dispose();
  }

  Widget _buildSearchableDropdown({
    required String labelText,
    required String? selectedValue,
    required VoidCallback onTap,
    String? Function(String?)? validator,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: TextEditingController(text: selectedValue),
        readOnly: true,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          suffixIcon: selectedValue != null && onClear != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: onClear,
                    ),
                    const Icon(Icons.arrow_drop_down, color: _profilePrimaryColor),
                  ],
                )
              : const Icon(Icons.arrow_drop_down, color: _profilePrimaryColor),
        ),
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
              title: Text('Select $title'),
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
                        prefixIcon: const Icon(Icons.search),
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
                            title: Text(item),
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
                  child: const Text('Close'),
                )
              ],
            );
          },
        );
      },
    );
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
        levelSetToNull: _selectedLevel == null,
        expectedGraduationDate: _graduationController.text.trim().isEmpty ? null : _graduationController.text.trim(),
        expectedGraduationDateSetToNull: _graduationController.text.trim().isEmpty,
        gpa: _gpaController.text.trim().isEmpty ? null : double.tryParse(_gpaController.text.trim()),
        gpaSetToNull: _gpaController.text.trim().isEmpty,
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
      body: SingleChildScrollView(
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
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value == 'Other' && _otherUniversityController.text.trim().isEmpty) return 'Please specify your university';
                  return null;
                },
                onTap: () async {
                  await _showSearchDialog(
                    context: context, items: _universitiesList, title: 'University',
                    onItemSelected: (value) => setState(() {
                      _selectedUniversity = value;
                      if (value != 'Other') _otherUniversityController.clear();
                    }),
                  );
                },
              ),
              if (_selectedUniversity == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextFormField(
                    controller: _otherUniversityController,
                    decoration: const InputDecoration(labelText: 'Please specify your university'),
                    // --- MODIFIED --- Character limit changed from 30 to 15
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              _buildSearchableDropdown(
                labelText: 'Major',
                selectedValue: _selectedMajor,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value == 'Other' && _otherMajorController.text.trim().isEmpty) return 'Please specify your major';
                  return null;
                },
                onTap: () async {
                  await _showSearchDialog(
                    context: context, items: _majorsList, title: 'Major',
                    onItemSelected: (value) => setState(() {
                      _selectedMajor = value;
                      if (value != 'Other') _otherMajorController.clear();
                    }),
                  );
                },
              ),
              if (_selectedMajor == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextFormField(
                    controller: _otherMajorController,
                    decoration: const InputDecoration(labelText: 'Please specify your major'),
                    // --- MODIFIED --- Character limit changed from 30 to 15
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLevel,
                onChanged: (value) => setState(() => _selectedLevel = value),
                decoration: InputDecoration(
                  labelText: 'Academic Level (Optional)',
                  // ADDED: Clear button for the academic level
                  suffixIcon: _selectedLevel != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => setState(() => _selectedLevel = null),
                        )
                      : null,
                ),
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
                decoration: InputDecoration(
                  labelText: 'Expected Graduation Date (Optional)',
                  // ADDED: Clear button for the graduation date
                  suffixIcon: _graduationController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => setState(() => _graduationController.clear()),
                        )
                      : const Icon(Icons.calendar_today, color: Colors.grey),
                ),
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
                decoration: InputDecoration(
                  labelText: 'GPA Scale (Optional)',
                  // ADDED: Clear button for the GPA scale
                  suffixIcon: _gpaScale != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => setState(() {
                            _gpaScale = null;
                            _gpaController.clear();
                          }),
                        )
                      : null,
                ),
                items: ['4.0', '5.0'].map((scale) => DropdownMenuItem(value: scale, child: Text(scale))).toList(),
              ),
              if (_gpaScale != null)
                const SizedBox(height: 16),
              if (_gpaScale != null)
                TextFormField(
                  controller: _gpaController,
                  decoration: const InputDecoration(labelText: 'GPA (Optional, e.g., 3.8)'),
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
              // --- MODIFIED --- Character limit changed from 30 to 15
              inputFormatters: [LengthLimitingTextInputFormatter(15)],
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Cannot be empty';
                if (value.length > 15) return 'Cannot exceed 15 characters';
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
                // --- MODIFIED --- Character limit changed from 30 to 15
                inputFormatters: [LengthLimitingTextInputFormatter(15)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Cannot be empty';
                  if (value.length > 15) return 'Cannot exceed 15 characters';
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
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png'],
    );
    if (result == null) return;
    final validFiles = result.files.where((file) {
      final extension = file.extension?.toLowerCase();
      final hasBytes = file.bytes != null;
      return hasBytes && (extension == 'pdf' || extension == 'png');
    }).toList();
    final skippedCount = result.files.length - validFiles.length;
    if (validFiles.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Only PDF or PNG files can be uploaded.')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _storageService.uploadFiles(
        uid: user.uid,
        collection: 'documents',
        files: validFiles,
      );
      _changed = true;
      await _loadDocuments(); // Refresh list
      if (!mounted) return;
      String baseMessage = validFiles.length == 1
          ? 'Document uploaded successfully.'
          : '${validFiles.length} documents uploaded successfully.';
      if (skippedCount > 0) {
        baseMessage += ' $skippedCount file(s) were skipped because they are not PDF or PNG.';
      }
      messenger.showSnackBar(SnackBar(content: Text(baseMessage)));
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isWide = constraints.maxWidth >= 600;
                        final int crossAxisCount = isWide ? 3 : 2;
                        final double childAspectRatio = isWide ? 1.0 : 0.75;
                        return GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: childAspectRatio,
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
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          document.name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () => _deleteDocument(document),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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

  void _checkPasswordStrength() {
    String password = _newPasswordController.text;
    setState(() {
      _is8CharsLong = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSymbol = password.contains(RegExp(r'[!@#$&*~]'));
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

// --- ADDED: 9. Delete Account Screen ---

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  bool _deleting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text('This action is irreversible. All your data, including your profile, documents, and resumes, will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Delete My Account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // IMPORTANT: The implementation for this method needs to be added in `AuthService`.
      // It must handle:
      // 1. Re-authenticating the user with the provided password.
      // 2. Deleting all user files from Firebase Storage.
      // 3. Deleting the user's document from Firestore.
      // 4. Finally, deleting the user from Firebase Authentication.
      await _authService.deleteStudentAccount(_passwordController.text);

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Your account has been permanently deleted.'),
        backgroundColor: Colors.green,
      ));

      // Pop all routes and push a new root route (e.g., a login or splash screen).
      // Replace '/login' with your actual initial route name.
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);

    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text("Deletion failed: ${e.toString()}"),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Delete Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              const Text(
                'Delete Your Account Permanently',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You are about to request the permanent deletion of your account. Once this process begins, it cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              const Text(
                'For security, please enter your password to continue.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your password' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _deleting ? null : _handleDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _deleting
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Delete Account Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 9. Change Email Screen ---

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key, required this.currentEmail});
  final String currentEmail;

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _authService.updateStudentEmail(
        password: _passwordController.text,
        newEmail: _emailController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email updated. Please verify the new address.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Change Email')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'New Email'),
                validator: (value) => (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Update Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
