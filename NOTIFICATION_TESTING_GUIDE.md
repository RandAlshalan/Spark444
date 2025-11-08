# 🧪 Single Device Notification Testing Guide

## Quick Access to Test Screen

After logging in, look for **"Test Notifications (Debug)"** button at the bottom of the login screen (only visible in debug mode).

Or navigate manually:
```dart
Navigator.pushNamed(context, '/testNotifications');
```

---

## Method 1: Local Notification Test (Instant) ⚡

**Perfect for:** Quick testing, verifying notification UI

1. Open the app in debug mode
2. Login with any account
3. Tap **"Test Notifications (Debug)"** button on login screen
4. Tap **"Test Local Notification"** button
5. ✅ Notification appears immediately!

**Tests:**
- ✅ Notification display
- ✅ Notification icon/sound
- ✅ Notification tap navigation
- ✅ Local notification service

---

## Method 2: Firebase Console Test (Push) 🔥

**Perfect for:** Testing real push notifications, cloud messaging

### Step 1: Get Your FCM Token
1. Open test screen (`/testNotifications`)
2. Your FCM token is displayed under "FCM Token"
3. Tap the **copy icon** to copy it

### Step 2: Send Test from Firebase
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **Spark** project
3. Click **Cloud Messaging** in left sidebar (under "Engage")
4. Click **"Send your first message"** or **"New notification"**

### Step 3: Configure Test Message
Fill in the form:
- **Notification title**: "🔔 Test from Firebase"
- **Notification text**: "This is a push notification test!"
- **Image** (optional): Leave blank or add image URL
- Click **Next**

### Step 4: Target Your Device
- Click **"Send test message"**
- Paste your FCM token
- Click **"Test"**

### Step 5: Verify
- ✅ Notification should appear on your device
- ✅ Works in foreground, background, and terminated states

---

## Method 3: Code-Based Test (Advanced) 💻

Add a test function in your company's post opportunity code:

```dart
// After posting opportunity successfully
await NotificationService().showLocalNotification(
  title: '✨ New Opportunity Posted!',
  body: 'Your opportunity "${opportunityTitle}" is now live',
  route: '/notifications',
);
```

---

## Testing Different App States

### 🟢 Foreground (App Open)
- Open the app
- Send test notification
- ✅ Should display as in-app notification

### 🟡 Background (App Minimized)
- Minimize the app (press home button)
- Send test notification
- ✅ Should appear in notification tray
- Tap notification → app opens to specified route

### 🔴 Terminated (App Closed)
- Force close the app
- Send test notification
- ✅ Should appear in notification tray
- Tap notification → app launches and navigates

---

## Troubleshooting Checklist

### ❌ "Token not available"
- Ensure Firebase is initialized
- Check internet connection
- Try restarting the app
- Verify firebase_messaging permission in Info.plist (iOS)

### ❌ "Notification not appearing"
1. Check notification permissions:
   - iOS: Settings → Spark → Notifications → Enable
   - Android: Settings → Apps → Spark → Notifications → Enable

2. Verify FCM token is saved:
   - Check Firestore console
   - Look in `student` or `companies` collection
   - User document should have `fcmToken` field

3. Check console logs:
   - Look for `✅ FCM token saved`
   - Look for `📩 Foreground message received`
   - Look for any error messages

### ❌ "Notification appears but tap doesn't navigate"
- Verify route exists in `main.dart`
- Check `navigatorKey` is set in MyApp
- Verify payload/route is correct

---

## Test Scenarios Checklist

Use this checklist to verify all notification features:

- [ ] **Local notification** appears when test button pressed
- [ ] **Push notification** appears from Firebase Console
- [ ] **Foreground** notification displays correctly
- [ ] **Background** notification appears in tray
- [ ] **Terminated** notification appears in tray
- [ ] **Tapping notification** navigates to correct screen
- [ ] **Sound** plays with notification (if enabled)
- [ ] **Vibration** works (if enabled)
- [ ] **FCM token** saves to Firestore on login
- [ ] **Multiple notifications** can be received
- [ ] **Notification permission** can be granted

---

## Quick Firebase Console URLs

- **Firebase Console**: https://console.firebase.google.com
- **Cloud Messaging**: https://console.firebase.google.com/project/YOUR_PROJECT_ID/notification
- **Firestore Database**: https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore

Replace `YOUR_PROJECT_ID` with your actual Firebase project ID.

---

## Expected Console Output (Success)

When everything works, you should see these logs:

```
✅ Firebase initialized successfully
✅ Background message handler registered
✅ NotificationService initialized successfully
✅ User granted notification permissions
✅ Local notifications initialized
✅ Foreground notifications configured
📱 FCM Token: [your-token-here]
✅ FCM token saved for student/companies: [user-id]
```

When notification arrives:
```
📩 Foreground message received: [message-id]
Title: Test Notification
Body: This is a test
✅ Local notification displayed: Test Notification
```

---

## Need Help?

If notifications still don't work:

1. **Check logs** for error messages
2. **Verify Firebase setup** in Firebase Console
3. **Confirm google-services.json** (Android) and **GoogleService-Info.plist** (iOS) are present
4. **Test permissions** in device settings
5. **Try uninstalling and reinstalling** the app

---

## Pro Tips 💡

1. **Keep test screen open** during development for quick testing
2. **Test on real device** - simulators may not support all notification features
3. **Check Firestore** to verify tokens are being saved
4. **Use Firebase Console** to see delivery status
5. **Test in different time zones** if scheduling notifications

Happy Testing! 🚀
