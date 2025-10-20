import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/company.dart';
import '../models/student.dart';
import '../services/authService.dart';
import 'company_theme.dart';

class FollowersPage extends StatefulWidget {
  const FollowersPage({super.key, required this.company});

  final Company company;

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  List<Student> _followers = [];

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CompanyColors.background,
      appBar: AppBar(
        title: const Text(
          'My Followers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: CompanyColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFollowers,
        color: CompanyColors.primary,
        backgroundColor: Colors.white,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CompanyColors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFollowers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_followers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _followers.length,
      itemBuilder: (context, index) {
        final follower = _followers[index];
        return _buildFollowerCard(follower);
      },
    );
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final companyId = widget.company.uid;
      if (companyId == null || companyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _followers = const [];
          _error = 'Company identifier is missing. Please contact support.';
        });
        return;
      }

      final snapshot = await _firestore
          .collection(AuthService.kStudentCol)
          .where('followedCompanies', arrayContains: companyId)
          .get();

      final followers = snapshot.docs
          .map((doc) => Student.fromFirestore(doc))
          .toList()
        ..sort(
          (a, b) => a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase()),
        );

      if (!mounted) return;
      setState(() {
        _followers = followers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load followers. Please try again later.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 120,
              color: CompanyColors.muted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Followers Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CompanyColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'When students follow your company, they\'ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: CompanyColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowerCard(Student follower) {
    final fullName = '${follower.firstName} ${follower.lastName}'.trim();
    final displayName = fullName.isEmpty ? follower.email : fullName;
    final email = follower.email;
    final major = follower.major.trim();
    final level = follower.level?.trim() ?? '';
    final university = follower.university.trim();
    final initials = _getInitials(displayName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: CompanyColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: CompanyColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: CompanyColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 14, color: CompanyColors.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: CompanyColors.muted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (university.isNotEmpty || major.isNotEmpty || level.isNotEmpty)
              const SizedBox(height: 12),
            if (university.isNotEmpty)
              _buildInfoRow('University', university, Icons.school_outlined),
            if (major.isNotEmpty)
              _buildInfoRow('Major', major, Icons.badge_outlined),
            if (level.isNotEmpty)
              _buildInfoRow('Level', level, Icons.layers_outlined),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CompanyColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Following',
                  style: TextStyle(
                    fontSize: 12,
                    color: CompanyColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: CompanyColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                fontSize: 13,
                color: CompanyColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
