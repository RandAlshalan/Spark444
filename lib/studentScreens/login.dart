import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/authService.dart';
import 'StudentProfilePage.dart';
import 'studentViewProfile.dart';
import 'welcomeScreen.dart';
import 'forgotPasswordScreen.dart';
import '../companyScreens/companyHomePage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // =======================
  // Controllers & Service
  // =======================
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _idError;
  String? _pwError;

  // =======================
  // Toast Setup
  // =======================
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                              color: Colors.white, fontWeight: FontWeight.w600),
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
    _toastEntry?..remove();
    _toastEntry = null;
  }

  void _setErrors({String? idError, String? pwError}) {
    if (mounted) {
      setState(() {
        _idError = idError;
        _pwError = pwError;
      });
    }
  }

  // =======================
  // Validators
  // =======================
  final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  bool _looksLikeEmailWithoutAt(String s) {
    final t = s.trim();
    if (t.isEmpty || t.contains('@') || t.contains(' ')) return false;
    final parts = t.split('.');
    if (parts.length >= 2) {
      final last = parts.last;
      if (RegExp(r'^[A-Za-z]{2,10}$').hasMatch(last)) return true;
    }
    if (RegExp(r'\.[A-Za-z]{2,10}\.[A-Za-z]{2,10}$').hasMatch(t)) return true;
    return false;
  }

  String? _validateIdentifier(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter username/email";

    if (trimmed.contains('@')) {
      final normalized = trimmed.replaceAll(' ', '');
      if (!_emailRegex.hasMatch(normalized)) return "Invalid email format";
      return null;
    } else {
      if (_looksLikeEmailWithoutAt(trimmed)) return "Invalid email format";
      if (trimmed.contains(' ')) return "Please enter username/email";
      if (trimmed.length < 3) return "Please enter username/email";
      return null;
    }
  }

  String? _validatePassword(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter password";
    if (trimmed.length < 6) return "Please enter password";
    return null;
  }

  // =======================
  // Map Auth Errors
  // =======================
  String _mapAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      final code = error.code.toLowerCase();
      if (code == 'wrong-password' ||
          code == 'invalid-credential' ||
          code == 'invalid-credentials' ||
          code == 'invalid-password') {
        return "Incorrect password";
      }
      if (code == 'user-not-found' || code == 'user-disabled') {
        return "User not found";
      }
      if (code == 'invalid-email') return "Invalid email format";
      if (code == 'too-many-requests') {
        return "Too many attempts. Please try again later.";
      }
      if (code == 'network-request-failed') {
        return "Network error. Check your connection.";
      }
      return error.message ?? "";
    }

    final m = error.toString().toLowerCase();

    if (m.contains('wrong-password') || m.contains('invalid-credential')) {
      return "Incorrect password";
    }

    if (m.contains('user-not-found') || m.contains('no user record')) {
      return "User not found";
    }

    if (m.contains('invalid email') || m.contains('badly formatted')) {
      return "Invalid email format";
    }

    if (m.contains('too-many-requests')) {
      return "Too many attempts. Please try again later.";
    }
    if (m.contains('network')) {
      return "Network error. Check your connection.";
    }

    return "";
  }

  // =======================
  // Login
  // =======================
  Future<void> _login() async {
    final idRaw = _idController.text;
    final pwRaw = _passwordController.text;

    final idErr = _validateIdentifier(idRaw);
    final pwErr = _validatePassword(pwRaw);

    if (idErr != null || pwErr != null) {
      _setErrors(idError: idErr, pwError: pwErr);
      if (mounted) {
        _showTopToast(idErr ?? pwErr!);
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _setErrors(idError: null, pwError: null);
      });
    }

    try {
      final normalizedId = idRaw.trim().contains('@')
          ? idRaw.trim().replaceAll(' ', '')
          : idRaw.trim();
      final normalizedPw = pwRaw.trim();

      final loginResult = await _authService.login(normalizedId, normalizedPw);
      final String userType = loginResult['userType'];
      final bool isVerified = loginResult['isVerified'];

      if (!mounted) return;

      // توست ترحيبي
      _showTopToast("Welcome back!", icon: Icons.check_circle_outline);

      if (userType == 'student') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentViewProfile()),
        );
      } else if (userType == 'company') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CompanyHomePage()),
        );
      }

      // حالة الشركات غير verified
      if (userType == 'company' && !isVerified) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _showTopToast(
              "Please check your inbox to verify your email.",
              icon: Icons.warning_amber_rounded,
              duration: const Duration(seconds: 5),
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('Login Error Details: $e');

      String errorString = e.toString();
      if (errorString.contains('Please verify your email address first')) {
        _setErrors(idError: "Email not verified.");
        _showTopToast("Please verify your email address first.");
      } else {
        final mappedMsg = _mapAuthError(e);
        if (mappedMsg == "Incorrect password") {
          _setErrors(pwError: mappedMsg);
        } else if (mappedMsg == "User not found" ||
            mappedMsg == "Invalid email format") {
          _setErrors(idError: mappedMsg);
        }
        if (mappedMsg.isNotEmpty) _showTopToast(mappedMsg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =======================
  // Borders
  // =======================
  InputBorder _fieldBorder(bool hasError) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:
          BorderSide(color: hasError ? Colors.red.shade400 : Colors.transparent, width: hasError ? 1.2 : 0),
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

  // =======================
  // UI
  // =======================
  @override
  Widget build(BuildContext context) {
    final idHasError = _idError != null && _idError!.isNotEmpty;
    final pwHasError = _pwError != null && _pwError!.isNotEmpty;

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
                decoration: InputDecoration(
                  hintText: "Username or Email",
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  border: _fieldBorder(idHasError),
                  enabledBorder: _fieldBorder(idHasError),
                  focusedBorder: _fieldBorder(idHasError),
                ),
                onChanged: (_) => _setErrors(idError: null),
              ),
              if (idHasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _idError!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12.5,
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
                decoration: InputDecoration(
                  hintText: "Password",
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  border: _fieldBorder(pwHasError),
                  enabledBorder: _fieldBorder(pwHasError),
                  focusedBorder: _fieldBorder(pwHasError),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onChanged: (_) => _setErrors(pwError: null),
              ),
              if (pwHasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _pwError!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 22),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isLoading ? 0.85 : 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF99D46), Color(0xFFD64483)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
              ),
              const SizedBox(height: 16),

              // Forgot Password
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
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
                ),
              ),
              const SizedBox(height: 22),

              TextButton(
                onPressed: () {
                  if (!mounted) return;
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
            ],
          ),
        ),
      ),
    );
  }
}
