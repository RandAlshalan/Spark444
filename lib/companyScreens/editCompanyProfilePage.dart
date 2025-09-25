import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/authService.dart';
//import 'package:file_picker/file_picker.dart';
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
  late TextEditingController _contactInfoController;
  late TextEditingController _descriptionController;

  bool _isLoading = false;
  String? _logoPath;
  String? _logoUrl;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController(text: widget.company.companyName);
    _sectorController = TextEditingController(text: widget.company.sector);
    _contactInfoController = TextEditingController(text: widget.company.contactInfo);
    _descriptionController = TextEditingController(text: widget.company.description);
    _logoUrl = widget.company.logoUrl;
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _sectorController.dispose();
    _contactInfoController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /*Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['jpg', 'png'],
    );
    if (result != null) {
      setState(() {
        _logoPath = result.files.single.path;
      });
      // In a real app, you would upload this file to Firebase Storage
      // and get the download URL to set to _logoUrl.
      // For now, we'll just set a dummy URL.
      _logoUrl = 'https://example.com/new_logo.png';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo selected. It will be saved upon updating.')),
      );
    }
  }*/

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // We need to pass all properties from the original company object
      // to ensure no data is lost during the update.
      final updatedCompany = Company(
        uid: widget.company.uid,
        companyName: _companyNameController.text.trim(),
        email: widget.company.email,
        sector: _sectorController.text.trim(),
        contactInfo: _contactInfoController.text.trim(),
        description: _descriptionController.text.trim(),
        logoUrl: _logoUrl,
        userType: widget.company.userType,
        createdAt: widget.company.createdAt,
        isVerified: widget.company.isVerified,
        opportunitiesPosted: widget.company.opportunitiesPosted,
        studentReviews: widget.company.studentReviews,
      );

      try {
        // Corrected line: Use the 'updateCompany' method and pass the uid
        await _authService.updateCompany(widget.company.uid!, updatedCompany);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Color(0xFF422F5D), fontWeight: FontWeight.bold)),
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
                validator: (value) => value!.isEmpty ? 'Company name is required.' : null,
              ),
              _buildStyledTextFormField(
                controller: _sectorController,
                hintText: 'Sector',
                icon: Icons.category_outlined,
                validator: (value) => value!.isEmpty ? 'Sector is required.' : null,
              ),
              _buildStyledTextFormField(
                controller: _contactInfoController,
                hintText: 'Contact Info',
                icon: Icons.contact_mail_outlined,
                validator: (value) => value!.isEmpty ? 'Contact info is required.' : null,
              ),
              _buildStyledTextFormField(
                controller: _descriptionController,
                hintText: 'Company Description',
                icon: Icons.description_outlined,
                maxLines: 5,
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

  Widget _buildLogoSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.white,
          backgroundImage: _logoPath != null
              ? FileImage(File(_logoPath!))
              : _logoUrl != null
                  ? NetworkImage(_logoUrl!)
                  : const AssetImage('assets/spark_logo.png') as ImageProvider,
        ),
        /*TextButton.icon(
          onPressed: _pickLogo,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Change Logo'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6B4791),
          ),
        ),*/
      ],
    );
  }

  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    int? maxLines = 1,
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
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback onPressed, required bool isLoading}) {
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