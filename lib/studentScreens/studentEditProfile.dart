// lib/features/profile/screens/profile_edit_screens.dart
// This file contains all secondary screens for editing profile sections.

import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/student.dart';
import '../../../services/authService.dart';
import '../../../services/storage_service.dart';

// Color constant needed by some edit screens
const Color _profilePrimaryColor = Color(0xFF422F5D);

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
  late TextEditingController _locationController;
  late TextEditingController _summaryController;

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstNameController = TextEditingController(text: student.firstName);
    _lastNameController = TextEditingController(text: student.lastName);
    _usernameController = TextEditingController(text: student.username);
    _phoneController = TextEditingController(text: student.phoneNumber);
    _locationController = TextEditingController(text: student.location ?? '');
    _summaryController = TextEditingController(text: student.shortSummary ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    super.dispose();
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
    final firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance.ref().child(
      'students/$uid/profile/profile_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );

    final bytes = await file.readAsBytes();
    await ref.putData(bytes, firebase_storage.SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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

      final updated = widget.student.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: trimmedUsername,
        phoneNumber: _phoneController.text.trim(),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        shortSummary: _summaryController.text.trim().isEmpty ? null : _summaryController.text.trim(),
        profilePictureUrl: profileUrl,
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
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(labelText: 'Short Summary'),
                maxLines: 4,
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

  late TextEditingController _universityController;
  late TextEditingController _majorController;
  late TextEditingController _levelController;
  late TextEditingController _gpaController;
  late TextEditingController _graduationController;

  bool _saving = false;
  bool _loadingLists = true;
  List<String> _universities = [];
  List<String> _majors = [];

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _universityController = TextEditingController(text: student.university);
    _majorController = TextEditingController(text: student.major);
    _levelController = TextEditingController(text: student.level ?? '');
    _gpaController = TextEditingController(
      text: student.gpa != null ? student.gpa!.toStringAsFixed(2) : '',
    );
    _graduationController = TextEditingController(
      text: student.expectedGraduationDate ?? '',
    );
    _loadLists();
  }

  @override
  void dispose() {
    _universityController.dispose();
    _majorController.dispose();
    _levelController.dispose();
    _gpaController.dispose();
    _graduationController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final result = await _authService.getUniversitiesAndMajors();
    if (!mounted) return;
    setState(() {
      _universities = result['universities'] ?? [];
      _majors = result['majors'] ?? [];
      _loadingLists = false;
    });
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      suffixIcon: _loadingLists
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final updated = widget.student.copyWith(
        university: _universityController.text.trim(),
        major: _majorController.text.trim(),
        level: _levelController.text.trim().isEmpty ? null : _levelController.text.trim(),
        expectedGraduationDate: _graduationController.text.trim().isEmpty ? null : _graduationController.text.trim(),
        gpa: _gpaController.text.trim().isEmpty ? null : double.tryParse(_gpaController.text.trim()),
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
      appBar: AppBar(title: const Text('Academic Info')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _universityController,
                decoration: _dropdownDecoration('University'),
                readOnly: _universities.isNotEmpty,
                onTap: _universities.isEmpty
                    ? null
                    : () async {
                        final selection = await showDialog<String>(
                          context: context,
                          builder: (_) => _SelectionDialog(
                            title: 'Select University',
                            options: _universities,
                            selected: _universityController.text.trim(),
                          ),
                        );
                        if (selection != null) _universityController.text = selection;
                      },
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _majorController,
                decoration: _dropdownDecoration('Major'),
                readOnly: _majors.isNotEmpty,
                onTap: _majors.isEmpty
                    ? null
                    : () async {
                        final selection = await showDialog<String>(
                          context: context,
                          builder: (_) => _SelectionDialog(
                            title: 'Select Major',
                            options: _majors,
                            selected: _majorController.text.trim(),
                          ),
                        );
                        if (selection != null) _majorController.text = selection;
                      },
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _levelController,
                decoration: const InputDecoration(labelText: 'Level'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gpaController,
                decoration: const InputDecoration(labelText: 'GPA'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final gpa = double.tryParse(value.trim());
                  if (gpa == null || gpa < 0 || gpa > 4.0) return 'Enter a GPA between 0.0 and 4.0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _graduationController,
                decoration: const InputDecoration(labelText: 'Expected Graduation (e.g., May 2026)'),
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
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Skill name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _skills.add(result));
    }
  }

  Future<void> _editSkill(int index) async {
    final controller = TextEditingController(text: _skills[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Skill'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Skill name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
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

// --- 4. Followed Companies Screen ---

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

// --- 5. Documents Screen ---

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

// --- 6. Generated Resumes Screen ---

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

// --- 7. Settings & Preferences Screen ---

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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
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
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) => (value == null || value.length < 6) ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
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

// --- Private Helper Widget for this File ---

/// A dialog used by AcademicInfoScreen to select from a list of options.
class _SelectionDialog extends StatelessWidget {
  const _SelectionDialog({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (_, index) {
            final option = options[index];
            return ListTile(
              title: Text(option),
              trailing: option == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(option),
            );
          },
        ),
      ),
    );
  }
}