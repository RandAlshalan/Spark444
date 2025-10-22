import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Make sure these paths are correct for your project ---
import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/bookmarkService.dart';
import '../models/Application.dart'; 
import '../services/applicationService.dart';
// ---------------------------------------------------------

// --- Constants ---
const _purple = Color(0xFF422F5D);
const _pink = Color(0xFFD64483);

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
                                final reviewsCount =
                                    company.studentReviews.length;
                                return Center(
                                  child: TabBar(
                                    isScrollable: true,
                                    labelColor: Colors.black,
                                    labelStyle: GoogleFonts.lato(
                                        fontWeight: FontWeight.w700),
                                    unselectedLabelStyle: GoogleFonts.lato(),
                                    unselectedLabelColor:
                                        Colors.black.withOpacity(0.5),
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

                  // -------- Tab Content (from File 2)
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

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.reviewCount});
  final int reviewCount;

  // Dummy reviews data
  final List<Map<String, dynamic>> _dummyReviews = const [
    {
      'studentName': 'Sarah Ahmed',
      'rating': 5,
      'date': '2 weeks ago',
      'position': 'Software Engineering Intern',
      'review': 'Amazing experience! The team was incredibly supportive and I learned so much about modern development practices. The mentorship program is outstanding.',
    },
    {
      'studentName': 'Mohammed Ali',
      'rating': 4,
      'date': '1 month ago',
      'position': 'Data Science Intern',
      'review': 'Great company culture and excellent learning opportunities. The projects were challenging but rewarding. Would definitely recommend to other students.',
    },
    {
      'studentName': 'Layla Hassan',
      'rating': 5,
      'date': '1 month ago',
      'position': 'Marketing Intern',
      'review': 'Fantastic internship experience! I got to work on real campaigns and the team treated me like a valued member. Great work-life balance too.',
    },
    {
      'studentName': 'Omar Abdullah',
      'rating': 4,
      'date': '2 months ago',
      'position': 'Business Analyst Intern',
      'review': 'Very professional environment with plenty of opportunities to grow. The team was helpful and the work was meaningful. Minor issues with remote setup but overall great.',
    },
    {
      'studentName': 'Fatima Ibrahim',
      'rating': 5,
      'date': '3 months ago',
      'position': 'UI/UX Design Intern',
      'review': 'Best internship I could have asked for! The design team was amazing and I got hands-on experience with real client projects. Highly recommend!',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_dummyReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet.',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: _dummyReviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final review = _dummyReviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name and Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['studentName'],
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        review['position'],
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStarRating(review['rating']),
              ],
            ),
            const SizedBox(height: 12),
            // Review text
            Text(
              review['review'],
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // Date
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  review['date'],
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating ? const Color(0xFFF99D46) : Colors.grey.shade400,
          size: 20,
        );
      }),
    );
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

// Simple extension to capitalize strings, useful for status chips
