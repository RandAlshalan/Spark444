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
import '../models/interview_review.dart';
import '../models/Application.dart';
import '../models/resume.dart';
import '../services/applicationService.dart';
import '../companyScreens/companyStudentProfilePage.dart'; // NEW: company-facing student profile view
import 'resumeSelectionDialog.dart';
import 'applicationConfirmationDialog.dart';
import '../widgets/application_success_dialog.dart';
// ---------------------------------------------------------

// --- Constants ---
const _purple = Color(0xFF422F5D);
const _pink = Color(0xFFD64483);

// New: review length limits
const int _reviewMinLength = 1;
const int _reviewMaxLength = 300;
// ---------------------------------------------------------

// ----------------------- VoteButtons widget -----------------------
class VoteButtons extends StatelessWidget {
  final DocumentReference docRef;

  const VoteButtons({required this.docRef, super.key});

  Future<void> _toggleVote(DocumentReference targetDocRef, String uid, int clickedVote) async {
    final voteDocRef = targetDocRef.collection('votes').doc(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final voteSnap = await tx.get(voteDocRef);
      final itemSnap = await tx.get(targetDocRef);

      final currentVote = voteSnap.exists ? (voteSnap.data()!['vote'] as int? ?? 0) : 0;
      final desiredVote = (currentVote == clickedVote) ? 0 : clickedVote;

      int deltaLikes = 0;
      int deltaDislikes = 0;

      if (currentVote == 1) deltaLikes -= 1;
      if (currentVote == -1) deltaDislikes -= 1;
      if (desiredVote == 1) deltaLikes += 1;
      if (desiredVote == -1) deltaDislikes += 1;

      if (desiredVote == 0) {
        if (voteSnap.exists) tx.delete(voteDocRef);
      } else {
        tx.set(voteDocRef, {'vote': desiredVote});
      }

      final updates = <String, dynamic>{};
      if (deltaLikes != 0) updates['likesCount'] = FieldValue.increment(deltaLikes);
      if (deltaDislikes != 0) updates['dislikesCount'] = FieldValue.increment(deltaDislikes);

      if (updates.isNotEmpty) {
        if (itemSnap.exists) {
          tx.update(targetDocRef, updates);
        } else {
          tx.set(targetDocRef, {'likesCount': 0, 'dislikesCount': 0, ...updates}, SetOptions(merge: true));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, itemSnap) {
        final data = itemSnap.data?.data() as Map<String, dynamic>? ?? {};
        final likes = (data['likesCount'] as num?)?.toInt() ?? 0;
        final dislikes = (data['dislikesCount'] as num?)?.toInt() ?? 0;

        if (uid == null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.thumb_up, size: 18), color: Colors.grey.shade600, onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to vote')))),
              Text('$likes', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.thumb_down, size: 18), color: Colors.grey.shade600, onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to vote')))),
              Text('$dislikes', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          );
        }

        final voteDocRef = docRef.collection('votes').doc(uid);

        return StreamBuilder<DocumentSnapshot>(
          stream: voteDocRef.snapshots(),
          builder: (context, voteSnap) {
            final userVote = voteSnap.data?.exists == true
                ? ((voteSnap.data!.data() as Map<String, dynamic>?)?['vote'] as int? ?? 0)
                : 0;
            final likeActive = userVote == 1;
            final dislikeActive = userVote == -1;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up, size: 18),
                  color: likeActive ? _purple : Colors.grey.shade600,
                  onPressed: () async {
                    try {
                      await _toggleVote(docRef, uid, 1);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
                    }
                  },
                ),
                Text('$likes', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.thumb_down, size: 18),
                  color: dislikeActive ? _purple : Colors.grey.shade600,
                  onPressed: () async {
                    try {
                      await _toggleVote(docRef, uid, -1);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
                    }
                  },
                ),
                Text('$dislikes', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
              ],
            );
          },
        );
      },
    );
  }
}
// --------------------- end VoteButtons ---------------------

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
          length: 4,
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
                                      return StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('interview_reviews').where('companyId', isEqualTo: companyId).snapshots(),
                                        builder: (context, interviewSnap) {
                                          final interviewCount = interviewSnap.data?.size ?? 0;
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
                                              Tab(text: 'Interview ($interviewCount)'),
                                            ],
                                          );
                                        }
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
                        _InterviewReviewsTab(
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
  final List<Review> replies; // replies authored by students (stored as top-level reviews with parentId)
  final List<_Reply> companyReplies; // replies stored in subcollection (company replies)

  _ReviewThread({
    required this.review,
    required this.replies,
    required this.companyReplies,
  });
}

// Lightweight reply model for company replies (and any subcollection-based replies)
class _Reply {
  final String id;
  final String authorId;
  final String authorName; // company name or student name
  final String authorType; // 'company' or 'student'
  final String text;
  final Timestamp createdAt;

  _Reply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorType,
    required this.text,
    required this.createdAt,
  });

  factory _Reply.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return _Reply(
      id: doc.id,
      authorId: (data['authorId'] ?? '') as String,
      authorName: (data['authorName'] ?? '') as String,
      authorType: (data['authorType'] ?? 'company') as String,
      text: (data['text'] ?? data['replyText'] ?? '') as String,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
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
        builder: (_) => CompanyStudentProfilePage(studentId: studentId),
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
      // IMPORTANT: do not attach a listener that calls setState() on every keystroke.
      // We'll update _replyHasText via the TextField.onChanged handler only when toggling.
    }
    return controller;
  }

  // Fetch all reviews for the company in a single query, then group them into threads.
  // This version also fetches the 'replies' subcollection documents under each parent review
  // and merges them as companyReplies so they appear under the correct review.
  Stream<List<_ReviewThread>> _getReviewsStream() {
    final reviewsQuery = FirebaseFirestore.instance
        .collection('reviews')
        .where('companyId', isEqualTo: widget.companyId)
        .orderBy('createdAt', descending: true);

    // Use asyncMap to allow awaiting per-review subcollection reads.
    return reviewsQuery.snapshots().asyncMap((snapshot) async {
      // Build Review objects for all docs
      final allReviews = snapshot.docs.map((doc) {
        final r = Review.fromFirestore(doc);
        // parentId already present for student replies stored as top-level reviews.
        return r;
      }).toList();

      // Map review id -> List<Review> to hold student replies which are stored as separate review docs (parentId).
      final Map<String, List<Review>> repliesMap = {};
      for (var r in allReviews) {
        if (r.parentId != null && r.parentId!.isNotEmpty) {
          repliesMap.putIfAbsent(r.parentId!, () => []).add(r);
        }
      }

      final List<_ReviewThread> threads = [];

      // For each top-level review (parentId == null or empty), also read the 'replies' subcollection
      // to retrieve company replies stored there.
      for (var doc in snapshot.docs) {
        final top = Review.fromFirestore(doc);
        if (top.parentId != null && top.parentId!.isNotEmpty) {
          // Skip non-root top-level iteration; they are replies already
          continue;
        }

        // Student replies (top-level replies that have parentId == top.id)
        final studentReplies = repliesMap[top.id] ?? [];

        // Fetch company replies from subcollection `reviews/{top.id}/replies`
        final repliesCol = doc.reference.collection('replies');
        List<_Reply> companyReplies = [];
        try {
          final repliesSnapshot = await repliesCol.orderBy('createdAt', descending: false).get();
          companyReplies = repliesSnapshot.docs.map((d) => _Reply.fromDoc(d)).toList();
        } catch (e) {
          // If a per-review replies fetch fails we swallow and continue (non-fatal).
          // You may want to log this in real app.
          companyReplies = [];
        }

        // Merge both lists into a thread; keep student replies in the original order (they already have createdAt).
        // Company replies are ordered by createdAt from the subcollection query above.
        threads.add(_ReviewThread(
          review: top,
          replies: studentReplies,
          companyReplies: companyReplies,
        ));
      }

      // Sort threads by top-level review createdAt descending (newest first)
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
  // Defensive: avoid calling .doc('') which causes the invalid argument error.
  if (reviewId.trim().isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete: invalid review id.'), backgroundColor: Colors.red),
      );
    }
    return;
  }

  if (widget.studentId == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to delete your content.'), backgroundColor: Colors.red),
      );
    }
    return;
  }

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

  if (confirmed != true) return;

  try {
    final reviewsCol = FirebaseFirestore.instance.collection('reviews');

    if (isParent) {
      // Only allow deleting the parent review if the current student is the author.
      final parentDocRef = reviewsCol.doc(reviewId);
      final parentSnap = await parentDocRef.get();
      if (!parentSnap.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review not found.'), backgroundColor: Colors.red));
        return;
      }
      final parentData = parentSnap.data() as Map<String, dynamic>? ?? {};
      final parentStudentId = (parentData['studentId'] ?? '').toString();

      if (parentStudentId != widget.studentId) {
        // Not the owner — do not allow mass deletion.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only delete your own review.'), backgroundColor: Colors.red));
        }
        return;
      }

      // Delete the parent document (the student's own review)
      // Also delete any child replies authored by this same student (but do NOT delete other users' replies or company replies)
      final batch = FirebaseFirestore.instance.batch();

      // Delete child replies authored by this student (top-level docs with parentId + studentId)
      final childRepliesSnap = await reviewsCol
          .where('parentId', isEqualTo: reviewId)
          .where('studentId', isEqualTo: widget.studentId)
          .get();
      for (final d in childRepliesSnap.docs) {
        batch.delete(d.reference);
      }

      batch.delete(parentDocRef);
      await batch.commit();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green));
    } else {
      // Deleting a single reply document. Allow only if the current student is the author.
      final docRef = reviewsCol.doc(reviewId);
      final snap = await docRef.get();
      if (!snap.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply not found.'), backgroundColor: Colors.red));
        return;
      }
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final replyStudentId = (data['studentId'] ?? '').toString();
      final authorType = (data['authorType'] ?? '').toString();

      if (replyStudentId != widget.studentId) {
        // Not the author. If it's a company reply (authorType == 'company') students cannot delete it here.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only delete your own replies.'), backgroundColor: Colors.red));
        }
        return;
      }

      await docRef.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply deleted'), backgroundColor: Colors.green));
    }
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
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
  // Ensure reply controller and states exist (existing code may do this)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // existing parent review UI (author, text, stars...) - keep as-is
          _buildReviewCard(thread.review),

          const SizedBox(height: 8),

          // Student replies (if any) - existing handling
          ...thread.replies.map((r) => _buildReplyTile(r)).toList(),

          // Company replies (from subcollection) - rendered in a visually distinct style
          ...thread.companyReplies.map((cr) => _buildCompanyReplyTile(cr)).toList(),

          // existing reply input/toggle UI (show reply button, reply textbox etc)
          // Reply toggle + input area for students
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  final cur = _showReplyBox[parentId] ?? false;
                  _showReplyBox[parentId] = !cur;
                  if (_showReplyBox[parentId] == true) {
                    // ensure controller exists before the user types
                    _ensureReplyController(parentId);
                  }
                });
              },
              icon: Icon(
                (_showReplyBox[parentId] ?? false) ? Icons.expand_less : Icons.reply,
                color: _purple,
              ),
              label: Text(
                (_showReplyBox[parentId] ?? false) ? 'Hide' : 'Reply',
                style: const TextStyle(color: _purple),
              ),
            ),
          ),

          if (_showReplyBox[parentId] ?? false) ...[
            const SizedBox(height: 8),
            // Reply input
            TextField(
              controller: _replyControllers[parentId],
              maxLines: 3,
              minLines: 1,
              inputFormatters: [LengthLimitingTextInputFormatter(_reviewMaxLength)],
              decoration: InputDecoration(
                hintText: 'Write a reply…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
                counterText: '',
              ),
              onChanged: (v) {
                // update internal flag without setState to avoid rebuilds per keystroke
                final has = v.trim().isNotEmpty;
                _replyHasText[parentId] = has;
              },
            ),
            const SizedBox(height: 8),

            // Author visibility + send button
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: _replyAuthorVisible[parentId] ?? true,
                        activeColor: _purple,
                        onChanged: (val) {
                          setState(() {
                            _replyAuthorVisible[parentId] = val;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      Text('Show my profile', style: GoogleFonts.lato(fontSize: 14)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (_isReplySubmitting[parentId] ?? false)
                      ? null
                      : () {
                          // Submit: call existing submit handler which performs validation & shows snackbars
                          _submitReply(parentId);
                        },
                  icon: (_isReplySubmitting[parentId] ?? false)
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text((_isReplySubmitting[parentId] ?? false) ? 'Sending' : 'Reply'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

// New helper to render a company reply
Widget _buildCompanyReplyTile(_Reply reply, [String? parentReviewId]) {
  // Compute the docRef for this reply:
  // Preferred path: reviews/{parentReviewId}/replies/{reply.id} when parentReviewId available.
  // Fallback: reviews/{reply.id} (harmless but won't reflect the actual reply doc if it's stored in subcollection).
  DocumentReference docRef;
  if (parentReviewId != null && parentReviewId.trim().isNotEmpty) {
    docRef = FirebaseFirestore.instance.collection('reviews').doc(parentReviewId).collection('replies').doc(reply.id);
  } else {
    docRef = FirebaseFirestore.instance.collection('reviews').doc(reply.id);
  }

  final createdAt = reply.createdAt.toDate();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8, bottom: 6),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F4EF), // company reply background, slightly different
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.reply, size: 18, color: _purple),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reply.text, style: GoogleFonts.lato(fontSize: 14)),
              const SizedBox(height: 6),
              Text(reply.authorName, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(DateFormat('MMM d, yyyy').format(createdAt), style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              // Votes for the company reply (we computed docRef above)
              VoteButtons(docRef: docRef),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildReviewCard(Review review) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Builder(builder: (ctx) {
    final visible = (review.authorVisible ?? true);

    // If we have a non-empty studentId, stream the student doc for up-to-date name; otherwise fall back to stored name.
    if (review.studentId.isNotEmpty) {
      return GestureDetector(
        onTap: () => _openStudentProfile(studentId: review.studentId, authorVisible: visible),
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
            final displayName = visible ? (currentName.isNotEmpty ? currentName : review.studentName) : 'Anonymous';
            return Text(displayName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: _purple));
          },
        ),
      );
    } else {
      // No studentId: render the stored name (or Anonymous) and don't allow navigation.
      final displayName = visible ? (review.studentName.isNotEmpty ? review.studentName : 'Student') : 'Anonymous';
      return Text(displayName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: _purple));
    }
  }),
),
        // Stars + optional delete for owner
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStarRating(review.rating.toInt()),
            if ((review.studentId ?? '') == (widget.studentId ?? ''))
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete your review',
                onPressed: () => _confirmAndDelete(review.id, isParent: true),
              ),
          ],
        ),
      ]),
      const SizedBox(height: 8),
      Text(review.reviewText, style: GoogleFonts.lato(fontSize: 14, color: Colors.black87, height: 1.5)),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(DateFormat('MMM d, yyyy').format(review.createdAt.toDate()), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
      ]),
      const SizedBox(height: 6),
      // Votes for the review (safe guard)
      if (review.id.trim().isNotEmpty)
        VoteButtons(docRef: FirebaseFirestore.instance.collection('reviews').doc(review.id)),
    ]);
  }

  Widget _buildReplyTile(Review reply) {
  // Helper to compute initials from a name string
  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }

  final hasStudentId = reply.studentId.isNotEmpty;

  return Padding(
    padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey.shade200,
        child: Builder(builder: (ctx) {
          if (hasStudentId) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('student').doc(reply.studentId).snapshots(),
              builder: (context, studentSnap) {
                String nameForInitials = reply.studentName;
                if (studentSnap.hasData && studentSnap.data?.data() != null) {
                  final sd = studentSnap.data!.data()!;
                  final fn = (sd['firstName'] ?? '').toString().trim();
                  final ln = (sd['lastName'] ?? '').toString().trim();
                  final combined = '$fn ${ln}'.trim();
                  if (combined.isNotEmpty) nameForInitials = combined;
                }
                final initials = _initialsFromName(nameForInitials);
                return Text(initials, style: GoogleFonts.lato(fontSize: 12, color: _purple));
              },
            );
          } else {
            // No student id: show initials from stored name
            final initials = _initialsFromName(reply.studentName);
            return Text(initials, style: GoogleFonts.lato(fontSize: 12, color: _purple));
          }
        }),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Builder(builder: (ctx) {
            final visible = (reply.authorVisible ?? true);
            if (hasStudentId) {
              return GestureDetector(
                onTap: () => _openStudentProfile(studentId: reply.studentId, authorVisible: visible),
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
                    final displayName = visible ? (currentName.isNotEmpty ? currentName : reply.studentName) : 'Anonymous';
                    return Text(displayName, style: GoogleFonts.lato(fontWeight: FontWeight.w700, color: _purple));
                  },
                ),
              );
            } else {
              final displayName = (reply.authorVisible ?? true) ? (reply.studentName.isNotEmpty ? reply.studentName : 'Student') : 'Anonymous';
              return Text(displayName, style: GoogleFonts.lato(fontWeight: FontWeight.w700, color: _purple));
            }
          }),
          const SizedBox(height: 4),
          Text(reply.reviewText, style: GoogleFonts.lato(fontSize: 13, color: Colors.black87, height: 1.4)),
          const SizedBox(height: 6),
          Row(
      children: [
        Text(DateFormat('MMM d, yyyy').format(reply.createdAt.toDate()), style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        if ((reply.studentId ?? '') == (widget.studentId ?? ''))
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            tooltip: 'Delete your reply',
            onPressed: () => _confirmAndDelete(reply.id, isParent: false),
          ),
        // Add spacer then votes so votes appear on the right like other places
        const Spacer(),
        if (reply.id.trim().isNotEmpty)
          VoteButtons(docRef: FirebaseFirestore.instance.collection('reviews').doc(reply.id)),
      ],
    ),
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
// == INTERVIEW REVIEWS TAB WIDGET
// =========================================================================

class _InterviewReviewThread {
  final InterviewReview review;
  final List<InterviewReview> replies;
  final List<_Reply> companyReplies;

  _InterviewReviewThread({
    required this.review,
    required this.replies,
    required this.companyReplies,
  });
}

class _InterviewReviewsTab extends StatefulWidget {
  const _InterviewReviewsTab({required this.companyId, required this.studentId});
  final String companyId;
  final String? studentId;

  @override
  State<_InterviewReviewsTab> createState() => _InterviewReviewsTabState();
}

class _InterviewReviewsTabState extends State<_InterviewReviewsTab> {
  final _reviewController = TextEditingController();
  bool? _overallExperience; // true = like, false = dislike
  String? _selectedDifficulty;
  bool _isSubmitting = false;
  bool _authorVisible = true;

  // Interview-specific fields
  final _interviewQuestionsController = TextEditingController();
  final _interviewAnswersController = TextEditingController();
  String? _wasAccepted;

  final List<String> _difficultyLevels = ['Very Easy', 'Easy', 'Average', 'Medium', 'Hard'];
  final List<String> _acceptanceOptions = ['Yes', 'No', 'Not Sure'];

  // Reply UI state per root review id
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReplyBox = {};
  final Map<String, bool> _replyAuthorVisible = {};
  final Map<String, bool> _isReplySubmitting = {};
  final Map<String, bool> _replyHasText = {};

  @override
  void dispose() {
    _reviewController.dispose();
    _interviewQuestionsController.dispose();
    _interviewAnswersController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ensureReplyController(String parentId) {
    var created = false;
    final controller = _replyControllers.putIfAbsent(parentId, () {
      created = true;
      return TextEditingController();
    });

    if (created) {
      _replyAuthorVisible[parentId] = true;
      _replyHasText[parentId] = controller.text.trim().isNotEmpty;
    }
    return controller;
  }

  Stream<List<_InterviewReviewThread>> _getInterviewReviewsStream() {
    final reviewsQuery = FirebaseFirestore.instance
        .collection('interview_reviews')
        .where('companyId', isEqualTo: widget.companyId)
        .orderBy('createdAt', descending: true);

    return reviewsQuery.snapshots().asyncMap((snapshot) async {
      final allReviews = snapshot.docs.map((doc) {
        return InterviewReview.fromFirestore(doc);
      }).toList();

      final Map<String, List<InterviewReview>> repliesMap = {};
      for (var r in allReviews) {
        if (r.parentId != null && r.parentId!.isNotEmpty) {
          repliesMap.putIfAbsent(r.parentId!, () => []).add(r);
        }
      }

      final List<_InterviewReviewThread> threads = [];

      for (var doc in snapshot.docs) {
        final top = InterviewReview.fromFirestore(doc);
        if (top.parentId != null && top.parentId!.isNotEmpty) {
          continue;
        }

        final studentReplies = repliesMap[top.id] ?? [];

        final repliesCol = doc.reference.collection('replies');
        List<_Reply> companyReplies = [];
        try {
          final repliesSnapshot = await repliesCol.orderBy('createdAt', descending: false).get();
          companyReplies = repliesSnapshot.docs.map((d) => _Reply.fromDoc(d)).toList();
        } catch (e) {
          companyReplies = [];
        }

        threads.add(_InterviewReviewThread(
          review: top,
          replies: studentReplies,
          companyReplies: companyReplies,
        ));
      }

      threads.sort((a, b) => b.review.createdAt.toDate().compareTo(a.review.createdAt.toDate()));

      return threads;
    });
  }

  Future<void> _submitInterviewReview() async {
    // Validate Overall Experience (required)
    if (_overallExperience == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your overall experience (Like or Dislike)'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        )
      );
      return;
    }

    // Validate Interview Difficulty (required)
    if (_selectedDifficulty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select interview difficulty'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        )
      );
      return;
    }

    // Validate Interview Questions (required)
    if (_interviewQuestionsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please share what questions they asked you'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        )
      );
      return;
    }

    // Validate Did you get accepted (required)
    if (_wasAccepted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please indicate if you got accepted'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        )
      );
      return;
    }

    if (widget.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to leave a review.'))
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final studentDoc = await FirebaseFirestore.instance.collection('student').doc(widget.studentId).get();
      final first = (studentDoc.data()?['firstName'] ?? '').toString();
      final last = (studentDoc.data()?['lastName'] ?? '').toString();
      final studentName = ('$first $last').trim();

      // Convert overall experience to rating for compatibility
      double rating = 3.0; // Default neutral
      if (_overallExperience == true) rating = 5.0; // Like
      if (_overallExperience == false) rating = 1.0; // Dislike

      final reviewData = {
        'studentId': widget.studentId!,
        'studentName': studentName,
        'companyId': widget.companyId,
        'rating': rating,
        'reviewText': '', // Empty string for compatibility with existing data model
        'createdAt': Timestamp.now(),
        'authorVisible': _authorVisible,
        'interviewDifficulty': _selectedDifficulty,
        'interviewQuestions': _interviewQuestionsController.text.trim().isNotEmpty ? _interviewQuestionsController.text.trim() : null,
        'interviewAnswers': _interviewAnswersController.text.trim().isNotEmpty ? _interviewAnswersController.text.trim() : null,
        'wasAccepted': _wasAccepted,
      };

      await FirebaseFirestore.instance.collection('interview_reviews').add(reviewData);

      if (mounted) {
        // Close the modal
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your interview review!'), backgroundColor: Colors.green)
        );
        _reviewController.clear();
        _interviewQuestionsController.clear();
        _interviewAnswersController.clear();
        setState(() {
          _overallExperience = null;
          _selectedDifficulty = null;
          _wasAccepted = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitReply(String parentReviewId) async {
    final controller = _ensureReplyController(parentReviewId);
    final text = controller.text.trim();
    final visible = _replyAuthorVisible.putIfAbsent(parentReviewId, () => true);

    if (widget.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to reply.'))
      );
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply cannot be empty.'))
      );
      return;
    }
    if (text.length < _reviewMinLength || text.length > _reviewMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your reply must be between $_reviewMinLength and $_reviewMaxLength characters.'))
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isReplySubmitting[parentReviewId] = true);
    try {
      final studentDoc = await FirebaseFirestore.instance.collection('student').doc(widget.studentId).get();
      final first = (studentDoc.data()?['firstName'] ?? '').toString();
      final last = (studentDoc.data()?['lastName'] ?? '').toString();
      final studentName = ('$first $last').trim();

      final replyData = {
        'studentId': widget.studentId!,
        'studentName': studentName,
        'companyId': widget.companyId,
        'rating': 0,
        'reviewText': text,
        'createdAt': Timestamp.now(),
        'authorVisible': visible,
        'parentId': parentReviewId,
      };

      await FirebaseFirestore.instance.collection('interview_reviews').add(replyData);

      if (!mounted) return;
      controller.clear();
      setState(() {
        _showReplyBox[parentReviewId] = false;
        _replyHasText[parentReviewId] = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit reply: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReplySubmitting[parentReviewId] = false);
      }
    }
  }

  Future<void> _confirmAndDelete(String reviewId, {required bool isParent}) async {
    if (reviewId.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete: invalid review id.'), backgroundColor: Colors.red)
        );
      }
      return;
    }

    if (widget.studentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to delete your content.'), backgroundColor: Colors.red)
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this item? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            child: const Text('Delete', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final reviewsCol = FirebaseFirestore.instance.collection('interview_reviews');

      if (isParent) {
        final parentDocRef = reviewsCol.doc(reviewId);
        final parentSnap = await parentDocRef.get();
        if (!parentSnap.exists) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review not found.'), backgroundColor: Colors.red)
          );
          return;
        }
        final parentData = parentSnap.data() as Map<String, dynamic>? ?? {};
        final parentStudentId = (parentData['studentId'] ?? '').toString();

        if (parentStudentId != widget.studentId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can only delete your own review.'), backgroundColor: Colors.red)
            );
          }
          return;
        }

        final batch = FirebaseFirestore.instance.batch();

        final childRepliesSnap = await reviewsCol
            .where('parentId', isEqualTo: reviewId)
            .where('studentId', isEqualTo: widget.studentId)
            .get();
        for (final d in childRepliesSnap.docs) {
          batch.delete(d.reference);
        }

        batch.delete(parentDocRef);
        await batch.commit();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green)
        );
      } else {
        final docRef = reviewsCol.doc(reviewId);
        final snap = await docRef.get();
        if (!snap.exists) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply not found.'), backgroundColor: Colors.red)
          );
          return;
        }
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final replyStudentId = (data['studentId'] ?? '').toString();

        if (replyStudentId != widget.studentId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can only delete your own replies.'), backgroundColor: Colors.red)
            );
          }
          return;
        }

        await docRef.delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply deleted'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red)
      );
    }
  }

  void _showWriteReviewDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildWriteInterviewReviewForm(setModalState),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWriteInterviewReviewForm(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with enhanced colors
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _purple.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withAlpha(80),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.rate_review, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Your Interview',
                      style: GoogleFonts.lato(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _purple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your experience to help others',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Overall Experience Section with enhanced design
        Row(
          children: [
            Icon(Icons.psychology_outlined, size: 20, color: _purple),
            const SizedBox(width: 8),
            Text(
              'Overall Experience',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      setState(() => _overallExperience = true);
                    });
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _overallExperience == true
                          ? _purple.withAlpha(25)
                          : Colors.grey.shade50,
                      border: Border.all(
                        color: _overallExperience == true
                            ? _purple
                            : Colors.grey.shade300,
                        width: _overallExperience == true ? 2.5 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _overallExperience == true
                          ? [
                              BoxShadow(
                                color: _purple.withAlpha(40),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.thumb_up_rounded,
                            key: ValueKey<bool>(_overallExperience == true),
                            color: _overallExperience == true
                                ? _purple
                                : Colors.grey.shade400,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: _overallExperience == true
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _overallExperience == true
                                ? _purple
                                : Colors.grey.shade600,
                          ),
                          child: const Text('Like'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      setState(() => _overallExperience = false);
                    });
                    HapticFeedback.lightImpact();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _overallExperience == false
                          ? _purple.withAlpha(25)
                          : Colors.grey.shade50,
                      border: Border.all(
                        color: _overallExperience == false
                            ? _purple
                            : Colors.grey.shade300,
                        width: _overallExperience == false ? 2.5 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _overallExperience == false
                          ? [
                              BoxShadow(
                                color: _purple.withAlpha(40),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            Icons.thumb_down_rounded,
                            key: ValueKey<bool>(_overallExperience == false),
                            color: _overallExperience == false
                                ? _purple
                                : Colors.grey.shade400,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            fontWeight: _overallExperience == false
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _overallExperience == false
                                ? _purple
                                : Colors.grey.shade600,
                          ),
                          child: const Text('Dislike'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Interview Difficulty Section with color coding
        Row(
          children: [
            Icon(Icons.speed_outlined, size: 20, color: _purple),
            const SizedBox(width: 8),
            Text(
              'Interview Difficulty',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _difficultyLevels.asMap().entries.map((entry) {
            final level = entry.value;
            final isSelected = _selectedDifficulty == level;

            // Color coding for difficulty levels
            Color getDifficultyColor() {
              switch(level) {
                case 'Very Easy': return const Color(0xFF10B981);
                case 'Easy': return const Color(0xFF3B82F6);
                case 'Average': return const Color(0xFFF59E0B);
                case 'Medium': return const Color(0xFFEF4444);
                case 'Hard': return const Color(0xFF991B1B);
                default: return Colors.grey;
              }
            }

            final color = getDifficultyColor();

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setModalState(() {
                    setState(() => _selectedDifficulty = level);
                  });
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withAlpha(25) : Colors.grey.shade50,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    level,
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        // Interview Questions Section
        Row(
          children: [
            Icon(Icons.quiz_outlined, size: 20, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Q: What were the main things they asked you?',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _interviewQuestionsController,
          maxLines: 5,
          maxLength: 1000,
          style: GoogleFonts.lato(fontSize: 15, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Share the questions you were asked...\ne.g., "Tell me about yourself", "Describe a challenging project you worked on"',
            hintStyle: GoogleFonts.lato(
              color: Colors.grey.shade400,
              fontSize: 14,
              height: 1.5,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _purple, width: 2.5),
            ),
            contentPadding: const EdgeInsets.all(18),
            counterStyle: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 28),

        // How You Answered (Optional)
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 20, color: _purple),
            const SizedBox(width: 8),
            Text(
              'How did you approach answering?',
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.lato(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _interviewAnswersController,
          maxLines: 4,
          maxLength: 1000,
          style: GoogleFonts.lato(fontSize: 15, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Describe your approach to answering (optional)...',
            hintStyle: GoogleFonts.lato(
              color: Colors.grey.shade400,
              fontSize: 14,
              height: 1.5,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _purple, width: 2.5),
            ),
            contentPadding: const EdgeInsets.all(18),
            counterStyle: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 28),

        // Additional Options Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Additional Information',
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Did you get accepted?',
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _wasAccepted,
                    decoration: InputDecoration(
                      hintText: 'Select an option',
                      hintStyle: GoogleFonts.lato(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _purple, width: 2.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: _acceptanceOptions.map((String option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(
                          option,
                          style: GoogleFonts.lato(fontSize: 15, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setModalState(() {
                        setState(() => _wasAccepted = newValue);
                      });
                    },
                    icon: Icon(Icons.arrow_drop_down, color: _purple),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setModalState(() {
                      setState(() => _authorVisible = !_authorVisible);
                    });
                    HapticFeedback.selectionClick();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _authorVisible ? _purple : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _authorVisible ? _purple : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: _authorVisible
                              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Show profile',
                                style: GoogleFonts.lato(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'If not, it\'s anonymous',
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Submit Button with enhanced styling
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _purple.withAlpha(80),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitInterviewReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Submit Interview Review',
                        style: GoogleFonts.lato(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F4FB),
      child: StreamBuilder<List<_InterviewReviewThread>>(
        stream: _getInterviewReviewsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final threads = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(child: _buildReviewListView(threads)),
              _buildRateInterviewFooter(context, threads.isEmpty),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewListView(List<_InterviewReviewThread> threads) {
    final children = <Widget>[
      if (threads.isNotEmpty) _buildInterviewInsights(threads),
    ];

    if (threads.isEmpty) {
      children.add(_buildEmptyState());
    } else {
      for (final thread in threads) {
        children
          ..add(_buildInterviewReviewThreadCard(thread))
          ..add(const SizedBox(height: 12));
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      children: children,
    );
  }

  Widget _buildInterviewInsights(List<_InterviewReviewThread> threads) {
    if (threads.isEmpty) return const SizedBox.shrink();

    final total = threads.length;
    final accepted = threads.where((t) => t.review.wasAccepted == 'Yes').length;
    final difficultyCounts = <String, int>{};
    for (final thread in threads) {
      final diff = thread.review.interviewDifficulty;
      if (diff == null || diff.trim().isEmpty) continue;
      final key = diff.trim();
      difficultyCounts[key] = (difficultyCounts[key] ?? 0) + 1;
    }

    String? mostCommonDifficulty;
    if (difficultyCounts.isNotEmpty) {
      mostCommonDifficulty = difficultyCounts.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      ).key;
    }

    final acceptancePercent = total == 0 ? 0 : ((accepted / total) * 100).round();

    Widget buildStat(String value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_purple, _pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interview insights',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              buildStat(total.toString(), 'reviews collected'),
              const SizedBox(width: 12),
              buildStat('$acceptancePercent%', 'accepted offers'),
            ],
          ),
          if (mostCommonDifficulty != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(mostCommonDifficulty!),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Most reported: $mostCommonDifficulty',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w700,
                      color: _purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateInterviewFooter(BuildContext context, bool noReviews) {
    final canSubmit = widget.studentId != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_purple, _pink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _purple.withOpacity(0.18),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                noReviews ? 'Be the first to rate this interview' : 'Share your interview experience',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                canSubmit
                    ? 'Tell other students about the process, the questions asked, and how hard it felt.'
                    : 'Sign in to tell other students about the interview process.',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSubmit ? () => _showWriteReviewDialog(context) : null,
                  icon: Icon(canSubmit ? Icons.rate_review_outlined : Icons.lock_outline, size: 20),
                  label: Text(canSubmit ? 'Rate Interview' : 'Sign in to rate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _purple,
                    disabledBackgroundColor: Colors.white.withOpacity(0.35),
                    disabledForegroundColor: _purple.withOpacity(0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_purple, _pink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.quiz_outlined, size: 52, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'No interview reviews yet',
            style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your interview experience and help others prepare!',
            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewReviewThreadCard(_InterviewReviewThread thread) {
    final parentId = thread.review.id;
    _ensureReplyController(parentId);
    _showReplyBox.putIfAbsent(parentId, () => false);
    _replyAuthorVisible.putIfAbsent(parentId, () => true);
    _isReplySubmitting.putIfAbsent(parentId, () => false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInterviewReviewCard(thread.review),
            if (thread.replies.isNotEmpty || thread.companyReplies.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 12),
            ],
            ...thread.replies.map((r) => _buildInterviewReplyTile(r)),
            ...thread.companyReplies.map((cr) => _buildCompanyReplyTile(cr)),

            // Reply button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    final cur = _showReplyBox[parentId] ?? false;
                    _showReplyBox[parentId] = !cur;
                    if (_showReplyBox[parentId] == true) {
                      _ensureReplyController(parentId);
                    }
                  });
                },
                icon: Icon(
                  (_showReplyBox[parentId] ?? false) ? Icons.expand_less : Icons.reply,
                  color: _purple,
                ),
                label: Text(
                  (_showReplyBox[parentId] ?? false) ? 'Hide' : 'Reply',
                  style: const TextStyle(color: _purple),
                ),
              ),
            ),

            if (_showReplyBox[parentId] ?? false) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _replyControllers[parentId],
                maxLines: 3,
                minLines: 1,
                inputFormatters: [LengthLimitingTextInputFormatter(_reviewMaxLength)],
                decoration: InputDecoration(
                  hintText: 'Write a reply…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                  counterText: '',
                ),
                onChanged: (v) {
                  _replyHasText[parentId] = v.trim().isNotEmpty;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Switch(
                          value: _replyAuthorVisible[parentId] ?? true,
                          activeColor: _purple,
                          onChanged: (val) {
                            setState(() {
                              _replyAuthorVisible[parentId] = val;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        Text('Show my profile', style: GoogleFonts.lato(fontSize: 14)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_isReplySubmitting[parentId] ?? false)
                        ? null
                        : () => _submitReply(parentId),
                    icon: (_isReplySubmitting[parentId] ?? false)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Icon(Icons.send),
                    label: Text((_isReplySubmitting[parentId] ?? false) ? 'Sending' : 'Reply'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInterviewReviewCard(InterviewReview review) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _purple.withAlpha(80), width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: _purple.withAlpha(25),
                  child: Text(
                    _getInitials((review.authorVisible) ? review.studentName : 'A'),
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _purple,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (review.authorVisible) ? (review.studentName.isNotEmpty ? review.studentName : 'Student') : 'Anonymous',
                    style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(review.createdAt.toDate()),
                        style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (review.studentId == widget.studentId)
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                tooltip: 'Delete your review',
                onPressed: () => _confirmAndDelete(review.id, isParent: true),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Overall experience badge
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Overall Experience (Like/Dislike)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: review.rating >= 4 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: review.rating >= 4 ? Colors.green.shade300 : Colors.red.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    review.rating >= 4 ? Icons.thumb_up : Icons.thumb_down,
                    size: 16,
                    color: review.rating >= 4 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    review.rating >= 4 ? 'Like' : 'Dislike',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: review.rating >= 4 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // Difficulty Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getDifficultyColor(review.interviewDifficulty ?? 'Medium').withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getDifficultyColor(review.interviewDifficulty ?? 'Medium').withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                review.interviewDifficulty ?? 'Medium',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _getDifficultyColor(review.interviewDifficulty ?? 'Medium'),
                ),
              ),
            ),
            if (review.wasAccepted != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: review.wasAccepted == 'Yes'
                      ? Colors.green.shade50
                      : review.wasAccepted == 'No'
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: review.wasAccepted == 'Yes'
                        ? Colors.green.shade300
                        : review.wasAccepted == 'No'
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      review.wasAccepted == 'Yes'
                          ? Icons.check_circle
                          : review.wasAccepted == 'No'
                              ? Icons.cancel
                              : Icons.help_outline,
                      size: 16,
                      color: review.wasAccepted == 'Yes'
                          ? Colors.green.shade700
                          : review.wasAccepted == 'No'
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.wasAccepted == 'Yes'
                          ? 'Accepted'
                          : review.wasAccepted == 'No'
                              ? 'Not Accepted'
                              : 'Not Sure',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: review.wasAccepted == 'Yes'
                            ? Colors.green.shade700
                            : review.wasAccepted == 'No'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Interview questions section
        if (review.interviewQuestions != null && review.interviewQuestions!.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.question_answer, size: 18, color: _purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q: What were the main things they asked you?',
                  style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              review.interviewQuestions!,
              style: GoogleFonts.lato(fontSize: 14, color: Colors.black87, height: 1.6),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Interview answers section (optional)
        if (review.interviewAnswers != null && review.interviewAnswers!.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'How did you approach answering?',
                  style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              review.interviewAnswers!,
              style: GoogleFonts.lato(fontSize: 14, color: Colors.black87, height: 1.6),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildInterviewReplyTile(InterviewReview reply) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            child: Text(
              _getInitials(reply.studentName),
              style: GoogleFonts.lato(fontSize: 12, color: _purple)
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (reply.authorVisible) ? (reply.studentName.isNotEmpty ? reply.studentName : 'Student') : 'Anonymous',
                  style: GoogleFonts.lato(fontWeight: FontWeight.w700, color: _purple)
                ),
                const SizedBox(height: 4),
                Text(reply.reviewText, style: GoogleFonts.lato(fontSize: 13, color: Colors.black87, height: 1.4)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(reply.createdAt.toDate()),
                      style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)
                    ),
                    const SizedBox(width: 8),
                    if (reply.studentId == widget.studentId)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        tooltip: 'Delete your reply',
                        onPressed: () => _confirmAndDelete(reply.id, isParent: false),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyReplyTile(_Reply reply) {
    final createdAt = reply.createdAt.toDate();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.reply, size: 18, color: _purple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reply.text.isEmpty ? '—' : reply.text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      reply.authorName.isEmpty ? 'Company' : reply.authorName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(createdAt.toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.trim().toLowerCase()) {
      case 'very easy':
        return const Color(0xFF10B981);
      case 'easy':
        return const Color(0xFF34D399);
      case 'average':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFFEF4444);
      case 'hard':
        return const Color(0xFF991B1B);
      default:
        return _purple;
    }
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

    final selection = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResumeSelectionDialog(studentId: _studentId!),
    );

    if (selection == null) return;

    final resume = selection['resume'] as Resume?;
    final coverLetter = selection['coverLetter'] as String?;

    if (resume == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a resume to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ApplicationConfirmationDialog(
        opportunity: widget.opportunity,
        resume: resume,
        coverLetter: coverLetter,
      ),
    );

    if (confirm != true) return;

    setState(() => _isApplying = true);
    try {
      await _applicationService.submitApplication(
        studentId: _studentId!,
        opportunityId: widget.opportunity.id,
        resumeId: resume.id,
        resumePdfUrl: resume.pdfUrl,
        coverLetterText: coverLetter,
      );

      if (!mounted) return;

      final includeCoverLetter =
          coverLetter != null && coverLetter.trim().isNotEmpty;

      await _fetchApplicationStatus();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ApplicationSuccessDialog(
          opportunityTitle: widget.opportunity.role,
          companyName: null,
          resumeTitle: resume.title,
          includeCoverLetter: includeCoverLetter,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
