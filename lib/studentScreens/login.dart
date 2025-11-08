import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/authService.dart';
import '../services/notification_service.dart';
import '../studentScreens/studentViewProfile.dart';
import '../companyScreens/companyHomePage.dart';
import 'forgotPasswordScreen.dart';
import 'welcomeScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _idError;
  String? _pwError;

  OverlayEntry? _toastEntry;
  late final AnimationController _toastController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<Offset> _toastSlide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _toastController, curve: Curves.easeOut));

  void _showTopToast(
    String message, {
    IconData icon = Icons.error_outline,
    Duration duration = const Duration(seconds: 2),
  }) async {
    _hideTopToast();
    if (!mounted) return;
    final overlay = Overlay.of(context);
    _toastEntry = OverlayEntry(
      builder: (overlayContext) {
        final topSafe = MediaQuery.of(overlayContext).padding.top;
        return Positioned(
          top: 0,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: SlideTransition(
              position: _toastSlide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(top: topSafe > 0 ? 0 : 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF99D46), Color(0xFFD64483)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _hideTopToast,
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_toastEntry!);
    await _toastController.forward();
    Future.delayed(duration, () async {
      if (!mounted) return;
      await _toastController.reverse();
      _hideTopToast();
    });
  }

  void _hideTopToast() {
    _toastEntry?.remove();
    _toastEntry = null;
  }

  void _setErrors({String? idError, String? pwError}) {
    if (!mounted) return;
    setState(() {
      _idError = idError;
      _pwError = pwError;
    });
  }

  final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  String? _validateIdentifier(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter username/email";
    if (raw.contains(' ')) return "Username/email cannot contain spaces";
    if (trimmed.contains('@') && !_emailRegex.hasMatch(trimmed)) {
      return "Invalid email format";
    }
    return null;
  }

  String? _validatePassword(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter password";
    if (raw.contains(' ')) return "Password cannot contain spaces";
    return null;
  }

  String _mapAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code.toLowerCase()) {
        // ✅ MODIFIED: Handles new generic Firebase error
        case 'invalid-credential':
          return "Wrong email/username or password";

        case 'invalid-email':
          return "Invalid email format";
        case 'email-not-verified':
          return "Email not verified";
        case 'too-many-requests':
          // Removed rate limiting error - allow continued login attempts
          return "Wrong email/username or password";
        case 'network-request-failed':
          return "Network error. Check connection";
        default:
          return error.message ?? "Login failed";
      }
    }
    return error.toString();
  }

  Future<void> _login() async {
    final idRaw = _idController.text;
    final pwRaw = _passwordController.text;

    final idErr = _validateIdentifier(idRaw);
    final pwErr = _validatePassword(pwRaw);

    if (idErr != null || pwErr != null) {
      _setErrors(idError: idErr, pwError: pwErr);
      _showTopToast(idErr ?? pwErr!);
      return;
    }

    setState(() {
      _isLoading = true;
      _setErrors(idError: null, pwError: null);
    });

    try {
      final loginResult = await _authService.login(idRaw.trim(), pwRaw.trim());

      if (!mounted) return; // Avoid using BuildContext across async gaps

      final String userType = loginResult['userType'];

      // Save FCM token for push notifications
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          // Use correct collection based on user type
          final collection = userType == 'student' ? 'student' : 'companies';
          await NotificationService().saveFCMToken(
            currentUser.uid,
            userType: collection,
          );
          debugPrint('✅ FCM token saved for $userType: ${currentUser.uid}');
        } catch (tokenError) {
          debugPrint('⚠️ Failed to save FCM token: $tokenError');
          // Don't block login if token save fails
        }
      }

      _showTopToast("Welcome back!", icon: Icons.check_circle_outline);

      if (userType == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewProfile()),
        );
      } else if (userType == 'company') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CompanyHomePage()),
        );
      }
    } catch (e) {
      final mappedMsg = _mapAuthError(e);
      // Since the error message is now generic, we can't be sure which field is wrong.
      // So, we'll just show the toast without highlighting a specific field.
      // You could optionally highlight both fields if you prefer.
      _setErrors(
        pwError: " ",
        idError: " ",
      ); // Add a space to trigger the red border without text
      _showTopToast(mappedMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputBorder _fieldBorder(bool hasError) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: hasError ? Colors.red : Colors.transparent),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _toastController.dispose();
    _hideTopToast();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idHasError = _idError != null;
    final pwHasError = _pwError != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset('assets/spark_logo.png', height: 150),
              const SizedBox(height: 5),
              const Text(
                "SPARK",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF422F5D),
                ),
              ),
              const Text(
                "Ignite your future",
                style: TextStyle(
                  color: Color(0xFFF99D46),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              // Identifier
              TextField(
                controller: _idController,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'\s'),
                  ), // Prevent spaces
                ],
                decoration: InputDecoration(
                  hintText: "Username or Email",
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  border: _fieldBorder(idHasError),
                  enabledBorder: _fieldBorder(idHasError),
                  focusedBorder: _fieldBorder(idHasError),
                ),
                onChanged: (_) => _setErrors(idError: null),
              ),
              if (idHasError && _idError!.isNotEmpty && _idError != " ")
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _idError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    RegExp(r'\s'),
                  ), // Prevent spaces
                ],
                decoration: InputDecoration(
                  hintText: "Password",
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  border: _fieldBorder(pwHasError),
                  enabledBorder: _fieldBorder(pwHasError),
                  focusedBorder: _fieldBorder(pwHasError),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onChanged: (_) => _setErrors(pwError: null),
              ),
              if (pwHasError && _pwError!.isNotEmpty && _pwError != " ")
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _pwError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              // Log In Button
              SizedBox(
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
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Log In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: Color(0xFF6B4791),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text(
                  "Back to Welcome Page",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B4791),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Debug: Test Notifications Button
              if (const bool.fromEnvironment('dart.vm.product') == false)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/testNotifications');
                  },
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text(
                    "Test Notifications (Debug)",
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
