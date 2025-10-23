import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;

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
    Duration duration = const Duration(seconds: 3),
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

  final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  String? _validateEmail(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return "Please enter email address";

    final normalized = trimmed.replaceAll(' ', '');
    if (!_emailRegex.hasMatch(normalized))
      return "Please enter a valid email address";

    return null;
  }

  Future<void> _resetPassword() async {
    final emailRaw = _emailController.text;
    final emailErr = _validateEmail(emailRaw);

    debugPrint('Attempting password reset for email: ${emailRaw.trim()}');

    if (emailErr != null) {
      setState(() => _emailError = emailErr);
      _showTopToast(emailErr);
      debugPrint('Email validation failed: $emailErr');
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      final normalizedEmail = emailRaw.trim().replaceAll(' ', '');
      debugPrint('Sending password reset email to: $normalizedEmail');

      // Add timeout for the request
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
            email: normalizedEmail,
            // You can add custom ActionCodeSettings if needed
            // actionCodeSettings: ActionCodeSettings(
            //   url: 'https://your-app.com/reset-password',
            //   handleCodeInApp: true,
            //   androidPackageName: 'com.your.package',
            //   iOSBundleId: 'com.your.bundle',
            // ),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your internet connection.',
              );
            },
          );

      debugPrint('Password reset email sent successfully');

      if (!mounted) return;

      _showTopToast(
        "Password reset email sent! Check your inbox and spam folder.",
        icon: Icons.check_circle_outline,
        duration: const Duration(seconds: 5),
      );

      // Show additional instructions Ghaida!1
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Email Sent!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We sent a password reset link to:\n$normalizedEmail'),
                const SizedBox(height: 16),
                const Text('Please:'),
                const Text('• Check your inbox'),
                const Text('• Check your spam/junk folder'),
                const Text('• Wait up to 5 minutes for delivery'),
                const Text('• Click the link to reset your password'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to login
                },
                child: const Text('Got it'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Password reset error: $e');

      if (!mounted) return;

      String errorMessage = "Failed to send reset email. Please try again.";

      if (e is FirebaseAuthException) {
        debugPrint('Firebase Auth Error Code: ${e.code}');
        debugPrint('Firebase Auth Error Message: ${e.message}');

        switch (e.code) {
          case 'user-not-found':
            errorMessage = "No account found with this email address";
            setState(() => _emailError = errorMessage);
            break;
          case 'invalid-email':
            errorMessage = "Please enter a valid email address";
            setState(() => _emailError = errorMessage);
            break;
          case 'too-many-requests':
            // Removed rate limiting error - allow continued password reset attempts
            errorMessage = "Please check your email for the password reset link";
            break;
          case 'network-request-failed':
            errorMessage = "Network error. Check your connection.";
            break;
          case 'configuration-not-found':
          case 'project-not-found':
            errorMessage =
                "Service configuration error. Please contact support.";
            break;
          default:
            errorMessage = "Error: ${e.message ?? e.code}";
        }
      } else {
        // Handle other types of errors (timeout, network, etc.)
        errorMessage = e.toString().contains('timeout')
            ? "Request timed out. Please check your connection."
            : "Error: ${e.toString()}";
      }

      _showTopToast(errorMessage, duration: const Duration(seconds: 6));

      // Show detailed error dialog for debugging
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Debug Information'),
            content: SingleChildScrollView(child: Text('Error details:\n$e')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    _emailController.dispose();
    _toastController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailHasError = _emailError != null && _emailError!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF422F5D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset('assets/spark_logo.png', height: 120),
              const SizedBox(height: 5),
              const Text(
                "Reset Password",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF422F5D),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Enter your email address and we'll send you a link to reset your password",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), fontSize: 16),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: "Email Address",
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  border: _fieldBorder(emailHasError),
                  enabledBorder: _fieldBorder(emailHasError),
                  focusedBorder: _fieldBorder(emailHasError),
                ),
                onChanged: (_) => setState(() => _emailError = null),
              ),
              if (emailHasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _emailError!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 30),

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
                      onPressed: _isLoading ? null : _resetPassword,
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
                              'Send Reset Link',
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
              const SizedBox(height: 20),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Back to Login",
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
