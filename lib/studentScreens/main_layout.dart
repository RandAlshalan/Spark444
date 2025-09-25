import 'package:flutter/material.dart';
import 'StudentProfilePage.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  // Pages linked to nav items
  final List<Widget> _pages = const [
    Center(child: Text("Dashboard (coming soon)")),
    Center(child: Text("Internships (coming soon)")),
    Center(child: Text("Clubs (coming soon)")),
    StudentProfilePage(), // ✅ your real profile page
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // Global AppBar
      appBar: AppBar(
        title: const Text("Spark"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF6A4EA5), // Spark purple
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
        ],
      ),

      // Body switches by tab
      body: _pages[_selectedIndex],

      // Global Bottom Nav
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF6A4EA5),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: "Internships",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Clubs"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
