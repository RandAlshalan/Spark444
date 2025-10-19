import 'package:flutter/material.dart';
import 'company_theme.dart';

class FollowersPage extends StatefulWidget {
  const FollowersPage({super.key});

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> {
  // Placeholder data - replace with actual follower data from database
  final List<Map<String, String>> _followers = [];

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
      body: _followers.isEmpty ? _buildEmptyState() : _buildFollowersList(),
    );
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

  Widget _buildFollowersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _followers.length,
      itemBuilder: (context, index) {
        final follower = _followers[index];
        return _buildFollowerCard(follower);
      },
    );
  }

  Widget _buildFollowerCard(Map<String, String> follower) {
    final name = follower['name'] ?? 'Unknown Student';
    final email = follower['email'] ?? '';
    final major = follower['major'] ?? '';
    final initials = _getInitials(name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: CompanyColors.surface,
      elevation: CompanySpacing.cardElevation,
      shape: RoundedRectangleBorder(borderRadius: CompanySpacing.cardRadius),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
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
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CompanyColors.primary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 14,
                    color: CompanyColors.muted,
                  ),
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
            if (major.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 14,
                    color: CompanyColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    major,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CompanyColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
}
