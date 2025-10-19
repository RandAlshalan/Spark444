// lib/studentScreens/studentCompaniesPage.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/studentScreens/StudentCompanyProfilePage.dart';

import '../services/companyService.dart';
import '../models/company.dart';

// --- NAV BAR IMPORTS START ---
// Imports extracted from studentOppPage.dart
import 'package:google_fonts/google_fonts.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentViewProfile.dart';
import '../studentScreens/studentSavedOpp.dart';
import '../studentScreens/studentOppPage.dart'; // For navigating to opportunities
// --- NAV BAR IMPORTS END ---

const _purple = Color(0xFF422F5D);

const String kStudentsCollection = 'student';

class StudentCompaniesPage extends StatefulWidget {
  const StudentCompaniesPage({super.key});

  @override
  State<StudentCompaniesPage> createState() => _StudentCompaniesPageState();
}

class _StudentCompaniesPageState extends State<StudentCompaniesPage> {
  // Original state variables
  final _service = CompanyService();
  final _searchCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final Set<String> _pendingToggles = {};
  final Map<String, bool> _optimisticFollowing = {};
  bool _modified = false;
  String _query = '';

  // --- NAV BAR STATE START ---
  // This page corresponds to index 1 (Companies)
  int _currentIndex = 1;
  // --- NAV BAR STATE END ---

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow({
    required String studentId,
    required String companyId,
    required bool isFollowing,
  }) async {
    try {
      setState(() {
        _pendingToggles.add(companyId);
        _optimisticFollowing[companyId] = !isFollowing;
      });

      await _db.collection(kStudentsCollection).doc(studentId).set({
        'followedCompanies': isFollowing
            ? FieldValue.arrayRemove([companyId])
            : FieldValue.arrayUnion([companyId]),
      }, SetOptions(merge: true));

      _modified = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticFollowing[companyId] = isFollowing;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _pendingToggles.remove(companyId);
        });
      }
    }
  }

  // --- NAV BAR HANDLERS START ---

  void _onNavigationTap(int index) {
    if (index == _currentIndex) return; // Do nothing if same tab is tapped

    switch (index) {
      case 0:
        // This case was a "Coming soon!" message (e.g., Home/Chat)
        _showInfoMessage('Coming soon!');
        break;
      // case 1: (Current Page) - is handled by the initial `if` check.
      case 2:
        // Navigate to Opportunities Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const studentOppPgae()),
        );
        break;
      case 3:
        // Navigate to Profile Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewProfile()),
        );
        break;
    }
  }

  void _navigateToSaved() {
    // Use the existing _auth service to get the current user's ID
    final studentId = _auth.currentUser?.uid;

    if (studentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedstudentOppPgae(studentId: studentId),
        ),
      );
    } else {
      _showInfoMessage("Could not open saved items. User ID not found.");
    }
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato()),
        backgroundColor: const Color(0xFF422F5D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- NAV BAR HANDLERS END ---

  @override
  Widget build(BuildContext context) {
    final studentId = _auth.currentUser?.uid;

    // احتياط: لو ما فيه مستخدم (حالة نادرة)
    if (studentId == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in.')),
      );
    }

    final companiesStream = _service.searchByName(_query);
    final studentDocStream = _db
        .collection(kStudentsCollection)
        .doc(studentId)
        // نقرأ تغييرات الميتاداتا (محلي/أونلاين) لتسريع التحديث
        .snapshots(includeMetadataChanges: true);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _modified); // نرجّع النتيجة
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Companies'),
          leading: BackButton(
            onPressed: () => Navigator.pop(context, _modified),
          ),
          // --- APP BAR ACTION ADDED ---
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: _navigateToSaved,
              tooltip: 'Saved',
            ),
          ],
          // ---
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search by company name…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Company>>(
                stream: companiesStream,
                builder: (context, compSnap) {
                  if (compSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final companies = compSnap.data ?? [];
                  if (companies.isEmpty) {
                    return const Center(child: Text('No companies found.'));
                  }

                  // نقرأ لائحة المتابعات للطالب كستريم واحد
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: studentDocStream,
                    builder: (context, stuSnap) {
                      final data = stuSnap.data?.data();
                      final followed = Set<String>.from(
                        (data?['followedCompanies'] ?? const []) as List,
                      );
                      return _buildList(
                        companies,
                        studentId,
                        followed: followed,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        // --- BOTTOM NAV BAR ADDED ---
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
        ),
        // ---
      ),
    );
  }

  Widget _buildList(
    List<Company> companies,
    String studentId, {
    required Set<String> followed,
  }) {
    return ListView.separated(
      itemCount: companies.length,
      separatorBuilder: (ctx, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final c = companies[i];
        final id = c.uid ?? '';

        // الحالة القادمة من الستريم
        final isFollowingStream = id.isNotEmpty && followed.contains(id);
        // لو عندنا قرار تفاؤلي، يطغى على الستريم مؤقتًا
        final optimistic = _optimisticFollowing[id];
        final isFollowing = optimistic ?? isFollowingStream;

        final pending = _pendingToggles.contains(id);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
              ? CircleAvatar(backgroundImage: NetworkImage(c.logoUrl!))
              : const CircleAvatar(child: Icon(Icons.apartment)),
          title: Text(
            c.companyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (c.sector.isNotEmpty) c.sector,
              if ((c.description ?? '').isNotEmpty) c.description!,
            ].join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (id.isNotEmpty)
                OutlinedButton(
                  onPressed: pending
                      ? null
                      : () => _toggleFollow(
                          studentId: studentId,
                          companyId: id,
                          isFollowing: isFollowing,
                        ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: const StadiumBorder(),
                    foregroundColor: isFollowing ? Colors.white : _purple,
                    backgroundColor: isFollowing ? _purple : Colors.transparent,
                    side: const BorderSide(color: _purple),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: pending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isFollowing ? 'Following' : 'Follow'),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {
            if (id.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Company ID is missing')),
              );
              return;
            }
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => StudentCompanyProfilePage(companyId: id),
              ),
            );
          },
        );
      },
    );
  }
}