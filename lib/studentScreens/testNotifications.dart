import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';

/// Test screen for notification functionality
/// Access this from your app to test notifications on a single device
class TestNotificationsScreen extends StatefulWidget {
  const TestNotificationsScreen({super.key});

  @override
  State<TestNotificationsScreen> createState() =>
      _TestNotificationsScreenState();
}

class _TestNotificationsScreenState extends State<TestNotificationsScreen> {
  String _fcmToken = 'Loading...';
  String _userId = 'Not logged in';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadTokenInfo();
  }

  Future<void> _loadTokenInfo() async {
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() => _userId = user.uid);
      }

      // Get FCM token
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        setState(() => _fcmToken = token);
      } else {
        setState(() => _fcmToken = 'Token not available');
      }
    } catch (e) {
      setState(() => _fcmToken = 'Error: $e');
    }
  }

  Future<void> _testLocalNotification() async {
    setState(() => _statusMessage = 'Sending local notification...');

    try {
      await NotificationService().showLocalNotification(
        title: '🎉 Test Notification',
        body: 'This is a local notification test from your device!',
        route: '/profile',
      );

      setState(() => _statusMessage = '✅ Local notification sent!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error: $e');
    }
  }

  Future<void> _copyTokenToClipboard() async {
    if (_fcmToken != 'Loading...' && _fcmToken != 'Token not available') {
      await Clipboard.setData(ClipboardData(text: _fcmToken));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FCM Token copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
        backgroundColor: const Color(0xFF422F5D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF99D46), Color(0xFFD64483)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 50,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Notification Test Center',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // User Info Card
            _buildInfoCard(
              title: 'User ID',
              content: _userId,
              icon: Icons.person,
            ),
            const SizedBox(height: 15),

            // FCM Token Card
            _buildInfoCard(
              title: 'FCM Token',
              content: _fcmToken,
              icon: Icons.vpn_key,
              trailing: IconButton(
                icon: const Icon(Icons.copy, color: Color(0xFF422F5D)),
                onPressed: _copyTokenToClipboard,
                tooltip: 'Copy token',
              ),
            ),
            const SizedBox(height: 30),

            // Test Local Notification Button
            ElevatedButton.icon(
              onPressed: _testLocalNotification,
              icon: const Icon(Icons.notification_add),
              label: const Text('Test Local Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF422F5D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Refresh Token Button
            OutlinedButton.icon(
              onPressed: _loadTokenInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Token'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF422F5D),
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: Color(0xFF422F5D)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status Message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅')
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _statusMessage.contains('✅')
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('✅')
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 30),

            // Instructions Card
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF422F5D)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF422F5D),
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Text(
                  'How to Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildInstructionStep(
              '1',
              'Test Local Notification',
              'Tap "Test Local Notification" button above to see a notification appear immediately.',
            ),
            _buildInstructionStep(
              '2',
              'Test Push Notification (Firebase)',
              'Copy your FCM token (tap copy icon), then:\n'
                  '• Go to Firebase Console → Cloud Messaging\n'
                  '• Click "Send test message"\n'
                  '• Paste your token and send',
            ),
            _buildInstructionStep(
              '3',
              'Test in Different States',
              'Try notifications while app is:\n'
                  '• Foreground (open)\n'
                  '• Background (minimized)\n'
                  '• Terminated (closed)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(
    String number,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
