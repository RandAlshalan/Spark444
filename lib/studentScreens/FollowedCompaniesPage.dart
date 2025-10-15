// lib/studentScreens/FollowedCompaniesPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './StudentCompanyProfilePage.dart';

const _purple = Color(0xFF422F5D);
const String kStudentsCollection = 'student';

class FollowedCompaniesPage extends StatefulWidget {
  const FollowedCompaniesPage({super.key});

  @override
  State<FollowedCompaniesPage> createState() => _FollowedCompaniesPageState();
}

class _FollowedCompaniesPageState extends State<FollowedCompaniesPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // إذا صار Unfollow نخزّن أنه صار تعديل عشان نرجّعه للأب
  bool _modified = false;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in.')),
      );
    }

    final studentDocStream = _db
        .collection(kStudentsCollection)
        .doc(uid)
        .snapshots(includeMetadataChanges: true);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _modified); // نرجّع النتيجة للأب (البروفايل)
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Followed Companies'),
          leading: BackButton(
            onPressed: () => Navigator.pop(context, _modified),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: studentDocStream,
          builder: (context, snap) {
            final data = snap.data?.data();
            final ids = List<String>.from(
              (data?['followedCompanies'] ?? const []) as List,
            );

            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (ids.isEmpty) {
              return const Center(
                child: Text('You are not following any companies.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: ids.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final companyId = ids[i];
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: _db.collection('companies').doc(companyId).get(),
                  builder: (context, cSnap) {
                    if (cSnap.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.business_outlined),
                        ),
                        title: Text('Loading...'),
                      );
                    }
                    if (!cSnap.hasData || !(cSnap.data?.exists ?? false)) {
                      return const ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.business_outlined),
                        ),
                        title: Text('Company not found'),
                      );
                    }

                    final m = cSnap.data!.data()!;
                    final name =
                        (m['companyName'] ?? m['name'] ?? 'Unknown Company')
                            .toString();
                    final sector = (m['sector'] ?? '').toString();
                    final logoUrl = m['logoUrl'] as String?;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: (logoUrl == null || logoUrl.isEmpty)
                          ? const CircleAvatar(
                              child: Icon(Icons.business_outlined),
                            )
                          : CircleAvatar(
                              backgroundImage: NetworkImage(logoUrl),
                            ),
                      title: Text(name),
                      subtitle: sector.isNotEmpty ? Text(sector) : null,

                      // افتحي صفحة بروفايل الشركة
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StudentCompanyProfilePage(companyId: companyId),
                          ),
                        );
                      },

                      // زر Following (إلغاء المتابعة)
                      trailing: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Following',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () async {
                          await _db
                              .collection(kStudentsCollection)
                              .doc(uid)
                              .update({
                                'followedCompanies': FieldValue.arrayRemove([
                                  companyId,
                                ]),
                              });
                          if (!context.mounted) return;
                          _modified =
                              true; // علّمنا إن صار تعديل (عشان البروفايل يحدّث العداد)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unfollowed $name')),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
