import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/authService.dart';
//import 'editProfilePage.dart'; // Create this page later for editing profiles

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({Key? key}) : super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final AuthService _authService = AuthService();
  Student? _student;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Fetch the current student's data from Firestore via AuthService
      // This should return a Student object
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pop(); // Return to login screen
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final student = _student;
    if (student == null) {
      return const Center(child: Text('Profile data not found.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: student.profilePictureUrl != null
                      ? NetworkImage(student.profilePictureUrl!)
                      : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student.firstName} ${student.lastName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '@${student.username}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // Navigate to edit profile page
                    // Navigator.push(
                    //context,
                    //MaterialPageRoute(
                    //  builder: (context) => const EditProfilePage(),
                    // ),
                    //);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Academic info card
            Card(
              child: ListTile(
                title: const Text('Academic Information'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('University: ${student.university}'),
                    Text('Major: ${student.major}'),
                    if (student.level != null && student.level!.isNotEmpty)
                      Text('Level: ${student.level}'),
                    if (student.expectedGraduationDate != null)
                      Text('Graduation: ${student.expectedGraduationDate}'),
                    if (student.gpa != null) Text('GPA: ${student.gpa}'),
                  ],
                ),
              ),
            ),

            // Contact info card
            Card(
              child: ListTile(
                title: const Text('Contact Information'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${student.email}'),
                    Text('Phone: ${student.phoneNumber}'),
                  ],
                ),
              ),
            ),

            // Skills card
            Card(
              child: ListTile(
                title: const Text('Skills'),
                subtitle: Wrap(
                  spacing: 8.0,
                  children: [
                    for (var skill in student.skills)
                      Chip(label: Text(skill.toString())),
                  ],
                ),
              ),
            ),

            // Experience/badges section (optional)
            if (student.followedCompanies.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Followed Companies',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: [
                  for (var company in student.followedCompanies)
                    Chip(label: Text(company.toString())),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
