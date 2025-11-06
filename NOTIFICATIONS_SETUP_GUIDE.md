# 🔔 Spark App - Push Notifications Setup Guide

## ✅ Implementation Complete

Your Spark app now has full push notification support for both Android and iOS!

---

## 📋 What Has Been Implemented

### 1. **NotificationService** ([lib/services/notification_service.dart](lib/services/notification_service.dart))
A complete singleton service that handles:
- ✅ Firebase Cloud Messaging (FCM) initialization
- ✅ Notification permissions for iOS and Android 13+
- ✅ Foreground message handling
- ✅ Background message handling
- ✅ Local notification display
- ✅ FCM token management in Firestore
- ✅ Navigation when notifications are tapped
- ✅ Manual local notifications

### 2. **Main App Updates** ([lib/main.dart](lib/main.dart))
- ✅ Background message handler registered
- ✅ NotificationService initialized on app start
- ✅ Navigation key configured for notification routing

### 3. **Android Configuration** ([android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml))
- ✅ POST_NOTIFICATIONS permission (Android 13+)
- ✅ VIBRATE, WAKE_LOCK permissions
- ✅ Firebase Messaging service configured
- ✅ Default notification icon and color set

### 4. **iOS Configuration** ([ios/Runner/Info.plist](ios/Runner/Info.plist))
- ✅ User notifications usage description
- ✅ Background modes enabled (remote-notification)
- ✅ Fetch capability enabled

---

## 🚀 How to Use

### **Save FCM Token After User Login**

When a user logs in, save their FCM token to Firestore:

```dart
import 'package:spark/services/notification_service.dart';

// After successful login
String userId = 'user123'; // Your user's ID
await NotificationService().saveFCMToken(userId);
```

This will save the token under `users/{userId}/fcmToken` in Firestore.

---

### **Send Push Notifications from Backend**

#### Using Firebase Admin SDK (Node.js):

```javascript
const admin = require('firebase-admin');

// Get user's FCM token from Firestore
const userDoc = await admin.firestore().collection('users').doc(userId).get();
const fcmToken = userDoc.data().fcmToken;

// Send notification
await admin.messaging().send({
  token: fcmToken,
  notification: {
    title: 'New Opportunity!',
    body: 'Check out this amazing internship opportunity',
  },
  data: {
    route: '/opportunities', // Where to navigate when tapped
    opportunityId: 'opp123',
  },
});
```

#### Using Firebase Cloud Functions (Trigger on Firestore change):

```javascript
exports.sendOpportunityNotification = functions.firestore
  .document('opportunities/{oppId}')
  .onCreate(async (snap, context) => {
    const opportunity = snap.data();

    // Get all users who should be notified
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('interests', 'array-contains', opportunity.category)
      .get();

    const tokens = usersSnapshot.docs
      .map(doc => doc.data().fcmToken)
      .filter(token => token); // Remove null/undefined tokens

    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: 'New Opportunity Match!',
          body: `${opportunity.role} at ${opportunity.companyName}`,
        },
        data: {
          route: '/opportunities',
          opportunityId: context.params.oppId,
        },
      });
    }
  });
```

---

### **Show Local Notifications Manually**

Trigger notifications from within your app:

```dart
import 'package:spark/services/notification_service.dart';

// Simple notification
await NotificationService().showLocalNotification(
  title: 'Application Submitted',
  body: 'Your application has been sent successfully!',
);

// With custom navigation route
await NotificationService().showLocalNotification(
  title: 'New Message',
  body: 'You have a new message from XYZ Company',
  route: '/chat/companyId123',
);
```

---

### **Delete FCM Token on Logout**

When a user logs out, remove their FCM token:

```dart
import 'package:spark/services/notification_service.dart';

// On logout
String userId = 'user123';
await NotificationService().deleteFCMToken(userId);
```

---

## 📱 Testing Push Notifications

### **Method 1: Firebase Console (Quick Test)**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Spark project
3. Navigate to **Cloud Messaging** → **Send test message**
4. Get FCM token from your app logs (printed when app starts)
5. Paste token and send test notification

### **Method 2: Using Flutter DevTools**

Run your app and check the debug console for:
```
✅ NotificationService initialized successfully
📱 FCM Token: [YOUR_TOKEN_HERE]
```

### **Method 3: Postman/cURL**

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: Bearer YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "USER_FCM_TOKEN",
    "notification": {
      "title": "Test Notification",
      "body": "This is a test"
    },
    "data": {
      "route": "/notifications"
    }
  }'
```

---

## 🎯 Notification Routing

When a user taps a notification, the app will automatically navigate to the specified route:

```dart
// In your notification data
data: {
  route: '/opportunities', // User goes to opportunities page
  route: '/chat/companyId', // User goes to specific chat
  route: '/profile', // User goes to profile
}
```

**Default route**: If no route is specified, users go to `/notifications`

---

## 🔧 Advanced Configuration

### **Customize Notification Channel (Android)**

Edit [lib/services/notification_service.dart](lib/services/notification_service.dart):

```dart
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'spark_channel', // ID - must be unique
  'Spark Notifications', // Name shown in settings
  description: 'Notifications for Spark app',
  importance: Importance.high, // High priority
  enableVibration: true,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'), // Custom sound
);
```

### **Listen for Token Refresh**

If you need to handle token refresh globally:

```dart
// In notification_service.dart, update _listenForTokenRefresh()
void _listenForTokenRefresh() {
  _firebaseMessaging.onTokenRefresh.listen((newToken) {
    debugPrint('🔄 FCM Token refreshed: $newToken');

    // Get current user ID (you'll need to implement this)
    String? userId = getCurrentUserId();
    if (userId != null) {
      saveFCMToken(userId);
    }
  });
}
```

---

## 🛠️ Troubleshooting

### **Notifications not showing on Android**

1. Check permission is granted:
   ```dart
   NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
   print('Permission: ${settings.authorizationStatus}');
   ```

2. Verify channel is created (Android 8.0+)
3. Check app is not in battery optimization

### **Notifications not showing on iOS**

1. Enable **Push Notifications** capability in Xcode:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target → Signing & Capabilities
   - Click **+ Capability** → Add **Push Notifications**

2. Enable **Background Modes**:
   - Same location, add **Background Modes**
   - Check **Remote notifications**

3. Upload APNs certificate/key to Firebase Console

### **App crashes on notification tap**

- Ensure the route exists in your `MaterialApp` routes
- Add the route in [lib/main.dart](lib/main.dart):
  ```dart
  routes: {
    '/notifications': (_) => const NotificationsPage(),
    // Add other routes...
  }
  ```

---

## 📊 Firestore Data Structure

The FCM token is saved in this structure:

```
users (collection)
  └── {userId} (document)
      ├── fcmToken: "eXaMpLe_tOkEn_123..."
      ├── lastTokenUpdate: Timestamp
      └── ... (other user data)
```

---

## 🎨 Create a Notifications Page (Next Step)

Create [lib/studentScreens/NotificationsPage.dart](lib/studentScreens/NotificationsPage.dart):

```dart
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Welcome to Spark!'),
            subtitle: const Text('Your notification journey starts here'),
            trailing: const Text('Just now'),
          ),
          // Add more notifications from Firestore
        ],
      ),
    );
  }
}
```

Then add the route in [lib/main.dart](lib/main.dart):

```dart
routes: {
  '/notifications': (_) => const NotificationsPage(),
  // ... other routes
}
```

---

## 🔔 Automatic Notifications for Followed Companies

**NEW**: Students now automatically receive notifications when companies they follow post new opportunities!

### **How It Works:**
1. Student follows a company (added to `following` array in Firestore)
2. Company posts a new opportunity
3. Cloud Function automatically detects it
4. All followers receive push notifications instantly

### **Setup Required:**
Deploy the Cloud Functions to activate this feature:

```bash
cd functions
firebase deploy --only functions
```

📖 **Complete deployment guide**: [CLOUD_FUNCTIONS_DEPLOYMENT_GUIDE.md](CLOUD_FUNCTIONS_DEPLOYMENT_GUIDE.md)

### **Cloud Function Features:**
- ✅ Automatically triggers on new opportunity creation
- ✅ Queries all students who follow the company
- ✅ Sends push notifications to all followers
- ✅ Creates notification history in Firestore
- ✅ Handles invalid tokens and cleanup
- ✅ Comprehensive logging for debugging

---

## 📦 Required Packages

Ensure these are in your `pubspec.yaml`:

```yaml
dependencies:
  firebase_messaging: ^16.0.1
  flutter_local_notifications: ^17.0.0
  firebase_core: ^3.0.0
  cloud_firestore: ^5.0.0
```

---

## 🎉 You're All Set!

Your Spark app now has a complete notification system that:
- ✅ Works on both Android and iOS
- ✅ Handles foreground, background, and terminated states
- ✅ Saves FCM tokens to Firestore
- ✅ Navigates users when they tap notifications
- ✅ Allows manual local notifications
- ✅ **Automatic notifications when followed companies post opportunities**

**Need help?** Check the detailed comments in [lib/services/notification_service.dart](lib/services/notification_service.dart)!

**Deploy Cloud Functions**: See [CLOUD_FUNCTIONS_DEPLOYMENT_GUIDE.md](CLOUD_FUNCTIONS_DEPLOYMENT_GUIDE.md)

---

## 📚 Additional Resources

- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
