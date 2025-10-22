import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spark/studentScreens/FollowedCompaniesPage.dart';

import '../models/student.dart';
import '../services/authService.dart';
import 'login.dart';
import 'studentEditProfile.dart' show DocumentsScreen;

const Color _profilePrimaryColor = Color(0xFF422F5D);
const Color _profileSecondaryColor = Color(0xFFF99D46);
const Color _profileAccentColor = Color(0xFFD64483);
const Color _profileBackgroundColor = Color(0xFFF8F9FA);
const Color _profileTextColor = Color(0xFF1E1E1E);
const Color _profileCardColor = Color(0xFFFFFFFF);
const Color _profileSurfaceColor = Color(0xFFF1F3F5);

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final AuthService _authService = AuthService();
  Student? _student;
  bool _loading = true;
  int _currentIndex = 3;

  Color _withAlpha(Color color, double opacity) {
    final double normalized = opacity < 0
        ? 0
        : opacity > 1
        ? 1
        : opacity;

    // Use withAlpha for better compatibility
    final int alpha = (normalized * 255).round();
    return color.withAlpha(alpha);
  }

  String _buildGreeting(String fullName) {
    final String firstName = fullName.split(' ').first;
    final int hour = DateTime.now().hour;
    final String salutation;
    if (hour < 12) {
      salutation = 'Good morning';
    } else if (hour < 17) {
      salutation = 'Good afternoon';
    } else {
      salutation = 'Good evening';
    }

    const weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final String weekday = weekdayNames[(DateTime.now().weekday + 6) % 7];

    return '$salutation, $firstName - happy $weekday!';
  }

  String _buildProgressPrompt(double completion) {
    if (completion >= 0.9) {
      return 'You are almost career ready. Keep inspiring!';
    }
    if (completion >= 0.7) {
      return 'A few final touches will make your profile shine.';
    }
    if (completion >= 0.4) {
      return 'Let\'s add more accomplishments to boost your visibility.';
    }
    return 'Start building your journey - complete your profile today.';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile(showSpinner: true));
  }

  Future<void> _loadProfile({bool showSpinner = false}) async {
    try {
      if (showSpinner) {
        setState(() => _loading = true);
      }
      final fetchedStudent = await _authService.getCurrentStudent();
      if (!mounted) return;
      setState(() {
        _student = fetchedStudent;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _showInfoMessage('Error loading profile. Please try again.');
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showLogoutDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _profilePrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildLoadingScaffold();
    }

    final student = _student;
    if (student == null) {
      return _buildMissingProfileScaffold();
    }

    final profile = _ProfileUiModel.fromStudent(student);
    final menuContent = _buildMenuSection(student, profile);

    final mediaQuery = MediaQuery.of(context);
    final double headerContentTopPadding =
        mediaQuery.padding.top + (kToolbarHeight / 2.5) + 24;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _profileBackgroundColor,
      appBar: _buildAppBar(onGradient: true),
      body: RefreshIndicator(
        onRefresh: () => _loadProfile(showSpinner: false),
        color: _profilePrimaryColor,
        edgeOffset: headerContentTopPadding,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderSection(profile, student, headerContentTopPadding),
              const SizedBox(height: 100),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [...menuContent, const SizedBox(height: 32)],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar({bool onGradient = false}) {
    return AppBar(
      backgroundColor: onGradient
          ? Colors.transparent
          : _profileBackgroundColor,
      elevation: 0,
      foregroundColor: onGradient ? Colors.white : _profileTextColor,
      systemOverlayStyle: onGradient
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      title: const Text('My Profile'),
      centerTitle: true,
    );
  }

  Widget _buildHeaderSection(
    _ProfileUiModel profile,
    Student student,
    double topPadding,
  ) {
    final completion = _calculateProfileCompletion(profile).clamp(0.0, 1.0);
    final completionPercent = (completion * 100).round();

    final mediaSize = MediaQuery.of(context).size;
    final double backgroundHeight = (mediaSize.height * 0.36 + topPadding)
        .clamp(topPadding + 200, topPadding + 260);

    final greeting = _buildGreeting(profile.fullName);
    final progressPrompt = _buildProgressPrompt(completion);

    return SizedBox(
      height: backgroundHeight + 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: backgroundHeight,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, 96),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_profileSecondaryColor, _profileAccentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Text(
                  greeting,
                  style: TextStyle(
                    color: _withAlpha(Colors.white, 0.92),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progressPrompt,
                  style: TextStyle(
                    color: _withAlpha(Colors.white, 0.75),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: -36,
            child: _buildProfileSummaryCard(
              profile,
              student,
              completion,
              completionPercent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummaryCard(
    _ProfileUiModel profile,
    Student student,
    double completion,
    int completionPercent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _profileCardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _withAlpha(_profileTextColor, 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: _withAlpha(_profileTextColor, 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: completion),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOutCubic,
            builder: (context, value, child) {
              return SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background progress circle
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _withAlpha(_profilePrimaryColor, 0.08),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                    // Animated progress circle
                    ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          colors: [_profileSecondaryColor, _profileAccentColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.srcIn,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    // Profile picture centered in the circle
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _profileCardColor,
                        boxShadow: [
                          BoxShadow(
                            color: _withAlpha(_profileTextColor, 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: _withAlpha(_profilePrimaryColor, 0.04),
                        backgroundImage: profile.profilePictureUrl != null
                            ? NetworkImage(profile.profilePictureUrl!)
                            : null,
                        child: profile.profilePictureUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: _profilePrimaryColor,
                              )
                            : null,
                      ),
                    ),
                    // Edit button positioned at bottom right
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Material(
                        color: _profilePrimaryColor,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          tooltip: 'Edit photo',
                          onPressed: () => _openScreen(
                            PersonalInformationScreen(student: student),
                          ),
                          icon: const Icon(
                            Icons.edit,
                            size: 12,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 22,
                            height: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            profile.fullName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _profilePrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (profile.username != null) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: TextStyle(
                fontSize: 14,
                color: _withAlpha(_profilePrimaryColor, 0.7),
              ),
            ),
          ],
          if (profile.shortSummary != null) ...[
            const SizedBox(height: 8),
            Text(
              profile.shortSummary!,
              style: TextStyle(
                color: _withAlpha(_profileTextColor, 0.7),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (profile.location != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: _profilePrimaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  profile.location!,
                  style: TextStyle(
                    color: _withAlpha(_profilePrimaryColor, 0.8),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_profileSecondaryColor, _profileAccentColor],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _withAlpha(_profileAccentColor, 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Profile $completionPercent% complete',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (profile.phoneNumber != null)
                _InfoPill(
                  icon: Icons.phone_rounded,
                  label: profile.phoneNumber!,
                ),
              if (profile.university.isNotEmpty)
                _InfoPill(
                  icon: Icons.school_outlined,
                  label: profile.university,
                ),
              if (profile.major.isNotEmpty)
                _InfoPill(icon: Icons.menu_book_outlined, label: profile.major),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Edit Info',
                  onTap: () =>
                      _openScreen(PersonalInformationScreen(student: student)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.file_present_outlined,
                  label: 'Documents',
                  onTap: () => _openScreen(DocumentsScreen(student: student)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.settings_suggest_outlined,
                  label: 'Preferences',
                  onTap: () =>
                      _openScreen(SettingsPreferencesScreen(student: student)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuSection(Student student, _ProfileUiModel profile) {
    final sections = [
      _MenuSection(
        title: 'Profile Management',
        items: [
          _MenuItemData(
            icon: Icons.manage_accounts_outlined,
            title: 'Personal Details',
            subtitle: 'Name, contact, photo',
            onTap: () =>
                _openScreen(PersonalInformationScreen(student: student)),
          ),
          _MenuItemData(
            icon: Icons.school_outlined,
            title: 'Academic Info',
            subtitle: 'University, major, GPA',
            onTap: () => _openScreen(AcademicInfoScreen(student: student)),
          ),
          _MenuItemData(
            icon: Icons.psychology_alt_outlined,
            title: 'Skills',
            subtitle: 'You have ${profile.skills.length} skills',
            trailing: profile.skills.isEmpty
                ? const Icon(
                    Icons.add_circle_outline,
                    color: _profilePrimaryColor,
                  )
                : _BadgeChip(label: profile.skills.length.toString()),
            onTap: () => _openScreen(SkillsScreen(student: student)),
          ),
        ],
      ),
      _MenuSection(
        title: 'Career',
        items: [
          _MenuItemData(
            icon: Icons.folder_shared_outlined,
            title: 'Documents',
            subtitle: 'Upload transcripts & certificates',
            onTap: () => _openScreen(DocumentsScreen(student: student)),
          ),
          _MenuItemData(
            icon: Icons.description_outlined,
            title: 'Generated Resumes',
            subtitle: 'Tailored resumes for employers',
            onTap: () => _openScreen(GeneratedResumesScreen(student: student)),
          ),
          _MenuItemData(
            icon: Icons.workspace_premium_outlined,
            title: 'Followed Companies',
            subtitle: 'Following ${profile.followedCompanies.length} companies',
            trailing: profile.followedCompanies.isEmpty
                ? const Icon(Icons.trending_up, color: _profilePrimaryColor)
                : _BadgeChip(
                    label: profile.followedCompanies.length.toString(),
                  ),
            onTap: () => _openScreen(const FollowedCompaniesPage()),
          ),
        ],
      ),
      _MenuSection(
        title: 'Settings',
        items: [
          _MenuItemData(
            icon: Icons.tune,
            title: 'Preferences',
            subtitle: 'Notifications & privacy',
            onTap: () =>
                _openScreen(SettingsPreferencesScreen(student: student)),
          ),
          _MenuItemData(
            icon: Icons.lock_reset,
            title: 'Change Password',
            subtitle: 'Keep your account secure',
            onTap: () => _openScreen(const ChangePasswordScreen()),
          ),
          _MenuItemData(
            icon: Icons.alternate_email,
            title: 'Change Email',
            subtitle: 'Update your login email',
            onTap: () =>
                _openScreen(ChangeEmailScreen(currentEmail: profile.email)),
          ),
          _MenuItemData(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of this device',
            iconColor: Colors.red,
            titleColor: Colors.red,
            onTap: () async {
              _showLogoutDialog();
            },
          ),
        ],
      ),
    ];

    return [
      Container(
        decoration: BoxDecoration(
          color: _profileCardColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _withAlpha(_profileTextColor, 0.07),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 6),
          child: Column(
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 18),
                    child: Divider(
                      height: 1,
                      thickness: 0.7,
                      indent: 24,
                      endIndent: 24,
                      color: _withAlpha(_profileTextColor, 0.08),
                    ),
                  ),
                _SectionHeader(title: sections[i].title),
                ..._buildSectionTiles(sections[i]),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSectionTiles(_MenuSection section) {
    final tiles = <Widget>[];
    for (var i = 0; i < section.items.length; i++) {
      tiles.add(_buildMenuListTile(section.items[i]));
      if (i != section.items.length - 1) {
        tiles.add(
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 68,
            endIndent: 20,
            color: _withAlpha(_profileTextColor, 0.06),
          ),
        );
      }
    }
    return tiles;
  }

  Widget _buildMenuListTile(_MenuItemData item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withOpacity(0.88)],
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _withAlpha(item.iconColor ?? _profilePrimaryColor, 0.22),
                _withAlpha(item.iconColor ?? _profilePrimaryColor, 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            item.icon,
            color: item.iconColor ?? _profilePrimaryColor,
            size: 20,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: item.titleColor ?? _profileTextColor,
          ),
        ),
        subtitle: item.subtitle != null
            ? Text(
                item.subtitle!,
                style: TextStyle(
                  color: _withAlpha(_profileTextColor, 0.6),
                  fontSize: 13,
                ),
              )
            : null,
        trailing:
            item.trailing ??
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _withAlpha(_profilePrimaryColor, 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_right,
                size: 18,
                color: _profilePrimaryColor,
              ),
            ),
        onTap: () => item.onTap(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Scaffold _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: _profileBackgroundColor,
      appBar: _buildAppBar(onGradient: false),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _profilePrimaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _profileTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _buildMissingProfileScaffold() {
    return Scaffold(
      backgroundColor: _profileBackgroundColor,
      appBar: _buildAppBar(onGradient: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: _withAlpha(_profileTextColor, 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile data not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _profileTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try refreshing or contact support',
              style: TextStyle(
                fontSize: 14,
                color: _withAlpha(_profileTextColor, 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadProfile(showSpinner: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _profilePrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: _profileCardColor,
        boxShadow: [
          BoxShadow(
            color: _withAlpha(_profileTextColor, 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
            spreadRadius: -2,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: _profilePrimaryColor,
          unselectedItemColor: _withAlpha(_profileTextColor, 0.5),
          selectedFontSize: 12,
          unselectedFontSize: 11,
          iconSize: 22,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Companies',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'Jobs',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _onNavigationTap(int index) {
    if (!mounted) return;
    if (_currentIndex == index) {
      if (index == 3) {
        _showInfoMessage('Already on profile page');
      }
      return;
    }

    setState(() => _currentIndex = index);

    const placeholders = [
      'Home page coming soon!',
      'Companies page coming soon!',
      'Jobs page coming soon!',
      null,
      'Settings page coming soon!',
    ];

    final message = placeholders[index];
    if (message != null) {
      _showInfoMessage(message);
    }
  }

  Future<void> _openScreen(Widget page) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (result == true) {
      await _loadProfile(showSpinner: false);
    }
  }
}

double _calculateProfileCompletion(_ProfileUiModel profile) {
  final checks = <bool>[
    profile.profilePictureUrl != null,
    profile.phoneNumber != null,
    profile.location != null,
    profile.shortSummary != null,
    profile.university.isNotEmpty,
    profile.major.isNotEmpty,
    profile.level != null,
    profile.gpa != null,
    profile.graduationDate != null,
    profile.skills.isNotEmpty,
  ];
  if (checks.isEmpty) {
    return 1;
  }
  final completed = checks.where((element) => element).length;
  return completed / checks.length;
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Future<void> Function() onTap;
  final Color? iconColor;
  final Color? titleColor;
}

class _MenuSection {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItemData> items;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_profileSecondaryColor, _profileAccentColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
              color: _profileTextColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_profileSecondaryColor, _profileAccentColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _profileAccentColor.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _profileSurfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _profilePrimaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _profilePrimaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: _profileTextColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_profileSecondaryColor, _profileAccentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _profileAccentColor.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileUiModel {
  final String fullName;
  final String email;
  final String? username;
  final String? phoneNumber;
  final String university;
  final String major;
  final String? level;
  final String? gpa;
  final String? graduationDate;
  final List<String> skills;
  final String? shortSummary;
  final String? profilePictureUrl;
  final List<String> followedCompanies;
  final String? location;

  const _ProfileUiModel({
    required this.fullName,
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.university,
    required this.major,
    required this.level,
    required this.gpa,
    required this.graduationDate,
    required this.skills,
    required this.shortSummary,
    required this.profilePictureUrl,
    required this.followedCompanies,
    required this.location,
  });

  factory _ProfileUiModel.fromStudent(Student student) {
    String? safePhone = student.phoneNumber.trim().isEmpty
        ? null
        : student.phoneNumber.trim();
    return _ProfileUiModel(
      fullName: '${student.firstName} ${student.lastName}'.trim(),
      email: student.email,
      username: student.username.trim().isEmpty
          ? null
          : student.username.trim(),
      phoneNumber: safePhone,
      university: student.university,
      major: student.major,
      level: _emptyToNull(student.level),
      gpa: student.gpa?.toStringAsFixed(2),
      graduationDate: _emptyToNull(student.expectedGraduationDate),
      skills: student.skills.where((skill) => skill.trim().isNotEmpty).toList(),
      shortSummary: _emptyToNull(student.shortSummary),
      profilePictureUrl: _emptyToNull(student.profilePictureUrl),
      followedCompanies: student.followedCompanies
          .where((company) => company.trim().isNotEmpty)
          .toList(),
      location: _emptyToNull(student.location),
    );
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key, required this.student});

  final Student student;

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _summaryController;

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstNameController = TextEditingController(text: student.firstName);
    _lastNameController = TextEditingController(text: student.lastName);
    _usernameController = TextEditingController(text: student.username);
    _phoneController = TextEditingController(text: student.phoneNumber);
    _locationController = TextEditingController(text: student.location ?? '');
    _summaryController = TextEditingController(
      text: student.shortSummary ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _previewBytes = bytes;
      });
    }
  }

  Future<String?> _uploadProfilePicture(String uid, XFile file) async {
    final firebase_storage.Reference
    ref = firebase_storage.FirebaseStorage.instance.ref().child(
      'students/$uid/profile/profile_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );

    final bytes = await file.readAsBytes();
    await ref.putData(
      bytes,
      firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      final trimmedUsername = _usernameController.text.trim();
      if (trimmedUsername.isEmpty) {
        throw Exception('Username cannot be empty.');
      }

      if (trimmedUsername != widget.student.username) {
        final unique = await _authService.isUsernameUnique(trimmedUsername);
        if (!unique) {
          throw Exception('This username is already taken.');
        }
      }

      String? profileUrl = widget.student.profilePictureUrl;
      if (_pickedImage != null) {
        profileUrl = await _uploadProfilePicture(user.uid, _pickedImage!);
      }

      final updated = widget.student.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: trimmedUsername,
        phoneNumber: _phoneController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        shortSummary: _summaryController.text.trim().isEmpty
            ? null
            : _summaryController.text.trim(),
        profilePictureUrl: profileUrl,
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? backgroundImage;
    if (_previewBytes != null) {
      backgroundImage = MemoryImage(_previewBytes!);
    } else if (widget.student.profilePictureUrl != null) {
      backgroundImage = NetworkImage(widget.student.profilePictureUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: backgroundImage,
                      backgroundColor: Colors.grey[200],
                      child: backgroundImage == null
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: _profilePrimaryColor,
                        fixedSize: const Size(36, 36),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(labelText: 'Short Summary'),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AcademicInfoScreen extends StatefulWidget {
  const AcademicInfoScreen({super.key, required this.student});

  final Student student;

  @override
  State<AcademicInfoScreen> createState() => _AcademicInfoScreenState();
}

class _AcademicInfoScreenState extends State<AcademicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  late TextEditingController _universityController;
  late TextEditingController _majorController;
  late TextEditingController _levelController;
  late TextEditingController _gpaController;
  late TextEditingController _graduationController;

  bool _saving = false;
  bool _loadingLists = true;
  List<String> _universities = [];
  List<String> _majors = [];

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _universityController = TextEditingController(text: student.university);
    _majorController = TextEditingController(text: student.major);
    _levelController = TextEditingController(text: student.level ?? '');
    _gpaController = TextEditingController(
      text: student.gpa != null ? student.gpa!.toStringAsFixed(2) : '',
    );
    _graduationController = TextEditingController(
      text: student.expectedGraduationDate ?? '',
    );
    _loadLists();
  }

  @override
  void dispose() {
    _universityController.dispose();
    _majorController.dispose();
    _levelController.dispose();
    _gpaController.dispose();
    _graduationController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    final result = await _authService.getUniversitiesAndMajors();
    if (!mounted) return;
    setState(() {
      _universities = result['universities'] ?? [];
      _majors = result['majors'] ?? [];
      _loadingLists = false;
    });
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      suffixIcon: _loadingLists
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      final updated = widget.student.copyWith(
        university: _universityController.text.trim(),
        major: _majorController.text.trim(),
        level: _levelController.text.trim().isEmpty
            ? null
            : _levelController.text.trim(),
        expectedGraduationDate: _graduationController.text.trim().isEmpty
            ? null
            : _graduationController.text.trim(),
        gpa: _gpaController.text.trim().isEmpty
            ? null
            : double.tryParse(_gpaController.text.trim()),
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Academic Info')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _universityController,
                decoration: _dropdownDecoration('University'),
                readOnly: _universities.isNotEmpty,
                onTap: _universities.isEmpty
                    ? null
                    : () async {
                        final selection = await showDialog<String>(
                          context: context,
                          builder: (_) => _SelectionDialog(
                            title: 'Select University',
                            options: _universities,
                            selected: _universityController.text.trim(),
                          ),
                        );
                        if (selection != null) {
                          _universityController.text = selection;
                        }
                      },
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _majorController,
                decoration: _dropdownDecoration('Major'),
                readOnly: _majors.isNotEmpty,
                onTap: _majors.isEmpty
                    ? null
                    : () async {
                        final selection = await showDialog<String>(
                          context: context,
                          builder: (_) => _SelectionDialog(
                            title: 'Select Major',
                            options: _majors,
                            selected: _majorController.text.trim(),
                          ),
                        );
                        if (selection != null) {
                          _majorController.text = selection;
                        }
                      },
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _levelController,
                decoration: const InputDecoration(labelText: 'Level'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gpaController,
                decoration: const InputDecoration(labelText: 'GPA'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final gpa = double.tryParse(value.trim());
                  if (gpa == null || gpa < 0 || gpa > 4.0) {
                    return 'Enter a GPA between 0.0 and 4.0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _graduationController,
                decoration: const InputDecoration(
                  labelText: 'Expected Graduation (e.g., May 2026)',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key, required this.student});

  final Student student;

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final AuthService _authService = AuthService();
  late List<String> _skills;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _skills = List<String>.from(widget.student.skills);
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      final updated = widget.student.copyWith(
        skills: List<String>.from(_skills),
      );
      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skills updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addSkill() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Skill name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _skills.add(result));
    }
  }

  Future<void> _editSkill(int index) async {
    final controller = TextEditingController(text: _skills[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Skill'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Skill name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _skills[index] = result);
    }
  }

  Future<void> _removeSkill(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Skill'),
        content: Text('Are you sure you want to remove "${_skills[index]}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _skills.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Skills'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _persist,
            child: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSkill,
        child: const Icon(Icons.add),
      ),
      body: _skills.isEmpty
          ? const Center(child: Text('No skills added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _skills.length,
              itemBuilder: (context, index) {
                final skill = _skills[index];
                return Card(
                  child: ListTile(
                    title: Text(skill),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editSkill(index);
                        } else if (value == 'remove') {
                          _removeSkill(index);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'remove', child: Text('Remove')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FollowedCompaniesScreen extends StatefulWidget {
  const FollowedCompaniesScreen({super.key, required this.student});

  final Student student;

  @override
  State<FollowedCompaniesScreen> createState() =>
      _FollowedCompaniesScreenState();
}

class _FollowedCompaniesScreenState extends State<FollowedCompaniesScreen> {
  final AuthService _authService = AuthService();
  late List<String> _companies;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companies = List<String>.from(widget.student.followedCompanies);
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }
      final updated = widget.student.copyWith(
        followedCompanies: List<String>.from(_companies),
      );
      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _removeCompany(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unfollow Company'),
        content: Text('Stop following "${_companies[index]}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _companies.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Followed Companies'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _persist,
            child: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _companies.isEmpty
          ? const Center(
              child: Text('You are not following any companies yet.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _companies.length,
              itemBuilder: (context, index) {
                final company = _companies[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade100,
                    child: Text(company[0].toUpperCase()),
                  ),
                  title: Text(company),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeCompany(index),
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(),
            ),
    );
  }
}

// --- DocumentsScreen has been moved to studentEditProfile.dart to support groups ---

class GeneratedResumesScreen extends StatefulWidget {
  const GeneratedResumesScreen({super.key, required this.student});

  final Student student;

  @override
  State<GeneratedResumesScreen> createState() => _GeneratedResumesScreenState();
}

class _GeneratedResumesScreenState extends State<GeneratedResumesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;

  bool _loading = false;
  bool _changed = false;
  List<_StoredFile> _resumes = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadResumes());
  }

  Future<void> _loadResumes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    final snapshot = await _firestore
        .collection(AuthService.kStudentCol)
        .doc(user.uid)
        .collection('resumes')
        .orderBy('uploadedAt', descending: true)
        .get();
    final items = snapshot.docs
        .map(
          (doc) => _StoredFile(
            id: doc.id,
            name: doc['name'] as String? ?? 'Resume',
            url: doc['url'] as String,
            storagePath: doc['storagePath'] as String,
            uploadedAt: (doc['uploadedAt'] as Timestamp?)?.toDate(),
          ),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _resumes = items;
      _loading = false;
    });
  }

  Future<void> _uploadResume() async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;

    final file = result.files.single;
    if (file.bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to read the selected file.')),
      );
      return;
    }

    final path =
        'students/${user.uid}/resumes/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    setState(() => _loading = true);
    try {
      final ref = _storage.ref().child(path);
      await ref.putData(
        file.bytes!,
        firebase_storage.SettableMetadata(
          contentType: 'application/octet-stream',
        ),
      );
      final url = await ref.getDownloadURL();

      await _firestore
          .collection(AuthService.kStudentCol)
          .doc(user.uid)
          .collection('resumes')
          .add({
            'name': file.name,
            'url': url,
            'storagePath': path,
            'uploadedAt': FieldValue.serverTimestamp(),
          });

      _changed = true;
      await _loadResumes();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Resume uploaded.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _deleteResume(_StoredFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Resume'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _storage.ref(file.storagePath).delete();
      await _firestore
          .collection(AuthService.kStudentCol)
          .doc(user.uid)
          .collection('resumes')
          .doc(file.id)
          .delete();
      _changed = true;
      await _loadResumes();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Resume deleted.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_changed);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Generated Resumes')),
        floatingActionButton: FloatingActionButton(
          onPressed: _uploadResume,
          child: const Icon(Icons.upload),
        ),
        body: RefreshIndicator(
          onRefresh: _loadResumes,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _resumes.isEmpty
              ? ListView(
                  children: [
                    SizedBox(height: 220),
                    Center(child: Text('No resumes uploaded yet.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _resumes.length,
                  itemBuilder: (context, index) {
                    final resume = _resumes[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF1F3F4),
                        child: Icon(Icons.description, color: Colors.black87),
                      ),
                      title: Text(resume.name),
                      subtitle: Text(
                        resume.uploadedAt != null
                            ? 'Uploaded ${resume.uploadedAt}'
                            : 'Awaiting upload timestamp',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteResume(resume),
                      ),
                      onTap: () => _openLink(resume.url),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                ),
        ),
      ),
    );
  }

  void _openLink(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Open $url in browser. (Integrate url_launcher as needed)',
        ),
      ),
    );
  }
}

class SettingsPreferencesScreen extends StatefulWidget {
  const SettingsPreferencesScreen({super.key, required this.student});

  final Student student;

  @override
  State<SettingsPreferencesScreen> createState() =>
      _SettingsPreferencesScreenState();
}

class _SettingsPreferencesScreenState extends State<SettingsPreferencesScreen> {
  final AuthService _authService = AuthService();
  late bool _resumePublic;
  late bool _documentsPublic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resumePublic = widget.student.resumeVisibility == 'public';
    _documentsPublic = widget.student.documentsVisibility == 'public';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      final updated = widget.student.copyWith(
        resumeVisibility: _resumePublic ? 'public' : 'private',
        documentsVisibility: _documentsPublic ? 'public' : 'private',
      );

      await _authService.updateStudent(user.uid, updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Settings & Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            value: _resumePublic,
            title: const Text('Public Resumes'),
            subtitle: const Text(
              'Allow companies to view your generated resumes.',
            ),
            onChanged: (value) => setState(() => _resumePublic = value),
          ),
          SwitchListTile(
            value: _documentsPublic,
            title: const Text('Public Documents'),
            subtitle: const Text('Allow companies to view uploaded documents.'),
            onChanged: (value) => setState(() => _documentsPublic = value),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _submitting = false;
  bool _sendingReset = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _authService.updateStudentPassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _sendResetEmail() async {
    if (_sendingReset) return;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email is associated with this account.'),
        ),
      );
      return;
    }

    setState(() => _sendingReset = true);
    try {
      await _authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset link sent to $email.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _sendingReset = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) => (value == null || value.length < 6)
                    ? 'Minimum 6 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                validator: (value) => (value != _newPasswordController.text)
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Password'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _sendingReset ? null : _sendResetEmail,
                icon: _sendingReset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.email_outlined),
                label: Text(
                  _sendingReset
                      ? 'Sending reset email...'
                      : 'Email me a reset link',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key, required this.currentEmail});

  final String currentEmail;

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  //
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _authService.updateStudentEmail(
        password: _passwordController.text,
        newEmail: _emailController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email updated. Please verify the new address.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Change Email')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'New Email'),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your password'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDialog extends StatelessWidget {
  const _SelectionDialog({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (_, index) {
            final option = options[index];
            return ListTile(
              title: Text(option),
              trailing: option == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(option),
            );
          },
        ),
      ),
    );
  }
}

class _StoredFile {
  const _StoredFile({
    required this.id,
    required this.name,
    required this.url,
    required this.storagePath,
    required this.uploadedAt,
  });

  final String id;
  final String name;
  final String url;
  final String storagePath;
  final DateTime? uploadedAt;
}
