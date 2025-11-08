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
        final level = (data['level'] ?? '').toString();
        final university = (data['university'] ?? '').toString();
        final bio = (data['shortSummary'] ?? '').toString();
        final photo = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _purple,
            elevation: 0,
            title: Text('Student Profile', style: GoogleFonts.lato(color: _purple)),
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
                      child: photo.isNotEmpty
                          ? CircleAvatar(
                              radius: 52,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: CachedNetworkImageProvider(photo),
                            )
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800)),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(bio, style: GoogleFonts.lato(height: 1.4, color: Colors.grey.shade700)),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      if (level.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.school_outlined, color: _purple),
                          title: Text('Level', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(level, style: GoogleFonts.lato()),
                        ),
                      if (major.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.work_outline, color: _purple),
                          title: Text('Major', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(major, style: GoogleFonts.lato()),
                        ),
                      if (university.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.location_on_outlined, color: _purple),
                          title: Text('University', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(university, style: GoogleFonts.lato()),
                        ),
                      if (email.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: _purple),
                          title: Text('Email', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(email, style: GoogleFonts.lato()),
                        ),
                      if (phone.isNotEmpty)
                        ListTile(
                          leading: Icon(Icons.phone_outlined, color: _purple),
                          title: Text('Phone', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(phone, style: GoogleFonts.lato()),
                        ),
                    ],
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