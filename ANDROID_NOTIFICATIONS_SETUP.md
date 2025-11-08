# Android Push Notifications Setup Guide

This guide will help you set up and test push notifications on a physical Android device for the Spark app.

## ✅ Current Configuration Status

Your app is already configured with:
- ✓ Firebase Cloud Messaging setup
- ✓ AndroidManifest.xml permissions
- ✓ Notification service implementation
- ✓ Local notifications setup
- ✓ Custom notification icon
- ✓ google-services.json file

## 📱 Testing on Physical Android Device

### Step 1: Build and Install the App

```bash
# Clean the project first
flutter clean

# Get dependencies
flutter pub get

# Build and run on connected Android device
flutter run --release
```

**Note:** Use `--release` mode for testing push notifications, as they work more reliably in release mode.

### Step 2: Grant Notification Permissions

When you first open the app on Android 13+ (API 33+), you'll see a permission dialog:
1. The app will automatically request notification permissions
2. Tap "Allow" to enable notifications
3. If you miss this, go to: Settings → Apps → Spark → Notifications → Enable

### Step 3: Verify FCM Token

The app automatically:
1. Requests an FCM token when the app starts
2. Saves the token to Firestore when a user logs in
3. Links the token to the student's document in the `student` collection

Check the console logs for:
```
✅ FCM token saved to Firestore for student: [userId]
📱 FCM Token: [long token string]
```

### Step 4: Test In-App Notifications

The app has a built-in in-app notification system that works immediately:

1. **Follow a company**: Go to a company profile and tap the follow button
2. **Wait for new opportunities**: When a company posts a new opportunity, all followers receive a notification
3. **Check notification page**: Tap the bell icon in the home page to see notifications

Features:
- Real-time notification count badge
- Swipe to delete notifications
- Tap notification to navigate to relevant page
- Mark all as read functionality

### Step 5: Test Push Notifications (Foreground)

**Testing while app is open:**

1. Log in to the app on your physical device
2. Stay on the home screen
3. Use Firebase Console to send a test notification:
   - Go to: https://console.firebase.google.com
   - Select your project
   - Navigate to: Engage → Messaging
   - Click "New campaign" → "Firebase Notification messages"
   - Fill in:
     - **Notification title**: "Test Notification"
     - **Notification text**: "This is a test from Firebase!"
   - Click "Send test message"
   - Paste the FCM token from your console logs
   - Click "Test"

4. You should see a notification banner appear while the app is in foreground

### Step 6: Test Push Notifications (Background)

**Testing while app is in background:**

1. Press the home button to put the app in the background
2. Send another test notification from Firebase Console
3. You should see the notification in your device's notification tray
4. Tap the notification to open the app

**Testing while app is terminated:**

1. Force close the app (swipe it away from recent apps)
2. Send another test notification from Firebase Console
3. You should see the notification in your device's notification tray
4. Tap the notification to launch the app

## 🔧 Advanced Testing with Firebase Console

### Sending Notifications with Custom Data

To test navigation, send notifications with custom data payloads:

1. In Firebase Console Messaging:
   - Create a new notification
   - Under "Additional options" → "Custom data"
   - Add key-value pairs:
     - `route`: `/notifications` (or any valid route)
     - `opportunityId`: `[opportunity_id]`
     - `companyId`: `[company_id]`

2. When the user taps the notification, the app will navigate to the specified route

## 🧪 Testing Notification Features

### 1. New Opportunity Notifications
```dart
// When a company posts a new opportunity, the NotificationHelper automatically:
// 1. Finds all students following that company
// 2. Creates in-app notifications for each follower
// 3. Sends push notifications to devices with FCM tokens

// To test:
// - Follow a company as Student A
// - Post a new opportunity as that company
// - Student A should receive a notification
```

### 2. Application Status Update Notifications
```dart
// When a company updates an application status:
// - Student receives an in-app notification
// - Push notification sent to their device
```

### 3. Review Reply Notifications
```dart
// When a company replies to a student's interview review:
// - Student receives a notification
// - Can navigate to the review from the notification
```

## 📊 Verifying Setup

### Check 1: AndroidManifest.xml Permissions
```xml
<!-- These should be present in android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### Check 2: Notification Icon
The custom notification icon should be at:
```
android/app/src/main/res/drawable/ic_notification.xml
```

### Check 3: Firebase Configuration
```
android/app/google-services.json ✓ Present
```

### Check 4: Dependencies in pubspec.yaml
```yaml
dependencies:
  firebase_messaging: ^16.0.1
  flutter_local_notifications: ^17.0.0
  firebase_core: ^2.x.x
```

## 🐛 Troubleshooting

### Problem: No notifications appear
**Solutions:**
1. Check notification permissions: Settings → Apps → Spark → Notifications
2. Verify the app is in release mode: `flutter run --release`
3. Check FCM token is saved in Firestore
4. Look for errors in console: `flutter logs`

### Problem: Token not saved to Firestore
**Solutions:**
1. Make sure user is logged in
2. Check that `NotificationService().saveFCMToken()` is called after login
3. Verify internet connection
4. Check Firestore security rules allow writes to student collection

### Problem: Notifications work but navigation doesn't
**Solutions:**
1. Verify the `navigatorKey` is set in main.dart
2. Check that routes are defined in the app
3. Ensure payload data contains the correct `route` key

### Problem: Background notifications don't work
**Solutions:**
1. Use release mode instead of debug mode
2. Verify the background handler is registered in main.dart:
   ```dart
   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
   ```
3. Check Android battery optimization isn't blocking the app

### Problem: Icon shows as grey square
**Solution:**
- The notification icon must be a monochrome vector drawable
- Already fixed: using `@drawable/ic_notification`
- Color is applied via `notification_color` in colors.xml

## 📱 Device-Specific Notes

### Android 13+ (API 33+)
- Runtime permission required for POST_NOTIFICATIONS
- The app automatically requests this on first launch

### Android 12 (API 31-32)
- Notification permissions granted by default
- Users can disable in settings

### Android 8-11 (API 26-30)
- Notification channels required (already configured)
- High importance for heads-up notifications

## 🚀 Production Setup

### For Production Push Notifications:

Currently, the app creates in-app notifications, but push notifications are only sent when using Firebase Console manually. For automatic push notifications:

1. **Set up Firebase Cloud Functions** (recommended):
   ```javascript
   // Example Cloud Function
   exports.sendNotificationToFollowers = functions.firestore
     .document('opportunities/{oppId}')
     .onCreate(async (snap, context) => {
       const opportunity = snap.data();
       // Get followers
       // Send FCM messages
     });
   ```

2. **Or use Firebase Admin SDK** in your backend server

3. **Security**: Never expose FCM server key in client code

## ✅ Testing Checklist

- [ ] App builds and runs on physical Android device
- [ ] Notification permission granted
- [ ] FCM token appears in console logs
- [ ] FCM token saved to Firestore after login
- [ ] In-app notifications appear in notification page
- [ ] Notification badge shows unread count
- [ ] Foreground push notification displays
- [ ] Background push notification displays in notification tray
- [ ] Terminated app receives notification in notification tray
- [ ] Tapping notification navigates to correct page
- [ ] Notification icon and color display correctly
- [ ] Notification sound and vibration work

## 📝 Additional Notes

### Current Notification Flow:

1. **User logs in** → FCM token saved to Firestore
2. **Company posts opportunity** → NotificationHelper creates in-app notifications for followers
3. **Student opens app** → Sees notification badge and can view notifications
4. **Student taps notification** → Navigates to opportunities page

### Future Enhancements:

- Implement Firebase Cloud Functions for automatic push notifications
- Add notification preferences (sound, vibration, types)
- Add notification categories (opportunities, applications, reviews)
- Implement scheduled notifications
- Add notification history

## 🔗 Useful Links

- [Firebase Console](https://console.firebase.google.com)
- [FCM Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Firebase Messaging Flutter](https://pub.dev/packages/firebase_messaging)

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review console logs: `flutter logs`
3. Check Firebase Console for errors
4. Verify all configuration files are correct
