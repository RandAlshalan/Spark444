import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

const _purple = Color(0xFF422F5D);
const _bg = Color(0xFFF7F4F0);
const _cardLilac = Color(0xFFF7ECFF);

class CompanyStudentProfilePage extends StatelessWidget {
  final String studentId;
  const CompanyStudentProfilePage({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student')
          .doc(studentId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(body: Center(child: Text('Student not found')));
        }

        final data = snap.data!.data() as Map<String, dynamic>;

        String fullName =
            (data['fullName'] ??
                    data['name'] ??
                    data['displayName'] ??
                    data['studentName'] ??
                    '')
                .toString()
                .trim();

        final email = (data['email'] ?? '').toString().trim();
        final username = (data['username'] ?? data['userName'] ?? '')
            .toString()
            .trim();

        final phone =
            (data['phoneNumber'] ?? data['phone'] ?? data['mobile'] ?? '')
                .toString()
                .trim();
        final location = (data['location'] ?? data['city'] ?? '')
            .toString()
            .trim();
        final university = (data['university'] ?? data['college'] ?? '')
            .toString()
            .trim();
        final major = (data['major'] ?? data['specialization'] ?? '')
            .toString()
            .trim();
        final photoUrl =
            (data['profilePictureUrl'] ??
                    data['profileImage'] ??
                    data['photoUrl'] ??
                    data['imageUrl'] ??
                    '')
                .toString()
                .trim();

        List<String> skills = [];
        if (data['skills'] is List) {
          skills = (data['skills'] as List)
              .map((e) => e.toString().trim())
              .toList();
        }
        if (fullName.isEmpty) {
          final first = (data['firstName'] ?? '').toString().trim();
          final last = (data['lastName'] ?? '').toString().trim();
          if (first.isNotEmpty || last.isNotEmpty) {
            fullName = [first, last].where((e) => e.isNotEmpty).join(' ');
          }
        }
        final digitsOnly = RegExp(r'^\d+$');
        if ((fullName.isEmpty || digitsOnly.hasMatch(fullName))) {
          if (username.isNotEmpty) {
            fullName = username.startsWith('@')
                ? username.substring(1)
                : username;
          } else if (email.isNotEmpty && email.contains('@')) {
            fullName = email.split('@')[0];
          } else {
            fullName = 'Student';
          }
        }

        return Scaffold(
          backgroundColor: _bg,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // ================= HEADER =================
                Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF5A34B7), Color(0xFFD64483)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 100, 16, 0),
                      padding: const EdgeInsets.fromLTRB(16, 56, 16, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  fullName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _purple,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: _purple,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (username.isNotEmpty)
                            Text(
                              '@${username.replaceFirst("@", "")}',
                              style: TextStyle(
                                color: Colors.black.withOpacity(.5),
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (location.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: _purple,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    location,
                                    style: const TextStyle(
                                      color: _purple,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              if (university.isNotEmpty)
                                const _ProfileChip(
                                  icon: Icons.school_outlined,
                                  label: 'King Saud University',
                                ),
                              if (major.isNotEmpty)
                                _ProfileChip(
                                  icon: Icons.menu_book_outlined,
                                  label: 'Software engineering',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      top: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: _bg,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: _purple,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: _cardLilac,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.person_outline,
                          title: fullName,
                          subtitle: 'Full Name',
                        ),
                        if (username.isNotEmpty)
                          _InfoRow(
                            icon: Icons.tag_outlined,
                            title: '@${username.replaceFirst("@", "")}',
                            subtitle: 'Username',
                          ),
                        if (location.isNotEmpty)
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            title: location,
                            subtitle: 'Location',
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: _cardLilac,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text(
                            'Contact Info',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _purple,
                            ),
                          ),
                        ),
                        if (email.isNotEmpty)
                          _InfoRow(
                            icon: Icons.alternate_email_outlined,
                            title: email,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              color: _purple,
                              fontWeight: FontWeight.w600,
                            ),
                            subtitle: 'Email Address',
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.open_in_new,
                                color: _purple,
                              ),
                              onPressed: () => _launchEmail(email),
                            ),
                          ),

                        if (phone.isNotEmpty)
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            title: phone,
                            subtitle: 'Phone Number',
                            trailing: IconButton(
                              icon: const Icon(Icons.call, color: _purple),
                              onPressed: () => _launchPhone(phone),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // =============== SKILLS ===============
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(.85),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: skills.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'No skills added.',
                            style: TextStyle(
                              color: Colors.black.withOpacity(.5),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills
                              .map(
                                (s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE7F3),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      color: _purple,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),

                const SizedBox(height: 18),

                // =============== APPLICATIONS ===============
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Applications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StudentApplicationsList(studentId: studentId),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// =============== widgets ===============

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ProfileChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE3F5),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _purple),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _purple),
      title: Text(
        title,
        style:
            titleStyle ??
            const TextStyle(fontWeight: FontWeight.w600, color: _purple),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.black.withOpacity(.5)),
      ),
      trailing: trailing,
    );
  }
}

class _StudentApplicationsList extends StatelessWidget {
  final String studentId;
  const _StudentApplicationsList({required this.studentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('studentId', isEqualTo: studentId)
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'No applications yet.',
              style: TextStyle(color: Colors.black.withOpacity(.5)),
            ),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final oppTitle =
                (data['opportunityName'] ?? data['opportunityTitle'] ?? '—')
                    .toString();
            final companyName = (data['companyName'] ?? '').toString();
            final status = (data['status'] ?? 'pending').toString();
            final appliedAt = (data['appliedAt'] as Timestamp?)?.toDate();

            Color statusColor;
            switch (status.toLowerCase()) {
              case 'accepted':
                statusColor = Colors.green;
                break;
              case 'rejected':
                statusColor = Colors.red;
                break;
              default:
                statusColor = _purple;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(Icons.work_outline, color: _purple),
                title: Text(oppTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (companyName.isNotEmpty) Text(companyName),
                    if (appliedAt != null)
                      Text(
                        appliedAt.toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
