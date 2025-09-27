import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/studentScreens/login.dart';
import 'package:my_app/studentScreens/welcomeScreen.dart';
import '../models/company.dart';
import '../services/authService.dart';
// import 'package:file_picker/file_picker.dart'; // Keep commented if not used yet

class CompanySignup extends StatefulWidget {
  const CompanySignup({super.key});

  @override
  _CompanySignupState createState() => _CompanySignupState();
}

class _CompanySignupState extends State<CompanySignup> {
  // ✅ ADDED: Form key for robust validation
  final _formKey = GlobalKey<FormState>();
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
  String? _logoPath;

  // ✅ ADDED: State for async company name validation
  String? _companyNameError;
  Timer? _debounce;
  bool _isCheckingName = false;

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


  @override
  void initState() {
    super.initState();
    // ✅ ADDED: Listeners for real-time validation and checks
    _passwordController.addListener(_checkPasswordStrength);
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Also check for async errors
    if (_companyNameError != null) {
      return;
    }
    setState(() => _currentStep = 1);
  }

  Future<void> _signUpCompany() async {
    // Step 2 doesn't have required fields, so no validation needed here
    // But we still ensure step 1 was valid
    if (!_formKey.currentState!.validate()) {
      // This is a safeguard, user shouldn't reach here with an invalid form
      setState(() => _currentStep = 0); 
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      // ✅ IMPROVED: Contact info is now structured.
      // In your Company model, it's best to have separate fields
      // but we will keep the combined string for now as per the original code.
      final String combinedContactInfo =
          '${_contactPersonController.text.trim()} - ${_phoneNumberController.text.trim()}';

      final company = Company(
        email: _emailController.text.trim(),
        companyName: _companyNameController.text.trim(),
        sector: _sectorController.text.trim(),
        contactInfo: combinedContactInfo,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
        logoUrl: _logoPath,
        userType: 'company',
      );

      await _authService.signUpCompany(company, _passwordController.text.trim());

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
    return Column(
      children: [
        _buildStyledTextFormField(
          controller: _companyNameController,
          hintText: 'Company Name',
          icon: Icons.business_outlined,
          onChanged: _checkCompanyNameUniqueness,
          errorText: _companyNameError,
          suffixIcon: _isCheckingName
              ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)))
              : null,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter company name';
            if (_companyNameError != null) return _companyNameError;
            return null;
          },
        ),
        _buildStyledTextFormField(
          controller: _emailController,
          hintText: 'Business Email',
          icon: Icons.mail_outline,
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
    );
  }

  // ✅ ADDED: Builder for Step 2 Form for better organization
  Widget _buildStep2Form() {
    return Column(
      children: [
        _buildStyledTextFormField(
          controller: _sectorController,
          hintText: 'Sector (e.g., Tech, Finance)',
          icon: Icons.category_outlined,
          validator: (value) => value == null || value.isEmpty ? 'Please enter a sector' : null,
        ),
        _buildStyledTextFormField(
          controller: _contactPersonController,
          hintText: 'Contact Person Name',
          icon: Icons.person_outline,
          validator: (value) => value == null || value.isEmpty ? 'Please enter a contact name' : null,
        ),
        _buildStyledTextFormField(
          controller: _phoneNumberController,
          hintText: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a phone number';
            if (value.length < 9) return 'Please enter a valid phone number';
            return null;
          },
        ),
        _buildStyledTextFormField(
            controller: _descriptionController,
            hintText: 'Company Description (Optional)',
            icon: Icons.description_outlined,
            maxLines: 4),
        const SizedBox(height: 30),
        _buildGradientButton(text: 'Create Company Account', onPressed: _signUpCompany),
      ],
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
              // ✅ WRAPPED: The main content in a Form widget
              Form(
                key: _formKey,
                child: _currentStep == 0 ? _buildStep1Form() : _buildStep2Form(),
              ),
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
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                            (Route<dynamic> route) => false,
                          );
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