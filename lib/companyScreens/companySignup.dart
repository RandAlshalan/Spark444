import 'package:flutter/material.dart';
import '../models/company.dart'; // Import your new Company model
import '../services/authService.dart'; // Import your AuthService
// import 'package:file_picker/file_picker.dart'; // Uncomment if using file picker

class CompanySignup extends StatefulWidget {
  const CompanySignup({super.key});

  @override
  _CompanySignupState createState() => _CompanySignupState();
}

class _CompanySignupState extends State<CompanySignup> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController(); // Renamed for clarity
  final TextEditingController _phoneNumberController = TextEditingController();   // New field for phone number
  final TextEditingController _descriptionController = TextEditingController();

  bool _obscurePassword = true;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _logoPath; // For company logo upload

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _sectorController.dispose();
    _contactPersonController.dispose(); // Dispose renamed controller
    _phoneNumberController.dispose();   // Dispose new controller
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _signUpCompany() async {
    // Consolidated validation for all required fields
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _companyNameController.text.isEmpty ||
        _sectorController.text.isEmpty ||
        _contactPersonController.text.isEmpty || // Check new contact person field
        _phoneNumberController.text.isEmpty) {   // Check new phone number field
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine contact person and phone number into the existing contactInfo field
      // Ideally, your Company model would have separate fields for contactPerson and phoneNumber.
      final String combinedContactInfo =
          'Contact Person: ${_contactPersonController.text.trim()}, Phone: ${_phoneNumberController.text.trim()}';

      final company = Company(
        email: _emailController.text.trim(),
        companyName: _companyNameController.text.trim(),
        sector: _sectorController.text.trim(),
        contactInfo: combinedContactInfo, // Now combines person and phone
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        logoUrl: _logoPath, // This would be the URL after uploading to Firebase Storage
        userType: 'company',
        createdAt: DateTime.now(),
      );

      // Diagnostic print statements
      print('Attempting to sign up company with email: ${company.email}');
      if (company.email.isEmpty) {
        print('WARNING: Company email is empty!');
      }

      final authService = AuthService();
      await authService.signUpCompany(company, _passwordController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company account created successfully!')),
      );

      Navigator.of(context).pop(); // Navigate back or to a success screen

    } on Exception catch (e) { // Catch the re-thrown Exception which now includes FirebaseAuthException details
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    int? maxLines = 1,
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
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
          suffixIcon: suffixIcon ??
              (hintText.toLowerCase() == 'password'
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    )
                  : null),
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback onPressed}) {
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
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: _isLoading
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

  /*
  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowedExtensions: ['jpg', 'png'],
    );
    if (result != null) {
      setState(() {
        _logoPath = result.files.single.path;
        // In a real app, you would upload this file to Firebase Storage
        // and get the download URL to set to _logoPath.
      });
      // Example of uploading to Storage (requires firebase_storage package)
      // final file = File(result.files.single.path!);
      // final ref = firebase_storage.FirebaseStorage.instance.ref().child('company_logos/${_companyNameController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}.png');
      // await ref.putFile(file);
      // final downloadUrl = await ref.getDownloadURL();
      // setState(() {
      //   _logoPath = downloadUrl;
      // });
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/spark_logo.png', height: 250), // Ensure this asset exists
              const SizedBox(height: 5),
              const Text(
                'SPARK',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF422F5D),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Connect with Talent', // Changed tagline for companies
                style: TextStyle(
                  color: Color(0xFFF99D46),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              Container(
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
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentStep = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: _currentStep == 0
                                ? const LinearGradient(colors: [Color(0xFFF99D46), Color(0xFFD64483)])
                                : null,
                            color: _currentStep == 0 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Basic Info', // Changed to be more company-specific
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _currentStep == 0 ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentStep = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: _currentStep == 1
                                ? const LinearGradient(colors: [Color(0xFFF99D46), Color(0xFFD64483)])
                                : null,
                            color: _currentStep == 1 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Profile Details', // Changed to be more company-specific
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _currentStep == 1 ? Colors.white : Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (_currentStep == 0) ...[
                _buildStyledTextField(controller: _companyNameController, hintText: 'Company Name', icon: Icons.business_outlined),
                _buildStyledTextField(controller: _emailController, hintText: 'Business Email', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                _buildStyledTextField(controller: _passwordController, hintText: 'Password', obscureText: _obscurePassword, icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                _buildStyledTextField(controller: _sectorController, hintText: 'Sector (e.g., Tech, Finance)', icon: Icons.category_outlined),
                _buildStyledTextField(controller: _contactPersonController, hintText: 'Contact Person Name', icon: Icons.person_outline), // Updated hint text
                _buildStyledTextField(controller: _phoneNumberController, hintText: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone), // New field
                const SizedBox(height: 20),
                _buildGradientButton(
                  text: 'Next Step',
                  onPressed: () {
                    // Basic validation before moving to next step
                    if (_companyNameController.text.isEmpty ||
                        _emailController.text.isEmpty ||
                        _passwordController.text.isEmpty ||
                        _sectorController.text.isEmpty ||
                        _contactPersonController.text.isEmpty || // Check new contact person field
                        _phoneNumberController.text.isEmpty) {   // Check new phone number field
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all required fields for basic info.')),
                      );
                      return;
                    }
                    setState(() => _currentStep = 1);
                  },
                ),
              ],

              if (_currentStep == 1) ...[
                const Text(
                  'Add more details to attract talent!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                _buildStyledTextField(controller: _descriptionController, hintText: 'Company Description', icon: Icons.description_outlined, maxLines: 5),

                // Logo Upload Section
                GestureDetector(
                  // onTap: _pickLogo, // Uncomment when FilePicker is enabled
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _logoPath != null ? 'Logo Uploaded' : 'Upload Company Logo',
                          style: TextStyle(color: _logoPath != null ? Colors.black : Colors.grey),
                        ),
                        Icon(
                          _logoPath != null ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                          color: _logoPath != null ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildGradientButton(text: 'Create Company Account', onPressed: _signUpCompany),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}