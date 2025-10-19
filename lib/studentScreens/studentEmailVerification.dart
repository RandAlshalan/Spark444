import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/studentScreens/welcomeScreen.dart';
import '../services/authService.dart';

class StudentEmailVerification extends StatefulWidget {
  const StudentEmailVerification({super.key});

  @override
  _StudentEmailVerificationState createState() =>
      _StudentEmailVerificationState();
}

class _StudentEmailVerificationState extends State<StudentEmailVerification> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  bool _isChecking = false;
  bool _isResending = false;
  bool _isGoingBack = false;

  Future<void> _manualCheckVerification() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    User? user = _auth.currentUser;
    await user?.reload(); // The most important step: fetch latest user data

    // Check the status again after reloading
    if (mounted && (user?.emailVerified ?? false)) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email not verified yet. Please check your inbox (and spam folder).',
          ),
        ),
      );
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend email.')),
        );
      }
    }
    setState(() => _isResending = false);
  }

  Future<void> _goBackAndCancel() async {
    setState(() => _isGoingBack = true);
    try {
      await _authService.cancelSignUpAndDeleteUser();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
    if (mounted) {
      setState(() => _isGoingBack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 100,
                color: Color(0xFF422F5D),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF422F5D),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'A verification link has been sent to:\n${_auth.currentUser?.email ?? 'your email address.'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // --- NEW: Main "Done" Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _manualCheckVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF99D46),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          "I've Verified, Continue",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Secondary Buttons ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isGoingBack ? null : _goBackAndCancel,
                    child: _isGoingBack
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Text(
                            'Go Back & Edit Info',
                            style: TextStyle(color: Color(0xFF422F5D)),
                          ),
                  ),
                  TextButton(
                    onPressed: _isResending ? null : _resendVerificationEmail,
                    child: _isResending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(),
                          )
                        : const Text(
                            'Resend Email',
                            style: TextStyle(color: Color(0xFF422F5D)),
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
