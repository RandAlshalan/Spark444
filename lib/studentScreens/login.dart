import 'package:flutter/material.dart';
import '../services/authService.dart';
import 'studentSignup.dart';
import '../companyScreens/companySignup.dart';
import 'studentProfilePage.dart';
import 'welcomeScreen.dart'; // Import the WelcomeScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController(); 
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  // ====== Top Toast (Overlay) ======
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
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _toastEntry = OverlayEntry(
      builder: (_) {
        final topSafe = MediaQuery.of(context).padding.top;
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
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
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

  void _showSuccess(String msg) =>
      _showTopToast(msg, icon: Icons.check_circle_outline);

  void _hideTopToast() {
    _toastEntry?..remove();
    _toastEntry = null;
  }

  // ====== Validators & Helpers ======
  final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  String _normalizeIdentifier(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.contains('@')) {
      return t.replaceAll(' ', '').toLowerCase();
    }
    return t.toLowerCase();
  }

  String? _validateIdentifier(String raw) {
    final id = _normalizeIdentifier(raw);
    if (id.isEmpty) return 'Please enter username/email';

    final isEmail = id.contains('@');
    if (isEmail) {
      if (!_emailRegex.hasMatch(id)) return 'Invalid email format';
      return null;
    } else {
      if (id.contains(' ')) return 'Username cannot contain spaces';
      if (id.length < 3) return 'Username must be at least 3 characters';
      if (id.length > 30) return 'Username is too long';
      final usernameRegex = RegExp(r'^[a-z0-9._-]+$');
      if (!usernameRegex.hasMatch(id)) {
        return 'Username can only contain letters, numbers, dot, underscore, and hyphen';
      }
      return null;
    }
  }

  String _normalizePassword(String raw) => raw.trim();

  String? _validatePassword(String raw) {
    final p = _normalizePassword(raw);
    if (p.isEmpty) return 'Please enter password';
    if (p.length < 6) return 'Password must be at least 6 characters';
    if (p.length > 50) return 'Password is too long';
    return null;
  }

  // ====== Lifecycle ======
  @override
  void dispose() {
    _hideTopToast();
    _toastController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ====== Actions ======
  Future<void> _login() async {
    final idRaw = _idController.text;
    final pwRaw = _passwordController.text;

    final idErr = _validateIdentifier(idRaw);
    final pwErr = _validatePassword(pwRaw);
    if (idErr != null || pwErr != null) {
      _showTopToast(idErr ?? pwErr!);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userType = await _authService.login(
        idRaw,
        _normalizePassword(pwRaw),
      );

      if (!mounted) return;

      if (userType == 'student') {
        _showSuccess('Welcome back!');
        await Future.delayed(const Duration(milliseconds: 200));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StudentProfilePage()),
        );
      } else if (userType == 'company') {
        _showSuccess('Welcome Company!');
        // TODO: استبدلي بصفحة الـ Company المناسبة
        // Navigator.pushReplacementNamed(context, '/companyHome');
      } else {
        _showTopToast('Unknown user type');
      }
    } catch (e) {
      if (!mounted) return;
      _showTopToast(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final idRaw = _idController.text;
    if (idRaw.trim().isEmpty) {
      _showTopToast('Enter your username/email first.');
      return;
    }
    try {
      await _authService.resetPassword(idRaw);
      if (!mounted) return;
      _showSuccess('Password reset link sent to your email.');
    } catch (e) {
      if (!mounted) return;
      _showTopToast('Reset error: $e');
    }
  }

  Future<void> _goTo(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/spark_logo.png', height: 150),
                  const SizedBox(height: 0),
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

                  // Identifier
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
                    child: TextField(
                      controller: _idController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Username or Email',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Password
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
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.grey,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Log In button
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
                  const SizedBox(height: 20),

                  // Forgot Password
                  GestureDetector(
                    onTap: _isLoading ? null : _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF6B4791),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  // Back to Welcome Page button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: const Text(
                          'Back to Welcome Page',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B4791),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                ],
              ),
            ),
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}