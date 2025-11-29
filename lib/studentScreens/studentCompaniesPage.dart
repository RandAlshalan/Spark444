// lib/studentScreens/studentCompaniesPage.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark/studentScreens/StudentCompanyProfilePage.dart';

import '../services/companyService.dart';
import '../models/company.dart';
import '../theme/student_theme.dart';

// --- NAV BAR IMPORTS START ---
import 'package:google_fonts/google_fonts.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentViewProfile.dart';
import '../studentScreens/StudentChatPage.dart';
import '../studentScreens/studentSavedOpp.dart';
import '../studentScreens/studentOppPage.dart';
import '../studentScreens/StudentHomePage.dart';
import '../utils/page_transitions.dart';
// --- NAV BAR IMPORTS END ---

const String kStudentsCollection = 'student';

class StudentCompaniesPage extends StatefulWidget {
  const StudentCompaniesPage({super.key});

  @override
  State<StudentCompaniesPage> createState() => _StudentCompaniesPageState();
}

class _StudentCompaniesPageState extends State<StudentCompaniesPage> {
  final _service = CompanyService();
  final _searchCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final Set<String> _pendingToggles = {};
  final Map<String, bool> _optimisticFollowing = {};
  bool _modified = false;
  String _query = '';
  Set<String> _followedCompanies = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _studentSubscription;

  // --- NAV BAR STATE START ---
  int _currentIndex = 1; // Companies tab
  // --- NAV BAR STATE END ---

  @override
  void initState() {
    super.initState();
    _listenToFollowedCompanies();
  }

  @override
  void dispose() {
    _studentSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _listenToFollowedCompanies() {
    final studentId = _auth.currentUser?.uid;
    if (studentId == null) return;
    _studentSubscription = _db
        .collection(kStudentsCollection)
        .doc(studentId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;
      final newFollowed = Set<String>.from(
        (data['followedCompanies'] ?? const []) as List,
      );
      if (!setEquals(newFollowed, _followedCompanies)) {
        setState(() => _followedCompanies = newFollowed);
      }
    });
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
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          NoTransitionRoute(page: const StudentHomePage()),
        );
        break;
       case 2: 
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StudentChatPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const studentOppPgae()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewProfile()),
        );
        break;
    }
  }

  void _navigateToSaved() {
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

  Future<void> _backfillCompanyNameLowerOnce() async {
    final col = FirebaseFirestore.instance.collection('companies');
    final qs = await col.get();

    int updated = 0;
    for (final d in qs.docs) {
      final data = d.data();
      final name = (data['companyName'] ?? '').toString();
      final hasLower = (data['companyNameLower'] ?? '').toString().isNotEmpty;

      // نتخطى اللي ما له اسم، أو اللي انضاف له الحقل من قبل
      if (name.isEmpty || hasLower) continue;

      await d.reference.set({
        'companyNameLower': name.toLowerCase(),
      }, SetOptions(merge: true));
      updated++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backfill done ✅ (updated $updated companies)')),
    );
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

    if (studentId == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in.')),
      );
    }

    final companiesStream = _service.searchByName(_query);
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _modified);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          centerTitle: true,
          title: Text(
            'Companies',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined, color: Colors.white),
              onPressed: _navigateToSaved,
              tooltip: 'Saved',
            ),
          ],
        ),

        body: Column(
          children: [
            Container(
              color: StudentTheme.cardColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    setState(() => _query = v.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: 'Search by company name…',
                  hintStyle: GoogleFonts.lato(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: StudentTheme.primaryColor),
                  filled: true,
                  fillColor: StudentTheme.surfaceColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(StudentTheme.radiusMD),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(StudentTheme.radiusMD),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(StudentTheme.radiusMD),
                    borderSide: BorderSide(color: StudentTheme.primaryColor, width: 2),
                  ),
                ),
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

                  return _buildList(
                    companies,
                    studentId,
                    followed: _followedCompanies,
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onNavigationTap,
        ),
      ),
    );
  }

  Widget _buildList(
    List<Company> companies,
    String studentId, {
    required Set<String> followed,
  }) {
    return Container(
      color: StudentTheme.backgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: companies.length,
        itemBuilder: (ctx, i) {
        final c = companies[i];
        final id = c.uid ?? '';

        final isFollowingStream = id.isNotEmpty && followed.contains(id);
        final optimistic = _optimisticFollowing[id];
        final isFollowing = optimistic ?? isFollowingStream;
        final pending = _pendingToggles.contains(id);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: StudentTheme.cardDecoration,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
                  ? CircleAvatar(
                      radius: 28,
                      backgroundColor: StudentTheme.primaryColor.withValues(alpha: 0.08),
                      backgroundImage: CachedNetworkImageProvider(c.logoUrl!),
                    )
                  : CircleAvatar(
                      radius: 28,
                      backgroundColor: StudentTheme.primaryColor.withValues(alpha: 0.08),
                      child: Icon(Icons.apartment, color: StudentTheme.primaryColor),
                    ),
            ),
            title: Text(
              c.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: StudentTheme.textColor,
              ),
            ),
            subtitle: c.sector.isEmpty
                ? null
                : Text(
                    c.sector,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: StudentTheme.textColor.withValues(alpha: 0.7),
                    ),
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
                    foregroundColor: isFollowing ? Colors.white : StudentTheme.primaryColor,
                    backgroundColor: isFollowing ? StudentTheme.primaryColor : Colors.transparent,
                    side: BorderSide(color: StudentTheme.primaryColor),
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
          ),
        );
        },
      ),
    );
  }
}
