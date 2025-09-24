import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // مهم لمسك FirebaseAuthException
import '../services/authService.dart';
import 'studentProfilePage.dart';
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

  String? _idError; // رسالة خطأ تحت حقل المعرّف
  String? _pwError; // رسالة خطأ تحت حقل الباسوورد

  // ====== Toast (أعلى الشاشة) ======
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
    _toastEntry?..remove();
    _toastEntry = null;
  }

  void _setErrors({String? idError, String? pwError}) {
    setState(() {
      _idError = idError;
      _pwError = pwError;
    });
  }

  // ====== Validators ======
  final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  // يلتقط حالات "شكله إيميل" لكن بدون @ (مثل: xxxxx.student.ksu.edu.sa)
  bool _looksLikeEmailWithoutAt(String s) {
    final t = s.trim();
    if (t.isEmpty || t.contains('@') || t.contains(' ')) return false;
    // يحتوي على نقطة ونهاية امتداد أحرف فقط (2-10)
    final parts = t.split('.');
    if (parts.length >= 2) {
      final last = parts.last;
      if (RegExp(r'^[A-Za-z]{2,10}$').hasMatch(last)) return true;
    }
    // مفيد لحالات جامعية/نطاقات معقدة (.edu.sa)
    if (RegExp(r'\.[A-Za-z]{2,10}\.[A-Za-z]{2,10}$').hasMatch(t)) return true;
    return false;
  }

  String? _validateIdentifier(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter username/email";

    if (trimmed.contains('@')) {
      final normalized = trimmed.replaceAll(' ', '');
      if (!_emailRegex.hasMatch(normalized)) return "Invalid email format";
      return null; // valid email
    } else {
      // هنا التعديل: إذا كان شكله دومين/إيميل لكنه بدون @ → خطأ "Invalid email format"
      if (_looksLikeEmailWithoutAt(trimmed)) return "Invalid email format";

      // غير ذلك نعامله كـ username عادي
      if (trimmed.contains(' ')) return "Please enter username/email";
      if (trimmed.length < 3) return "Please enter username/email";
      return null; // valid username
    }
  }

  String? _validatePassword(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter password";
    if (trimmed.length < 6) return "Please enter password";
    return null;
  }

  // ====== مطابقة أخطاء Firebase/الخدمة إلى رسائل الـ UI ======
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
      if (code == 'invalid-email') {
        return "Invalid email format";
      }
      if (code == 'too-many-requests') {
        return "Too many attempts. Please try again later.";
      }
      if (code == 'network-request-failed') {
        return "Network error. Check your connection.";
      }
      return "Login failed. Please try again.";
    }

    final m = error.toString().toLowerCase();

    if (m.contains('wrong-password') ||
        m.contains('invalid-credential') ||
        m.contains('invalid-credentials') ||
        m.contains('invalid password') ||
        m.contains('password is invalid') ||
        m.contains('the supplied auth credential is incorrect') ||
        m.contains('[firebase_auth/wrong-password]') ||
        m.contains('code 17009')) {
      return "Incorrect password";
    }

    if (m.contains('user-not-found') ||
        m.contains('[firebase_auth/user-not-found]') ||
        m.contains('no user record') ||
        m.contains('there is no user record') ||
        m.contains('user not found')) {
      return "User not found";
    }

    if (m.contains('invalid email') ||
        m.contains('invalid-email') ||
        m.contains('badly formatted') ||
        m.contains('[firebase_auth/invalid-email]')) {
      return "Invalid email format";
    }

    if (m.contains('too-many-requests')) {
      return "Too many attempts. Please try again later.";
    }
    if (m.contains('network')) {
      return "Network error. Check your connection.";
    }

    return "Login failed. Please try again.";
  }

  // ====== Login ======
  Future<void> _login() async {
    final idRaw = _idController.text;
    final pwRaw = _passwordController.text;

    final idErr = _validateIdentifier(idRaw);
    final pwErr = _validatePassword(pwRaw);

    if (idErr != null || pwErr != null) {
      _setErrors(idError: idErr, pwError: pwErr);
      // نفس سلوك التوست كما بالصورة (يطلع بالرسالة نفسها)
      if (idErr != null && pwErr != null) {
        _showTopToast("Please enter username/email and password");
      } else {
        _showTopToast(idErr ?? pwErr!);
      }
      return; // مهم: لا نرسل أي طلب للباكند
    }

    setState(() {
      _isLoading = true;
      _setErrors(idError: null, pwError: null);
    });

    try {
      // نرسل قيم منظّفة
      final normalizedId = idRaw.trim().contains('@')
          ? idRaw.trim().replaceAll(' ', '')
          : idRaw.trim();
      final normalizedPw = pwRaw.trim();

      final userType = await _authService.login(normalizedId, normalizedPw);

      if (!mounted) return;

      if (userType == "student" || userType == "company") {
        _showTopToast("Welcome back!", icon: Icons.check_circle_outline);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StudentProfilePage()),
        );
      } else {
        _showTopToast("Login failed. Please try again.");
      }
    } catch (err) {
      if (!mounted) return;
      final msg = _mapAuthError(err);

      // نحدّد مكان الخطأ (أحمر) حسب الرسالة
      if (msg == "Incorrect password") {
        _setErrors(pwError: msg);
      } else if (msg == "User not found" || msg == "Invalid email format") {
        _setErrors(idError: msg);
      }

      _showTopToast(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====== Borders ======
  InputBorder _fieldBorder(bool hasError) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: hasError ? Colors.red.shade400 : Colors.transparent,
        width: hasError ? 1.2 : 0,
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _toastController.dispose();
    super.dispose();
  }

  // ====== UI ======
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

              // === Log In button with gradient ===
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
                        backgroundColor: Colors.transparent, // مهم للتدرّج
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
              GestureDetector(
                onTap: () {
                  /* hook reset flow here */
                },
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: Color(0xFF6B4791),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
            ],
          ),
        ),
      ),
    );
  }
}
