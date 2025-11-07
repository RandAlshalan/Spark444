// lib/companyScreens/companyReviewsPage.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/review.dart';
import 'companyStudentProfilePage.dart';

const _purple = Color(0xFF422F5D);

class CompanyReviewsPage extends StatelessWidget {
  final String companyId;
  final String companyName;

  const CompanyReviewsPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4F0),
        elevation: 0,
        iconTheme: const IconThemeData(color: _purple),
        title: const Text(
          'My Reviews',
          style: TextStyle(color: _purple, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('companyId', isEqualTo: companyId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading reviews'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No reviews yet'));
          }

          // Convert docs to Review model list
          final allReviews = docs.map((d) => Review.fromFirestore(d)).toList();

          // Build a map for student replies (those stored as top-level docs with parentId)
          final Map<String, List<Review>> studentRepliesMap = {};
          for (var r in allReviews) {
            final pid = r.parentId;
            if (pid != null && pid.isNotEmpty) {
              studentRepliesMap.putIfAbsent(pid, () => []).add(r);
            }
          }

          // Filter top-level reviews (parentId empty or null)
          final topLevelReviews = allReviews.where((r) => r.parentId == null || r.parentId!.isEmpty).toList();

          return ListView.builder(
            itemCount: topLevelReviews.length,
            itemBuilder: (context, index) {
              final review = topLevelReviews[index];
              final studentReplies = studentRepliesMap[review.id] ?? [];

              return _CompanyReviewThreadCard(
                review: review,
                studentReplies: studentReplies,
                companyId: companyId,
                companyName: companyName,
              );
            },
          );
        },
      ),
    );
  }
}

class _CompanyReviewThreadCard extends StatelessWidget {
  final Review review;
  final List<Review> studentReplies;
  final String companyId;
  final String companyName;

  const _CompanyReviewThreadCard({
    required this.review,
    required this.studentReplies,
    required this.companyId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: const Color(0xFFFDF9FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-level review header (avatar + name + rating)
            StreamBuilder<DocumentSnapshot>(
              stream: (review.studentId.isNotEmpty)
                  ? FirebaseFirestore.instance.collection('student').doc(review.studentId).snapshots()
                  : null,
              builder: (context, snap) {
                String? photoUrl;
                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  photoUrl =
                      (data['profilePictureUrl'] ?? data['profileImage'] ?? data['photoUrl'] ?? data['imageUrl'])?.toString();
                }

                final displayName = review.authorVisible ? (review.studentName.isNotEmpty ? review.studentName : 'Student') : 'Anonymous';

                // make the review header tappable — navigate to student profile when available
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final sid = (review.studentId ?? '').trim();
                    if (sid.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unable to open profile: missing id')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CompanyStudentProfilePage(studentId: sid)),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _purple.withOpacity(.1),
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  color: _purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _purple,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _purple,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // Review text and date
            Text(review.reviewText, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              review.createdAt.toDate().toString(),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),

            const SizedBox(height: 12),

            // Combined thread: student replies (top-level docs with parentId) + company replies
            // We fetch company replies in realtime and merge them with the already-available studentReplies.
            // Both types are ordered by their createdAt timestamp.
            Builder(builder: (ctx) {
              // Guard for empty review id
              if (review.id.trim().isEmpty) {
                // Still show student replies if present
                if (studentReplies.isEmpty) return const SizedBox.shrink();
                final sortedStudent = [...studentReplies];
                sortedStudent.sort((a, b) => a.createdAt.toDate().compareTo(b.createdAt.toDate()));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(thickness: 1, height: 18, color: Color(0xFFE3DCEB)),
                    const SizedBox(height: 6),
                    ...sortedStudent.map((r) => _CompanyStudentReplyTile(reply: r)).toList(),
                  ],
                );
              }

              final repliesRef = FirebaseFirestore.instance
                  .collection('reviews')
                  .doc(review.id)
                  .collection('replies')
                  .orderBy('createdAt', descending: false);

              return StreamBuilder<QuerySnapshot>(
                stream: repliesRef.snapshots(),
                builder: (context, snap) {
                  // Map company replies
                  final companyDocs = snap.data?.docs ?? [];

                  // Build combined list entries: each entry is a map with keys:
                  // { 'isCompany': bool, 'student': Review?, 'company': Map<String,dynamic>?, 'createdAt': DateTime }
                  final List<Map<String, dynamic>> combined = [];

                  // Add student replies
                  for (final s in studentReplies) {
                    final dt = s.createdAt?.toDate() ?? DateTime.now();
                    combined.add({
                      'isCompany': false,
                      'student': s,
                      'company': null,
                      'createdAt': dt,
                    });
                  }

                  // Add company replies from subcollection
                  for (final d in companyDocs) {
                    final data = d.data() as Map<String, dynamic>;
                    final ts = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    combined.add({
                      'isCompany': true,
                      'student': null,
                      'company': {
                        'id': d.id,
                        'text': (data['text'] ?? data['replyText'] ?? '').toString(),
                        'authorId': (data['authorId'] ?? '').toString(),
                        'authorName': (data['authorName'] ?? '').toString(),
                        'authorType': (data['authorType'] ?? '').toString(),
                      },
                      'createdAt': ts,
                      'docRef': d.reference,
                    });
                  }

                  // If there are no combined replies, render nothing
                  if (combined.isEmpty) return const SizedBox.shrink();

                  // Sort combined entries by createdAt ascending
                  combined.sort((a, b) => a['createdAt'].compareTo(b['createdAt']));

                  // Render combined thread
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(thickness: 1, height: 18, color: Color(0xFFE3DCEB)),
                      const SizedBox(height: 6),
                      ...combined.map((entry) {
                        if (entry['isCompany'] == true) {
                          final company = entry['company'] as Map<String, dynamic>;
                          final createdAt = entry['createdAt'] as DateTime;
                          final byCompanyId = company['authorId'] as String;
                          final authorName = (company['authorName'] as String).isNotEmpty ? company['authorName'] as String : companyName;
                          final canDelete = byCompanyId == companyId || (byCompanyId.isEmpty && (company['authorType'] ?? '') == 'company');

                          // Company's reply UI (matching previous design)
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.fromLTRB(10, 10, 4, 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4EF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.reply, size: 18, color: _purple),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((company['text'] as String).isEmpty ? '—' : (company['text'] as String)),
                                      const SizedBox(height: 3),
                                      Text(
                                        authorName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        createdAt.toString(),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canDelete)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete reply?'),
                                          content: const Text('This action cannot be undone.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        final docRef = entry['docRef'] as DocumentReference;
                                        await docRef.delete();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply deleted')));
                                        }
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        } else {
                          final Review r = entry['student'] as Review;
                          return _CompanyStudentReplyTile(reply: r);
                        }
                      }).toList(),
                    ],
                  );
                },
              );
            }),

            const SizedBox(height: 8),

            // Reply button (company can reply only to top-level review) — unchanged
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  final repliesRef = FirebaseFirestore.instance.collection('reviews').doc(review.id).collection('replies');
                  _showReplyDialog(
                    context: Navigator.of(context, rootNavigator: true).context,
                    repliesRef: repliesRef,
                    companyId: companyId,
                    companyName: companyName,
                  );
                },
                icon: const Icon(Icons.add_box_outlined, color: _purple),
                label: const Text('Reply', style: TextStyle(color: _purple)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to show reply dialog - companies reply only to top-level reviews (replies subcollection).
  void _showReplyDialog({
    required BuildContext context,
    required CollectionReference repliesRef,
    required String companyId,
    required String companyName,
  }) {
    final ctrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: !loading,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            final count = ctrl.text.length;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Reply to review'),
              content: SizedBox(
                width: 500,
                child: TextField(
                  controller: ctrl,
                  maxLines: 6,
                  minLines: 3,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [LengthLimitingTextInputFormatter(200)],
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Write your reply…',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: '$count / 200 chars',
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: loading || ctrl.text.trim().isEmpty
                      ? null
                      : () async {
                          setState(() => loading = true);
                          try {
                            final text = ctrl.text.trim();
                            await repliesRef.add({
                              'text': text,
                              'authorType': 'company',
                              'authorId': companyId,
                              'authorName': companyName,
                              'createdAt': FieldValue.serverTimestamp(),
                              // include parent review id to make client-side grouping easier
                              'reviewId': repliesRef.parent?.id ?? '',
                            });
                            if (context.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply posted')));
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                            }
                          }
                        },
                  icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Student reply tile used by the company view to mirror the student's nested replies.
class _CompanyStudentReplyTile extends StatelessWidget {
  final Review reply;

  const _CompanyStudentReplyTile({required this.reply});

  @override
  Widget build(BuildContext context) {
    final displayName = (reply.authorVisible ?? true) ? (reply.studentName.isNotEmpty ? reply.studentName : 'Student') : 'Anonymous';

    // make each student reply tappable to open the student's profile
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final sid = (reply.studentId ?? '').trim();
        if (sid.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open profile: missing id')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CompanyStudentProfilePage(studentId: sid)),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F8FB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade200,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                style: const TextStyle(color: _purple, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, color: _purple)),
                const SizedBox(height: 4),
                Text(reply.reviewText, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(reply.createdAt.toDate().toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyRepliesSubcollection extends StatelessWidget {
  final String reviewId;
  final String companyId;
  final String companyName;

  const _CompanyRepliesSubcollection({
    required this.reviewId,
    required this.companyId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    // safe guard: don't try to reference an empty doc id
    if (reviewId.trim().isEmpty) return const SizedBox.shrink();

    final repliesRef = FirebaseFirestore.instance.collection('reviews').doc(reviewId).collection('replies');

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(thickness: 1, height: 20, color: Color(0xFFE3DCEB)),
            const SizedBox(height: 6),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final replyText = (data['text'] ?? data['replyText'] ?? '').toString();
              final byCompanyId = (data['authorId'] ?? '').toString();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final authorType = (data['authorType'] ?? '').toString();
              final canDelete = byCompanyId == companyId || (byCompanyId.isEmpty && authorType == 'company');

              // backfill missing authorId/name for older replies if needed
              if (byCompanyId.isEmpty && authorType == 'company') {
                d.reference.update({
                  'authorId': companyId,
                  'authorName': companyName,
                });
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(10, 10, 4, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4EF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply, size: 18, color: _purple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(replyText.isEmpty ? '—' : replyText),
                          const SizedBox(height: 3),
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              createdAt.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete reply?'),
                              content: const Text(
                                'This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await d.reference.delete();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reply deleted')),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
