import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_app/studentScreens/welcomeScreen.dart';
import '../models/student.dart';
import '../services/authService.dart';

class StudentSignup extends StatefulWidget {
  const StudentSignup({super.key});

  @override
  _StudentSignupState createState() => _StudentSignupState();
}

class _StudentSignupState extends State<StudentSignup> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: '+966'); // Changed
  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _graduationController = TextEditingController();
  final TextEditingController _gpaController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedUniversity;
  String? _selectedMajor;

  bool _obscurePassword = true;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _cvPath;
  String? _profilePicPath;
  final List<String> _selectedSkills = [];
  bool _isUniversityEmail = false;

  final List<String> _universityDomains = [
    '.edu', '.ac.uk', '.edu.sa', '.edu.au', '.edu.ca', '.edu.cn'
  ];

  final List<String> ksaUniversities = [
    'King Saud University',
    'King Abdulaziz University',
    'King Fahd University',
    'King Abdullah University',
    'King Khalid University',
    'Alfaisal University',
    'Umm Al-Qura University',
    'Imam Abdulrahman University',
    'Taibah University',
    'King Saud bin Abdulaziz University',
    'Qassim University',
    'Al-Yamamah University',
    'Effat University',
    'University of Tabuk',
    'Imam Mohammad IbnUniversity',
    'Prince Sultan University',
    'Taif University',
    'Najran University',
    'Al Jouf University',
    'Prince Mohammad Bin University',
    'Islamic University of Madinah',
    'Prince Sattam Bin  University',
    'Fahad Bin Sultan University',
    'Jazan University',
    'Shaqra University',
    'Majmaah University',
    'Dar Al-Hekma University',
    'Dar Al Uloom University',
    'Northern Border University',
    'University of Hafr Al Batin',
    'Arab Open University',
    'Ibn Sina National College',
    'Sulaiman Al Rajhi University',
    'Jubail Industrial College',
    'University of Prince Mugrin',
    'Fakeeh College for',
    'Yanbu Industrial College',
    'Prince Sultan Aviation Academy',
    'Prince Mohammed Bin Salman',
    'Princess Nourah Bint ',
    'Riyadh Elm University',
    'University of Jeddah',
    'University of Bisha',
    'Jeddah International College',
    'Prince Sattam bin Abdulaziz ',
  ];

  final List<String> ksaMajors = [
    'Computer Science',
    'Medicine',
    'Engineering',
    'Business Administration',
    'Law',
    'Information Technology',
    'Finance',
    'Accounting',
    'Architecture',
    'Humanities',
    'Education',
    'Arts & Design',
    'Nursing',
    'Pharmacy',
    'Dentistry',
    'Mechanical Engineering',
    'Electrical Engineering',
    'Civil Engineering',
    'Chemical Engineering',
    'Islamic Studies',
    'Science (Physics, Chemistry, Biology)',
    'Public Health',
    'Marketing',
    'Psychology',
    'Data Science',
    'Cybersecurity',
    'Industrial Engineering',
    'International Relations',
    'Tourism and Hospitality',
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailDomain);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailDomain);
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _levelController.dispose();
    _graduationController.dispose();
    _gpaController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _validateEmailDomain() {
    final email = _emailController.text.trim();
    bool isValid = _universityDomains.any((domain) => email.endsWith(domain));
    if (isValid != _isUniversityEmail) {
      setState(() {
        _isUniversityEmail = isValid;
      });
    }
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
    const LatLng initialLocation = LatLng(24.7136, 46.6753); // Riyadh

    String? finalSelectedLocationName;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final Set<Marker> markers = {};

        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Select Location', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(target: initialLocation, zoom: 10),
                  markers: markers,
                  onTap: (latLng) async {
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
                        final p = placemarks.first;
                        finalSelectedLocationName = p.locality;
                      } else {
                        finalSelectedLocationName = "Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}";
                      }
                    } catch (e) {
                      print("Error getting placemark: $e");
                      finalSelectedLocationName = "Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}";
                    }
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: secondaryColor)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                if (finalSelectedLocationName != null) {
                  _locationController.text = finalSelectedLocationName!;
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

  Future<bool> _showManualReviewDialog() async {
    bool proceed = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unrecognized University Email'),
        content: const Text('The email domain you provided is not on our recognized list. Would you like to submit it for manual review and proceed?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              proceed = false;
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: const Text('Proceed'),
            onPressed: () {
              proceed = true;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    return proceed;
  }

  Future<void> _signUpStudent() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors in the form.')),
      );
      return;
    }

    if (!_isUniversityEmail) {
      bool userWantsToProceed = await _showManualReviewDialog();
      if (!userWantsToProceed) {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final student = Student(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        university: _selectedUniversity!,
        major: _selectedMajor!,
        phoneNumber: _phoneController.text.trim(), // Use the full text with prefix
        userType: 'student',
        level: _levelController.text.isNotEmpty ? _levelController.text.trim() : null,
        expectedGraduationDate: _graduationController.text.isNotEmpty ? _graduationController.text.trim() : null,
        gpa: _gpaController.text.isNotEmpty ? double.tryParse(_gpaController.text.trim()) : null,
        skills: _selectedSkills,
        profilePictureUrl: _profilePicPath,
        createdAt: DateTime.now(),
        followedCompanies: [],
        location: _locationController.text.trim(),
      );

      final authService = AuthService();
      await authService.signUpStudent(student, _passwordController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student account created successfully! Check your email to verify.')),
      );
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    Widget? prefix,
    String? errorText,
    TextStyle? errorStyle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          prefix: prefix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF422F5D))),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red, width: 2)),
          suffixIcon: suffixIcon,
          errorText: errorText,
          errorStyle: errorStyle,
        ),
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String hintText,
    required List<String> items,
    required String? selectedValue,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: onChanged,
        validator: (value) => value == null ? 'Please select a ${hintText.toLowerCase()}' : null,
        dropdownColor: const Color(0xFFF7F4F0),
        menuMaxHeight: 250,
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF422F5D)),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF422F5D))),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red, width: 2)),
        ),
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF422F5D),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
            children: [
              Image.asset('assets/spark_logo.png', height: 200),
              const SizedBox(height: 5),
              const Text('SPARK', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF422F5D))),
              const Text('Ignite your future', style: TextStyle(color: Color(0xFFF99D46), fontStyle: FontStyle.italic, fontSize: 14)),
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
                            gradient: _currentStep == 0 ? const LinearGradient(colors: [Color(0xFFF99D46), Color(0xFFD64483)]) : null,
                            color: _currentStep == 0 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('Step 1', style: TextStyle(fontWeight: FontWeight.bold, color: _currentStep == 0 ? Colors.white : Colors.grey[700]))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            setState(() => _currentStep = 1);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete Step 1 first.')));
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: _currentStep == 1 ? const LinearGradient(colors: [Color(0xFFF99D46), Color(0xFFD64483)]) : null,
                            color: _currentStep == 1 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('Step 2', style: TextStyle(fontWeight: FontWeight.bold, color: _currentStep == 1 ? Colors.white : Colors.grey[700]))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (_currentStep == 0)
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildStyledTextFormField(
                        controller: _firstNameController,
                        hintText: 'First Name',
                        icon: Icons.person_outline,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter first name' : null,
                      ),
                      _buildStyledTextFormField(
                        controller: _lastNameController,
                        hintText: 'Last Name',
                        icon: Icons.person_outline,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter last name' : null,
                      ),
                      _buildStyledTextFormField(
                        controller: _emailController,
                        hintText: 'University Email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        suffixIcon: _isUniversityEmail ? const Icon(Icons.check_circle, color: Colors.green) : null,
                        errorText: _isUniversityEmail || _emailController.text.isEmpty ? null : "We will verify if it's a university email",
                        errorStyle: const TextStyle(color: Colors.grey),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter university email';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Invalid email format';
                          return null;
                        },
                      ),
                      _buildStyledTextFormField(
                        controller: _passwordController,
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter password';
                          if (value.length < 8) return 'Password must be at least 8 characters long';
                          if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$').hasMatch(value)) {
                            return 'Use uppercase, lowercase, number & symbol';
                          }
                          return null;
                        },
                      ),
                      _buildStyledTextFormField(
                        controller: _usernameController,
                        hintText: 'Username',
                        icon: Icons.person_pin_outlined,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter username';
                          if (value.contains(' ')) return 'Username cannot contain spaces';
                          return null;
                        },
                      ),
                      _buildStyledTextFormField(
                        controller: _phoneController,
                        hintText: 'Phone Number',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter phone number';
                          if (!value.startsWith('+966')) {
                            return 'Phone number must start with +966';
                          }
                          final phoneNumberWithoutPrefix = value.substring(4); // Remove '+966'
                          if (!RegExp(r'^[0-9]{9}$').hasMatch(phoneNumberWithoutPrefix)) {
                            return 'Invalid KSA phone number (9 digits after +966)';
                          }
                          return null;
                        },
                      ),
                      _buildDropdownFormField(
                        hintText: 'University',
                        items: ksaUniversities,
                        selectedValue: _selectedUniversity,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedUniversity = newValue;
                          });
                        },
                        icon: Icons.school_outlined,
                      ),
                      _buildDropdownFormField(
                        hintText: 'Major',
                        items: ksaMajors,
                        selectedValue: _selectedMajor,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedMajor = newValue;
                          });
                        },
                        icon: Icons.book_outlined,
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          controller: _locationController,
                          readOnly: true,
                          onTap: _selectLocation,
                          validator: (value) => value == null || value.isEmpty ? 'Please enter location' : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Location',
                            prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red, width: 1.5)),
                            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red, width: 2)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildGradientButton(
                        text: 'Next Step',
                        onPressed: () {
                           if (_formKey.currentState!.validate()) {
                             setState(() => _currentStep = 1);
                           }
                         },
                      ),
                    ],
                  ),
                ),
              
              if (_currentStep == 1) ...[
                const Text('You can skip these fields for now!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 15),
                _buildStyledTextFormField(controller: _levelController, hintText: 'Level (e.g., Junior, Senior)', icon: Icons.trending_up),
                _buildStyledTextFormField(controller: _graduationController, hintText: 'Expected Graduation Date (e.g., May 2025)', icon: Icons.calendar_today),
                _buildStyledTextFormField(controller: _gpaController, hintText: 'GPA (e.g., 3.8)', icon: Icons.grade, keyboardType: TextInputType.numberWithOptions(decimal: true)),

                _buildStyledTextFormField(
                  controller: _skillsController,
                  hintText: 'Add a Skill',
                  icon: Icons.lightbulb_outline,
                  suffixIcon: IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: _addSkill),
                ),
                Wrap(
                  spacing: 8.0,
                  children: _selectedSkills.map((skill) => Chip(
                    label: Text(skill),
                    backgroundColor: const Color(0xFFF99D46).withOpacity(0.8),
                    labelStyle: const TextStyle(color: Colors.white),
                    onDeleted: () => _removeSkill(skill),
                    deleteIconColor: Colors.white,
                  )).toList(),
                ),
                const SizedBox(height: 30),
                _buildGradientButton(text: 'Sign Up', onPressed: _signUpStudent),
              ],

              const SizedBox(height: 20),
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