// lib/studentScreens/studentCompaniesPage.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/studentScreens/StudentCompanyProfilePage.dart';

import '../services/companyService.dart';
import '../models/company.dart';

// --- NAV BAR IMPORTS START ---
import 'package:google_fonts/google_fonts.dart';
import '../widgets/CustomBottomNavBar.dart';
import '../studentScreens/studentViewProfile.dart';
import '../studentScreens/studentSavedOpp.dart';
import '../studentScreens/studentOppPage.dart';
// --- NAV BAR IMPORTS END ---

const _purple = Color(0xFF422F5D);
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

  // --- NAV BAR STATE START ---
  int _currentIndex = 1; // Companies tab
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
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        _showInfoMessage('Coming soon!');
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const studentOppPgae()),
        );
        break;
      case 3:
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
    final studentDocStream = _db
        .collection(kStudentsCollection)
        .doc(studentId)
        .snapshots(includeMetadataChanges: true);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _modified);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Companies',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined, color: Colors.black),
              onPressed: _navigateToSaved,
              tooltip: 'Saved',
            ),
          ],
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) =>
                    setState(() => _query = v.toLowerCase().trim()),
                decoration: InputDecoration(
                  hintText: 'Search by company name…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.35),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
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
    return ListView.separated(
      itemCount: companies.length,
      separatorBuilder: (ctx, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final c = companies[i];
        final id = c.uid ?? '';

        final isFollowingStream = id.isNotEmpty && followed.contains(id);
        final optimistic = _optimisticFollowing[id];
        final isFollowing = optimistic ?? isFollowingStream;
        final pending = _pendingToggles.contains(id);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
              ? CircleAvatar(backgroundImage: CachedNetworkImageProvider(c.logoUrl!))
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
