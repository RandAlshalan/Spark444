import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/authService.dart';

class StudentSignup extends StatefulWidget {
  const StudentSignup({Key? key}) : super(key: key);

  @override
  _StudentSignupState createState() => _StudentSignupState();
}

class _StudentSignupState extends State<StudentSignup> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _universityController.dispose();
    _majorController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signUpStudent() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _universityController.text.isEmpty ||
        _majorController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final student = Student(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        university: _universityController.text.trim(),
        major: _majorController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        userType: 'student',
        createdAt: DateTime.now(),
        skills: [],
        followedCompanies: [],
      );

      final authService = AuthService();
      await authService.signUpStudent(student, _passwordController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student account created successfully!')),
      );

      // هنا ممكن تضيف التنقل لشاشة ثانية بعد التسجيل
      // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(color: Colors.deepOrangeAccent, width: 2.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA), Color(0xFFFF7043)],
                stops: [0.1, 0.5, 0.9],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 80),
                Image.asset('assets/spark_logo.png', height: 100, width: 100, fit: BoxFit.contain),
                const SizedBox(height: 10),
                const Text('SPARK', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 50),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25.0),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentStep = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                decoration: BoxDecoration(
                                  gradient: _currentStep == 0
                                      ? const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFFAB40)])
                                      : null,
                                  color: _currentStep == 0 ? null : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Step 1: Personal Details',
                                  style: TextStyle(color: _currentStep == 0 ? Colors.white : Colors.white70),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentStep = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                decoration: BoxDecoration(
                                  gradient: _currentStep == 1
                                      ? const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFFAB40)])
                                      : null,
                                  color: _currentStep == 1 ? null : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Documents & Skills',
                                  style: TextStyle(color: _currentStep == 1 ? Colors.white : Colors.white70),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_currentStep == 0) ...[
                        _buildStyledTextField(controller: _emailController, labelText: 'University Email', icon: Icons.mail_outline),
                        _buildStyledTextField(controller: _usernameController, labelText: 'Username', icon: Icons.person_outline),
                        _buildStyledTextField(controller: _passwordController, labelText: 'Password', icon: Icons.lock_outline, obscureText: true),
                        _buildStyledTextField(controller: _firstNameController, labelText: 'First Name', icon: Icons.person_outline),
                        _buildStyledTextField(controller: _lastNameController, labelText: 'Last Name', icon: Icons.person_outline),
                        _buildStyledTextField(controller: _phoneController, labelText: 'Phone Number', icon: Icons.phone_android),
                        _buildStyledTextField(controller: _universityController, labelText: 'University', icon: Icons.school_outlined),
                        _buildStyledTextField(controller: _majorController, labelText: 'Major', icon: Icons.book_outlined),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFFAB40)]),
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUpStudent,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Next Step', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],

                      if (_currentStep == 1)
                        const Text('Documents & Skills content goes here!', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
