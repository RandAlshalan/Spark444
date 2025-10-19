import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/company.dart';
import '../services/authService.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EditCompanyProfilePage extends StatefulWidget {
  final Company company;

  const EditCompanyProfilePage({super.key, required this.company});

  @override
  _EditCompanyProfilePageState createState() => _EditCompanyProfilePageState();
}

class _EditCompanyProfilePageState extends State<EditCompanyProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _companyNameController;
  late TextEditingController _sectorController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _descriptionController;

  bool _isLoading = false;
  String? _logoPath;
  String? _logoUrl;
  final AuthService _authService = AuthService();

  // Sector dropdown
  String? _selectedSector;
  static const List<String> _sectorsList = [
    'Information Technology & Software',
    'Telecommunications',
    'Finance & Banking',
    'Insurance',
    'Healthcare & Pharmaceuticals',
    'Education & Training',
    'Manufacturing',
    'Construction & Real Estate',
    'Transportation & Logistics',
    'Retail & E-commerce',
    'Hospitality & Tourism',
    'Food & Beverages',
    'Energy & Utilities (Oil, Gas, Renewable, Electricity, Water)',
    'Agriculture & Farming',
    'Media & Entertainment',
    'Professional Services (Consulting, Legal, Accounting, etc.)',
    'Government & Public Sector',
    'Non-Profit & NGOs',
    'Other',
  ];

  static const int _maxDescriptionLength = 500;
  int _descriptionCharCount = 0;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController(
      text: widget.company.companyName,
    );
    _sectorController = TextEditingController();
    _contactNameController = TextEditingController();
    _contactNumberController = TextEditingController();
    _descriptionController = TextEditingController(
      text: widget.company.description,
    );
    _logoUrl = widget.company.logoUrl;

    if (_sectorsList.contains(widget.company.sector)) {
      _selectedSector = widget.company.sector;
    } else {
      _selectedSector = 'Other';
      _sectorController.text = widget.company.sector;
    }

    _parseContactInfo(widget.company.contactInfo);
    _descriptionCharCount = (widget.company.description ?? '').length;
    _descriptionController.addListener(_updateDescriptionCharCount);
  }

  void _parseContactInfo(String contactInfo) {
    final parts = contactInfo.split(' - ');
    if (parts.length == 2) {
      _contactNameController.text = parts[0].trim();
      final phoneNumber = parts[1].trim();
      if (phoneNumber.startsWith('+966')) {
        _contactNumberController.text = phoneNumber.substring(4);
      } else {
        _contactNumberController.text = phoneNumber;
      }
    } else {
      _contactNameController.text = contactInfo;
    }
  }

  void _updateDescriptionCharCount() {
    final currentLength = _descriptionController.text.length;
    if (_descriptionCharCount != currentLength) {
      setState(() {
        _descriptionCharCount = currentLength;
      });
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _sectorController.dispose();
    _contactNameController.dispose();
    _contactNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Logo Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF422F5D),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF6B4791),
                  ),
                  title: const Text('Photo Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF6B4791),
                  ),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _isUploadingLogo = true;
        });

        final fileSize = await pickedFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Logo file size must be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isUploadingLogo = false);
          return;
        }

        if (_logoUrl != null && _logoUrl!.contains('firebase')) {
          try {
            final oldRef = FirebaseStorage.instance.refFromURL(_logoUrl!);
            await oldRef.delete();
          } catch (e) {
            debugPrint('Error deleting old logo: $e');
          }
        }

        final extension = pickedFile.name.split('.').last.toLowerCase();
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('company_logos')
            .child(
              '${widget.company.uid}_${DateTime.now().millisecondsSinceEpoch}.$extension',
            );

        String contentType = 'image/jpeg';
        if (extension == 'png') {
          contentType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          contentType = 'image/jpeg';
        }

        UploadTask uploadTask;
        final metadata = SettableMetadata(contentType: contentType);
        if (kIsWeb) {
          final Uint8List bytes = await pickedFile.readAsBytes();
          uploadTask = storageRef.putData(bytes, metadata);
        } else {
          final file = File(pickedFile.path);
          uploadTask = storageRef.putFile(file, metadata);
        }

        final uploadSnapshot = await uploadTask;
        final downloadUrl = await uploadSnapshot.ref.getDownloadURL();

        setState(() {
          _logoPath = pickedFile.path;
          _logoUrl = downloadUrl;
          _isUploadingLogo = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logo uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteLogo() async {
    try {
      setState(() => _isUploadingLogo = true);
      if (_logoUrl != null && _logoUrl!.contains('firebase')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(_logoUrl!);
          await ref.delete();
        } catch (e) {
          debugPrint('Error deleting old logo: $e');
        }
      }
      setState(() {
        _logoPath = null;
        _logoUrl = null;
        _isUploadingLogo = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final String combinedContactInfo =
          _contactNumberController.text.trim().isNotEmpty
          ? '${_contactNameController.text.trim()} - +966${_contactNumberController.text.trim()}'
          : _contactNameController.text.trim();

      final String finalSector = _selectedSector == 'Other'
          ? _sectorController.text.trim()
          : _selectedSector ?? 'Other';

      final updatedCompany = Company(
        uid: widget.company.uid,
        companyName: _companyNameController.text.trim(),
        email: widget.company.email,
        sector: finalSector,
        contactInfo: combinedContactInfo,
        description: _descriptionController.text.trim(),
        logoUrl: _logoUrl,
        userType: widget.company.userType,
        createdAt: widget.company.createdAt,
        isVerified: widget.company.isVerified,
        opportunitiesPosted: widget.company.opportunitiesPosted,
        studentReviews: widget.company.studentReviews,
      );

      try {
        await _authService.updateCompany(widget.company.uid!, updatedCompany);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF422F5D),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF7F4F0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF422F5D)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildLogoSection(),
              const SizedBox(height: 30),
              _buildStyledTextFormField(
                controller: _companyNameController,
                hintText: 'Company Name',
                icon: Icons.business_outlined,
                // MODIFIED: Removed character filter to allow numbers and special characters
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Company name is required.';
                  }
                  if (value.startsWith(' ')) {
                    return 'Name cannot start with a space';
                  }
                  if (value.length > 40) {
                    return 'Company name cannot exceed 40 characters.';
                  }
                  return null;
                },
              ),
              _buildSectorDropdown(),
              _buildStyledTextFormField(
                controller: _contactNameController,
                hintText: 'Contact Person Name',
                icon: Icons.person_outlined,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(50),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],

                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Please enter a contact name';
                  if (value.startsWith(' ')) {
                    return 'Name cannot start with a space';
                  }
                },
              ),
              _buildPhoneFormField(),
              _buildDescriptionField(),
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$_descriptionCharCount/$_maxDescriptionLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: _descriptionCharCount > _maxDescriptionLength
                          ? Colors.red
                          : _descriptionCharCount >
                                (_maxDescriptionLength * 0.9)
                          ? const Color(0xFFF99D46)
                          : Colors.grey,
                      fontWeight:
                          _descriptionCharCount > (_maxDescriptionLength * 0.9)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildGradientButton(
                text: 'Save Changes',
                onPressed: _updateProfile,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: _maxDescriptionLength,
            buildCounter:
                (
                  BuildContext context, {
                  required int currentLength,
                  required bool isFocused,
                  required int? maxLength,
                }) => const SizedBox.shrink(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Company description is required.';
              }
              if (value.length > _maxDescriptionLength) {
                return 'Description cannot exceed $_maxDescriptionLength characters.';
              }
              return null;
            },
            decoration: const InputDecoration(
              hintText: 'Company Description',
              prefixIcon: Icon(Icons.description_outlined, color: Colors.grey),
              contentPadding: EdgeInsets.fromLTRB(20, 15, 20, 15),
              border: InputBorder.none,
            ),
          ),
          Positioned(
            bottom: 8.0,
            right: 8.0,
            child: ElevatedButton(
              onPressed: () => FocusScope.of(context).unfocus(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF422F5D).withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    final bool hasCustomLogo = _logoUrl != null && _logoUrl!.isNotEmpty;
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white,
              backgroundImage: _logoPath != null
                  ? FileImage(File(_logoPath!))
                  : _logoUrl != null && _logoUrl!.isNotEmpty
                  ? NetworkImage(_logoUrl!)
                  : null,
              child:
                  (_logoPath == null && (_logoUrl == null || _logoUrl!.isEmpty))
                  ? const Icon(
                      Icons.apartment_outlined,
                      color: Color(0xFF6B4791),
                      size: 48,
                    )
                  : null,
            ),
            if (_isUploadingLogo)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _isUploadingLogo ? null : _pickLogo,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(hasCustomLogo ? 'Change Photo' : 'Add Photo'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF422F5D),
              ),
            ),
            if (hasCustomLogo) ...[
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _isUploadingLogo ? null : _deleteLogo,
                icon: const Icon(Icons.delete_outlined),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
        if (hasCustomLogo)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Custom logo uploaded',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF422F5D),
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Using default placeholder logo',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildSectorDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSector,
            isExpanded: true,
            onChanged: (String? newValue) {
              setState(() {
                _selectedSector = newValue;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a sector' : null,
            dropdownColor: const Color(0xFFF7F4F0),
            menuMaxHeight: 300,
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF422F5D)),
            decoration: const InputDecoration(
              hintText: 'Sector',
              prefixIcon: Icon(Icons.category_outlined, color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              border: InputBorder.none,
            ),
            items: _sectorsList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Tooltip(
                  message: value,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF422F5D),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedSector == 'Other')
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextFormField(
                controller: _sectorController,
                decoration: const InputDecoration(
                  hintText: 'Please specify your sector',
                  prefixIcon: Icon(Icons.edit, color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  border: InputBorder.none,
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'This field is required'
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneFormField() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: _contactNumberController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a phone number';
          }
          if (value.length != 9) return 'Phone number must be 9 digits';
          if (!value.startsWith('5')) return 'Must start with 5';
          return null;
        },
        decoration: const InputDecoration(
          hintText: '5X XXX XXXX',
          prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey),
          prefixText: '+966 ',
          prefixStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int? maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF99D46), Color(0xFFD64483)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
