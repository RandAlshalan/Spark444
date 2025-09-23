import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/authService.dart';
//import 'package:file_picker/file_picker.dart';

class StudentSignup extends StatefulWidget {
  const StudentSignup({super.key});

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
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _graduationController = TextEditingController();
  final TextEditingController _gpaController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _obscurePassword = true;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _cvPath;
  String? _profilePicPath;
  final List<String> _selectedSkills = []; // New list to store skills

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
    _levelController.dispose();
    _graduationController.dispose();
    _gpaController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _addSkill() {
    final skill = _skillsController.text.trim();
    if (skill.isNotEmpty && !_selectedSkills.contains(skill)) {
      setState(() {
        _selectedSkills.add(skill);
        _skillsController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }

  Future<void> _signUpStudent() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _universityController.text.isEmpty ||
        _majorController.text.isEmpty ||
        _phoneController.text.isEmpty) {
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
        level: _levelController.text.isNotEmpty ? _levelController.text.trim() : null,
        expectedGraduationDate: _graduationController.text.isNotEmpty ? _graduationController.text.trim() : null,
        gpa: _gpaController.text.isNotEmpty ? double.tryParse(_gpaController.text.trim()) : null,
        skills: _selectedSkills,
        profilePictureUrl: _profilePicPath,
        createdAt: DateTime.now(),
        followedCompanies: [],
        location: _locationController.text.isNotEmpty ? _locationController.text.trim() : null,
      );

      final authService = AuthService();
      await authService.signUpStudent(student, _passwordController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student account created successfully!')),
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

  /*Future<void> _pickFile(bool isProfilePic) async {
    final result = await FilePicker.platform.pickFiles(
      type: isProfilePic ? FileType.image : FileType.custom,
      allowedExtensions: isProfilePic ? ['jpg', 'png'] : ['pdf'],
    );
    if (result != null) {
      setState(() {
        if (isProfilePic) {
          _profilePicPath = result.files.single.path;
        } else {
          _cvPath = result.files.single.path;
        }
      });
    }
  }*/

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
                              'Step 1',
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
                              'Step 2',
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
                _buildStyledTextField(controller: _firstNameController, hintText: 'First Name', icon: Icons.person_outline),
                _buildStyledTextField(controller: _lastNameController, hintText: 'Last Name', icon: Icons.person_outline),
                _buildStyledTextField(controller: _emailController, hintText: 'University Email', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                _buildStyledTextField(controller: _passwordController, hintText: 'Password', obscureText: true, icon: Icons.lock_outline),
                _buildStyledTextField(controller: _usernameController, hintText: 'Username', icon: Icons.person_pin_outlined),
                _buildStyledTextField(controller: _phoneController, hintText: 'Phone Number', icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                _buildStyledTextField(controller: _universityController, hintText: 'University', icon: Icons.school_outlined),
                _buildStyledTextField(controller: _majorController, hintText: 'Major', icon: Icons.book_outlined),
                _buildStyledTextField(controller: _locationController,hintText: 'Location', icon: Icons.location_on_outlined,),

                const SizedBox(height: 20),
                _buildGradientButton(
                  text: 'Next Step',
                  onPressed: () {
                    setState(() => _currentStep = 1);
                  },
                ),
              ],
              
              if (_currentStep == 1) ...[
                const Text(
                  'You can skip these fields for now!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                _buildStyledTextField(controller: _levelController, hintText: 'Level', icon: Icons.trending_up),
                _buildStyledTextField(controller: _graduationController, hintText: 'Expected Graduation Date', icon: Icons.calendar_today),
                _buildStyledTextField(controller: _gpaController, hintText: 'GPA', icon: Icons.grade),

                // Skills Input with Add Button and Chips
                _buildStyledTextField(
                  controller: _skillsController,
                  hintText: 'Skills',
                  icon: Icons.lightbulb_outline,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _addSkill,
                  ),
                ),
                Wrap(
                  spacing: 8.0,
                  children: _selectedSkills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      backgroundColor: const Color(0xFFF99D46).withOpacity(0.8),
                      labelStyle: const TextStyle(color: Colors.white),
                      onDeleted: () => _removeSkill(skill),
                      deleteIconColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),

                // CV Upload Section
                GestureDetector(
                 // onTap: () => _pickFile(false),
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
                          _cvPath != null ? 'CV Uploaded' : 'Upload your CV',
                          style: TextStyle(color: _cvPath != null ? Colors.black : Colors.grey),
                        ),
                        Icon(
                          _cvPath != null ? Icons.check_circle_outline : Icons.file_upload,
                          color: _cvPath != null ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // Profile Picture Upload Section
                GestureDetector(
                  //onTap: () => _pickFile(true),
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
                          _profilePicPath != null ? 'Profile Picture Uploaded' : 'Upload Profile Picture',
                          style: TextStyle(color: _profilePicPath != null ? Colors.black : Colors.grey),
                        ),
                        Icon(
                          _profilePicPath != null ? Icons.check_circle_outline : Icons.file_upload,
                          color: _profilePicPath != null ? Colors.green : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _buildGradientButton(text: 'Sign Up', onPressed: _signUpStudent),
                const SizedBox(height: 20),

              ],
            ],
          ),
        ),
      ),
    );
  }
}