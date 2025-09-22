import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/authService.dart';
import 'login.dart'; // Import the login screen
//import 'editProfilePage.dart'; // Import this page when you create it

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({Key? key}) : super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final AuthService _authService = AuthService();
  Student? _student;
  bool _loading = true;

  // Define your color palette as constants for easy reuse
  static const Color primaryColor = Color(0xFF422F5D);
  static const Color secondaryColor = Color(0xFFF99D46);
  static const Color accentColor = Color(0xFFD64483);
  static const Color backgroundColor = Color(0xFFF7F4F0);
  static const Color textColor = Color(0xFF1E1E1E);
  static const Color lightGrey = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final fetchedStudent = await _authService.getCurrentStudent();
      if (mounted) {
        setState(() {
          _student = fetchedStudent;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final student = _student;
    if (student == null) {
      return const Scaffold(body: Center(child: Text('Profile data not found.')));
    }

    // Assign student data to local variables for cleaner code
    final String fullName = '${student.firstName} ${student.lastName}';
    final String email = student.email;
    final String? phoneNumber = student.phoneNumber;
    final String university = student.university;
    final String major = student.major;
    final String? level = student.level;
    final String? gpa = student.gpa?.toStringAsFixed(2);
    final String? graduationDate = student.expectedGraduationDate;
    final List<String> skills = student.skills;
    final String? shortSummary = student.shortSummary;
    final String? profilePictureUrl = student.profilePictureUrl;
    final List<String> followedCompanies = student.followedCompanies;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: textColor), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                              ? NetworkImage(profilePictureUrl)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: lightGrey,
                                ),
                              ),
                              if (phoneNumber != null && phoneNumber.isNotEmpty)
                                Text(
                                  phoneNumber,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: lightGrey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [secondaryColor, accentColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to EditProfilePage
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Edit Profile Page Coming Soon!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // My Information Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    _buildInfoRow('University', university),
                    _buildInfoRow('Major', major),
                    if (level != null && level.isNotEmpty) _buildInfoRow('Level', level),
                    if (gpa != null && gpa.isNotEmpty) _buildInfoRow('GPA', gpa),
                    if (graduationDate != null && graduationDate.isNotEmpty)
                      _buildInfoRow('Graduation', graduationDate),
                  ],
                ),
              ),
            ),

            // Skills Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: skills.map((skill) => _buildSkillChip(skill)).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Followed Companies Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Followed Companies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: followedCompanies.isEmpty
                          ? [
                              Text(
                                'You are not following any companies yet.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ]
                          : followedCompanies.map((company) {
                              return Chip(
                                label: Text(
                                  company,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                backgroundColor: primaryColor, // Using one of the theme colors
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              );
                            }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Short Summary Card
            if (shortSummary != null && shortSummary.isNotEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Short Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    Text(
                      shortSummary,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),

            // Documents Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    Row(
                      children: [
                        _buildDocumentItem('Supporting Documents.pdf', Icons.picture_as_pdf),
                        const SizedBox(width: 10),
                        _buildDocumentItem('Cover Letter - Tech Firm.pdf', Icons.insert_drive_file),
                      ],
                    ),
                    const SizedBox(height: 10),
                     Row(
                      children: [
                        _buildDocumentItem('AWS Certificate.png', Icons.image),
                        const SizedBox(width: 10),
                        _buildDocumentItem('Capstone Report.pdf', Icons.picture_as_pdf),
                        const SizedBox(width: 10),
                        _buildAddDocumentButton(), // Add document button
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Generated Resumes
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generated Resumes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    Row(
                      children: [
                        _buildResumeGeneratorButton('Google', 'assets/google_logo.png'),
                        const SizedBox(width: 10),
                        _buildResumeGeneratorButton('Microsoft', 'assets/microsoft_logo.png'),
                        // Add more buttons for other platforms
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Delete Account Button
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  // TODO: Implement delete account functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete Account Functionality Coming Soon!')),
                  );
                },
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper function to build an info row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build a skill chip
  Widget _buildSkillChip(String skill) {
    return Chip(
      label: Text(
        skill,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      backgroundColor: secondaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // Helper function to build a document item
  Widget _buildDocumentItem(String fileName, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.grey[700]),
            const SizedBox(height: 5),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build an add document button
  Widget _buildAddDocumentButton() {
    return Expanded(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Document functionality coming soon!')),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[400]!),
          ),
          child: Column(
            children: [
              Icon(Icons.add, size: 30, color: Colors.grey[700]),
              const SizedBox(height: 5),
              Text(
                'Add Document',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to build a resume generator button
  Widget _buildResumeGeneratorButton(String platformName, String? logoAssetPath) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generate resume for $platformName coming soon!')),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (logoAssetPath != null)
                Image.asset(
                  logoAssetPath,
                  height: 30,
                  width: 30,
                )
              else
                Icon(Icons.description, size: 30, color: Colors.grey[700]),
              const SizedBox(height: 5),
              Text(
                platformName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}