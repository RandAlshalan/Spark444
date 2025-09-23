import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _grad = LinearGradient(
    colors: [Color(0xFFF99D46), Color(0xFFD64483)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // محتوى الصفحة العلوي
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

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

                      const SizedBox(height: 28),

                      // Headline + sub
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

                      // زر Get Started
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _grad,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: ElevatedButton(
                            onPressed: _toggle,
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

                      // فقاعتين يطلعن من تحت الزر
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: _expanded
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: 14,
                                    bottom: 6,
                                  ),
                                  child: FadeTransition(
                                    opacity: _fade,
                                    child: SlideTransition(
                                      position: _slide,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _Bubble(
                                            icon: Icons.school_outlined,
                                            label: 'as Student',
                                            onTap: () {
                                              _toggle();
                                              Navigator.pushNamed(
                                                context,
                                                '/signup',
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 22),
                                          _Bubble(
                                            icon:
                                                Icons.business_center_outlined,
                                            label: 'as Company',
                                            onTap: () {
                                              _toggle();
                                              Navigator.pushNamed(
                                                context,
                                                '/companySignup',
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      // Log In أعلى من الصورة وتحت الزر
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text(
                          'Log In',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // الصورة أسفل الصفحة بعرض كامل
            Image.asset(
              'assets/students.png',
              width: double.infinity,
              height: 200, // تقدرين تغيرينها (مثلاً 240)
              fit: BoxFit.cover, // تمتد بعرض الشاشة
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, size: 64),
            ),
          ],
        ),
      ),
    );
  }
}

// فقاعة دائرية ملوّنة
class _Bubble extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Bubble({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(60),
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFF99D46), Color(0xFFD64483)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
