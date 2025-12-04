// lib/features/profile/screens/profile_edit_screens.dart
// This file contains all secondary screens for editing profile sections.

import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/document_group.dart';
import '../companyScreens/company_theme.dart';

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
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => screen));

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
      backgroundColor: const Color(0xFFF7F2FB),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildSection(
            header: 'Profile Information',
            tiles: [
              _buildProfileTile(
                'Personal Information',
                Icons.person_outline,
                () => _navigateAndRefresh(
                  PersonalInformationScreen(student: _student),
                ),
              ),
              _buildProfileTile(
                'Academic Information',
                Icons.school_outlined,
                () =>
                    _navigateAndRefresh(AcademicInfoScreen(student: _student)),
              ),
              _buildProfileTile(
                'Skills',
                Icons.lightbulb_outline,
                () => _navigateAndRefresh(SkillsScreen(student: _student)),
              ),
              _buildProfileTile(
                'Followed Companies',
                Icons.business_center_outlined,
                () => _navigateAndRefresh(
                  FollowedCompaniesScreen(student: _student),
                ),
              ),
            ],
          ),
          _buildSection(
            header: 'Documents & Resumes',
            tiles: [
              _buildProfileTile(
                'My Documents',
                Icons.folder_open_outlined,
                () => _navigateAndRefresh(DocumentsScreen(student: _student)),
              ),
              _buildProfileTile(
                'Generated Resumes',
                Icons.description_outlined,
                () => _navigateAndRefresh(
                  GeneratedResumesScreen(student: _student),
                ),
              ),
            ],
          ),
          _buildSection(
            header: 'Account Settings',
            tiles: [
              _buildProfileTile(
                'Settings & Preferences',
                Icons.settings_outlined,
                () => _navigateAndRefresh(
                  SettingsPreferencesScreen(student: _student),
                ),
              ),
              _buildProfileTile(
                'Change Password',
                Icons.lock_outline,
                () => _navigateAndRefresh(const ChangePasswordScreen()),
              ),
              // --- ADDED: Delete Account Tile ---
              _buildProfileTile(
                'Delete Account',
                Icons.delete_forever_outlined,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DeleteAccountScreen(),
                  ),
                ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.15),
            backgroundImage: _student.profilePictureUrl != null
                ? NetworkImage(_student.profilePictureUrl!)
                : null,
            child: _student.profilePictureUrl == null
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            '${_student.firstName} ${_student.lastName}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${_student.username}',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 16),
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
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Column(children: tiles),
        const SizedBox(height: 10),
      ],
    );
  }

  /// --- MODIFIED: Added optional color parameter for styling ---
  /// Builds a single navigation list tile.
  Widget _buildProfileTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.white70,
          ),
          onTap: onTap,
        ),
      ),
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
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
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
    'Riyadh',
    'Jeddah',
    'Dammam',
    'Khobar',
    'Dhahran',
    'Mecca',
    'Medina',
    'Other',
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
    _phoneController = TextEditingController(
      text: phoneNumber.replaceAll(' ', ''),
    );

    _summaryController = TextEditingController(
      text: student.shortSummary ?? '',
    );
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
                    const Icon(
                      Icons.arrow_drop_down,
                      color: _profilePrimaryColor,
                    ),
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
                              .where(
                                (item) => item.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
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
                ),
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
      if (mounted)
        setState(() {
          _isCheckingUsername = true;
        });
      if (_usernameError != null) {
        setState(() {
          _usernameError = null;
        });
      }
      if (value.isNotEmpty && value != widget.student.username) {
        final isUnique = await _authService.isUsernameUnique(value);
        if (!isUnique && mounted) {
          setState(() {
            _usernameError = 'This username is already taken.';
          });
        }
      }
      if (mounted)
        setState(() {
          _isCheckingUsername = false;
        });
    });
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
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
    final firebase_storage.Reference
    ref = firebase_storage.FirebaseStorage.instance.ref().child(
      'students/$uid/profile/profile_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );

    final bytes = await file.readAsBytes();
    await ref.putData(
      bytes,
      firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_usernameError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_usernameError!)));
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
            await firebase_storage.FirebaseStorage.instance
                .refFromURL(widget.student.profilePictureUrl!)
                .delete();
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
        shortSummary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        shortSummarySetToNull: _summaryController.text.trim().isEmpty,
        profilePictureUrl: profileUrl,
        profilePictureUrlSetToNull: profileUrl == null,
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
                      child: backgroundImage == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
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
                    if (_previewBytes != null ||
                        widget.student.profilePictureUrl != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: IconButton(
                          onPressed: _removeImage,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 18,
                          ),
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
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                      ),
                      inputFormatters: [LengthLimitingTextInputFormatter(15)],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Required';
                        if (value.contains(' ')) {
                          return 'First name cannot contain spaces';
                        }
                        if (RegExp(
                          r'[0-9!@#$%^&*(),.?":{}|<>]',
                        ).hasMatch(value)) {
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
                        if (value == null || value.trim().isEmpty)
                          return 'Required';
                        if (value.contains(' ')) {
                          return 'Last name cannot contain spaces';
                        }
                        if (RegExp(
                          r'[0-9!@#$%^&*(),.?":{}|<>]',
                        ).hasMatch(value)) {
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
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.0),
                          ),
                        )
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
                    Container(
                      height: 20,
                      width: 1,
                      color: Colors.grey.shade400,
                    ),
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
                          if (value == null || value.isEmpty)
                            return 'Please enter phone number';
                          final digitsOnly = value.replaceAll(' ', '');
                          if (digitsOnly.length != 9) return 'Must be 9 digits';
                          if (!digitsOnly.startsWith('5'))
                            return 'Must start with 5';
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: '5X XXX XXXX',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
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
                    decoration: const InputDecoration(
                      labelText: 'Please specify your location',
                    ),
                    // --- MODIFIED --- Character limit changed from 30 to 15
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    validator: null,
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(
                  labelText: 'Short Summary (Optional)',
                ),
                maxLines: 4,
                maxLength: 250,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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
    'King Saud University',
    'King Fahd University of Petroleum and Minerals',
    'Alfaisal University',
    'Princess Nourah bint Abdulrahman University',
    'Imam Abdulrahman bin Faisal University',
    'Other',
  ];
  final List<String> _majorsList = [
    'Computer Science',
    'Software Engineering',
    'Information Technology',
    'Cybersecurity',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Business Administration',
    'Finance',
    'Other',
  ];

  final List<String> _academicLevels = [
    'Freshman (Level 1-2)',
    'Sophomore (Level 3-4)',
    'Junior (Level 5-6)',
    'Senior (Level 7-8)',
    'Senior (Level +9)',
    'Graduate Student',
  ];

  @override
  void initState() {
    super.initState();
    final student = widget.student;

    _otherUniversityController = TextEditingController();
    _otherMajorController = TextEditingController();
    if (student.university.isNotEmpty &&
        _universitiesList.contains(student.university)) {
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
    _graduationController = TextEditingController(
      text: student.expectedGraduationDate ?? '',
    );

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
                    const Icon(
                      Icons.arrow_drop_down,
                      color: _profilePrimaryColor,
                    ),
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
                              .where(
                                (item) => item.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
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
                ),
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
        expectedGraduationDate: _graduationController.text.trim().isEmpty
            ? null
            : _graduationController.text.trim(),
        expectedGraduationDateSetToNull: _graduationController.text
            .trim()
            .isEmpty,
        gpa: _gpaController.text.trim().isEmpty
            ? null
            : double.tryParse(_gpaController.text.trim()),
        gpaSetToNull: _gpaController.text.trim().isEmpty,
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Academic info updated successfully!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
                  if (value == 'Other' &&
                      _otherUniversityController.text.trim().isEmpty)
                    return 'Please specify your university';
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
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextFormField(
                    controller: _otherUniversityController,
                    decoration: const InputDecoration(
                      labelText: 'Please specify your university',
                    ),
                    // --- MODIFIED --- Character limit changed from 30 to 15
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              _buildSearchableDropdown(
                labelText: 'Major',
                selectedValue: _selectedMajor,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value == 'Other' &&
                      _otherMajorController.text.trim().isEmpty)
                    return 'Please specify your major';
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
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextFormField(
                    controller: _otherMajorController,
                    decoration: const InputDecoration(
                      labelText: 'Please specify your major',
                    ),
                    // --- MODIFIED --- Character limit changed from 30 to 15
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                          onPressed: () =>
                              setState(() => _selectedLevel = null),
                        )
                      : null,
                ),
                items: _academicLevels.map<DropdownMenuItem<String>>((
                  String value,
                ) {
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
                          onPressed: () =>
                              setState(() => _graduationController.clear()),
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
                items: ['4.0', '5.0']
                    .map(
                      (scale) =>
                          DropdownMenuItem(value: scale, child: Text(scale)),
                    )
                    .toList(),
              ),
              if (_gpaScale != null) const SizedBox(height: 16),
              if (_gpaScale != null)
                TextFormField(
                  controller: _gpaController,
                  decoration: const InputDecoration(
                    labelText: 'GPA (Optional, e.g., 3.8)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final gpa = double.tryParse(value);
                    if (gpa == null) return 'Invalid GPA format';
                    if (_gpaScale == '4.0' && (gpa < 0 || gpa > 4.0))
                      return 'GPA must be between 0 and 4.0';
                    if (_gpaScale == '5.0' && (gpa < 0 || gpa > 5.0))
                      return 'GPA must be between 0 and 5.0';
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
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

      final updated = widget.student.copyWith(
        skills: List<String>.from(_skills),
      );
      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skills updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
              if (value == null || value.trim().isEmpty)
                return 'Cannot be empty';
              if (value.length > 15) return 'Cannot exceed 15 characters';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
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
              if (value == null || value.trim().isEmpty)
                return 'Cannot be empty';
              if (value.length > 15) return 'Cannot exceed 15 characters';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
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
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSkill,
        child: const Icon(Icons.add),
      ),
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
                        if (value == 'edit')
                          _editSkill(index);
                        else if (value == 'remove')
                          _removeSkill(index);
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
  State<FollowedCompaniesScreen> createState() =>
      _FollowedCompaniesScreenState();
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
      final updated = widget.student.copyWith(
        followedCompanies: List<String>.from(_companies),
      );
      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeCompany(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unfollow Company'),
        content: Text('Stop following "${_companies[index]}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unfollow'),
          ),
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
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _companies.isEmpty
          ? const Center(
              child: Text('You are not following any companies yet.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _companies.length,
              itemBuilder: (context, index) {
                final company = _companies[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade100,
                    child: Text(company[0].toUpperCase()),
                  ),
                  title: Text(company),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeCompany(index),
                  ),
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

// Palette aligned with the refreshed student UI
const Color _docPrimary = Color(0xFF8D52CC);
const Color _docSecondary = Color(0xFFD54DB9);
const Color _docMuted = Color(0xFF5F6368);
const Color _docSurface = Colors.white;
const Color _docBackground = Color(0xFFF7F2FB);
const LinearGradient _docHeaderGradient = LinearGradient(
  colors: [_docSecondary, _docPrimary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient _docPageGradient = LinearGradient(
  colors: [Color(0xFFF7F2FB), Color(0xFFFFFBFF)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class _DocumentsScreenState extends State<DocumentsScreen> {
  final StorageService _storageService = StorageService();
  bool _loading = false;
  bool _changed = false;
  bool _editMode = false; // Toggle between view and edit mode
  List<DocumentGroup> _groups = [];
  Map<String, List<StoredFile>> _groupFiles = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroups());
  }

  Future<void> _loadGroups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      // Ensure default group exists
      await _storageService.ensureDefaultGroup(user.uid);

      // Load all groups
      final groups = await _storageService.getDocumentGroups(user.uid);

      // Load files for each group
      final Map<String, List<StoredFile>> groupFiles = {};
      for (final group in groups) {
        final files = await _storageService.getFilesInGroup(user.uid, group.id);
        groupFiles[group.id] = files;
      }

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _groupFiles = groupFiles;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading documents: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addNewGroup() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Group'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Group Title',
                  hintText: 'Enter group name (max 50 characters)',
                  counterText: '${controller.text.length}/50',
                ),
                autofocus: true,
                maxLength: 50,
                onChanged: (_) => formKey.currentState?.validate(),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Group name cannot be empty';
                  }
                  if (trimmed.length < 2) {
                    return 'Group name must be at least 2 characters';
                  }
                  if (trimmed.length > 50) {
                    return 'Group name must be 50 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) => Text(
                  '${value.text.length}/50',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final text = controller.text.trim();
                Navigator.of(context).pop(text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _storageService.createDocumentGroup(uid: user.uid, title: title);
      _changed = true;
      await _loadGroups();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Group "$title" created successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
    }
  }

  Future<void> _uploadDocument(String groupId) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'txt'],
    );
    if (result == null) return;
    final validExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'txt'];
    final validFiles = result.files.where((file) {
      final extension = file.extension?.toLowerCase();
      final hasBytes = file.bytes != null;
      return hasBytes && extension != null && validExtensions.contains(extension);
    }).toList();
    final skippedCount = result.files.length - validFiles.length;
    if (validFiles.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Only PDF, PNG, JPG, DOC, DOCX, and TXT files can be uploaded.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      for (final file in validFiles) {
        await _storageService.uploadFileToGroup(
          uid: user.uid,
          groupId: groupId,
          file: file,
        );
      }
      _changed = true;
      await _loadGroups(); // Refresh list
      if (!mounted) return;
      String baseMessage = validFiles.length == 1
          ? 'Document uploaded successfully.'
          : '${validFiles.length} documents uploaded successfully.';
      if (skippedCount > 0) {
        baseMessage +=
            ' $skippedCount file(s) were skipped (unsupported format).';
      }
      messenger.showSnackBar(SnackBar(content: Text(baseMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _previewDocument(StoredFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(file.url);
      if (uri.scheme.startsWith('http')) {
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _DocumentPreviewPage(title: file.name, url: file.url),
          ),
        );
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not open document'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error opening document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDocument(String groupId, StoredFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _storageService.deleteFileFromGroup(
        uid: user.uid,
        groupId: groupId,
        file: file,
      );
      _changed = true;
      await _loadGroups();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Document deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }

  Future<void> _editGroupName(DocumentGroup group) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: group.title);
    final formKey = GlobalKey<FormState>();

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Group Title',
                  hintText: 'Enter group name (max 50 characters)',
                  counterText: '${controller.text.length}/50',
                ),
                autofocus: true,
                maxLength: 50,
                onChanged: (_) => formKey.currentState?.validate(),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Group name cannot be empty';
                  }
                  if (trimmed.length < 2) {
                    return 'Group name must be at least 2 characters';
                  }
                  if (trimmed.length > 50) {
                    return 'Group name must be 50 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, value, __) => Text(
                  '${value.text.length}/50',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final text = controller.text.trim();
                Navigator.of(context).pop(text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.isEmpty || newTitle == group.title) return;

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection(AuthService.kStudentCol)
          .doc(user.uid)
          .collection('documentGroups')
          .doc(group.id)
          .update({'title': newTitle});

      _changed = true;
      await _loadGroups();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Group name updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _deleteGroup(DocumentGroup group) async {
    // Don't allow deleting the default "Untitled" group
    if (group.title == 'Untitled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the default Untitled group.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fileCount = _groupFiles[group.id]?.length ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete "${group.title}"?\n\n'
          '${fileCount > 0 ? 'This will also delete $fileCount document(s) in this group.' : 'This group is empty.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _storageService.deleteDocumentGroup(
        uid: user.uid,
        groupId: group.id,
      );
      _changed = true;
      await _loadGroups();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Group deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }

  Future<void> _reorderGroups(int oldIndex, int newIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final group = _groups.removeAt(oldIndex);
      _groups.insert(newIndex, group);
    });

    try {
      await _storageService.updateGroupOrder(
        uid: user.uid,
        groups: _groups,
      );
      _changed = true;
    } catch (e) {
      // Revert on error
      await _loadGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reorder groups: $e')),
      );
    }
  }

  Widget _buildDocumentCard(String groupId, StoredFile document) {
    final extension = document.name.split('.').last.toLowerCase();

    IconData icon;
    Color iconColor;
    Color accentColor;

    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        iconColor = const Color(0xFFC62828);
        accentColor = const Color(0xFFFDE0DC);
        break;
      case 'png':
      case 'jpg':
      case 'jpeg':
        icon = Icons.image;
        iconColor = _docSecondary;
        accentColor = const Color(0xFFFBE3EE);
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        iconColor = const Color(0xFF1565C0);
        accentColor = const Color(0xFFE3F2FD);
        break;
      case 'txt':
        icon = Icons.text_snippet;
        iconColor = _docMuted;
        accentColor = const Color(0xFFF3F4F6);
        break;
      default:
        icon = Icons.insert_drive_file;
        iconColor = _docPrimary;
        accentColor = const Color(0xFFEDE7F6);
    }

    return Card(
      elevation: CompanySpacing.cardElevation,
      color: _docSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => _previewDocument(document),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: Text(
                    document.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _docPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => _previewDocument(document),
                    icon: const Icon(Icons.visibility_outlined,
                        color: _docPrimary),
                    tooltip: 'Preview',
                    iconSize: 22,
                  ),
                  if (_editMode)
                    IconButton(
                      onPressed: () => _deleteDocument(groupId, document),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: _docSecondary,
                      ),
                      tooltip: 'Delete',
                      iconSize: 22,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: _docBackground,
        appBar: AppBar(
          title: const Text('Documents'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: _docHeaderGradient),
          ),
          actions: [
            if (_editMode)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: _addNewGroup,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Group'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(_editMode ? Icons.check : Icons.edit),
              color: Colors.white,
              onPressed: () {
                setState(() {
                  _editMode = !_editMode;
                });
              },
              tooltip: _editMode ? 'Done' : 'Edit Mode',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: _docPageGradient),
          child: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: _docPrimary,
                    backgroundColor: _docSurface,
                    onRefresh: _loadGroups,
                    child: _groups.isEmpty
                        ? _buildEmptyState(context)
                        : ReorderableListView.builder(
                            padding: CompanySpacing.pagePadding(context),
                            physics: const AlwaysScrollableScrollPhysics(),
                            header: _buildDocumentsHeader(),
                            itemCount: _groups.length,
                            onReorder: _reorderGroups,
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              final files = _groupFiles[group.id] ?? [];
                              final isUntitled = group.title == 'Untitled';

                              return Card(
                                key: ValueKey(group.id),
                                margin: const EdgeInsets.only(bottom: 20),
                                elevation: CompanySpacing.cardElevation,
                                color: _docSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: CompanySpacing.cardRadius,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 18,
                                      ),
                                      decoration: const BoxDecoration(
                                        gradient: _docHeaderGradient,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          if (_editMode) ...[
                                            const Icon(
                                              Icons.drag_indicator,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  group.title,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${files.length} document(s)',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_editMode)
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                IconButton(
                                                  onPressed: () => _uploadDocument(group.id),
                                                  icon: const Icon(Icons.upload_file, color: Colors.white),
                                                  tooltip: 'Upload Document',
                                                ),
                                                IconButton(
                                                  onPressed: () => _editGroupName(group),
                                                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                                                  tooltip: 'Rename Group',
                                                ),
                                                if (!isUntitled)
                                                  IconButton(
                                                    onPressed: () => _deleteGroup(group),
                                                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                                                    tooltip: 'Delete Group',
                                                  ),
                                              ],
                                            )
                                        ],
                                      ),
                                    ),
                                    if (files.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.folder_open, color: _docMuted),
                                            SizedBox(width: 8),
                                            Text(
                                              'No documents in this group yet.',
                                              style: TextStyle(
                                                color: _docMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final bool isWide = constraints.maxWidth >= 600;
                                            final int crossAxisCount = isWide ? 3 : 2;
                                            final double childAspectRatio = isWide ? 0.82 : 0.75;

                                            return GridView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                crossAxisSpacing: 16,
                                                mainAxisSpacing: 16,
                                                childAspectRatio: childAspectRatio,
                                              ),
                                              itemCount: files.length,
                                              itemBuilder: (context, fileIndex) {
                                                return _buildDocumentCard(
                                                  group.id,
                                                  files[fileIndex],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: CompanySpacing.pagePadding(context),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildDocumentsHeader(),
        Card(
          elevation: CompanySpacing.cardElevation,
          shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
          color: _docSurface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No document groups yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _docPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first group to organise resumes, certificates, and other supporting files.',
                  style: TextStyle(color: _docMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _addNewGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _docPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Group'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsHeader() {
    final totalDocuments = _groupFiles.values.fold<int>(
      0,
      (sum, files) => sum + files.length,
    );
    final totalGroups = _groups.length;
    final headline = widget.student.firstName.isNotEmpty
        ? '${widget.student.firstName}\'s Document Library'
        : 'Document Library';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: _docHeaderGradient,
            borderRadius: CompanySpacing.cardRadius,
            boxShadow: [
              BoxShadow(
                color: _docPrimary.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Organise your documents and keep them ready to share with companies.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSummaryChip(
                    Icons.folder_open,
                    '$totalGroups ${totalGroups == 1 ? 'Group' : 'Groups'}',
                  ),
                  _buildSummaryChip(
                    Icons.insert_drive_file_rounded,
                    '$totalDocuments ${totalDocuments == 1 ? 'Document' : 'Documents'}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSummaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
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

class _DocumentPreviewPage extends StatelessWidget {
  const _DocumentPreviewPage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SfPdfViewer.network(url),
    );
  }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading resumes: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadResume() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;
    final file = result.files.single;

    setState(() => _loading = true);
    try {
      await _storageService.uploadFile(
        uid: user.uid,
        collection: 'resumes',
        file: file,
      );
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await _storageService.deleteFile(
        uid: user.uid,
        collection: 'resumes',
        file: file,
      );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Open $url in browser.')));
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
        floatingActionButton: FloatingActionButton(
          onPressed: _uploadResume,
          child: const Icon(Icons.upload),
        ),
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
                      subtitle: Text(
                        resume.uploadedAt != null
                            ? 'Uploaded ${resume.uploadedAt!.toLocal()}'
                            : 'Awaiting timestamp',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteResume(resume),
                      ),
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
  State<SettingsPreferencesScreen> createState() =>
      _SettingsPreferencesScreenState();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
            subtitle: const Text(
              'Allow companies to view your generated resumes.',
            ),
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
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
  bool get _isPasswordValid =>
      _is8CharsLong &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSymbol &&
      _hasNoSpaces;

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
      await _authService.updateStudentPassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _sendResetEmail() async {
    if (_sendingReset) return;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email is associated with this account.'),
        ),
      );
      return;
    }

    setState(() => _sendingReset = true);
    try {
      await _authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset link sent to $email.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
          Text(
            text,
            style: TextStyle(color: met ? Colors.black87 : Colors.grey),
          ),
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
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                focusNode: _passwordFocusNode,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter new password';
                  if (value.contains(' '))
                    return 'Password cannot contain spaces';
                  if (!_isPasswordValid)
                    return 'Please meet all password requirements';
                  return null;
                },
              ),
              if ((_isPasswordFocused ||
                      _newPasswordController.text.isNotEmpty) &&
                  !_isPasswordValid)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordCriteriaRow(
                        'At least 8 characters',
                        _is8CharsLong,
                      ),
                      _buildPasswordCriteriaRow(
                        'Contains an uppercase letter',
                        _hasUppercase,
                      ),
                      _buildPasswordCriteriaRow(
                        'Contains a lowercase letter',
                        _hasLowercase,
                      ),
                      _buildPasswordCriteriaRow(
                        'Contains a number',
                        _hasNumber,
                      ),
                      _buildPasswordCriteriaRow(
                        'Contains a symbol (!@#\$&*~)',
                        _hasSymbol,
                      ),
                      _buildPasswordCriteriaRow(
                        'Does not contain spaces',
                        _hasNoSpaces,
                      ),
                      const SizedBox(height: 8),
                      if (!_isPasswordValid)
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
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
                validator: (value) => (value != _newPasswordController.text)
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Password'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _sendingReset ? null : _sendResetEmail,
                icon: _sendingReset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.email_outlined),
                label: Text(
                  _sendingReset
                      ? 'Sending reset email...'
                      : 'Email me a reset link',
                ),
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
        content: const Text(
          'This action is irreversible. All your data, including your profile, documents, and resumes, will be permanently deleted.',
        ),
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account has been permanently deleted.'),
          backgroundColor: Colors.green,
        ),
      );

      // Pop all routes and push a new root route (e.g., a login or splash screen).
      // Replace '/login' with your actual initial route name.
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text("Deletion failed: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
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
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Your Account Permanently',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
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
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter your password'
                    : null,
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Delete Account Permanently',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email updated. Please verify the new address.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your password'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
