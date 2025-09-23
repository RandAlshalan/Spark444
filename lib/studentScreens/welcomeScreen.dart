import 'package:flutter/material.dart';
import 'login.dart'; // لأنه داخل studentScreens مع welcomeScreen

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _showRolePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Continue as',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Bubble(
                    icon: Icons.school_outlined,
                    label: 'Student',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(
                        context,
                        '/signup',
                      ); // يفتح صفحة الطالب
                    },
                  ),
                  _Bubble(
                    icon: Icons.business_center_outlined,
                    label: 'Company',
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(
                        context,
                        '/companySignup',
                      ); // يفتح صفحة الشركة
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 28),

                // Logo + tagline
                Column(
                  children: [
                    Image.asset(
                      'assets/spark_logo.png',
                      height: 96,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image, size: 48),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SPARK',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF422F5D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ignite your future',
                      style: TextStyle(
                        color: Color(0xFFF99D46),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                const Text(
                  'Unlock Your Future.\nYour Way',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Connect with careers that fit your skills, ambition, and personality',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Colors.black54,
                  ),
                ),

                const Spacer(),

                // Illustration (تأكدي الاسم مطابق للملف students.png)
                Image.asset(
                  'assets/students.png',
                  height: 300,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 64),
                ),

                const Spacer(),

                // Get Started → يفتح فقاعات
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
                      onPressed: () => _showRolePicker(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Log In → login.dart
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text(
                    'Log In',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Privacy Policy',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                    SizedBox(width: 18),
                    Text(
                      'Terms of Service',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Bubble({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7E7E7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF5B4B7A)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
