import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_app/studentScreens/welcomeScreen.dart';
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

  Future<void> _selectLocation() async {
    const Color primaryColor = Color(0xFF422F5D);
    const Color secondaryColor = Color(0xFFF99D46);
    const Color backgroundColor = Color(0xFFF7F4F0);

    const LatLng initialLocation = LatLng(24.7136, 46.6753); // Riyadh, Saudi Arabia

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedLocationName;
        LatLng? selectedLatLng;
        final Set<Marker> markers = {};

        return AlertDialog(
          backgroundColor: backgroundColor,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Location',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: initialLocation,
                    zoom: 10,
                  ),
                  onTap: (latLng) async {
                    selectedLatLng = latLng;
                    setState(() {
                      markers.clear();
                      markers.add(
                        Marker(
                          markerId: const MarkerId('selected-location'),
                          position: latLng,
                        ),
                      );
                    });
                    try {
                      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
                      if (placemarks.isNotEmpty) {
                        final location = placemarks.first;
                        selectedLocationName = "${location.locality}, ${location.administrativeArea}, ${location.country}";
                      }
                    } catch (e) {
                      selectedLocationName = "Unknown location";
                    }
                  },
                  markers: markers,
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: secondaryColor)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                if (selectedLocationName != null) {
                  _locationController.text = selectedLocationName!;
                }
                Navigator.of(context).pop();
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signUpStudent() async {
    // Trim spaces from email and username
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim().replaceAll(' ', '');
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final university = _universityController.text.trim();
    final major = _majorController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();

    // Required fields check
    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter first name.')));
      return;
    }
    if (lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter last name.')));
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter university email.')));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter password.')));
      return;
    }
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter username.')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter phone number.')));
      return;
    }
    if (university.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter university.')));
      return;
    }
    if (major.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter major.')));
      return;
    }
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter location.')));
      return;
    }

    // Email format check
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email format.')));
      return;
    }

    // University domain check
    final allowedDomains = ['.edu', '.edu.sa', '.ac.uk'];
    final domain = email.split('@').last;
    if (!allowedDomains.any((d) => domain.endsWith(d))) {
      bool submitForReview = false;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unrecognized university domain'),
          content: const Text('Do you want to submit your email for manual review?'),
          actions: [
            TextButton(
              onPressed: () {
                submitForReview = false;
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                submitForReview = true;
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (!submitForReview) return;
    }

    // Password checks
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password too short (min 8 characters).')));
      return;
    }
    final pwComplexity = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).+$');
    if (!pwComplexity.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must include uppercase, lowercase, number, and symbol.')));
      return;
    }

    // Phone number regex (example: 10-15 digits)
    final phoneRegex = RegExp(r'^\+?\d{10,15}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number format.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final student = Student(
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        university: university,
        major: major,
        phoneNumber: phone,
        userType: 'student',
        level: _levelController.text.isNotEmpty ? _levelController.text.trim() : null,
        expectedGraduationDate: _graduationController.text.isNotEmpty ? _graduationController.text.trim() : null,
        gpa: _gpaController.text.isNotEmpty ? double.tryParse(_gpaController.text.trim()) : null,
        skills: _selectedSkills,
        profilePictureUrl: _profilePicPath,
        createdAt: DateTime.now(),
        followedCompanies: [],
        location: location,
      );

      final authService = AuthService();
      await authService.signUpStudent(student, password);

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
              // Step Selector
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
                GestureDetector(
                  onTap: _selectLocation,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                        const Icon(Icons.location_on_outlined, color: Colors.grey),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            _locationController.text.isNotEmpty ? _locationController.text : 'Location',
                            style: TextStyle(
                              fontSize: 16,
                              color: _locationController.text.isNotEmpty ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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

              // Back to Welcome Page link
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF422F5D),
                      ),
                    ),
                  ),
                ],
              ),

              // Back to Welcome Screen link
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
                    child: const Text(
                      'Welcome Screen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF422F5D),
                      ),
                    ),
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

