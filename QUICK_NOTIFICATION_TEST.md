# Quick Notification Testing Guide 🚀

## Step 1: Connect Your Android Device

```bash
# Check if device is connected
flutter devices

# You should see something like:
# Android SDK built for arm64 (mobile) • emulator-5554 • android-arm64 • Android 13 (API 33)
# Or your physical device name
```

## Step 2: Build and Run on Device

```bash
# Clean and build
flutter clean
flutter pub get

# Run in RELEASE mode (important for notifications!)
flutter run --release
```

**Why release mode?** Push notifications work more reliably in release mode on Android.

## Step 3: Test In-App Notifications (Works Immediately!)

### Test 1: Follow a Company
1. Open the app on your device
2. Log in as a student
3. Go to Companies tab
4. Find and follow a company
5. Open another device/browser and log in as that company
6. Post a new opportunity
7. **Result:** Your student account should receive a notification!
   - Bell icon shows badge with count
   - Tap bell to see notification
   - Tap notification to navigate to opportunities

### Test 2: View Notification Page
1. Tap the bell icon in the home page
2. You'll see all your notifications
3. Features to test:
   - Swipe left to delete a notification
   - Tap "Mark all as read" button
   - Tap a notification to navigate

## Step 4: Get Your FCM Token

### Method 1: From Console Logs
```bash
# Run this in a terminal while app is running
flutter logs | grep "FCM Token"

# You'll see:
# 📱 FCM Token: eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Method 2: From Firestore
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Firestore Database
4. Navigate to: `student` collection → find your student document
5. Look for the `fcmToken` field
6. Copy this token for testing

## Step 5: Send Test Push Notification from Firebase

### Using Firebase Console:

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com
   - Select your project

2. **Navigate to Messaging**
   - Click "Engage" in left sidebar
   - Click "Messaging"
   - Click "Create your first campaign"
   - Select "Firebase Notification messages"

3. **Create Test Notification**
   - **Notification title:** "Test from Firebase!"
   - **Notification text:** "Tap me to open the app"
   - Click "Next"

4. **Select Target**
   - Click "Send test message"
   - Paste your FCM token from Step 4
   - Click "Test"

5. **What to Expect:**
   - **App in foreground:** Notification appears as a banner
   - **App in background:** Notification in notification tray
   - **App closed:** Notification in notification tray, tapping opens app

## Step 6: Test Advanced Features

### Test Notification with Navigation:

Send a notification with custom data to test navigation:

1. In Firebase Console, when creating notification:
2. Expand "Additional options"
3. Click "Custom data"
4. Add these key-value pairs:
   ```
   Key: route
   Value: /notifications

   Key: opportunityId
   Value: any_id_here
   ```
5. Send the notification
6. Tap the notification
7. App should navigate to the notifications page!

## Common Test Scenarios

### Scenario 1: App is Open (Foreground)
```
✅ Notification appears as banner at top
✅ Notification plays sound
✅ Can tap to navigate
```

### Scenario 2: App is in Background
```
✅ Notification appears in notification tray
✅ Red badge appears on app icon
✅ Tapping opens app and navigates
```

### Scenario 3: App is Closed/Terminated
```
✅ Notification appears in notification tray
✅ Tapping launches app and navigates
✅ Background handler processes message
```

## Troubleshooting Quick Fixes

### "No notifications appearing"
```bash
# 1. Check you're in release mode
flutter run --release

# 2. Check notification permissions
# Go to device: Settings → Apps → Spark → Notifications → Enable
```

### "Token not found"
```bash
# Make sure you're logged in first
# FCM token is only saved after login
# Check logs: flutter logs | grep -i token
```

### "Notification shows but doesn't navigate"
```
# Make sure notification has 'route' in custom data
# Check that the route exists in your app
# Verify navigatorKey is set in main.dart ✓ (already configured)
```

## Expected Console Output

When everything is working, you should see:

```
✅ FCM token saved to Firestore for student: [userId]
📱 FCM Token: [long token string]
✅ Local notifications initialized
✅ NotificationService initialized successfully
📩 Foreground message received: [messageId]
✅ Local notification displayed: [title]
```

## Quick Verification Checklist

- [ ] Device connected and recognized by Flutter
- [ ] App built in release mode
- [ ] App installed and running on device
- [ ] User logged in
- [ ] Notification permission granted
- [ ] FCM token visible in logs or Firestore
- [ ] Bell icon appears in home page
- [ ] In-app notifications work (follow company test)
- [ ] Push notification received from Firebase Console
- [ ] Tapping notification navigates to correct page

## Testing Tips

1. **Always use release mode** for push notification testing
2. **Check Firestore** to see if notifications are being created
3. **Use Firebase Console** for manual push notification testing
4. **Check device logs** if something doesn't work
5. **Ensure internet connection** is active
6. **Don't force kill the app** during testing (use home button instead)

## Next Steps

Once basic notifications work:
- Set up Firebase Cloud Functions for automatic push notifications
- Customize notification icons and sounds
- Add notification categories
- Implement notification preferences
- Add rich notifications with images

## Need Help?

Check these logs:
```bash
# All logs
flutter logs

# Just Firebase/Notification logs
flutter logs | grep -i "notification\|firebase\|fcm"

# Just errors
flutter logs | grep -i "error"
```

---

**Ready to test?** Start with Step 1! 🚀
