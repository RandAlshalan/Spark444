import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company.dart';
// --- (1) إضافة Import للسيرفس ---
import '../services/bookmarkService.dart'; 

const _purple = Color(0xFF422F5D);
const _pink = Color(0xFFD64483);
const _chipBg = Color(0xFFEDE7F3);

class StudentCompanyProfilePage extends StatelessWidget {
  const StudentCompanyProfilePage({super.key, required this.companyId});
  final String companyId;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _companyDocStream() {
    return FirebaseFirestore.instance.collection('companies').doc(companyId).snapshots();
  }

  Stream<int> _oppsCountStream() {
    return FirebaseFirestore.instance
        .collection('opportunities')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((s) => s.size);
  }

  Stream<bool> _isFollowingStream(String studentId) {
    return FirebaseFirestore.instance.collection('student').doc(studentId).snapshots().map((d) {
      final data = d.data();
      final list = List<String>.from(data?['followedCompanies'] ?? []);
      return list.contains(companyId);
    });
  }

  Future<void> _toggleFollow({required String studentId, required bool following}) async {
    final ref = FirebaseFirestore.instance.collection('student').doc(studentId);
    await ref.set({
      'followedCompanies': following ? FieldValue.arrayRemove([companyId]) : FieldValue.arrayUnion([companyId]),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final studentId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _companyDocStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists || snap.data!.data() == null) {
          return Scaffold(appBar: AppBar(title: const Text('Company')), body: const Center(child: Text('Company not found')));
        }

        final data = snap.data!.data()!;
        final company = Company.fromMap(snap.data!.id, data);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // -------- Header (taller + big avatar + raised follow btn)
                  Stack(
                    children: [
                      Container(
                        height: 260, // أعلى للهيدر
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_purple, _pink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Avatar XL (radius 60) مع إطار أبيض وظل خفيف
                      Positioned.fill(
                        child: Align(
                          alignment: const Alignment(0, 0.22),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 8))],
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.white,
                              child: (company.logoUrl != null && company.logoUrl!.isNotEmpty)
                                  ? CircleAvatar(radius: 58, backgroundImage: NetworkImage(company.logoUrl!))
                                  : CircleAvatar(
                                      radius: 58,
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        (company.companyName.trim().isEmpty
                                                ? ''
                                                : company.companyName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join())
                                            .toUpperCase(),
                                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _purple),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (studentId != null)
                        Positioned(
                          right: 16,
                          bottom: 72, // رفعت الزر فوق حتى ما يغطي الكارد
                          child: StreamBuilder<bool>(
                            stream: _isFollowingStream(studentId),
                            builder: (context, s) {
                              final following = s.data ?? false;
                              return OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                ),
                                onPressed: () async {
                                  try {
                                    await _toggleFollow(studentId: studentId, following: following);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                    }
                                  }
                                },
                                child: Text(following ? 'Following' : 'Follow'),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  // -------- Card (centered tabs)
                  Container(
                    transform: Matrix4.translationValues(0, -36, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      elevation: 0,
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(company.companyName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            if (company.sector.isNotEmpty)
                              Text(company.sector, style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 14)),
                            const SizedBox(height: 10),
                            if ((company.description ?? '').isNotEmpty)
                              Text(company.description!, style: TextStyle(color: Colors.black.withOpacity(0.75), height: 1.4)),
                            const SizedBox(height: 16),

                            StreamBuilder<int>(
                              stream: _oppsCountStream(),
                              builder: (context, oppCountSnap) {
                                final oppCount = oppCountSnap.data ?? 0;
                                final reviewsCount = company.studentReviews.length;
                                return Center(
                                  child: TabBar(
                                    isScrollable: true, // <-- الحل لمشكلة ضيق المساحة
                                    labelColor: Colors.black,
                                    unselectedLabelColor: Colors.black.withOpacity(0.5),
                                    indicatorColor: _purple,
                                    indicatorWeight: 3,
                                    dividerColor: Colors.transparent,
                                    tabs: [
                                      const Tab(text: 'Details'),
                                      Tab(text: 'Opportunities ($oppCount)'),
                                      Tab(text: 'Reviews ($reviewsCount)'),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // -------- Tabs
                  Container(
                    height: 700,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBarView(
                      children: [
                        _DetailsTab(company: company, data: data),
                        _OpportunitiesTab(companyId: companyId),
                        _ReviewsTab(reviewCount: company.studentReviews.length),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =================== Details Tab ===================

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.company, required this.data});
  final Company company;
  final Map<String, dynamic> data;

  Future<void> _launchEmail(String email) async {
    if (email.trim().isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchPhone(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _extractEmail(String text) {
    final m = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}').firstMatch(text);
    return (m?.group(0) ?? '').trim();
  }

  String _extractPhone(String text) {
    final m = RegExp(r'(\+?\d[\d\s\-\(\)]{7,})').firstMatch(text);
    return (m?.group(1) ?? '').trim();
  }

  List<String> _detectServices(String description, String sector) {
    final text = (description + ' ' + sector).toLowerCase();
    final map = <String, String>{
      'cloud': 'Cloud & Data Center',
      'data center': 'Cloud & Data Center',
      'security': 'Cybersecurity',
      'cyber': 'Cybersecurity',
      'cybersecurity': 'Cybersecurity',
      'network': 'Networking',
      'networking': 'Networking',
      'iot': 'IoT / Edge Computing',
      'edge': 'IoT / Edge Computing',
      'managed services': 'Managed Services',
      'consult': 'Consulting',
      'ai': 'AI',
      'machine learning': 'ML',
      'analytics': 'Analytics',
      'infrastructure': 'Infrastructure',
      'software': 'Software',
      'mobile': 'Mobile',
      'web': 'Web',
      'devops': 'DevOps',
      'support': 'Support',
    };
    final out = <String>[];
    for (final k in map.keys) {
      if (text.contains(k)) {
        final label = map[k]!;
        if (!out.contains(label)) out.add(label);
      }
    }
    if (out.isEmpty && sector.trim().isNotEmpty) out.add(sector.trim());
    return out.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final about = (company.description ?? '').trim();
    final rawContact = company.contactInfo.trim();

    // EMAIL
    final emailFromFields = (data['contactEmail'] ?? data['email'] ?? company.email).toString().trim();
    final emailFromText = _extractEmail('$rawContact $about');
    final email = emailFromFields.isNotEmpty ? emailFromFields : emailFromText;

    // PHONE
    String phone = (data['phone'] ?? data['contactPhone'] ?? '').toString().trim();
    if (phone.isEmpty) phone = _extractPhone('$rawContact $about');

    // Contact name بدون رقم/إيميل
    var contactName = rawContact;
    if (phone.isNotEmpty) {
      contactName = contactName.replaceAll(phone, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    }
    if (emailFromText.isNotEmpty) {
      contactName = contactName.replaceAll(emailFromText, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    }
    contactName = contactName.replaceAll(RegExp(r'^[\-\•\|,;:()\s]+|[\-\•\|,;:()\s]+$'), '').trim();

    // CORE SERVICES
    List<String> services;
    final raw = data['coreServices'] ?? data['services'] ?? data['core_services'];
    if (raw is Iterable) {
      services = raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    } else if (raw is String) {
      services = raw.split(RegExp(r'[;,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      services = _detectServices(about, company.sector);
    }

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        );

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        sectionTitle('About Us'),
        Text(about.isNotEmpty ? about : 'No description provided.', style: TextStyle(color: Colors.black.withOpacity(0.75), height: 1.45)),
        const Divider(height: 28),

        sectionTitle('Core Services'),
        if (services.isEmpty)
          Text('No services listed.', style: TextStyle(color: Colors.black.withOpacity(0.6)))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: services
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(28)),
                      child: Text(s, style: const TextStyle(color: _purple, fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        const Divider(height: 28),

        sectionTitle('Contact Details'),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined, color: _purple), // رجّعنا الأيقونة
                title: Text(email.isNotEmpty ? 'Email: $email' : 'Email: Not provided'),
                subtitle: contactName.isNotEmpty ? Text(contactName) : null,
                trailing: ElevatedButton(onPressed: email.isEmpty ? null : () => _launchEmail(email), child: const Text('Email')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: _purple), // رجّعنا الأيقونة
                title: Text(phone.isNotEmpty ? 'Phone: $phone' : 'Phone: Not provided'),
                trailing: ElevatedButton(onPressed: phone.isEmpty ? null : () => _launchPhone(phone), child: const Text('Call')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =================== Opportunities Tab (new) ===================

class _OpportunitiesTab extends StatelessWidget {
   _OpportunitiesTab({required this.companyId});
  final String companyId;

  // --- (2) إضافة السيرفس هنا ---
  final BookmarkService _bookmarkService = BookmarkService();

  Stream<QuerySnapshot<Map<String, dynamic>>> _oppsStream() {
    return FirebaseFirestore.instance
        .collection('opportunities')
        .where('companyId', isEqualTo: companyId)
        .snapshots();
  }

  // --- (3) الدالة الجديدة لقراءة حالة الحفظ (تستخدم السيرفس) ---
  Stream<bool> _isBookmarkedStream(String uid, String opportunityId) {
    return _bookmarkService.isBookmarkedStream(
      studentId: uid,
      opportunityId: opportunityId,
    );
  }
  
  // --- (4) الدالة الجديدة لحفظ/حذف (تستخدم السيرفس) ---
  Future<void> _toggleBookmark({
    required String uid,
    required String opportunityId,
    required bool isBookmarked,
    required BuildContext context,
  }) async {
    try {
      if (isBookmarked) {
        await _bookmarkService.removeBookmark(
          studentId: uid,
          opportunityId: opportunityId,
        );
      } else {
        await _bookmarkService.addBookmark(
          studentId: uid,
          opportunityId: opportunityId,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update bookmark: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in to view opportunities.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _oppsStream(),
      builder: (context, oppSnap) {
        if (oppSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final oppDocs = oppSnap.data?.docs ?? [];
        if (oppDocs.isEmpty) {
          return const Center(child: Text('No opportunities yet.'));
        }

        // --- (5) حذف الـ StreamBuilder<Set<String>> الخارجي ---
        // تم نقله لداخل كل عنصر في القائمة
        
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: oppDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final m = oppDocs[i].data();
            final oppId = oppDocs[i].id;
            
            // هذا الكود الذي طلبته لعرض الـ role
            final role =
                (m['role'] ?? m['title'] ?? m['positionTitle'] ?? 'Opportunity').toString();
                
            final companyName = (m['companyName'] ?? '').toString();
            final location = (m['location'] ?? '').toString();
            final modality = (m['modality'] ?? m['workType'] ?? '').toString(); // Remote / In-person ..
            final paid = (m['paid'] ?? m['isPaid'] ?? false) == true;
            final desc = (m['shortDescription'] ?? m['description'] ?? '')
                .toString();

            // --- تم حذف final isBookmarked = bookmarked.contains(oppId); ---

            return Card(
              elevation: 0,
              color: const Color(0xFFF7F1FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان + Bookmark
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // لوجو بسيط مكان الصورة
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.work_outline, color: _purple),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(role, // <-- استخدام متغير role هنا
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (companyName.isNotEmpty)
                                Text(companyName,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                    )),
                            ],
                          ),
                        ),
                        
                        // --- (5) إضافة StreamBuilder هنا حول الـ IconButton ---
                        StreamBuilder<bool>(
                          stream: _isBookmarkedStream(uid, oppId),
                          builder: (context, snapshot) {
                            final isBookmarked = snapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: _purple,
                              ),
                              onPressed: () => _toggleBookmark(
                                uid: uid,
                                opportunityId: oppId,
                                isBookmarked: isBookmarked,
                                context: context,
                              ),
                              tooltip: isBookmarked ? 'Remove' : 'Save',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // وصف مختصر
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.8),
                          height: 1.35,
                        ),
                      ),

                    const SizedBox(height: 12),
                    // Chips (location / modality / paid)
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (location.isNotEmpty)
                          _TagChip(icon: Icons.location_on_outlined, label: location),
                        if (modality.isNotEmpty)
                          _TagChip(icon: Icons.business_center_outlined, label: modality),
                        _TagChip(
                          icon: Icons.attach_money,
                          label: paid ? 'Paid' : 'Unpaid',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Chip بسيط شبيه بالتصميم
class _TagChip extends StatelessWidget {
  const _TagChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
    );
  }
}


// =================== Reviews Tab ===================

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviewCount});
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        reviewCount > 0 ? 'There are $reviewCount reviews (design placeholder).' : 'No reviews yet.',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}