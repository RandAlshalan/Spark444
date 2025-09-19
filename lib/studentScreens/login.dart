import 'package:flutter/material.dart';
import '../services/authService.dart';
import 'studentSignup.dart';
import '../companyScreens/companySignup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // 👇 جديد: إخفاء/إظهار كلمة المرور
  bool _obscurePassword = true;

  final AuthService _authService = AuthService();

  // pressed state for segmented sign-up buttons: 0 => student, 1 => company
  int? _signUpPressedIndex;

  // Colors (same palette you already use)
  static const Color kOrange = Color(0xFFFF7043);
  static const Color kOrangeLight = Color(0xFFFFAB40);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userType = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      if (userType == 'student') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Welcome Student!")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Welcome Company!")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter your email first.")));
      return;
    }
    try {
      await _authService.resetPassword(email);
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

  // Navigate with pressed highlight
  Future<void> _goTo(Widget page, int index) async {
    setState(() => _signUpPressedIndex = index);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() => _signUpPressedIndex = null);
  }

  // Segmented "Sign Up" buttons (press turns orange)
  Widget _signupSegmentedButtons() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _goTo(const StudentSignup(), 0),
              onTapDown: (_) => setState(() => _signUpPressedIndex = 0),
              onTapCancel: () => setState(() => _signUpPressedIndex = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: _signUpPressedIndex == 0
                      ? const LinearGradient(colors: [kOrange, kOrangeLight])
                      : null,
                  color: _signUpPressedIndex == 0
                      ? null
                      : Colors.white.withOpacity(0.15),
                ),
                child: const Text(
                  "Sign Up as Student",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => _goTo(const companySignup(), 1),
              onTapDown: (_) => setState(() => _signUpPressedIndex = 1),
              onTapCancel: () => setState(() => _signUpPressedIndex = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: _signUpPressedIndex == 1
                      ? const LinearGradient(colors: [kOrange, kOrangeLight])
                      : null,
                  color: _signUpPressedIndex == 1
                      ? null
                      : Colors.white.withOpacity(0.15),
                ),
                child: const Text(
                  "Sign Up as Company",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6A1B9A),
                  Color(0xFF8E24AA),
                  Color(0xFFFF7043),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Image.asset('assets/spark_logo.png', height: 190, width: 200),
                  const SizedBox(height: 10),
                  const Text(
                    'SPARK',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ignite your future',
                    style: TextStyle(
                      color: kOrangeLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Email
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.mail_outline),
                      labelText: 'Email',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Password with show/hide toggle 👇
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      // زرّ العين
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Login
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Login', style: TextStyle(fontSize: 18)),
                    ),
                  ),

                  // Segmented Sign Up + Forgot password
                  const SizedBox(height: 22),
                  _signupSegmentedButtons(),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isLoading ? null : _forgotPassword,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
