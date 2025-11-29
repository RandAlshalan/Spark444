import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // These colors are taken from your profile screen for consistency
    const Color profileCardColor = Color(0xFFFFFFFF);
    const Color sparkPrimaryPurple = Color(0xFFD54DB9); // match header gradient start
    const Color profileTextColor = Color(0xFF1E1E1E);
    const gradient = LinearGradient(
      colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    Widget _activeIcon(IconData icon) {
      return ShaderMask(
        shaderCallback: (Rect bounds) => gradient.createShader(bounds),
        child: Icon(icon, color: Colors.white),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: profileCardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed, // هذا النوع مهم لعرض 5 أيقونات
          backgroundColor: profileCardColor,
          selectedItemColor: sparkPrimaryPurple,
          unselectedItemColor: profileTextColor.withOpacity(0.5),
          selectedLabelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: GoogleFonts.lato(fontSize: 10),
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 24,
          elevation: 0,
          enableFeedback: true,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: _activeIcon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: _activeIcon(Icons.business),
              label: 'Companies',
            ),
            
            // --- ✨ الأيقونة الجديدة المضافة هنا ---
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: _activeIcon(Icons.chat_bubble_rounded),
              label: 'Chatbot',
            ),
            // --- نهاية الإضافة ---

            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: _activeIcon(Icons.work),
              label: 'Opportunities',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: _activeIcon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
