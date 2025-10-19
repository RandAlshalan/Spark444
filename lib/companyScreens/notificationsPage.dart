import 'package:flutter/material.dart';
import 'company_theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CompanyColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: CompanyColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _buildEmptyState(),
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
              Icons.notifications_outlined,
              size: 120,
              color: CompanyColors.muted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CompanyColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You\'re all caught up! When you have new notifications, they\'ll appear here.',
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
}
