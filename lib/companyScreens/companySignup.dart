import 'package:flutter/material.dart';
import '../models/company.dart';
import '../services/authService.dart';

class CompanySignup extends StatefulWidget {
  const CompanySignup({Key? key}) : super(key: key);

  @override
  _CompanySignupState createState() => _CompanySignupState();
}

class _CompanySignupState extends State<CompanySignup> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _sectorController = TextEditingController();
  final TextEditingController _contactInfoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _companyNameController.dispose();
    _sectorController.dispose();
    _contactInfoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUpCompany() async {
    // Basic validation
    if (_companyNameController.text.isEmpty ||
        _sectorController.text.isEmpty ||
        _contactInfoController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a dummy Company object with the available data
      final company = Company(
        name: _companyNameController.text.trim(),
        sector: _sectorController.text.trim(),
        contactInfo: _contactInfoController.text.trim(),
        logoUrl: 'no-logo.png', // Dummy value for the required parameter
        userType: 'company',
        createdAt: DateTime.now(), email: '',
      );

      final authService = AuthService();
      await authService.signUpCompany(company, _passwordController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company account created successfully!')),
      );

      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: InputBorder.none,
          suffixIcon: suffixIcon ??
              (hintText == 'Password'
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
              Image.asset('assets/spark_logo.png', height: 250),
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
                'Ignite your future',
                style: TextStyle(
                  color: Color(0xFFF99D46),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),

              _buildStyledTextField(controller: _companyNameController, hintText: 'Company Name', icon: Icons.business_outlined),
              _buildStyledTextField(controller: _sectorController, hintText: 'Sector', icon: Icons.work_outline),
              _buildStyledTextField(controller: _contactInfoController, hintText: 'Email or Phone Number', icon: Icons.contact_mail_outlined, keyboardType: TextInputType.text),
              _buildStyledTextField(controller: _passwordController, hintText: 'Password', obscureText: true, icon: Icons.lock_outline),

              const SizedBox(height: 30),
              _buildGradientButton(text: 'Sign Up', onPressed: _signUpCompany),
            ],
          ),
        ),
      ),
    );
  }
}
/*import 'package:flutter/material.dart';

class companySignup extends StatelessWidget {
  const companySignup({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Company Signup")),
      body: const Center(child: Text("This is the Company Signup screen")),
    );
  }
}*/
