import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _purple = Color(0xFF422F5D);
const _pink = Color(0xFFD64483);

class StudentSingleProfilePage extends StatelessWidget {
  const StudentSingleProfilePage({super.key, required this.studentId});
  final String studentId;

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchStudent() {
    return FirebaseFirestore.instance.collection('student').doc(studentId).get();
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: _purple),
      title: Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(value.isNotEmpty ? value : 'Not specified', style: GoogleFonts.lato()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _fetchStudent(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists || snap.data!.data() == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.white, foregroundColor: _purple),
            body: Center(child: Text('Student not found', style: GoogleFonts.lato())),
          );
        }

        final data = snap.data!.data()!;
        final firstName = (data['firstName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final fullName = ('$firstName $lastName').trim().isEmpty ? 'Student' : ('$firstName $lastName').trim();
        final major = (data['major'] ?? '').toString();
        final degree = (data['degree'] ?? '').toString();
        final university = (data['university'] ?? '').toString();
        final year = (data['year'] ?? '').toString();
        final bio = (data['bio'] ?? data['about'] ?? '').toString();
        final photo = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _purple,
            elevation: 0,
            title: Text(fullName, style: GoogleFonts.lato(color: _purple)),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_purple, _pink], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.white,
                      child: (photo.isNotEmpty)
                          ? CircleAvatar(radius: 52, backgroundImage: CachedNetworkImageProvider(photo))
                          : CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.white,
                              child: Text(
                                fullName.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase(),
                                style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w800, color: _purple),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          if (major.isNotEmpty || degree.isNotEmpty)
                            Text(
                              [degree, major].where((s) => s.isNotEmpty).join(' • '),
                              style: GoogleFonts.lato(color: Colors.grey.shade700),
                            ),
                          if (university.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(university, style: GoogleFonts.lato(color: Colors.grey.shade700)),
                          ],
                          const SizedBox(height: 12),
                          if (bio.isNotEmpty)
                            Text(bio, style: GoogleFonts.lato(height: 1.4)),
                          const SizedBox(height: 12),
                          const Divider(),
                          _infoTile(Icons.school_outlined, 'Degree', degree),
                          _infoTile(Icons.work_outline, 'Major', major),
                          _infoTile(Icons.location_on_outlined, 'University / Year', [university, year].where((s)=>s.isNotEmpty).join(' • ')),
                          if (email.isNotEmpty) _infoTile(Icons.email_outlined, 'Email', email),
                          if (phone.isNotEmpty) _infoTile(Icons.phone_outlined, 'Phone', phone),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}