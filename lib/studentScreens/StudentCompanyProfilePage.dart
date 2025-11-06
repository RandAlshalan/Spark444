import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

// --- Make sure these paths are correct for your project ---
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/bookmarkService.dart';
import '../models/review.dart';
import '../models/Application.dart'; 
import '../services/applicationService.dart';
import 'StudentSingleProfilePage.dart'; // NEW: single-student followers-style view
// ---------------------------------------------------------

// --- Constants ---
const _purple = Color(0xFF422F5D);
const _pink = Color(0xFFD64483);

// New: review length limits
const int _reviewMinLength = 1;
const int _reviewMaxLength = 300;
// ---------------------------------------------------------

// =========================================================================
// == MAIN COMPANY PROFILE PAGE (Stateless)
// =========================================================================
// (This section is unchanged)

class StudentCompanyProfilePage extends StatelessWidget {
  const StudentCompanyProfilePage({super.key, required this.companyId});
  final String companyId;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _companyDocStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .snapshots();
  }

  Stream<int> _oppsCountStream() {
    return FirebaseFirestore.instance
        .collection('opportunities')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((s) => s.size);
  }

  Stream<int> _followersCountStream() {
    return FirebaseFirestore.instance
        .collection('student')
        .where('followedCompanies', arrayContains: companyId)
        .snapshots()
        .map((s) => s.size);
  }

  Stream<bool> _isFollowingStream(String studentId) {
    return FirebaseFirestore.instance
        .collection('student')
        .doc(studentId)
        .snapshots()
        .map((d) {
      final data = d.data();
      final list = List<String>.from(data?['followedCompanies'] ?? []);
      return list.contains(companyId);
    });
  }

  Future<void> _toggleFollow(
      {required String studentId, required bool following}) async {
    final ref = FirebaseFirestore.instance.collection('student').doc(studentId);
    await ref.set({
      'followedCompanies': following
          ? FieldValue.arrayRemove([companyId])
          : FieldValue.arrayUnion([companyId]),
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
          return Scaffold(
              appBar: AppBar(title: const Text('Company')),
              body: const Center(child: Text('Company not found')));
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
                  // -------- Header (from File 2)
                  Stack(
                    children: [
                      Container(
                        height: 260,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_purple, _pink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: const Alignment(0, 0.22),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.white,
                              child: (company.logoUrl != null &&
                                      company.logoUrl!.isNotEmpty)
                                  ? CircleAvatar(
                                      radius: 58,
                                      backgroundImage:
                                          CachedNetworkImageProvider(company.logoUrl!))
                                  : CircleAvatar(
                                      radius: 58,
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        (company.companyName.trim().isEmpty
                                                ? ''
                                                : company.companyName
                                                    .trim()
                                                    .split(RegExp(r'\s+'))
                                                    .take(2)
                                                    .map((w) => w[0])
                                                    .join())
                                            .toUpperCase(),
                                        style: GoogleFonts.lato(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: _purple,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (studentId != null)
                        Positioned(
                          right: 16,
                          bottom: 72,
                          child: StreamBuilder<bool>(
                            stream: _isFollowingStream(studentId),
                            builder: (context, s) {
                              final following = s.data ?? false;
                              return OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22)),
                                ),
                                onPressed: () async {
                                  try {
                                    await _toggleFollow(
                                        studentId: studentId,
                                        following: following);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('Failed: $e')));
                                    }
                                  }
                                },
                                child: Text(following ? 'Following' : 'Follow',
                                    style: GoogleFonts.lato()),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  // -------- Card with Tabs (from File 2)
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
                            Text(
                              company.companyName,
                              style: GoogleFonts.lato(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (company.sector.isNotEmpty)
                              Text(
                                company.sector,
                                style: GoogleFonts.lato(
                                  color: Colors.black.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 10),
                            if ((company.description ?? '').isNotEmpty)
                              Text(
                                company.description!,
                                style: GoogleFonts.lato(
                                  color: Colors.black.withOpacity(0.75),
                                  height: 1.4,
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Followers count row
                            StreamBuilder<int>(
                              stream: _followersCountStream(),
                              builder: (context, followersSnap) {
                                final followersCount = followersSnap.data ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 18,
                                        color: Colors.black.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$followersCount ${followersCount == 1 ? 'Follower' : 'Followers'}',
                                        style: GoogleFonts.lato(
                                          fontSize: 14,
                                          color: Colors.black.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            StreamBuilder<int>(
                              stream: _oppsCountStream(),
                              builder: (context, oppCountSnap) {
                                final oppCount = oppCountSnap.data ?? 0;
                                return Center(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('reviews').where('companyId', isEqualTo: companyId).snapshots(),
                                    builder: (context, reviewSnap) {
                                      final reviewsCount = reviewSnap.data?.size ?? 0;
                                      return TabBar(
                                        isScrollable: true,
                                        labelColor: Colors.black,
                                        labelStyle: GoogleFonts.lato(fontWeight: FontWeight.w700),
                                        unselectedLabelStyle: GoogleFonts.lato(),
                                        unselectedLabelColor: Colors.black.withOpacity(0.5),
                                        indicatorColor: _purple,
                                        indicatorWeight: 3,
                                        dividerColor: Colors.transparent,
                                        tabs: [
                                          const Tab(text: 'Details'),
                                          Tab(text: 'Opportunities ($oppCount)'),
                                          Tab(text: 'Reviews ($reviewsCount)'),
                                        ],
                                      );
                                    }
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // -------- Tab Content (from File 2)
                  Container(
                    height: 700,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBarView(
                      children: [
                        _DetailsTab(company: company, data: data),
                        _OpportunitiesTab(companyId: companyId), 
                        _ReviewsTab(
                          companyId: companyId,
                          studentId: studentId,
                        ),
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

// =========================================================================
// == DETAILS TAB WIDGET
// =========================================================================
// (This section is unchanged)
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
    final m = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}')
        .firstMatch(text);
    return (m?.group(0) ?? '').trim();
  }

  String _extractPhone(String text) {
    final m = RegExp(r'(\+?\d[\d\s\-\(\)]{7,})').firstMatch(text);
    return (m?.group(1) ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final about = (company.description ?? '').trim();
    final rawContact = company.contactInfo.trim();

    final emailFromFields =
        (data['contactEmail'] ?? data['email'] ?? company.email)
            .toString()
            .trim();
    final emailFromText = _extractEmail('$rawContact $about');
    final email = emailFromFields.isNotEmpty ? emailFromFields : emailFromText;

    String phone = (data['phone'] ?? data['contactPhone'] ?? '').toString().trim();
    if (phone.isEmpty) phone = _extractPhone('$rawContact $about');

    // Extract location from data
    final location = (data['location'] ?? data['address'] ?? '').toString().trim();

    var contactName = rawContact;
    if (phone.isNotEmpty) {
      contactName = contactName
          .replaceAll(phone, '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }
    if (emailFromText.isNotEmpty) {
      contactName = contactName
          .replaceAll(emailFromText, '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }
    contactName = contactName
        .replaceAll(RegExp(r'^[\-\•\|,;:()\s]+|[\-\•\|,;:()\s]+$'), '')
        .trim();

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            t,
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        sectionTitle('About Us'),
        Text(
          about.isNotEmpty ? about : 'No description provided.',
          style: GoogleFonts.lato(
            color: Colors.black.withOpacity(0.75),
            height: 1.45,
          ),
        ),
        const Divider(height: 28),
        sectionTitle('Contact Details'),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined, color: _purple),
                title: Text(
                  email.isNotEmpty ? 'Email: $email' : 'Email: Not provided',
                  style: GoogleFonts.lato(),
                ),
                subtitle: contactName.isNotEmpty
                    ? Text(contactName, style: GoogleFonts.lato())
                    : null,
                trailing: ElevatedButton(
                    onPressed: email.isEmpty ? null : () => _launchEmail(email),
                    child: Text('Email', style: GoogleFonts.lato())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: _purple),
                title: Text(
                  phone.isNotEmpty ? 'Phone: $phone' : 'Phone: Not provided',
                  style: GoogleFonts.lato(),
                ),
                trailing: ElevatedButton(
                    onPressed: phone.isEmpty ? null : () => _launchPhone(phone),
                    child: Text('Call', style: GoogleFonts.lato())),
              ),
              if (location.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: _purple),
                  title: Text(
                    'Location: $location',
                    style: GoogleFonts.lato(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


// =========================================================================
// == OPPORTUNITIES TAB WIDGET
// =========================================================================
// (This section is unchanged)

class _OpportunitiesTab extends StatelessWidget {
  _OpportunitiesTab({required this.companyId});
  final String companyId;

  final BookmarkService _bookmarkService = BookmarkService();

  Stream<QuerySnapshot<Map<String, dynamic>>> _oppsStream() {
    return FirebaseFirestore.instance
        .collection('opportunities')
        .where('companyId', isEqualTo: companyId)
        .snapshots();
  }

  Stream<bool> _isBookmarkedStream(String uid, String opportunityId) {
    return _bookmarkService.isBookmarkedStream(
      studentId: uid,
      opportunityId: opportunityId,
    );
  }

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
      return Center(
          child: Text(
        'Please sign in to view opportunities.',
        style: GoogleFonts.lato(),
      ));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _oppsStream(),
      builder: (context, oppSnap) {
        if (oppSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final oppDocs = oppSnap.data?.docs ?? [];
        if (oppDocs.isEmpty) {
          return Center(
              child: Text(
            'No opportunities yet.',
            style: GoogleFonts.lato(),
          ));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: oppDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final doc = oppDocs[i];
            final opportunity = Opportunity.fromFirestore(doc);

            return _OpportunityCard(
              opportunity: opportunity,
              bookmarkStream: _isBookmarkedStream(uid, opportunity.id),
              onToggleBookmark: (isBookmarked) => _toggleBookmark(
                uid: uid,
                opportunityId: opportunity.id,
                isBookmarked: isBookmarked,
                context: context,
              ),
            );
          },
        );
      },
    );
  }
}

// =========================================================================
// == OPPORTUNITY CARD WIDGET (With "View More" button)
// =========================================================================
// (This section is unchanged)

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.bookmarkStream,
    required this.onToggleBookmark,
  });

  final Opportunity opportunity;
  final Stream<bool>? bookmarkStream;
  final Future<void> Function(bool isBookmarked)? onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    Widget buildRow(IconData icon, String text) {
      return Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      );
  }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              opportunity.role,
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _purple,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              opportunity.name,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: _pink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            buildRow(Icons.location_on_outlined,
                opportunity.location ?? 'Location not specified'),
            const SizedBox(height: 6),
            if (opportunity.workMode != null)
              buildRow(Icons.apartment_outlined,
                  opportunity.workMode ?? 'Work mode not specified'),
            const SizedBox(height: 6),
            buildRow(
              Icons.payments_outlined,
              opportunity.isPaid ? 'Paid opportunity' : 'Unpaid opportunity',
            ),
            if (opportunity.applicationDeadline != null) ...[
              const SizedBox(height: 6),
              buildRow(
                Icons.event_available_outlined,
                'Apply before ${DateFormat('MMM d, yyyy').format(opportunity.applicationDeadline!.toDate())}',
              ),
            ],
            const SizedBox(height: 16),
            if (bookmarkStream != null && onToggleBookmark != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // --- "View More" Button ---
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OpportunityDetailPage(opportunity: opportunity),
                        ),
                      );
                    },
                    child: Text(
                      'View More',
                      style: GoogleFonts.lato(
                        color: _purple, // Use primary color
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // --- Bookmark Button (existing) ---
                  StreamBuilder<bool>(
                    stream: bookmarkStream,
                    builder: (context, snapshot) {
                      final isBookmarked = snapshot.data ?? false;
                      return TextButton.icon(
                        onPressed: () => onToggleBookmark!(isBookmarked),
                        icon: Icon(
                          isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          color: isBookmarked ? _pink : _purple,
                        ),
                        label: Text(
                          isBookmarked ? 'Bookmarked' : 'Save',
                          style: GoogleFonts.lato(
                            color: isBookmarked ? _pink : _purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// == REVIEWS TAB WIDGET
// =========================================================================

/* Small helper type to represent a review thread (top-level review + its replies) */
class _ReviewThread {
  final Review review;
  final List<Review> replies;
  _ReviewThread({required this.review, required this.replies});
}

class _ReviewsTab extends StatefulWidget {
  const _ReviewsTab({required this.companyId, required this.studentId});
  final String companyId;
  final String? studentId;

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  final _reviewController = TextEditingController();
  double _currentRating = 0;
  bool _isSubmitting = false;

  // control whether the review shows the student's profile (visible) or is anonymous
  bool _authorVisible = true;

  // Reply UI state per root review id
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReplyBox = {};
  final Map<String, bool> _replyAuthorVisible = {};
  final Map<String, bool> _isReplySubmitting = {};

  // Track whether a reply field currently has any text (true => enable Reply button).
  final Map<String, bool> _replyHasText = {};

  // Live review input state (for Submit button enabling)
  bool _reviewHasText = false;
  bool _reviewTextValid = false;
  bool _canSubmitReview = false;
  String? _ratingInlineError;

  // --- New helper to update review submit state ---
  void _updateReviewButtonState({bool force = false}) {
    final text = _reviewController.text.trim();
    final textValid = text.length >= _reviewMinLength && text.length <= _reviewMaxLength;
    final hasRating = _currentRating > 0;
    final newCan = textValid && hasRating;
    // Only setState when the actionable boolean changes to reduce rebuilds.
    if (force || newCan != _canSubmitReview || textValid != _reviewTextValid || (text.isNotEmpty) != _reviewHasText) {
      setState(() {
        _reviewHasText = text.isNotEmpty;
        _reviewTextValid = textValid;
        _canSubmitReview = newCan;
        // clear rating error if user fixes rating
        if (hasRating) _ratingInlineError = null;
      });
    }
  }

  // Helper to open the single-student page (only if authorVisible)
  void _openStudentProfile({required String studentId, required bool authorVisible}) {
    if (!authorVisible) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This student’s profile is private.")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSingleProfilePage(studentId: studentId),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Do not attach a listener that calls setState on each keystroke to avoid continuous rebuilds.
    // Initialize review button state from any existing controller text / rating.
    _reviewHasText = _reviewController.text.trim().isNotEmpty;
    _reviewTextValid = _reviewController.text.trim().length >= _reviewMinLength && _reviewController.text.trim().length <= _reviewMaxLength;
    _canSubmitReview = _reviewTextValid && _currentRating > 0;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Validate text length and return an inline error message or null.
  String? _validateTextLength(String text, {int min = _reviewMinLength, int max = _reviewMaxLength, String label = 'review'}) {
    final len = text.trim().length;
    if (len < min) return 'Your $label must be between $min and $max characters.';
    if (len > max) return 'Your $label must be between $min and $max characters.';
    return null;
  }

  // Ensure a reply controller exists for a parentId and attach listener once.
  TextEditingController _ensureReplyController(String parentId) {
    var created = false;
    final controller = _replyControllers.putIfAbsent(parentId, () {
      created = true;
      return TextEditingController();
    });

    if (created) {
      // initialize author-visibility default for this reply controller
      _replyAuthorVisible[parentId] = true;
      // Initialize the "hasText" flag based on current controller content.
      _replyHasText[parentId] = controller.text.trim().isNotEmpty;
      // IMPORTANT: do NOT attach a listener that calls setState() on every keystroke.
      // We'll update _replyHasText via the TextField.onChanged handler only when toggling.
    }
    return controller;
  }

  // Fetch all reviews for the company in a single query, then group them into threads.
  Stream<List<_ReviewThread>> _getReviewsStream() {
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('companyId', isEqualTo: widget.companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final r = Review.fromFirestore(doc);
        final data = doc.data() as Map<String, dynamic>;
        final parentIdRaw = data['parentId'];
        final parentId = (parentIdRaw is String && parentIdRaw.trim().isNotEmpty) ? parentIdRaw : null;
        return {'review': r, 'parentId': parentId};
      }).toList();

      final Map<String, List<Review>> repliesMap = {};
      for (var item in items) {
        final Review r = item['review'] as Review;
        final String? pid = item['parentId'] as String?;
        if (pid != null) {
          repliesMap.putIfAbsent(pid, () => []).add(r);
        }
      }

      final threads = items
          .where((i) => (i['parentId'] as String?) == null)
          .map((i) {
        final Review top = i['review'] as Review;
        final replies = repliesMap[top.id] ?? [];
        replies.sort((a, b) => a.createdAt.toDate().compareTo(b.createdAt.toDate()));
        return _ReviewThread(review: top, replies: replies);
      }).toList();

      threads.sort((a, b) => b.review.createdAt.toDate().compareTo(a.review.createdAt.toDate()));

      return threads;
    });
  }

  Future<void> _submitReview() async {
    final text = _reviewController.text.trim();

    // Client-side validation (length)
    final inlineErr = _validateTextLength(text, label: 'review');
    if (inlineErr != null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(inlineErr), backgroundColor: Colors.red.shade700));
      return;
    }

    if (_currentRating == 0) {
      // Prevent submission and show small inline message near stars (and snack for extra visibility)
      setState(() => _ratingInlineError = 'Please select a rating before submitting your review.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating before submitting your review.'), backgroundColor: Colors.red));
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a review before submitting.')));
      return;
    }
    if (widget.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to leave a review.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Backend (server-side) validation simulated here: ensure we reject invalid-length text just before storing.
      if (text.length < _reviewMinLength || text.length > _reviewMaxLength) {
        throw Exception('Your review must be between $_reviewMinLength and $_reviewMaxLength characters.');
      }

      final studentDoc = await FirebaseFirestore.instance.collection('student').doc(widget.studentId).get();
      final first = (studentDoc.data()?['firstName'] ?? '').toString();
      final last = (studentDoc.data()?['lastName'] ?? '').toString();
      final studentName = ('$first $last').trim();

      final reviewData = {
        'studentId': widget.studentId!,
        'studentName': studentName,
        'companyId': widget.companyId,
        'rating': _currentRating,
        'reviewText': text,
        'createdAt': Timestamp.now(),
        'authorVisible': _authorVisible,
        // top-level review => no parentId
      };

      await FirebaseFirestore.instance.collection('reviews').add(reviewData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your review!'), backgroundColor: Colors.green));
        _reviewController.clear();
        setState(() {
          _currentRating = 0;
          _ratingInlineError = null;
          _reviewHasText = false;
          _reviewTextValid = false;
          _canSubmitReview = false;
        });
      }
    } catch (e) {
      final msg = (e is Exception) ? e.toString().replaceAll('Exception: ', '') : 'Failed to submit review: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitReply(String parentReviewId) async {
    final controller = _ensureReplyController(parentReviewId);
    final text = controller.text.trim();
    final visible = _replyAuthorVisible.putIfAbsent(parentReviewId, () => true);

    // Client-side validation (length)
    final inlineErr = _validateTextLength(text, label: 'reply');
    if (inlineErr != null) {
      setState(() => _isReplySubmitting[parentReviewId] = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(inlineErr), backgroundColor: Colors.red.shade700));
      return;
    }

    if (widget.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to reply.')));
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply cannot be empty.')));
      return;
    }

    setState(() => _isReplySubmitting[parentReviewId] = true);
    try {
      // Backend (server-side) validation simulated here
      if (text.length < _reviewMinLength || text.length > _reviewMaxLength) {
        throw Exception('Your reply must be between $_reviewMinLength and $_reviewMaxLength characters.');
      }

      final studentDoc = await FirebaseFirestore.instance.collection('student').doc(widget.studentId).get();
      final first = (studentDoc.data()?['firstName'] ?? '').toString();
      final last = (studentDoc.data()?['lastName'] ?? '').toString();
      final studentName = ('$first $last').trim();

      final replyData = {
        'studentId': widget.studentId!,
        'studentName': studentName,
        'companyId': widget.companyId,
        'rating': 0, // replies don't carry rating
        'reviewText': text,
        'createdAt': Timestamp.now(),
        'authorVisible': visible,
        'parentId': parentReviewId,
      };

      await FirebaseFirestore.instance.collection('reviews').add(replyData);

      // clear and collapse reply box
      controller.clear();
      setState(() {
        _showReplyBox[parentReviewId] = false;
        _replyHasText[parentReviewId] = false;
      });
    } catch (e) {
      final msg = (e is Exception) ? e.toString().replaceAll('Exception: ', '') : 'Failed to submit reply: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
      }
    } finally {
      setState(() => _isReplySubmitting[parentReviewId] = false);
    }
  }

  Future<void> _confirmAndDelete(String reviewId, {required bool isParent}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this item? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: _purple), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final reviewsCol = FirebaseFirestore.instance.collection('reviews');
        if (isParent) {
          final repliesSnap = await reviewsCol.where('parentId', isEqualTo: reviewId).get();
          final batch = FirebaseFirestore.instance.batch();
          for (final d in repliesSnap.docs) batch.delete(d.reference);
          batch.delete(reviewsCol.doc(reviewId));
          await batch.commit();
        } else {
          await reviewsCol.doc(reviewId).delete();
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildWriteReviewSection() {
    if (widget.studentId == null) return const SizedBox.shrink();
    final isValid = _validateTextLength(_reviewController.text.trim()) == null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Write a Review', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () {
                  // set rating and update submit-button state
                  setState(() => _currentRating = index + 1.0);
                  // clear inline rating error and recalc button state
                  _ratingInlineError = null;
                  _updateReviewButtonState();
                },
                icon: Icon(index < _currentRating ? Icons.star : Icons.star_border, color: const Color(0xFFF99D46), size: 32),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Show my profile', style: GoogleFonts.lato()),
              Switch(value: _authorVisible, activeColor: _purple, onChanged: (v) => setState(() => _authorVisible = v)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            maxLength: _reviewMaxLength,
            inputFormatters: [LengthLimitingTextInputFormatter(_reviewMaxLength)],
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              counterText: '', // keep existing appearance
            ),
            // no per-keystroke state changes here (prevents reloads)
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Inline error / helper text
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _reviewController,
                  builder: (context, value, _) {
                    final remaining = _reviewMaxLength - value.text.trim().length;
                    return Text(
                      '$remaining characters remaining',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                  child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_ratingInlineError != null)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
              child: Text(
                _ratingInlineError!,
                style: GoogleFonts.lato(fontSize: 13, color: Colors.red.shade700),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_ReviewThread>>(
      stream: _getReviewsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final threads = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          children: [
            _buildWriteReviewSection(),
            if (threads.isEmpty) _buildEmptyState() else ...threads.map((t) => _buildReviewThreadCard(t)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No reviews yet.', style: GoogleFonts.lato(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Be the first to share your experience!', style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  Widget _buildReviewThreadCard(_ReviewThread thread) {
    final parentId = thread.review.id;
    // Ensure the reply controller exists and has listeners/counters
    _ensureReplyController(parentId);
    _showReplyBox.putIfAbsent(parentId, () => false);
    _replyAuthorVisible.putIfAbsent(parentId, () => true);
    _isReplySubmitting.putIfAbsent(parentId, () => false);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildReviewCard(thread.review),

          // Reply button + optional reply box
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showReplyBox[parentId] = !(_showReplyBox[parentId] ?? false)),
                child: Text('Reply', style: GoogleFonts.lato()),
              ),
              if (widget.studentId != null && widget.studentId == thread.review.studentId) ...[
                const SizedBox(width: 8),
                IconButton(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  onPressed: () => _confirmAndDelete(parentId, isParent: true),
                ),
              ],
            ],
          ),

          if (_showReplyBox[parentId] == true) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _replyControllers[parentId],
              maxLines: 3,
              maxLength: _reviewMaxLength,
              inputFormatters: [LengthLimitingTextInputFormatter(_reviewMaxLength)],
              decoration: InputDecoration(hintText: 'Write a reply...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), counterText: ''),
              // no per-keystroke state changes here (prevents reloads)
            ),
            const SizedBox(height: 6),
            // Inline reply error / remaining + controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _replyAuthorVisible[parentId] == true ? 'Visible to all' : 'Anonymous',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(children: [
                  Text('Show my profile', style: GoogleFonts.lato(fontSize: 14)),
                  const SizedBox(width: 8),
                  Switch(value: _replyAuthorVisible[parentId] ?? true, activeColor: _purple, onChanged: (v) => setState(() => _replyAuthorVisible[parentId] = v)),
                ]),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_isReplySubmitting[parentId] ?? false) ? null : () => _submitReply(parentId),
                  style: ElevatedButton.styleFrom(backgroundColor: _purple),
                  child: (_isReplySubmitting[parentId] ?? false) ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Reply', style: GoogleFonts.lato(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Replies (rendered thread.replies)
          if (thread.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            ...thread.replies.map((r) {
              return Stack(
                children: [
                  _buildReplyTile(r),
                  // delete reply icon for owner (overlay to the right)
                  if (widget.studentId != null && widget.studentId == r.studentId)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
                        onPressed: () => _confirmAndDelete(r.id, isParent: false),
                      ),
                    ),
                ],
              );
            }).toList(),
          ],
        ]),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openStudentProfile(studentId: review.studentId, authorVisible: (review.authorVisible ?? true)),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('student').doc(review.studentId).snapshots(),
              builder: (context, studentSnap) {
                String currentName = review.studentName;
                if (studentSnap.hasData && studentSnap.data?.data() != null) {
                  final sd = studentSnap.data!.data()!;
                  final fn = (sd['firstName'] ?? '').toString().trim();
                  final ln = (sd['lastName'] ?? '').toString().trim();
                  final combined = '$fn ${ln}'.trim();
                  if (combined.isNotEmpty) currentName = combined;
                }

                final visible = (review.authorVisible ?? true);
                final displayName = visible ? (currentName.isNotEmpty ? currentName : review.studentName) : 'Anonymous';

                return Text(displayName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: _purple));
              },
            ),
          ),
        ),
        _buildStarRating(review.rating.toInt()),
      ]),
      const SizedBox(height: 8),
      Text(review.reviewText, style: GoogleFonts.lato(fontSize: 14, color: Colors.black87, height: 1.5)),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(DateFormat('MMM d, yyyy').format(review.createdAt.toDate()), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    ]);
  }

  Widget _buildReplyTile(Review reply) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade200,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('student').doc(reply.studentId).snapshots(),
            builder: (context, studentSnap) {
              String initials = '';
              String nameForInitials = reply.studentName;
              if (studentSnap.hasData && studentSnap.data?.data() != null) {
                final sd = studentSnap.data!.data()!;
                final fn = (sd['firstName'] ?? '').toString().trim();
                final ln = (sd['lastName'] ?? '').toString().trim();
                final combined = '$fn ${ln}'.trim();
                if (combined.isNotEmpty) nameForInitials = combined;
              }
              initials = (nameForInitials.isNotEmpty) ? nameForInitials.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase() : '';
              return Text(initials, style: GoogleFonts.lato(fontSize: 12, color: _purple));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => _openStudentProfile(studentId: reply.studentId, authorVisible: (reply.authorVisible ?? true)),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('student').doc(reply.studentId).snapshots(),
                builder: (context, studentSnap) {
                  String currentName = reply.studentName;
                  if (studentSnap.hasData && studentSnap.data?.data() != null) {
                    final sd = studentSnap.data!.data()!;
                    final fn = (sd['firstName'] ?? '').toString().trim();
                    final ln = (sd['lastName'] ?? '').toString().trim();
                    final combined = '$fn ${ln}'.trim();
                    if (combined.isNotEmpty) currentName = combined;
                  }

                  final visible = (reply.authorVisible ?? true);
                  final displayName = visible ? (currentName.isNotEmpty ? currentName : reply.studentName) : 'Anonymous';

                  return Text(displayName, style: GoogleFonts.lato(fontWeight: FontWeight.w700, color: _purple));
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(reply.reviewText, style: GoogleFonts.lato(fontSize: 13, color: Colors.black87, height: 1.4)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(DateFormat('MMM d, yyyy').format(reply.createdAt.toDate()), style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (index) {
      return Icon(index < rating ? Icons.star : Icons.star_border, color: index < rating ? const Color(0xFFF99D46) : Colors.grey.shade400, size: 20);
    }));
  }
}

// =========================================================================
// == OPPORTUNITY DETAIL PAGE (HEAVILY UPDATED)
// =========================================================================
// (This is now a StatefulWidget to handle application state)

class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({super.key, required this.opportunity});
  final Opportunity opportunity;

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  final ApplicationService _applicationService = ApplicationService();
  final DateFormat _dateFormatter = DateFormat('MMM d, yyyy');
  String? _studentId;
  Application? _currentApplication;
  bool _isApplying = false;
  bool _isLoadingStatus = true; // Tracks initial status check

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingStatus = false);
      return;
    }
    _studentId = user.uid;
    await _fetchApplicationStatus();
  }

  Future<void> _fetchApplicationStatus() async {
    if (_studentId == null) return;
    setState(() => _isLoadingStatus = true);

    final app = await _applicationService.getApplicationForOpportunity(
      studentId: _studentId!,
      opportunityId: widget.opportunity.id,
    );

    if (mounted) {
      setState(() {
        _currentApplication = app as Application?;
        _isLoadingStatus = false;
        _isApplying = false;
      });
    }
  }

  Future<void> _applyNow() async {
    if (_studentId == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Application'),
        content: Text(
          'Are you sure you want to apply for the role of ${widget.opportunity.role}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isApplying = true);
    try {
      await _applicationService.submitApplication(
        studentId: _studentId!,
        opportunityId: widget.opportunity.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchApplicationStatus(); // Refresh the status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _withdrawApplication() async {
    if (_currentApplication == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application?'),
        content: const Text(
          'This will update your application status to "Withdrawn". You cannot undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _applicationService.withdrawApplication(
          applicationId: _currentApplication!.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application withdrawn.'),
              backgroundColor: Colors.green,
            ),
          );
          await _fetchApplicationStatus(); // Refresh the status
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper to format date ranges
  String _formatDateRange(Timestamp? start, Timestamp? end) {
    if (start == null && end == null) {
      return 'Not specified';
    }
    final String startDate =
        start != null ? _dateFormatter.format(start.toDate()) : 'N/A';
    final String endDate =
        end != null ? _dateFormatter.format(end.toDate()) : 'N/A';
    return '$startDate - $endDate';
  }

  @override
  Widget build(BuildContext) {
    final opp = widget.opportunity; // Shorthand

    return Scaffold(
      appBar: AppBar(
        title: Text(opp.role, style: GoogleFonts.lato()),
        backgroundColor: Colors.white,
        foregroundColor: _purple,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120), // Add bottom padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Text(
              opp.role,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _purple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              opp.name, // Company Name
              style: GoogleFonts.lato(
                fontSize: 18,
                color: _pink,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            // --- Key Details Section ---
            const Divider(height: 32),
            _buildDetailSection(
              'Key Details',
              Column(
                children: [
                  _buildIconRow(Icons.work_outline, 'Type', opp.type),
                  if (opp.location != null)
                    _buildIconRow(
                        Icons.location_on_outlined, 'Location', opp.location!),
                  if (opp.workMode != null)
                    _buildIconRow(
                        Icons.apartment_outlined, 'Work Mode', opp.workMode!),
                  if (opp.preferredMajor != null)
                    _buildIconRow(Icons.school_outlined, 'Preferred Major',
                        opp.preferredMajor!),
                  _buildIconRow(
                    Icons.payments_outlined,
                    'Payment',
                    opp.isPaid ? 'Paid opportunity' : 'Unpaid opportunity',
                  ),
                ],
              ),
            ),
            
            // --- Dates Section ---
            _buildDetailSection(
              'Dates',
              Column(
                children: [
                  _buildIconRow(
                    Icons.calendar_today_outlined,
                    'Duration',
                    _formatDateRange(opp.startDate, opp.endDate),
                  ),
                  _buildIconRow(
                    Icons.event_available_outlined,
                    'Apply Between',
                    _formatDateRange(
                        opp.applicationOpenDate, opp.applicationDeadline),
                  ),
                  if (opp.responseDeadlineVisible == true &&
                      opp.responseDeadline != null)
                    _buildIconRow(
                      Icons.hourglass_bottom_outlined,
                      'Response By',
                      _dateFormatter.format(opp.responseDeadline!.toDate()),
                    ),
                ],
              ),
            ),
            
            // --- Skills Section ---
            if (opp.skills != null && opp.skills!.isNotEmpty)
              _buildDetailSection(
                'Key Skills',
                _buildChipList(opp.skills!),
              ),
              
            // --- Requirements Section ---
            if (opp.requirements != null && opp.requirements!.isNotEmpty)
              _buildDetailSection(
                'Requirements',
                _buildRequirementList(opp.requirements!),
              ),
              
            // --- Description Section ---
            if (opp.description != null && opp.description!.isNotEmpty)
              _buildDetailSection(
                'About the Opportunity',
                Text(
                  opp.description!,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),

            // --- Posted Date ---
            _buildDetailRow(
              'Posted On',
              opp.postedDate != null
                  ? _dateFormatter.format(opp.postedDate!.toDate())
                  : 'Date not specified',
            ),
          ],
        ),
      ),
      bottomSheet: _buildActionBottomSheet(),
    );
  }

  // --- Helper Widgets for Detail Page (Moved inside State) ---

  // A generic section builder
  Widget _buildDetailSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _purple,
            ),
          ),
          const SizedBox(height: 12),
          content,
          const Divider(height: 24),
        ],
      ),
    );
  }

  // Helper for text rows
  Widget _buildDetailRow(String title, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for icon rows (now with a title)
  Widget _buildIconRow(IconData icon, String title, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _purple.withOpacity(0.8)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for skills chips
  Widget _buildChipList(List<String> items) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: items
          .map(
            (item) => Chip(
              label: Text(
                item,
                style: GoogleFonts.lato(
                  color: _purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: _purple.withOpacity(0.1),
              side: BorderSide.none,
            ),
          )
          .toList(),
    );
  }

  // Helper for requirements list
  Widget _buildRequirementList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: _purple,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      req,
                      style: GoogleFonts.lato(fontSize: 16, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // --- Helper Widgets for Bottom Sheet (Copied from studentOppPage) ---

  Widget _buildActionBottomSheet() {
    // 1. Show loading indicator while checking status
    if (_isLoadingStatus) {
      return Container(
        height: 80 + MediaQuery.of(context).padding.bottom,
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    // 2. Show disabled button if user is not logged in
    if (_studentId == null) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom,
        ),
        child: ElevatedButton(
          onPressed: null,
          child: Text('Please sign in to apply', style: GoogleFonts.lato()),
        ),
      );
    }
    
    // 3. Show Apply or Withdraw button
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom, // Safe area padding
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _currentApplication != null
          ? _buildStatusAndWithdrawView() // Show status and withdraw button
          : _buildApplyNowView(), // Show apply button
    );
  }

  Widget _buildApplyNowView() {
    // Check if application period has started
    final now = DateTime.now();
    final applicationOpenDate = widget.opportunity.applicationOpenDate?.toDate();
    final isUpcoming = applicationOpenDate != null && now.isBefore(applicationOpenDate);

    if (isUpcoming) {
      // Calculate time until open
      final daysUntil = applicationOpenDate.difference(now).inDays;
      final hoursUntil = applicationOpenDate.difference(now).inHours;

      String timeMessage;
      if (daysUntil > 0) {
        timeMessage = 'Opens in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}';
      } else if (hoursUntil > 0) {
        timeMessage = 'Opens in $hoursUntil ${hoursUntil == 1 ? 'hour' : 'hours'}';
      } else {
        timeMessage = 'Opens soon';
      }

      return SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: null, // Disabled
              icon: const Icon(Icons.schedule),
              label: const Text(
                "Application Not Yet Open",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              timeMessage,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Application period is open
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isApplying ? null : _applyNow, // Disable button while applying
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isApplying
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                "Apply Now",
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusAndWithdrawView() {
    final status = _currentApplication!.status;
    final canWithdraw =
        status.toLowerCase() == 'pending' || status.toLowerCase() == 'reviewed';

    return Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Status:',
              style: GoogleFonts.lato(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusChip(status), // Show status (e.g., "Pending")
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: canWithdraw ? _withdrawApplication : null, // Enable/disable
            style: ElevatedButton.styleFrom(
              backgroundColor: canWithdraw ? Colors.red.shade700 : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Withdraw',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.lato(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hired':
      case 'accepted':
        return Colors.green.shade600;
      case 'reviewed':
        return Colors.blue.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'withdrawn':
        return Colors.grey.shade600;
      case 'pending':
      default:
        return Colors.orange.shade700;
    }
  }
}
