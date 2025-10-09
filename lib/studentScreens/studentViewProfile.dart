// lib/features/profile/screens/profile_view_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../studentScreens/studentCompaniesPage.dart';

import '../../../models/student.dart';
import '../../../services/authService.dart';
import '../models/profile_ui_model.dart'; // Ensure this file exists
import '/studentScreens/studentEditProfile.dart'; // Ensure this file exists
import '../studentScreens/welcomeScreen.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentOppPage.dart';
import 'FollowedCompaniesPage.dart';

<<<<<<< HEAD
=======
// === ADD THIS IMPORT FOR THE NEW APPLICATIONS SCREEN ===
// Make sure the path is correct for your project structure.
import '../studentScreens/studentApplications.dart';

// A placeholder for the login screen to navigate to after logout
>>>>>>> a38869ac3d3b33b5c97e469e0f73dc5540ba532c
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // FIX: Return a real widget, like a Scaffold, to prevent a crash.
    return const Scaffold(
      body: Center(child: Text('You have been logged out.')),
    );
  }
}

// --- Color Constants inspired by Spark Logo ---
const Color _sparkPrimaryPurple = Color(
  0xFF422F5D,
); // Deep Purple from Spark text
const Color _sparkOrange = Color(0xFFF99D46); // Orange from Spark flame
const Color _sparkPink = Color(0xFFD64483); // Pink/Fuchsia from Spark flame
const Color _sparkRed = Color(0xFFCC3333); // Reddish tone from Spark flame

const Color _profileBackgroundColor = Color(
  0xFFF8F9FA,
); // Light background for contrast
const Color _profileTextColor = Color(0xFF1E1E1E); // Dark text for readability
const Color _profileCardColor = Color(0xFFFFFFFF); // White cards
const Color _profileSurfaceColor = Color(
  0xFFEEEAEF,
); // A very light purple/grey for surfaces

/// The main profile page that displays student information.
class StudentViewProfile extends StatefulWidget {
  const StudentViewProfile({super.key});

  @override
  State<StudentViewProfile> createState() => _StudentViewProfileState();
}

// helper model to show company nicely inside the profile page
class _MiniCompany {
  final String id;
  final String name;
  final String sector;
  final String? logoUrl;

  _MiniCompany({
    required this.id,
    required this.name,
    required this.sector,
    this.logoUrl,
  });

  factory _MiniCompany.fromMap(String id, Map<String, dynamic> m) {
    return _MiniCompany(
      id: id,
      name: (m['companyName'] ?? '').toString(),
      sector: (m['sector'] ?? '').toString(),
      logoUrl: m['logoUrl'] as String?,
    );
  }
}

class _StudentViewProfileState extends State<StudentViewProfile> {
  final AuthService _authService = AuthService();
  Student? _student;
  bool _loading = true;
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile(showSpinner: true));
  }

  // --- Helper Methods ---
  Color _withAlpha(Color color, double opacity) {
    return color.withOpacity(opacity.clamp(0.0, 1.0));
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
    return '$salutation, $firstName!';
  }

  String _buildProgressPrompt(double completion) {
    if (completion >= 0.9)
      return 'You are almost career ready. Keep inspiring!';
    if (completion >= 0.7)
      return 'A few final touches will make your profile shine.';
    if (completion >= 0.4)
      return 'Let\'s add more accomplishments to boost your visibility.';
    return 'Start building your journey - complete your profile today.';
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
    if (checks.isEmpty) return 1;
    final completed = checks.where((element) => element).length;
    return completed / checks.length;
  }

  // --- Data & Navigation Logic ---
  Future<void> _loadProfile({bool showSpinner = false}) async {
    try {
      if (showSpinner) setState(() => _loading = true);
      final fetchedStudent = await _authService.getCurrentStudent();

      if (!mounted) return; // Fix: Check if widget is still mounted

      setState(() {
        _student = fetchedStudent;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (!mounted) return; // Fix: Check if widget is still mounted
      setState(() => _loading = false);
      _showInfoMessage('Error loading profile. Please try again.');
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return; // Check if widget is still mounted

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _showLogoutDialog() {
    if (!mounted) return; // Fix: Check if widget is still mounted
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.lato()),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.lato(),
        ),
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
              backgroundColor: _sparkRed,
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
    if (!mounted) return; // Fix: Check if widget is still mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: _sparkPrimaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onNavigationTap(int index) {
    if (!mounted) return;
    if (_currentIndex == index) {
      // Profile is still at index 3
      if (index == 3) {
        _showInfoMessage('Already on profile page');
      }
      return;
    }
    switch (index) {
      case 0: // Home
        _showInfoMessage('Home page coming soon!');
        // When ready:
        // Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
        break;
      case 1: // Companies
        _openScreen(const StudentCompaniesPage());
        break;

      case 2: // Opportunities
        // Navigate to your existing OpportunitiesPage
        // Fix: 'S' is uppercase
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => studentOppPgae()),
        );
        break;
      case 3: // Profile
        // This is the current page, so we don't need to do anything.
        // The check at the top of the function already handles this.
        break;
    }
  }

  Future<void> _openScreen(Widget page) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));

    if (!mounted)
      return; // Fix: Check if widget is still mounted after navigation

    if (result == true) {
      await _loadProfile(showSpinner: false);
    }
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingScaffold();

    final student = _student;
    if (student == null) return _buildMissingProfileScaffold();

    final profile = _ProfileUiModel.fromStudent(student);
    final mediaQuery = MediaQuery.of(context);
    final double headerContentTopPadding =
        mediaQuery.padding.top + (kToolbarHeight / 2.5) + 24;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _profileBackgroundColor,
      appBar: _buildAppBar(onGradient: true),
      body: RefreshIndicator(
        onRefresh: () => _loadProfile(showSpinner: false),
        color: _sparkPrimaryPurple,
        edgeOffset: headerContentTopPadding,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderSection(profile, student, headerContentTopPadding),
              const SizedBox(
                height: 213,
              ), // Increased by 113 pixels to accommodate moved card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._buildMenuContent(student, profile),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // --- UI Builder Methods ---

  PreferredSizeWidget _buildAppBar({bool onGradient = false}) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: onGradient
          ? Colors.transparent
          : _profileBackgroundColor,
      elevation: 0,
      foregroundColor: onGradient ? Colors.white : _profileTextColor,
      systemOverlayStyle: onGradient
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      title: Text(
        'My Profile',
        style: GoogleFonts.lato(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }

  Widget _buildHeaderSection(
    _ProfileUiModel profile,
    Student student,
    double topPadding,
  ) {
    final completion = _calculateProfileCompletion(profile).clamp(0.0, 1.0);
    final mediaSize = MediaQuery.of(context).size;
    final double backgroundHeight = (mediaSize.height * 0.2 + topPadding).clamp(
      topPadding + 180,
      topPadding + 260,
    );
    final greeting = _buildGreeting(profile.fullName);
    final progressPrompt = _buildProgressPrompt(completion);

    return SizedBox(
      height:
          backgroundHeight +
          233, // Increased by 113 pixels to accommodate moved card
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: backgroundHeight,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, 96),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_sparkPrimaryPurple, _sparkPink],
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
                  style: GoogleFonts.lato(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progressPrompt,
                  style: GoogleFonts.lato(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: -149, // Moved down by 113 pixels (3 cm)
            child: _buildProfileSummaryCard(profile, student, completion),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummaryCard(
    _ProfileUiModel profile,
    Student student,
    double completion,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: _profileCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
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
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _sparkPrimaryPurple.withOpacity(0.1),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          colors: [_sparkOrange, _sparkPink],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.srcIn,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _profileCardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 43,
                        backgroundColor: _profileSurfaceColor,
                        backgroundImage: profile.profilePictureUrl != null
                            ? NetworkImage(profile.profilePictureUrl!)
                            : null,
                        child: profile.profilePictureUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: _sparkPrimaryPurple,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Material(
                        color: _sparkPrimaryPurple,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          tooltip: 'Edit photo',
                          onPressed: () => _openScreen(
                            PersonalInformationScreen(student: student),
                          ),
                          icon: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile.fullName,
                  style: GoogleFonts.lato(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _profileTextColor,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (profile.isAcademic)
                Tooltip(
                  message: 'This is a verified academic profile.',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                    ],
                  ),
                )
              else
                Tooltip(
                  message:
                      'Profile not recognized as academic.\nUse your university email to get verified.',
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: _sparkOrange,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (profile.username != null) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: GoogleFonts.lato(
                fontSize: 15,
                color: _profileTextColor.withOpacity(0.6),
              ),
            ),
          ],
          if (profile.shortSummary != null) ...[
            const SizedBox(height: 12),
            Text(
              profile.shortSummary!,
              style: GoogleFonts.lato(
                color: _profileTextColor.withOpacity(0.8),
                height: 1.4,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (profile.location != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: _sparkPrimaryPurple.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  profile.location!,
                  style: GoogleFonts.lato(
                    color: _sparkPrimaryPurple.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.phoneNumber != null)
                _InfoPill(
                  icon: Icons.phone_outlined,
                  label: profile.phoneNumber!,
                ),
              if (profile.university.isNotEmpty)
                _InfoPill(
                  icon: Icons.school_outlined,
                  label: profile.university,
                ),
              if (profile.major.isNotEmpty)
                _InfoPill(icon: Icons.book_outlined, label: profile.major),
            ],
          ),
        ],
      ),
    );
  }

  // --- Static View Builders ---
  Widget _buildPersonalDetailsView(_ProfileUiModel profile) {
    return _InfoCard(
      title: 'Personal Information',
      children: [
        _StyledInfoTile(
          icon: Icons.person_outline,
          label: 'Full Name',
          value: profile.fullName,
        ),
        _StyledInfoTile(
          icon: Icons.alternate_email_outlined,
          label: 'Email Address',
          value: profile.email,
        ),
        _StyledInfoTile(
          icon: Icons.tag,
          label: 'Username',
          value: profile.username != null ? '@${profile.username}' : null,
        ),
        _StyledInfoTile(
          icon: Icons.phone_outlined,
          label: 'Phone Number',
          value: profile.phoneNumber,
        ),
        _StyledInfoTile(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: profile.location,
        ),
        _StyledInfoTile(
          icon: Icons.notes_outlined,
          label: 'Short Summary',
          value: profile.shortSummary,
        ),
      ],
    );
  }

  Widget _buildAcademicInfoView(_ProfileUiModel profile) {
    return _InfoCard(
      title: 'Academic Background',
      children: [
        _StyledInfoTile(
          icon: Icons.school_outlined,
          label: 'University',
          value: profile.university,
        ),
        _StyledInfoTile(
          icon: Icons.book_outlined,
          label: 'Major',
          value: profile.major,
        ),
        _StyledInfoTile(
          icon: Icons.layers_outlined,
          label: 'Level',
          value: profile.level,
        ),
        _StyledInfoTile(
          icon: Icons.star_border_outlined,
          label: 'GPA',
          value: profile.gpa,
        ),
        _StyledInfoTile(
          icon: Icons.calendar_today_outlined,
          label: 'Expected Graduation',
          value: profile.graduationDate,
        ),
      ],
    );
  }

  Widget _buildSkillsView(_ProfileUiModel profile) {
    return _InfoCard(
      title: 'Skills',
      children: [
        if (profile.skills.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No skills have been added yet.')),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: profile.skills
                  .map(
                    (skill) => Chip(
                      label: Text(skill),
                      backgroundColor: _sparkPrimaryPurple.withOpacity(0.1),
                      labelStyle: const TextStyle(
                        color: _sparkPrimaryPurple,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentsView() {
    return _InfoCard(
      title: 'Documents',
      children: [
        ListTile(
          leading: Icon(
            Icons.info_outline,
            color: _profileTextColor.withOpacity(0.6),
          ),
          title: const Text(
            'This section is for managing your uploaded documents like transcripts and certificates.',
          ),
        ),
      ],
    );
  }

  Widget _buildGeneratedResumesView() {
    return _InfoCard(
      title: 'Generated Resumes',
      children: [
        ListTile(
          leading: Icon(
            Icons.info_outline,
            color: _profileTextColor.withOpacity(0.6),
          ),
          title: const Text(
            'Your tailored resumes for different job applications will appear here.',
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuContent(Student student, _ProfileUiModel profile) {
    final sections = [
      _MenuSection(
        title: 'Profile Management',
        items: [
          _MenuItemData(
            icon: Icons.person_outline,
            title: 'Personal Details',
            subtitle: 'Name, contact, photo',
            onTap: () => _openScreen(
              StaticInfoViewerPage(
                title: 'Personal Details',
                content: _buildPersonalDetailsView(profile),
                editingPage: PersonalInformationScreen(student: student),
              ),
            ),
          ),
          _MenuItemData(
            icon: Icons.school_outlined,
            title: 'Academic Info',
            subtitle: 'University, major, GPA',
            onTap: () => _openScreen(
              StaticInfoViewerPage(
                title: 'Academic Info',
                content: _buildAcademicInfoView(profile),
                editingPage: AcademicInfoScreen(student: student),
              ),
            ),
          ),
          _MenuItemData(
            icon: Icons.psychology_outlined,
            title: 'Skills',
            subtitle: 'You have ${profile.skills.length} skills',
            trailing: profile.skills.isEmpty
                ? null
                : _BadgeChip(label: profile.skills.length.toString()),
            onTap: () => _openScreen(
              StaticInfoViewerPage(
                title: 'Skills',
                content: _buildSkillsView(profile),
                editingPage: SkillsScreen(student: student),
              ),
            ),
          ),
        ],
      ),
      _MenuSection(
        title: 'Career',
        items: [
          // =================== NEW MENU ITEM ADDED HERE ===================
          _MenuItemData(
            icon: Icons.article_outlined, // A fitting icon for applications
            title: 'My Applications',
            subtitle: 'Track your submissions and status',
            onTap: () {
              // Ensure your Student model has an 'id' field containing the Firestore document ID.
              if (_student?.id != null) {
                _openScreen(
                  StudentApplicationsScreen(studentId: _student!.id),
                );
              } else {
                // Fallback in case the student ID is not available
                _showInfoMessage('Could not retrieve student profile ID.');
              }
            },
          ),
          // ================================================================
          _MenuItemData(
            icon: Icons.folder_open_outlined,
            title: 'Documents',
            subtitle: 'Upload transcripts & certificates',
            onTap: () => _openScreen(
              StaticInfoViewerPage(
                title: 'Documents',
                content: _buildDocumentsView(),
                editingPage: DocumentsScreen(student: student),
              ),
            ),
          ),
          _MenuItemData(
            icon: Icons.description_outlined,
            title: 'Generated Resumes',
            subtitle: 'Tailored resumes for employers',
            onTap: () => _openScreen(
              StaticInfoViewerPage(
                title: 'Generated Resumes',
                content: _buildGeneratedResumesView(),
                editingPage: GeneratedResumesScreen(student: student),
              ),
            ),
          ),
          _MenuItemData(
            icon: Icons.bookmark_border_outlined,
            title: 'Followed Companies',
            subtitle: 'Following ${profile.followedCompanies.length} companies',
            trailing: profile.followedCompanies.isEmpty
                ? null
                : _BadgeChip(
                    label: profile.followedCompanies.length.toString(),
                  ),
            onTap: () => _openScreen(const FollowedCompaniesPage()),
          ),
        ],
      ),
      _MenuSection(
        title: 'Account',
        items: [
          _MenuItemData(
            icon: Icons.tune_outlined,
            title: 'Preferences',
            subtitle: 'Notifications & privacy',
            onTap: () =>
                _openScreen(SettingsPreferencesScreen(student: student)),
          ),
          _MenuItemData(
            icon: Icons.lock_outline,
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
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Permanently erase your account',
            iconColor: _sparkRed,
            titleColor: _sparkRed,
            onTap: () => _openScreen(const DeleteAccountScreen()),
          ),
          _MenuItemData(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of this device',
            iconColor: _sparkRed,
            titleColor: _sparkRed,
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    ];

    List<Widget> buildSectionTiles(_MenuSection section) {
      final tiles = <Widget>[];
      for (var i = 0; i < section.items.length; i++) {
        tiles.add(_buildMenuListTile(section.items[i]));
      }
      return tiles;
    }

    return [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _SectionHeader(title: sections[i].title),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _profileCardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(children: buildSectionTiles(sections[i])),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildMenuListTile(_MenuItemData item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (item.iconColor ?? _sparkPrimaryPurple).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.icon,
          color: item.iconColor ?? _sparkPrimaryPurple,
          size: 22,
        ),
      ),
      title: Text(
        item.title,
        style: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: item.titleColor ?? _profileTextColor,
        ),
      ),
      subtitle: item.subtitle != null
          ? Text(
              item.subtitle!,
              style: GoogleFonts.lato(
                color: _profileTextColor.withOpacity(0.7),
                fontSize: 13,
              ),
            )
          : null,
      trailing:
          item.trailing ??
          const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: item.onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildBottomNavigationBar() {
    return CustomBottomNavBar(
      currentIndex: _currentIndex,
      onTap: _onNavigationTap,
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
                color: _sparkPrimaryPurple,
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
                backgroundColor: _sparkPrimaryPurple,
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
}

// --- Private Helper Data & Widget Classes for this file ---

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
  final bool isAcademic;

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
    required this.isAcademic,
  });

  factory _ProfileUiModel.fromStudent(Student student) {
    String? safePhone = student.phoneNumber.trim().isEmpty
        ? null
        : student.phoneNumber.trim();
    final email = student.email.toLowerCase();
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
      isAcademic:
          email.endsWith('.edu') ||
          email.contains('.edu.') ||
          email.contains('.ac.'),
    );
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
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
  final void Function() onTap;
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.lato(
          fontSize: 13,
          letterSpacing: 0.8,
          fontWeight: FontWeight.bold,
          color: _profileTextColor.withOpacity(0.6),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_sparkOrange, _sparkPink],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          color: Colors.white,
          fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _profileSurfaceColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _sparkPrimaryPurple),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.lato(
              color: _sparkPrimaryPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// --- REDESIGNED STATIC VIEWER PAGE AND HELPERS ---

class StaticInfoViewerPage extends StatelessWidget {
  final String title;
  final Widget content;
  final Widget editingPage;

  const StaticInfoViewerPage({
    super.key,
    required this.title,
    required this.content,
    required this.editingPage,
  });

  Future<void> _navigateToEdit(BuildContext context) async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => editingPage));

    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _profileBackgroundColor,
      appBar: AppBar(
        backgroundColor: _profileBackgroundColor,
        elevation: 0,
        foregroundColor: _profileTextColor,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          title,
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              tooltip: 'Edit',
              onPressed: () => _navigateToEdit(context),
              icon: const Icon(Icons.edit_outlined),
              color: _sparkPrimaryPurple,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: content,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _sparkPrimaryPurple,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _StyledInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _StyledInfoTile({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.trim();
    if (displayValue == null || displayValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: Icon(icon, color: _profileTextColor.withOpacity(0.6)),
      title: Text(
        displayValue,
        style: GoogleFonts.lato(fontSize: 16, color: _profileTextColor),
      ),
      subtitle: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 13,
          color: _profileTextColor.withOpacity(0.7),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}

// --- 9. Change Email Screen ---

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

// --- Private Helper Widget for this File ---

/// A dialog used by AcademicInfoScreen to select from a list of options.
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