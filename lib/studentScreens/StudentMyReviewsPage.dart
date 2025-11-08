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
  String? uid;
  bool _resolving = true;
  final Map<String, String> _companyNameCache = {};
  final Map<String, String?> _companyLogoCache = {};
  final DateFormat _dateFmt = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _initStudentId();
  }

  Future<void> _initStudentId() async {
    setState(() => _resolving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        uid = null;
        _resolving = false;
      });
      return;
    }

    try {
      final byId = await FirebaseFirestore.instance.collection('student').doc(user.uid).get();
      if (byId.exists) {
        setState(() {
          uid = byId.id;
          _resolving = false;
        });
        return;
      }

      if (user.email != null && user.email!.isNotEmpty) {
        final emailQuery = await FirebaseFirestore.instance
            .collection('student')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          setState(() {
            uid = emailQuery.docs.first.id;
            _resolving = false;
          });
          return;
        }
      }

      for (final field in ['uid', 'userId', 'authId', 'firebaseUid', 'id']) {
        final q = await FirebaseFirestore.instance
            .collection('student')
            .where(field, isEqualTo: user.uid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          setState(() {
            uid = q.docs.first.id;
            _resolving = false;
          });
          return;
        }
      }

      setState(() {
        uid = user.uid;
        _resolving = false;
      });
    } catch (e) {
      debugPrint('Failed to resolve student id: $e');
      setState(() {
        uid = null;
        _resolving = false;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myReviewsStream() {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null || _resolving) return const Stream.empty();

    final ids = <String>{};
    if (uid != null && uid!.isNotEmpty) ids.add(uid!);
    ids.add(authUid);

    final coll = FirebaseFirestore.instance.collection('reviews');
    if (ids.length == 1) {
      return coll.where('studentId', isEqualTo: ids.first).orderBy('createdAt', descending: true).snapshots();
    }
    return coll.where('studentId', whereIn: ids.toList()).orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myInterviewReviewsStream() {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null || _resolving) return const Stream.empty();

    final ids = <String>{};
    if (uid != null && uid!.isNotEmpty) ids.add(uid!);
    ids.add(authUid);

    final coll = FirebaseFirestore.instance.collection('interview_reviews');
    if (ids.length == 1) {
      return coll.where('studentId', isEqualTo: ids.first).orderBy('createdAt', descending: true).snapshots();
    }
    return coll.where('studentId', whereIn: ids.toList()).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _fetchCompanyMeta(String companyId) async {
    if (companyId.isEmpty || _companyNameCache.containsKey(companyId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      final data = doc.data();
      final name = (data?['companyName'] ?? '').toString();
      final logo = data?['logoUrl'] as String?;
      _companyNameCache[companyId] = name;
      _companyLogoCache[companyId] = logo;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load company meta $companyId: $e');
    }
  }

  Future<void> _deleteReviewRecursive(String rootId) async {
    final fs = FirebaseFirestore.instance;
    final toDelete = <DocumentReference>[];
    final queue = <String>[rootId];

    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      final ref = fs.collection('reviews').doc(cur);
      toDelete.add(ref);

      final replies = await fs.collection('reviews').where('parentId', isEqualTo: cur).get();
      queue.addAll(replies.docs.map((e) => e.id));
    }

    const batchLimit = 400;
    try {
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
    final data = doc.data() ?? {};
    final studentIdOnDoc = (data['studentId'] ?? '').toString();
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = authUid != null && studentIdOnDoc.isNotEmpty && (studentIdOnDoc == authUid || studentIdOnDoc == uid);

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

    if (confirm == true) {
      await _deleteReviewRecursive(doc.id);
    }
  }

  Future<void> _onRefresh() async {
    await _initStudentId();
    _companyNameCache.clear();
    _companyLogoCache.clear();
  }

  Widget _buildLeading(String companyId, String fallbackTitle) {
    final logo = _companyLogoCache[companyId];
    final name = _companyNameCache[companyId] ?? fallbackTitle;
    if (logo != null && logo.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(logo), backgroundColor: Colors.white);
    }
    final initials = (name.isNotEmpty
            ? name.split(RegExp(r'\s+')).map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
            : '?')
        .toUpperCase();
    return CircleAvatar(
      backgroundColor: _purple.withValues(alpha: 0.12),
      child: Text(initials, style: GoogleFonts.lato(color: _purple, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reviews'), backgroundColor: Colors.white, foregroundColor: _purple, elevation: 0),
        body: Center(child: Text('Please sign in to view your reviews.', style: GoogleFonts.lato())),
      );
    }

    if (_resolving) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reviews'), backgroundColor: Colors.white, foregroundColor: _purple, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Reviews'),
          backgroundColor: Colors.white,
          foregroundColor: _purple,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh, color: _purple),
            ),
          ],
          bottom: TabBar(
            labelColor: _purple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _purple,
            tabs: const [
              Tab(text: 'Reviews'),
              Tab(text: 'Interview Reviews'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReviewsTab(),
            _buildInterviewReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myReviewsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildMessageState('Error: ${snap.error}');
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
                _buildMessageState('You have not written any reviews yet.', compact: true),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _buildReviewCard(docs[index]),
          ),
        );
      },
    );
  }

  Widget _buildInterviewReviewsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myInterviewReviewsStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildMessageState('Error: ${snap.error}');
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
                _buildMessageState('No interview reviews yet.', compact: true),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _buildInterviewReviewCard(docs[index]),
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final text = (data['reviewText'] ?? '').toString();
    final snippet = text.length > 320 ? '${text.substring(0, 320)}…' : text;
    final companyId = (data['companyId'] ?? '').toString();
    final parentId = (data['parentId'] ?? '').toString();
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final rating = data['rating'];
    final isReply = parentId.isNotEmpty;

    if (companyId.isNotEmpty && !_companyNameCache.containsKey(companyId)) {
      _fetchCompanyMeta(companyId);
    }
    final companyName = _companyNameCache[companyId] ?? (isReply ? 'Reply' : 'Review');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            isReply ? 'Reply' : 'Review',
            style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: isReply ? _purple : Colors.grey.shade600),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: companyId.isNotEmpty
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StudentCompanyProfilePage(companyId: companyId)),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                            Text(companyName, style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(isReply ? 'Reply' : 'Review', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      if (!isReply && rating != null && rating.toString().isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.orange.shade600),
                            const SizedBox(width: 4),
                            Text(rating.toString(), style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _confirmAndDeleteReview(doc),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(snippet.isNotEmpty ? snippet : 'No text provided.', style: GoogleFonts.lato(height: 1.4)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (created != null)
                        Text(_dateFmt.format(created), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: doc.reference.snapshots(),
                        builder: (context, snap) {
                          final latest = snap.data?.data() ?? data;
                          final likes = (latest['likesCount'] as num?)?.toInt() ?? 0;
                          final dislikes = (latest['dislikesCount'] as num?)?.toInt() ?? 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
                              Text('$likes', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
                              const SizedBox(width: 12),
                              Icon(Icons.thumb_down_alt_outlined, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 4),
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
  }

  Widget _buildInterviewReviewCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final text = (data['reviewText'] ?? '').toString();
    final snippet = text.length > 400 ? '${text.substring(0, 400)}…' : text;
    final companyId = (data['companyId'] ?? '').toString();
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    final parentId = (data['parentId'] ?? '').toString();
    final wasAcceptedRaw = (data['wasAccepted'] ?? '').toString();
    final difficulty = (data['interviewDifficulty'] ?? '').toString();
    final questions = (data['interviewQuestions'] ?? '').toString();
    final answers = (data['interviewAnswers'] ?? '').toString();
    final rating = ((data['rating'] ?? 0) as num).toDouble();
    final isReply = parentId.isNotEmpty;

    if (companyId.isNotEmpty && !_companyNameCache.containsKey(companyId)) {
      _fetchCompanyMeta(companyId);
    }
    final companyName = _companyNameCache[companyId]?.trim().isNotEmpty == true ? _companyNameCache[companyId]! : 'Interview Review';

    final acceptanceLabel = _formatAcceptanceLabel(wasAcceptedRaw);
    final acceptanceColor = _acceptanceColor(wasAcceptedRaw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            isReply ? 'Reply' : 'Interview Review',
            style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: isReply ? _purple : Colors.grey.shade600),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: companyId.isNotEmpty
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StudentCompanyProfilePage(companyId: companyId)),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                            Text(companyName, style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(isReply ? 'Reply' : 'Interview Review', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _confirmAndDeleteInterviewReview(doc),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                    ],
                  ),
                  if (!isReply) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (acceptanceLabel != null)
                          _buildInfoChip(
                            acceptanceLabel,
                            Icons.flag,
                            background: acceptanceColor.withValues(alpha: 0.15),
                            foreground: acceptanceColor.darken(),
                          ),
                        if (difficulty.isNotEmpty)
                          _buildInfoChip(
                            'Difficulty: $difficulty',
                            Icons.speed,
                            background: Colors.blueGrey.shade50,
                            foreground: Colors.blueGrey.shade700,
                          ),
                        if (rating > 0)
                          _buildInfoChip(
                            'Rating: ${rating.toStringAsFixed(1)}',
                            Icons.star_rounded,
                            background: Colors.orange.shade50,
                            foreground: Colors.orange.shade700,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(snippet.isNotEmpty ? snippet : 'No interview notes yet.', style: GoogleFonts.lato(height: 1.4)),
                  if (!isReply && questions.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Questions', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(questions, style: GoogleFonts.lato(height: 1.4, color: Colors.grey.shade800)),
                  ],
                  if (!isReply && answers.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Answers / Tips', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(answers, style: GoogleFonts.lato(height: 1.4, color: Colors.grey.shade800)),
                  ],
                  const SizedBox(height: 12),
                  if (created != null)
                    Text(
                      _dateFmt.format(created),
                      style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _formatAcceptanceLabel(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) return null;
    if (normalized == 'yes' || normalized == 'accepted' || normalized == 'offer') return 'Offer received';
    if (normalized == 'no' || normalized == 'rejected') return 'No offer';
    if (normalized == 'not sure' || normalized == 'pending') return 'Outcome pending';
    return value;
  }

  Color _acceptanceColor(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'yes' || normalized == 'accepted' || normalized == 'offer') {
      return Colors.green.shade600;
    }
    if (normalized == 'no' || normalized == 'rejected') {
      return Colors.red.shade500;
    }
    if (normalized == 'not sure' || normalized == 'pending') {
      return Colors.orange.shade600;
    }
    return Colors.blueGrey.shade600;
  }

  Widget _buildInfoChip(
    String text,
    IconData icon, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }

  Widget _buildMessageState(String message, {bool compact = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 0 : 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(fontSize: 15, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteInterviewReview(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final studentIdOnDoc = (data['studentId'] ?? '').toString();
    final parentId = (data['parentId'] ?? '').toString();
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final canDelete = authUid != null && studentIdOnDoc.isNotEmpty && (studentIdOnDoc == authUid || studentIdOnDoc == uid);

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are not authorized to delete this interview review.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete interview review'),
        content: Text(parentId.isEmpty ? 'This will delete the review and its replies. Continue?' : 'Delete this reply?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (parentId.isEmpty) {
        await _deleteInterviewReviewThread(doc.id);
      } else {
        await doc.reference.delete();
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

  Future<void> _deleteInterviewReviewThread(String rootId) async {
    final fs = FirebaseFirestore.instance;
    final rootRef = fs.collection('interview_reviews').doc(rootId);
    final repliesSnap = await fs.collection('interview_reviews').where('parentId', isEqualTo: rootId).get();
    final companyRepliesSnap = await rootRef.collection('replies').get();
    final refs = <DocumentReference>[
      rootRef,
      ...repliesSnap.docs.map((e) => e.reference),
      ...companyRepliesSnap.docs.map((e) => e.reference),
    ];

    const batchLimit = 400;
    for (var i = 0; i < refs.length; i += batchLimit) {
      final end = (i + batchLimit) > refs.length ? refs.length : (i + batchLimit);
      final batch = fs.batch();
      for (var j = i; j < end; j++) {
        batch.delete(refs[j]);
      }
      await batch.commit();
    }
  }
}

extension _ColorShade on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
