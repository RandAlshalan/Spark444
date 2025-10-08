import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../studentScreens/login.dart';
import '../studentScreens/studentViewProfile.dart' hide LoginScreen;
import '../studentScreens/welcomeScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
import '../models/company.dart';
import '../services/authService.dart';
import '../services/storage_service.dart'; // For StoredFile if needed, though direct upload is fine here.

// ✅ ADDED: Custom formatter for phone number spacing, same as student signup
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Get digits only
    final newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (newText.isEmpty) {
      return const TextEditingValue();
    }
    
    final buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class CompanySignup extends StatefulWidget {
  const CompanySignup({super.key});

  @override
  _CompanySignupState createState() => _CompanySignupState();
}

class _CompanySignupState extends State<CompanySignup> {
  // ✅ MODIFIED: Use separate form keys for each step for robust validation
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  // State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  bool _isLoading = false;

  // ✅ MODIFIED: For image picking
  XFile? _pickedImage;
  String? _logoUrl;

  // ✅ ADDED: For sectors dropdown
  List<String> _sectorsList = [];
  String? _selectedSector;

  // ✅ ADDED: State for async company name validation
  String? _companyNameError;
  Timer? _debounce;
  bool _isCheckingName = false;
  bool _isUploadingLogo = false; // ✅ ADDED: State for logo upload

  // ✅ ADDED: Password Strength State
  bool _isPasswordFocused = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _is8CharsLong = false;
  bool get _isPasswordValid => _is8CharsLong && _hasUppercase && _hasLowercase && _hasNumber && _hasSymbol;
  
  // Theme Colors
  static const Color primaryColor = Color(0xFF422F5D);
  static const Color secondaryColor = Color(0xFFF99D46);
  static const Color backgroundColor = Color(0xFFF7F4F0);

  // ✅ ADDED: Hardcoded list of sectors as requested.
  static const List<String> _hardcodedSectors = [
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
    'Other', // The 'Other' option is included here.
  ];

  @override
  void initState() {
    super.initState();
    // ✅ ADDED: Listeners for real-time validation and checks
    _loadLists(); // Fetch sectors list
    _passwordController.addListener(_checkPasswordStrength);
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
  }

  // ✅ MODIFIED: Method to load sectors from a hardcoded list instead of AuthService
  Future<void> _loadLists() async {
    if (mounted) {
      setState(() {
        _sectorsList = _hardcodedSectors;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _sectorController.dispose();
    _contactPersonController.dispose();
    _phoneNumberController.dispose();
    _descriptionController.dispose();
    _passwordFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  
  // ✅ ADDED: Password strength check logic
  void _checkPasswordStrength() {
    String password = _passwordController.text;
    setState(() {
      _is8CharsLong = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSymbol = password.contains(RegExp(r'[!@#\$&*~]'));
    });
  }

  // ✅ ADDED: Async check for company name uniqueness
  void _checkCompanyNameUniqueness(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (mounted) setState(() { _isCheckingName = true; });
      if (_companyNameError != null) {
        setState(() { _companyNameError = null; });
      }
      
      if (value.isNotEmpty) {
        // We use the same isUsernameUnique function for this check
        final isUnique = await _authService.isUsernameUnique(value);
        if (!isUnique && mounted) {
          setState(() {
            _companyNameError = 'This company name is already registered.';
          });
        }
      }
      if (mounted) setState(() { _isCheckingName = false; });
    });
  }

  // ✅ MODIFIED: Navigate to next step only if form is valid
  Future<void> _goToNextStep() async {
    // Validate step 1 before proceeding.
    final isStep1Valid = _formKeyStep1.currentState?.validate() ?? false;
    if (!isStep1Valid) {
      return;
    }
    // Also check for async errors
    if (_companyNameError != null) {
      return;
    }
    // If valid, move to the next step.
    setState(() => _currentStep = 1);
  }

  // ✅ ADDED: Image picking and uploading logic
  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 512);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
      });
    }
  }

  Future<String?> _uploadLogo(String uid, XFile file) async {
    final ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('companies/$uid/logo/logo_${DateTime.now().millisecondsSinceEpoch}');
    await ref.putFile(File(file.path));
    return await ref.getDownloadURL();
  }

  Future<void> _signUpCompany() async {
    // Validate only the current step's form (Step 2).
    // Step 1 was already validated when the user clicked "Next".
    final isStep2Valid = _formKeyStep2.currentState?.validate() ?? false;
    if (!isStep2Valid) {
      return; // Stop execution.
    }
    
    setState(() => _isLoading = true);

    try {
      // Create the user in Firebase Auth first to get a stable UID.
      // This does NOT write to Firestore yet.
      final User? user = await _authService.createAuthUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (user == null) throw Exception("Account creation failed.");

      // Now, with a real UID, upload the logo if one was picked.
      if (_pickedImage != null) {
        setState(() => _isUploadingLogo = true);
        _logoUrl = await _uploadLogo(user.uid, _pickedImage!);
        setState(() => _isUploadingLogo = false);
      }

      // Prepare all data for the final Company object.
      final String combinedContactInfo =
          '${_contactPersonController.text.trim()} - +966${_phoneNumberController.text.trim().replaceAll(' ', '')}';
      final String finalSector = _selectedSector == 'Other'
          ? _sectorController.text.trim()
          : _selectedSector ?? 'Other';

      // Create the complete Company object.
      final finalCompany = Company(
        uid: user.uid, // Use the actual UID
        email: _emailController.text.trim(),
        companyName: _companyNameController.text.trim(),
        sector: finalSector,
        contactInfo: combinedContactInfo,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        logoUrl: _logoUrl,
        userType: 'company',
      );

      // Perform a single, atomic write to Firestore with the complete data.
      await _authService.createCompanyDocument(user.uid, finalCompany);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company account created! Please check email to verify.')),
      );
      Navigator.of(context).pop(); 

    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_isUploadingLogo) setState(() => _isUploadingLogo = false); // Ensure it's always reset
      }
    }
  }

  // ✅ REBUILT: A much more robust text field widget
  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    String? errorText,
    ValueChanged<String>? onChanged,
    int? maxLines = 1,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        focusNode: focusNode,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
          suffixIcon: suffixIcon,
          errorText: errorText,
        ),
      ),
    );
  }
  
  // ✅ ADDED: Password strength indicator widgets
  Widget _buildPasswordCriteriaRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon( met ? Icons.check_circle : Icons.remove_circle_outline, color: met ? Colors.green : Colors.grey, size: 18),
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
    return metCriteria / 5.0;
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength < 0.5) return Colors.red;
    if (strength < 0.9) return Colors.orange;
    return Colors.green;
  }

  Widget _buildGradientButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [secondaryColor, Color(0xFFD64483)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
  
  // ✅ ADDED: Builder for Step 1 Form for better organization
  Widget _buildStep1Form() {
    final passwordStrength = _calculatePasswordStrength();
    return Form(
      key: _formKeyStep1,
      child: Column(
        children: [
          _buildStyledTextFormField(
            controller: _companyNameController,
            hintText: 'Company Name',
            icon: Icons.business_outlined,
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
            onChanged: _checkCompanyNameUniqueness,
            errorText: _companyNameError,
            suffixIcon: _isCheckingName
                ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)))
                : null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter company name';
              // ✅ MODIFIED: Allow spaces and common symbols like '&' in company names.

              if (_companyNameError != null) return _companyNameError;
              return null;
              
            },
          ),
          _buildStyledTextFormField(
            controller: _emailController,
            hintText: 'Business Email',
            icon: Icons.mail_outline,
            inputFormatters: [
              LengthLimitingTextInputFormatter(100),
            ],
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter an email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Invalid email format';
              return null;
            },
          ),
          _buildStyledTextFormField(
            controller: _passwordController,
            hintText: 'Password',
            obscureText: _obscurePassword,
            icon: Icons.lock_outline,
            focusNode: _passwordFocusNode,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter password';
              if (!_isPasswordValid) return 'Password does not meet requirements';
              return null;
            },
          ),
          if ((_isPasswordFocused || _passwordController.text.isNotEmpty) && !_isPasswordValid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordCriteriaRow('At least 8 characters', _is8CharsLong),
                  _buildPasswordCriteriaRow('Contains an uppercase letter', _hasUppercase),
                  _buildPasswordCriteriaRow('Contains a lowercase letter', _hasLowercase),
                  _buildPasswordCriteriaRow('Contains a number', _hasNumber),
                  _buildPasswordCriteriaRow('Contains a symbol (!@#\$&*~)', _hasSymbol),
                  const SizedBox(height: 8),
                  if (!_isPasswordValid)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: passwordStrength,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade300,
                        color: _getPasswordStrengthColor(passwordStrength),
                      ),
                    ),
                ],
              ),
            ),
          _buildStyledTextFormField(
            controller: _confirmPasswordController,
            hintText: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
             suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildGradientButton(text: 'Next Step', onPressed: _goToNextStep),
        ],
      ),
    );
  }

  // ✅ ADDED: Builder for Step 2 Form for better organization
  Widget _buildStep2Form() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Company Logo (Optional)", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isUploadingLogo ? null : _pickLogo, // Disable tap while uploading
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: _pickedImage != null ? FileImage(File(_pickedImage!.path)) : null,
                  child: _pickedImage == null && !_isUploadingLogo
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Upload Logo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      : null,
                ),
                // ✅ ADDED: Loading indicator overlay
                if (_isUploadingLogo)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ✅ REPLACED: Text field with a dropdown for sectors
          DropdownButtonFormField<String>(
            initialValue: _selectedSector,
            isExpanded: true, // Fix dropdown width overflow
            onChanged: (String? newValue) {
              setState(() {
                _selectedSector = newValue;
              });
            },
            validator: (value) => value == null ? 'Please select a sector' : null,
            dropdownColor: backgroundColor,
            menuMaxHeight: 300,
            icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Sector',
              prefixIcon: const Icon(Icons.category_outlined, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
            ),
            items: _sectorsList.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: primaryColor, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2, // Allow wrapping to 2 lines for long text
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedSector == 'Other')
            _buildStyledTextFormField(
              controller: _sectorController, // Re-use for "Other"
              hintText: 'Please specify your sector',
              inputFormatters: [
                LengthLimitingTextInputFormatter(40),
              ],
              icon: Icons.edit,
              validator: (value) => value == null || value.trim().isEmpty ? 'This field is required' : null,
            ),
          _buildStyledTextFormField(
            controller: _contactPersonController,
            hintText: 'Contact Person Name',
            inputFormatters: [
              LengthLimitingTextInputFormatter(50),
            ],
            validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Please enter a contact name';

            if (RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
              return 'Names cannot contain numbers or symbols';
            }
            return null;
          },
            icon: Icons.person_outline,
            //validator: (value) => value == null || value.isEmpty ? 'Please enter a contact name' : null,
            
          ),
          _buildPhoneFormField(), // ✅ REPLACED: Using the new robust phone field
          _buildStyledTextFormField(
              controller: _descriptionController,
              hintText: 'Company Description (Optional)',
              inputFormatters: [
                LengthLimitingTextInputFormatter(500),
              ],
              icon: Icons.description_outlined,
              maxLines: 4,
              maxLength: 500),
          const SizedBox(height: 30),
          _buildGradientButton(text: 'Create Company Account', onPressed: _signUpCompany),
        ],
      ),
    );
  }

  // ✅ ADDED: The missing phone number form field widget
  Widget _buildPhoneFormField() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _phoneNumberController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter a phone number';
          if (value.length != 9) return 'Phone number must be 9 digits';
          if (!value.startsWith('5')) return 'Must start with 5';
          return null;
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: '5X XXX XXXX',
          prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
          prefixText: '+966 ',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/spark_logo.png', height: 120),
              const SizedBox(height: 5),
              const Text('SPARK for Companies', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
              const Text('Connect with Future Talent', style: TextStyle(color: secondaryColor, fontStyle: FontStyle.italic, fontSize: 14)),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentStep = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: _currentStep == 0 ? const LinearGradient(colors: [secondaryColor, Color(0xFFD64483)]) : null,
                            color: _currentStep == 0 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('Step 1: Account', style: TextStyle(fontWeight: FontWeight.bold, color: _currentStep == 0 ? Colors.white : Colors.grey[700]))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _goToNextStep, // Validate before allowing step change
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: _currentStep == 1 ? const LinearGradient(colors: [secondaryColor, Color(0xFFD64483)]) : null,
                            color: _currentStep == 1 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('Step 2: Profile', style: TextStyle(fontWeight: FontWeight.bold, color: _currentStep == 1 ? Colors.white : Colors.grey[700]))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // ✅ MODIFIED: Conditionally show the correct form based on the current step
              _currentStep == 0 ? _buildStep1Form() : _buildStep2Form(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    child: const Text('Login Page', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF422F5D))),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Want to go back?"),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Welcome Page', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF422F5D))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}