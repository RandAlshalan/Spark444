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

          final reviews = docs.map((d) => Review.fromFirestore(d)).toList();

          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _ReviewItem(
                review: review,
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

class _ReviewItem extends StatelessWidget {
  final Review review;
  final String companyId;
  final String companyName;

  const _ReviewItem({
    required this.review,
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
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('student')
                  .doc(review.studentId)
                  .snapshots(),
              builder: (context, snap) {
                String? photoUrl;
                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  photoUrl =
                      (data['profilePictureUrl'] ??
                              data['profileImage'] ??
                              data['photoUrl'] ??
                              data['imageUrl'])
                          ?.toString();
                }

                return InkWell(
                  onTap: () {
                    if (review.studentId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanyStudentProfilePage(
                            studentId: review.studentId,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _purple.withOpacity(.1),
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                                review.studentName.isNotEmpty
                                    ? review.studentName[0].toUpperCase()
                                    : 'S',
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
                          review.studentName,
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
            Text(review.reviewText, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              review.createdAt.toDate().toString(),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            _ReviewRepliesSection(
              reviewId: review.id,
              companyId: companyId,
              companyName: companyName,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRepliesSection extends StatelessWidget {
  final String reviewId;
  final String companyId;
  final String companyName;

  const _ReviewRepliesSection({
    required this.reviewId,
    required this.companyId,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    final repliesRef = FirebaseFirestore.instance
        .collection('reviews')
        .doc(reviewId)
        .collection('replies');

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (docs.isNotEmpty)
              const Divider(thickness: 1, height: 20, color: Color(0xFFE3DCEB)),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final replyText = (data['text'] ?? data['replyText'] ?? '')
                  .toString();
              final byCompanyId = (data['authorId'] ?? '').toString();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final authorType = (data['authorType'] ?? '').toString();
              final canDelete =
                  byCompanyId == companyId ||
                  (byCompanyId.isEmpty && authorType == 'company');
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
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
        );
      },
    );
  }

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
                  onPressed: loading
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
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
                            });
                            if (context.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reply posted')),
                              );
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          }
                        },
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
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
