import 'package:flutter/material.dart';
import '../services/authService.dart';
import 'studentSignup.dart';
import '../companyScreens/companySignup.dart';
import 'studentProfilePage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController(); // Username أو Email
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  // ====== Validators & Helpers ======

  final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  String _normalizeIdentifier(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.contains('@')) {
      return t
          .replaceAll(' ', '')
          .toLowerCase(); // Email: قص ومسح المسافات الداخلية
    }
    return t.toLowerCase(); // Username: نترك الداخلية ممنوعة في الفاليديشن
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
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ====== Actions ======

  Future<void> _login() async {
    final idRaw = _idController.text;
    final pwRaw = _passwordController.text;

    // UI validation
    final idErr = _validateIdentifier(idRaw);
    final pwErr = _validatePassword(pwRaw);
    if (idErr != null || pwErr != null) {
      final msg = idErr ?? pwErr!;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // أهم تغيير: نرسل المعرف كما هو لـ AuthService (هو اللي يحل Username→Email)
      final userType = await _authService.login(
        idRaw, // identifier (username أو email)
        _normalizePassword(pwRaw),
      );

      if (!mounted) return;
      if (userType == 'student') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => StudentProfilePage()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Welcome Company!")));
        // TODO: Navigator.pushReplacementNamed(context, '/companyHome');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final idRaw = _idController.text;
    if (idRaw.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter your username/email first.")),
        );
      }
      return;
    }
    try {
      // كذلك هنا: AuthService يحوّل username للإيميل داخليًا
      await _authService.resetPassword(idRaw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset link sent to your email."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reset error: $e")));
    }
  }

  Future<void> _goTo(Widget page, int index) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() => {});
  }

  // ====== UI ======

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
              /* const SizedBox(height: 50), //delete it bec we have welcomeScreen
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E1E),
                ),
              ),*/
              const SizedBox(height: 30),

              // Username or Email
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
                    prefixIcon: Icon(Icons.person_outline, color: Colors.grey),
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
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
                        ? const CircularProgressIndicator(color: Colors.white)
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

              const Text(
                "Don't have an account?",
                style: TextStyle(color: Color(0xFF888888)),
              ),
              const SizedBox(height: 1),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _goTo(const StudentSignup(), 0),
                    child: const Text(
                      'Sign Up as Student',
                      style: TextStyle(
                        color: Color(0xFF6B4791),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanySignup(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up as Company',
                      style: TextStyle(
                        color: Color(0xFF6B4791),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
