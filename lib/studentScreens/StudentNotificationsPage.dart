import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/notification.dart';
import '../models/student.dart';
import '../services/authService.dart';
import '../services/notification_helper.dart';
import 'studentOppPage.dart';

// Color Constants
const Color _purple = Color(0xFF422F5D);
const Color _sparkOrange = Color(0xFFF99D46);
const Color _sparkPink = Color(0xFFD64483);
const Color _backgroundColor = Color(0xFFF8F9FA);
const Color _cardColor = Color(0xFFFFFFFF);
const Color _textColor = Color(0xFF1E1E1E);

class StudentNotificationsPage extends StatefulWidget {
  const StudentNotificationsPage({super.key});

  @override
  State<StudentNotificationsPage> createState() =>
      _StudentNotificationsPageState();
}

class _StudentNotificationsPageState extends State<StudentNotificationsPage> {
  final AuthService _authService = AuthService();
  final NotificationHelper _notificationHelper = NotificationHelper();

  Student? _student;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    setState(() => _loading = true);
    try {
      final student = await _authService.getCurrentStudent();
      if (student != null) {
        await _notificationHelper.syncLegacyNotifications(student.id);
      }
      if (!mounted) return;
      setState(() {
        _student = student;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading student: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (!notification.read) {
      await _notificationHelper.markAsRead(notification.id);
    }
  }

  Future<void> _markAllAsRead() async {
    if (_student != null) {
      await _notificationHelper.markAllAsRead(_student!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All notifications marked as read',
              style: GoogleFonts.lato(),
            ),
            backgroundColor: _purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    await _notificationHelper.deleteNotification(notificationId);
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read
    _markAsRead(notification);

    // Navigate based on notification type
    final route = notification.data?['route'] as String?;
    if (route != null) {
      if (route == '/opportunities') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => studentOppPgae()),
        );
      }
      // Add more navigation cases as needed
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_opportunity':
        return Icons.work_outline;
      case 'application_update':
        return Icons.assignment_outlined;
      case 'review_reply':
        return Icons.comment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_opportunity':
        return _purple;
      case 'application_update':
        return _sparkOrange;
      case 'review_reply':
        return _sparkPink;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _purple,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _purple),
            )
          : _student == null
              ? Center(
                  child: Text(
                    'Unable to load notifications',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      color: _textColor.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : StreamBuilder<List<AppNotification>>(
                  stream: _notificationHelper
                      .getNotificationsStream(_student!.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _purple),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint('Notification stream error: ${snapshot.error}');
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: _textColor.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading notifications',
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  color: _textColor.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: Colors.red.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final notifications = snapshot.data ?? [];

                    if (notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: _textColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: GoogleFonts.lato(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _textColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You\'ll be notified when companies\nyou follow post new opportunities',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                color: _textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    final color = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);
    final timeAgo = timeago.format(notification.createdAt.toDate());

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification deleted',
              style: GoogleFonts.lato(),
            ),
            backgroundColor: _purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.read
              ? _cardColor
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.read
                ? Colors.grey.shade200
                : color.withValues(alpha: 0.3),
            width: notification.read ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(notification),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: GoogleFonts.lato(
                                  fontSize: 15,
                                  fontWeight: notification.read
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                            ),
                            if (!notification.read)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.body,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: _textColor.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: _textColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo,
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                color: _textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
