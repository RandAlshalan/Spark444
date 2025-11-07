import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'StudentCompanyProfilePage.dart';

const _purple = Color(0xFF422F5D);

class StudentMyReviewsPage extends StatefulWidget {
  const StudentMyReviewsPage({super.key});

  @override
  State<StudentMyReviewsPage> createState() => _StudentMyReviewsPageState();
}

class _StudentMyReviewsPageState extends State<StudentMyReviewsPage> {
  String? uid; // resolved student document id (or fallback)
  bool _resolving = true; // true while _initStudentId is running
  final Map<String, String> _companyNameCache = {}; // companyId -> name
  final Map<String, String?> _companyLogoCache = {}; // companyId -> logoUrl (nullable)
  final DateFormat _dateFmt = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _initStudentId();
  }

  Future<void> _initStudentId() async {
    setState(() {
      _resolving = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() {
        uid = null;
        _resolving = false;
      });
      return;
    }

    try {
      // 1) Try a student doc whose id matches the auth uid
      final byId = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
      if (byId.exists) {
        if (mounted) setState(() { uid = byId.id; _resolving = false; });
        return;
      }

      // 2) Try to find by email
      if (user.email != null && user.email!.isNotEmpty) {
        final qEmail = await FirebaseFirestore.instance
            .collection('student')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (qEmail.docs.isNotEmpty) {
          if (mounted) setState(() { uid = qEmail.docs.first.id; _resolving = false; });
          return;
        }
      }

      // 3) Try several common fields that might store the auth uid
      final possibleFields = ['uid', 'userId', 'authId', 'firebaseUid', 'id'];
      for (final field in possibleFields) {
        final q = await FirebaseFirestore.instance
            .collection('student')
            .where(field, isEqualTo: user.uid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          if (mounted) setState(() { uid = q.docs.first.id; _resolving = false; });
          return;
        }
      }

      // 4) Fallback to auth uid (may or may not match review.studentId)
      if (mounted) setState(() { uid = user.uid; _resolving = false; });
    } catch (e) {
      debugPrint('Failed to resolve student id: $e');
      if (mounted) setState(() { uid = null; _resolving = false; });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myReviewsStream() {
    final authUid = FirebaseAuth.instance.currentUser?.uid;

    // If no signed-in user at all -> empty stream
    if (authUid == null) return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();

    // If still resolving, return empty — UI will show a loader.
    if (_resolving) return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();

    // Build IDs to search for (avoid duplicates)
    final ids = <String>{};
    if (uid != null && uid!.isNotEmpty) ids.add(uid!);
    ids.add(authUid);

    final coll = FirebaseFirestore.instance.collection('reviews');

    // Single-id equality is slightly cheaper than whereIn
    if (ids.length == 1) {
      return coll.where('studentId', isEqualTo: ids.first).orderBy('createdAt', descending: true).snapshots();
    } else {
      // 'whereIn' supports up to 10 values — this covers our two-item case.
      return coll.where('studentId', whereIn: ids.toList()).orderBy('createdAt', descending: true).snapshots();
    }
  }

  Future<void> _fetchCompanyMeta(String companyId) async {
    if (companyId.isEmpty) return;
    if (_companyNameCache.containsKey(companyId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      final data = doc.data();
      final name = (data?['companyName'] ?? '').toString();
      final logo = (data?['logoUrl'] ?? null) as String?;
      _companyNameCache[companyId] = name.isNotEmpty ? name : '';
      _companyLogoCache[companyId] = logo;
      if (mounted) setState(() {}); // to refresh visible tiles
    } catch (e) {
      debugPrint('Failed to load company meta $companyId: $e');
    }
  }

  Future<void> _deleteReviewRecursive(String rootId) async {
    // Recursively collect docs to delete and then commit in batches.
    final FirebaseFirestore fs = FirebaseFirestore.instance;
    final toDelete = <DocumentReference>[];
    final queue = <String>[rootId];

    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      final ref = fs.collection('reviews').doc(cur);
      toDelete.add(ref);

      final repliesSnap = await fs.collection('reviews').where('parentId', isEqualTo: cur).get();
      for (final r in repliesSnap.docs) {
        queue.add(r.id);
      }
    }

    // Commit in batches of 400 to be safe (limit 500)
    try {
      const batchLimit = 400;
      for (var i = 0; i < toDelete.length; i += batchLimit) {
        final end = (i + batchLimit).clamp(0, toDelete.length);
        final batch = fs.batch();
        for (var j = i; j < end; j++) {
          batch.delete(toDelete[j]);
        }
        await batch.commit();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _confirmAndDeleteReview(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final id = doc.id;
    final data = doc.data() ?? {};
    final studentIdOnDoc = (data['studentId'] ?? '').toString();
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = (authUid != null) && (studentIdOnDoc.isNotEmpty) && (studentIdOnDoc == authUid || studentIdOnDoc == uid);

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are not authorized to delete this review.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This will also delete replies.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    await _deleteReviewRecursive(id);
  }

  Future<void> _onRefresh() async {
    await _initStudentId();
    // clear caches so refreshed names load if companies updated
    _companyNameCache.clear();
    _companyLogoCache.clear();
    // small delay for UX
    await Future.delayed(const Duration(milliseconds: 250));
  }

  Widget _buildLeading(String companyId, String fallbackTitle) {
    final logo = _companyLogoCache[companyId];
    final name = _companyNameCache[companyId] ?? fallbackTitle;
    if (logo != null && logo.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(logo), backgroundColor: Colors.white);
    }
    final initials = (name.isNotEmpty ? name.split(RegExp(r'\s+')).map((s) => s.isNotEmpty ? s[0] : '').take(2).join() : '').toUpperCase();
    return CircleAvatar(
      backgroundColor: _purple.withOpacity(0.12),
      child: Text(initials.isNotEmpty ? initials : '?', style: GoogleFonts.lato(color: _purple, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Not signed in
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reviews'), backgroundColor: Colors.white, foregroundColor: _purple, elevation: 0),
        body: Center(child: Text('Please sign in to view your reviews.', style: GoogleFonts.lato())),
      );
    }

    // Still resolving student's document id — show loader
    if (_resolving) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reviews'), backgroundColor: Colors.white, foregroundColor: _purple, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: Colors.white,
        foregroundColor: _purple,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () async => _onRefresh(),
            icon: const Icon(Icons.refresh, color: _purple),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _myReviewsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: GoogleFonts.lato()));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('You have not written any reviews yet.', style: GoogleFonts.lato(fontSize: 16))),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data() ?? {};
                final text = (data['reviewText'] ?? '').toString();
                final companyId = (data['companyId'] ?? '').toString();
                final parentId = data['parentId'];
                final createdTs = data['createdAt'] as Timestamp?;
                final created = createdTs?.toDate();
                final rating = (data['rating'] ?? 0);
                // allow displaying up to 300 characters (reviews are limited to 300 elsewhere)
                final snippet = text.length > 300 ? '${text.substring(0, 300)}…' : text;
                final isReply = (parentId != null) && parentId.toString().trim().isNotEmpty;

                // Ensure we have the company meta (async fetch with caching)
                if (companyId.isNotEmpty && !_companyNameCache.containsKey(companyId)) {
                  _fetchCompanyMeta(companyId);
                }

                final companyName = (_companyNameCache[companyId] ?? '').isNotEmpty ? _companyNameCache[companyId]! : (isReply ? 'Reply' : 'Review');

                // Show a small label above every card (Reply for replies, Review for root reviews)
                final labelText = isReply ? 'Reply' : 'Review';
                final labelColor = isReply ? _purple : Colors.grey.shade600;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        labelText,
                        style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor),
                      ),
                    ),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (companyId.isNotEmpty) {
                            // Navigate to company profile page if available
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentCompanyProfilePage(companyId: companyId),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildLeading(companyId, companyName),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(companyName, style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 15))),
                                            // Only show rating for root/main reviews
                                            if (!isReply && rating != null && rating.toString().trim().isNotEmpty)
                                              Row(
                                                children: [
                                                  Icon(Icons.star, size: 16, color: Colors.orange.shade600),
                                                  const SizedBox(width: 4),
                                                  Text(rating.toString(), style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(isReply ? 'Reply' : 'Review', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmAndDeleteReview(d),
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(snippet, style: GoogleFonts.lato()),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Left: created date (if available)
                                  if (created != null)
                                    Text(_dateFmt.format(created), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),

                                  // Right: read-only likes/dislikes counters (icons + numbers)
                                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: d.reference.snapshots(),
                                    builder: (context, voteSnap) {
                                      final map = voteSnap.data?.data() ?? {};
                                      final likes = (map['likesCount'] as num?)?.toInt() ?? 0;
                                      final dislikes = (map['dislikesCount'] as num?)?.toInt() ?? 0;

                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.thumb_up, size: 16, color: Colors.grey.shade700),
                                          const SizedBox(width: 6),
                                          Text('$likes', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.thumb_down, size: 16, color: Colors.grey.shade700),
                                          const SizedBox(width: 6),
                                          Text('$dislikes', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}