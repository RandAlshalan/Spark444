import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/company.dart';
import '../models/opportunity.dart';
import '../services/bookmarkService.dart';

const _primaryColor = Color(0xFF422F5D);
const _secondaryColor = Color(0xFFD64483);

class StudentCompanyProfilePage extends StatefulWidget {
  const StudentCompanyProfilePage({super.key, required this.companyId});

  final String companyId;

  @override
  State<StudentCompanyProfilePage> createState() =>
      _StudentCompanyProfilePageState();
}

class _StudentCompanyProfilePageState
    extends State<StudentCompanyProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BookmarkService _bookmarkService = BookmarkService();

  Stream<DocumentSnapshot<Map<String, dynamic>>> _companyStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _opportunitiesStream() {
    return FirebaseFirestore.instance
        .collection('opportunities')
        .where('companyId', isEqualTo: widget.companyId)
        .orderBy('postedDate', descending: true)
        .snapshots();
  }

  Stream<bool> _isFollowingStream(String uid) {
    return FirebaseFirestore.instance
        .collection('student')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      final followed =
          List<String>.from(data?['followedCompanies'] ?? const <String>[]);
      return followed.contains(widget.companyId);
    });
  }

  Future<void> _toggleFollow({
    required String uid,
    required bool isFollowing,
  }) async {
    final ref =
        FirebaseFirestore.instance.collection('student').doc(uid);

    await ref.set(
      {
        'followedCompanies': isFollowing
            ? FieldValue.arrayRemove([widget.companyId])
            : FieldValue.arrayUnion([widget.companyId]),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company'),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _companyStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists ||
              snapshot.data!.data() == null) {
            return const Center(child: Text('Company not found.'));
          }

          final data = snapshot.data!.data()!;
          final company = Company.fromMap(snapshot.data!.id, data);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompanyHeader(
                  company: company,
                  uid: uid,
                  isFollowingStream:
                      uid == null ? null : _isFollowingStream(uid),
                  onToggleFollow: uid == null
                      ? null
                      : (isFollowing) =>
                          _toggleFollow(uid: uid, isFollowing: isFollowing),
                ),
                const SizedBox(height: 24),
                Text(
                  'Opportunities',
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _opportunitiesStream(),
                  builder: (context, oppSnapshot) {
                    if (oppSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = oppSnapshot.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('No opportunities from this company yet.'),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final opportunity = Opportunity.fromFirestore(doc);

                        return _OpportunityCard(
                          opportunity: opportunity,
                          bookmarkStream: uid == null
                              ? null
                              : _bookmarkService.isBookmarkedStream(
                                  studentId: uid,
                                  opportunityId: opportunity.id,
                                ),
                          onToggleBookmark: uid == null
                              ? null
                              : (isBookmarked) =>
                                  _toggleBookmark(uid, opportunity.id, isBookmarked),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleBookmark(
    String uid,
    String opportunityId,
    bool isBookmarked,
  ) async {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bookmark: $e')),
      );
    }
  }
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({
    required this.company,
    required this.uid,
    required this.isFollowingStream,
    required this.onToggleFollow,
  });

  final Company company;
  final String? uid;
  final Stream<bool>? isFollowingStream;
  final Future<void> Function(bool isFollowing)? onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = company.contactInfo.trim();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  backgroundImage: company.logoUrl != null &&
                          company.logoUrl!.isNotEmpty
                      ? NetworkImage(company.logoUrl!)
                      : null,
                  child: (company.logoUrl == null ||
                          company.logoUrl!.isEmpty)
                      ? Text(
                          company.companyName.isEmpty
                              ? '?'
                              : company.companyName
                                  .trim()
                                  .split(RegExp(r'\\s+'))
                                  .map((word) => word[0])
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                          style: const TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.companyName,
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        company.sector,
                        style: GoogleFonts.lato(
                          color: _secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.lato(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (company.description != null &&
                company.description!.trim().isNotEmpty) ...[
              Text(
                company.description!,
                style: GoogleFonts.lato(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (uid != null && isFollowingStream != null) ...[
              StreamBuilder<bool>(
                stream: isFollowingStream,
                builder: (context, snapshot) {
                  final isFollowing = snapshot.data ?? false;
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isFollowing
                            ? Colors.white
                            : _primaryColor,
                        foregroundColor: isFollowing
                            ? _primaryColor
                            : Colors.white,
                        side: BorderSide(
                          color: isFollowing ? _primaryColor : Colors.transparent,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: onToggleFollow == null
                          ? null
                          : () => onToggleFollow!(isFollowing),
                      child: Text(
                        isFollowing ? 'Following' : 'Follow Company',
                        style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);

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
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              opportunity.name,
              style: GoogleFonts.lato(
                fontSize: 14,
                color: _secondaryColor,
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
              StreamBuilder<bool>(
                stream: bookmarkStream,
                builder: (context, snapshot) {
                  final isBookmarked = snapshot.data ?? false;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onToggleBookmark!(isBookmarked),
                      icon: Icon(
                        isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                        color: isBookmarked ? _secondaryColor : _primaryColor,
                      ),
                      label: Text(
                        isBookmarked ? 'Bookmarked' : 'Save for later',
                        style: GoogleFonts.lato(
                          color:
                              isBookmarked ? _secondaryColor : _primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
