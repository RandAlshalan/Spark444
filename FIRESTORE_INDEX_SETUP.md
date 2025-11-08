# Firestore Index Setup for Notifications

## The Issue

The notification query in `notification_helper.dart` uses both a `where` clause and an `orderBy` clause on different fields:

```dart
_firestore
  .collection('notifications')
  .where('userId', isEqualTo: userId)  // Filter by userId
  .orderBy('createdAt', descending: true)  // Sort by createdAt
  .limit(50)
```

This requires a **composite index** in Firestore.

## How to Fix

### Method 1: Automatic Index Creation (Recommended)

1. **Run the app** and navigate to the notifications page
2. **Check the console logs** - you'll see an error like:
   ```
   The query requires an index. You can create it here:
   https://console.firebase.google.com/v1/r/project/YOUR_PROJECT/firestore/indexes?create_composite=...
   ```
3. **Click the link** in the error message (or copy-paste into browser)
4. **Create the index** - Firebase Console will open with the index pre-configured
5. **Wait 1-2 minutes** for the index to build
6. **Refresh the app** - notifications should now load!

### Method 2: Manual Index Creation

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes** tab
4. Click **Create Index**
5. Configure the index:
   - **Collection ID**: `notifications`
   - **Fields to index**:
     - Field: `userId`, Type: `Ascending`
     - Field: `createdAt`, Type: `Descending`
   - **Query scope**: `Collection`
6. Click **Create Index**
7. Wait for the index to build (shows "Building..." then turns green)

### Method 3: Use firestore.indexes.json (For Deployment)

Create a file at the project root (if it doesn't exist):

**firestore.indexes.json**
```json
{
  "indexes": [
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "read",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Then deploy the indexes:
```bash
firebase deploy --only firestore:indexes
```

## Required Indexes for the App

The notification system requires two indexes:

### Index 1: For Notification List
- **Collection**: `notifications`
- **Fields**:
  - `userId` (Ascending)
  - `createdAt` (Descending)
- **Used in**: `getNotificationsStream()` - Display notifications sorted by date

### Index 2: For Unread Count
- **Collection**: `notifications`
- **Fields**:
  - `userId` (Ascending)
  - `read` (Ascending)
- **Used in**: `getUnreadCountStream()` and `markAllAsRead()`

## Verification

After creating the indexes:

1. Check index status in Firebase Console:
   - Go to Firestore Database → Indexes
   - Both indexes should show status: **Enabled** (green)

2. Test in the app:
   - Navigate to notifications page
   - Should see notifications load without errors
   - Badge should show correct unread count

## Common Issues

### "Index still not working"
- Wait 2-3 minutes after creation
- Index building can take time
- Check index status is "Enabled" not "Building"

### "Different error after creating index"
- Check Firestore security rules allow reading notifications
- Verify user is logged in
- Check console for specific error message

### "Can't create index from error link"
- Use Manual Index Creation method instead
- Ensure you have Owner/Editor permissions on Firebase project

## Testing Without Index (Development Only)

If you want to test without waiting for the index, you can temporarily modify the query:

**lib/services/notification_helper.dart** (line 241-252):
```dart
Stream<List<AppNotification>> getNotificationsStream(String userId) {
  return _firestore
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      // .orderBy('createdAt', descending: true)  // Commented out temporarily
      .limit(50)
      .snapshots()
      .map((snapshot) {
        final notifications = snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

        // Sort in memory instead
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notifications;
      });
}
```

⚠️ **Note**: This is less efficient and should only be used for testing. Always create the proper index for production!

## Quick Fix Command

If you have Firebase CLI installed:

```bash
# Initialize Firebase (if not already done)
firebase init firestore

# Create the indexes file (paste the JSON from Method 3 above)
# Then deploy:
firebase deploy --only firestore:indexes
```

## Expected Console Output When Fixed

Before fix (with error):
```
Error loading notifications
The query requires an index...
```

After fix (working):
```
✅ Loaded 5 notifications for user [userId]
```

---

**TL;DR**: Click the index creation link in the console error, wait 1-2 minutes, refresh the app. Done! 🎉
