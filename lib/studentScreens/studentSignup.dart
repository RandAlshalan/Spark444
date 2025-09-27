import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
// --- ADDED: Import for date formatting ---
import 'package:intl/intl.dart';
import 'package:my_app/studentScreens/login.dart';
import 'package:my_app/studentScreens/studentEmailVerification.dart';
import 'package:my_app/studentScreens/welcomeScreen.dart';
import '../models/student.dart';
import '../services/authService.dart';

// --- MODIFICATION 3: Custom formatter for phone number spacing ---
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
      // Add space after the 3rd and 6th digit
      if (i == 2 || i == 5) {
        buffer.write(' ');
      }
      buffer.write(newText[i]);
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}


class StudentSignup extends StatefulWidget {
  const StudentSignup({super.key});

  @override
  _StudentSignupState createState() => _StudentSignupState();
}

class _StudentSignupState extends State<StudentSignup> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // --- ADDED: Variables to hold lists from Firestore ---
  List<String> _universitiesList = [];
  List<String> _majorsList = [];
  late Future<void> _loadListsFuture;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _graduationController = TextEditingController();
  final TextEditingController _gpaController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  // --- ADDED: Controllers for the "Other" fields ---
  final TextEditingController _otherUniversityController = TextEditingController();
  final TextEditingController _otherMajorController = TextEditingController();

  // State
  String? _selectedUniversity;
  String? _selectedMajor;
  String? _gpaScale;
  String? _selectedLevel;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  bool _isLoading = false;
  final List<String> _selectedSkills = [];
  bool _isUniversityEmail = false;

  // Password Strength State
  bool _isPasswordFocused = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSymbol = false;
  bool _is8CharsLong = false;
  bool get _isPasswordValid => _is8CharsLong && _hasUppercase && _hasLowercase && _hasNumber && _hasSymbol;

  // --- ADDED: State for async username validation ---
  bool _isCheckingUsername = false;

  final List<String> _universityDomains = [
    '.edu', '.ac.uk', '.edu.sa', '.edu.au', '.edu.ca', '.edu.cn',
  ];

  final List<String> _academicLevels = [
    'Freshman (Level 1-2)', 'Sophomore (Level 3-4)', 'Junior (Level 5-6)',
    'Senior (Level 7-8)', 'Graduate Student'
  ];

  String? _usernameError;
  Timer? _debounce;
  final FocusNode _passwordFocusNode = FocusNode();
  
  static const Color primaryColor = Color(0xFF422F5D);
  static const Color secondaryColor = Color(0xFFF99D46);
  static const Color backgroundColor = Color(0xFFF7F4F0);

  @override
  void initState() {
    super.initState();
    // --- ADDED: Start fetching lists when the screen loads ---
    _loadListsFuture = _loadLists();

    _emailController.addListener(_validateEmailDomain);
    _passwordController.addListener(_checkPasswordStrength);
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
  }

  // --- ADDED: New function to load lists from AuthService and add "Other" option ---
  Future<void> _loadLists() async {
    final lists = await _authService.getUniversitiesAndMajors();
    if (mounted) {
      setState(() {
        _universitiesList = ["Other", ...lists['universities'] ?? []];
        _majorsList = ["Other", ...lists['majors'] ?? []];
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmailDomain);
    _passwordController.removeListener(_checkPasswordStrength);
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _graduationController.dispose();
    _gpaController.dispose();
    _skillsController.dispose();
    _locationController.dispose();
    // --- ADDED: Dispose new controllers ---
    _otherUniversityController.dispose();
    _otherMajorController.dispose();
    _debounce?.cancel();
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
    const LatLng initialLocation = LatLng(24.7136, 46.6753); // Riyadh
    String? finalSelectedLocationName;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final Set<Marker> markers = {};
        final Completer<GoogleMapController> _controller = Completer();
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Select Location', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(target: initialLocation, zoom: 10),
                    markers: markers,
                    onTap: (latLng) async {
                      setState(() {
                        markers.clear();
                        markers.add(Marker(markerId: const MarkerId('selected-location'), position: latLng));
                      });
                      try {
                        List<Placemark> placemarks = await placemarkFromCoordinates(
                          latLng.latitude, latLng.longitude,
                          localeIdentifier: "en_US",
                        );
                        if (placemarks.isNotEmpty) {
                          final p = placemarks.first;
                          final city = p.locality ?? p.subAdministrativeArea;
                          final country = p.country;
                          finalSelectedLocationName = '${city ?? ''}, ${country ?? ''}'.trim().replaceAll(RegExp(r'^, |,$'), '');
                        } else {
                          finalSelectedLocationName = "Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}";
                        }
                      } catch (e) {
                        finalSelectedLocationName = "Lat: ${latLng.latitude.toStringAsFixed(4)}, Lng: ${latLng.longitude.toStringAsFixed(4)}";
                      }
                    },
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unrecognized University Email', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        content: const Text('The email domain you provided is not on our recognized list. Would you like to submit it for manual review and proceed?', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
            onPressed: () { proceed = false; Navigator.of(context).pop(); }
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
            onPressed: () { proceed = true; Navigator.of(context).pop(); }
          ),
        ],
      ),
    );
    return proceed;
  }
  
  // --- IMPROVEMENT 1: Added a function for the Graduation Date Picker ---
  Future<void> _selectGraduationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year),
      lastDate: DateTime(DateTime.now().year + 10),
      initialDatePickerMode: DatePickerMode.year,
       // --- STYLING: You can add builder to style the date picker to match your theme ---
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: secondaryColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // Format date to "Month YYYY" e.g., "September 2025"
        _graduationController.text = DateFormat('MMMM yyyy').format(picked);
      });
    }
  }


  Future<void> _goToNextStep() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_usernameError != null) {
      return;
    }
    setState(() {
      _currentStep = 1;
    });
  }

  Future<void> _signUpStudent() async {
    if (!_formKey.currentState!.validate()) {
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
      // --- MODIFIED: Handle "Other" values before creating the Student object ---
      final String finalUniversity = _selectedUniversity == 'Other'
          ? _otherUniversityController.text.trim()
          : _selectedUniversity!;
      final String finalMajor = _selectedMajor == 'Other'
          ? _otherMajorController.text.trim()
          : _selectedMajor!;

      final student = Student(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        university: finalUniversity,
        major: finalMajor,
        // --- MODIFICATION 3: Also remove spaces here before saving ---
        phoneNumber: "+966${_phoneController.text.trim().replaceAll(' ', '')}",
        userType: 'student',
        level: _selectedLevel,
        expectedGraduationDate: _graduationController.text.isNotEmpty ? _graduationController.text.trim() : null,
        gpa: _gpaController.text.isNotEmpty ? double.tryParse(_gpaController.text.trim()) : null,
        skills: _selectedSkills,
        location: _locationController.text.trim(),
      );

      await _authService.signUpStudent(student, _passwordController.text.trim());

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const StudentEmailVerification()),
      );
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
    String? errorText,
    ValueChanged<String>? onChanged,
    // --- IMPROVEMENT 2: Added onFieldSubmitted for skills input ---
    ValueChanged<String>? onFieldSubmitted,
    String? helperText,
    TextStyle? helperStyle,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        inputFormatters: inputFormatters,
        focusNode: focusNode,
        readOnly: readOnly,
        onTap: onTap,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF422F5D))),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
          suffixIcon: suffixIcon,
          errorText: errorText,
          helperText: helperText,
          helperStyle: helperStyle,
        ),
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
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              '+966',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              // --- MODIFICATION 3: Apply the custom formatter ---
              inputFormatters: [
                LengthLimitingTextInputFormatter(11), // 9 digits + 2 spaces
                PhoneNumberFormatter(),
              ],
              // --- MODIFICATION 3: Update validator to handle spaces ---
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                final digitsOnly = value.replaceAll(' ', '');
                if (digitsOnly.length != 9) {
                  return 'Must be 9 digits';
                }
                if (!digitsOnly.startsWith('5')) {
                  return 'Must start with 5';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                // --- MODIFICATION 3: Update hintText ---
                hintText: '5X XXX XXXX',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _usernameManualValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    if (value.contains(' ')) {
      return 'Username cannot contain spaces';
    }
    if (_usernameError != null) {
      return _usernameError;
    }
    return null;
  }

  void _checkUsernameUniqueness(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // --- IMPROVEMENT 4: Show loading spinner ---
      if (mounted) setState(() { _isCheckingUsername = true; });
      if (_usernameError != null) {
        setState(() { _usernameError = null; });
      }
      if (value.isNotEmpty && !value.contains(' ')) {
        final isUnique = await _authService.isUsernameUnique(value);
        if (!isUnique && mounted) {
          setState(() {
            _usernameError = 'This username is already taken.';
          });
        }
      }
      // --- IMPROVEMENT 4: Hide loading spinner ---
      if (mounted) setState(() { _isCheckingUsername = false; });
    });
  }

  // --- ADDED: A reusable widget for the searchable fields ---
  Widget _buildSearchableDropdown({
    required String hintText,
    required String? selectedValue,
    required IconData icon,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: TextEditingController(text: selectedValue),
        readOnly: true,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF422F5D)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // --- ADDED: The search dialog logic ---
  Future<void> _showSearchDialog({
    required BuildContext context,
    required List<String> items,
    required String title,
    required Function(String) onItemSelected,
  }) async {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredItems = List.from(items);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Select $title', style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search for a $title...',
                        prefixIcon: const Icon(Icons.search, color: primaryColor),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor)),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredItems = items
                              .where((item) => item.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            title: Text(item, style: const TextStyle(color: Colors.black87)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onTap: () {
                              onItemSelected(item);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
  );
  }

  // --- KEPT: This is needed for Step 2 ---
  Widget _buildDropdownFormField({
    required String hintText,
    required List<String> items,
    required String? selectedValue,
    required void Function(String?) onChanged,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: onChanged,
        validator: validator,
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
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF422F5D))),
        ),
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(color: Color(0xFF422F5D), fontSize: 14), overflow: TextOverflow.ellipsis),
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
          gradient: const LinearGradient(colors: [Color(0xFFF99D46), Color(0xFFD64483)], begin: Alignment.centerLeft, end: Alignment.centerRight),
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
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white)
              : Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  // --- IMPROVEMENT 3: Logic and Widgets for Password Strength ---
  Widget _buildPasswordCriteriaRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.remove_circle_outline,
            color: met ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.black87 : Colors.grey,
            ),
          ),
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

  // --- IMPROVEMENT 5: Refactored UI into smaller builder functions ---

  // Builder for Step 1 Form
  Widget _buildStep1Form() {
    final passwordStrength = _calculatePasswordStrength();
    return Column(
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
          helperText: "We will verify if it's a university email",
          helperStyle: const TextStyle(color: Colors.grey),
          keyboardType: TextInputType.emailAddress,
          suffixIcon: _isUniversityEmail
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.warning_amber_rounded, color: Colors.orange),
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
          focusNode: _passwordFocusNode,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter password';
            if (!_isPasswordValid) return 'Please meet all password requirements';
            return null;
          },
        ),
        // --- MODIFICATION 2: Hide password criteria when valid ---
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
                 // --- IMPROVEMENT 3: Password Strength Indicator ---
                if(!_isPasswordValid)
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
            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please confirm your password';
            if (value != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        _buildStyledTextFormField(
          controller: _usernameController,
          hintText: 'Username',
          icon: Icons.person_pin_outlined,
          validator: _usernameManualValidator,
          onChanged: _checkUsernameUniqueness,
          errorText: _usernameError,
          // --- IMPROVEMENT 4: Added visual feedback for username checking ---
          suffixIcon: _isCheckingUsername 
            ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)))
            : null,
        ),
        _buildPhoneFormField(),
        _buildSearchableDropdown(
          hintText: 'University',
          selectedValue: _selectedUniversity,
          icon: Icons.school_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please select a university';
            if (value == 'Other' && _otherUniversityController.text.trim().isEmpty) return 'Please specify your university';
            return null;
          },
          onTap: () async {
            await _showSearchDialog(
              context: context,
              items: _universitiesList,
              title: 'University',
              onItemSelected: (value) => setState(() {
                _selectedUniversity = value;
                if (value != 'Other') _otherUniversityController.clear();
              }),
            );
            // --- MODIFICATION 1: Removed validation call to prevent flicker ---
          },
        ),
        if (_selectedUniversity == 'Other')
          _buildStyledTextFormField(
            controller: _otherUniversityController,
            hintText: 'Please specify your university',
            icon: Icons.edit,
            validator: (value) => value == null || value.trim().isEmpty ? 'This field is required' : null,
          ),
        _buildSearchableDropdown(
          hintText: 'Major',
          selectedValue: _selectedMajor,
          icon: Icons.book_outlined,
           validator: (value) {
            if (value == null || value.isEmpty) return 'Please select a major';
            if (value == 'Other' && _otherMajorController.text.trim().isEmpty) return 'Please specify your major';
            return null;
          },
          onTap: () async {
            await _showSearchDialog(
              context: context,
              items: _majorsList,
              title: 'Major',
              onItemSelected: (value) => setState(() {
                _selectedMajor = value;
                if (value != 'Other') _otherMajorController.clear();
              }),
            );
            // --- MODIFICATION 1: Removed validation call to prevent flicker ---
          },
        ),
        if (_selectedMajor == 'Other')
           _buildStyledTextFormField(
            controller: _otherMajorController,
            hintText: 'Please specify your major',
            icon: Icons.edit,
            validator: (value) => value == null || value.trim().isEmpty ? 'This field is required' : null,
          ),
        _buildStyledTextFormField(
          controller: _locationController,
          hintText: 'Location',
          icon: Icons.location_on_outlined,
          readOnly: true,
          onTap: _selectLocation,
          validator: (value) => value == null || value.isEmpty ? 'Please enter location' : null,
        ),
        const SizedBox(height: 20),
        _buildGradientButton(text: 'Next Step', onPressed: _goToNextStep),
      ],
    );
  }

  // Builder for Step 2 Form
  Widget _buildStep2Form() {
    return Column(
      children: [
        const Text(
          'You can skip these fields for now!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        _buildDropdownFormField(
          hintText: 'Academic Level',
          items: _academicLevels,
          selectedValue: _selectedLevel,
          onChanged: (String? newValue) => setState(() => _selectedLevel = newValue),
          icon: Icons.trending_up,
          validator: null, // Optional
        ),
        // --- IMPROVEMENT 1: Replaced with a Date Picker Field ---
        _buildStyledTextFormField(
          controller: _graduationController,
          hintText: 'Expected Graduation Date',
          icon: Icons.calendar_today,
          readOnly: true,
          onTap: () => _selectGraduationDate(context),
        ),
        _buildDropdownFormField(
          hintText: 'GPA Scale',
          items: const ['4.0', '5.0'],
          selectedValue: _gpaScale,
          onChanged: (String? newValue) {
            setState(() {
              _gpaScale = newValue;
              _gpaController.clear();
            });
          },
          icon: Icons.scale_outlined,
          validator: null, // Optional
        ),
        if (_gpaScale != null)
          _buildStyledTextFormField(
            controller: _gpaController,
            hintText: 'GPA (e.g., 3.8)',
            icon: Icons.grade,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return null;
              final gpa = double.tryParse(value);
              if (gpa == null) return 'Invalid GPA format';
              if (_gpaScale == '4.0' && (gpa < 0 || gpa > 4.0)) return 'GPA must be between 0 and 4.0';
              if (_gpaScale == '5.0' && (gpa < 0 || gpa > 5.0)) return 'GPA must be between 0 and 5.0';
              return null;
            },
          ),
        // --- IMPROVEMENT 2: Added onFieldSubmitted to add skill on Enter ---
        _buildStyledTextFormField(
          controller: _skillsController,
          hintText: 'Add a Skill and press Enter',
          icon: Icons.lightbulb_outline,
          onFieldSubmitted: (value) => _addSkill(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: _addSkill,
          ),
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
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      body: FutureBuilder<void>(
        future: _loadListsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError || _universitiesList.length <= 1) { // length <= 1 because "Other" is always there
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    const Text('Failed to load data', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const Text('Please check your internet connection and try again.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: () {
                        setState(() {
                          _loadListsFuture = _loadLists();
                        });
                      },
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/spark_logo.png', height: 120),
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
                              // Use the form key to validate before allowing step change
                              if (_formKey.currentState?.validate() ?? false) {
                                setState(() => _currentStep = 1);
                              } else {
                                // Scroll to the first error if needed or just show a message
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete Step 1 correctly.')));
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
                  Form(
                    key: _formKey,
                     // --- IMPROVEMENT 5: Using the refactored widgets ---
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
          );
        },
      ),
    );
  }
}// Ghaida!1 444201195@student.ksu.edu.sa