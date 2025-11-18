# 🚀 Spark App - Cloud Functions Deployment Guide

## ✅ Notification System Implementation Complete

Your Spark app now automatically notifies students when:
- Companies they follow post new opportunities
- Someone replies to their reviews
- Their application status is updated by a company

---

## 📋 What Has Been Implemented

### **Cloud Function 1: `notifyFollowersOnNewOpportunity`**
Located in: [functions/index.js](functions/index.js)

**Trigger**: Automatically runs when a new document is created in the `opportunities` collection

**What it does**:
1. ✅ Detects when a company posts a new opportunity
2. ✅ Finds all students who follow that company (queries `student` collection where `following` array contains `companyId`)
3. ✅ Retrieves FCM tokens from those students
4. ✅ Sends push notifications to all followers
5. ✅ Creates notification records in Firestore under `student/{studentId}/notifications`
6. ✅ Handles failed tokens and removes invalid ones
7. ✅ Logs everything for debugging

**Notification Content**:
- **Title**: "New Opportunity at [Company Name]!"
- **Body**: "[Company Name] just posted: [Role Name]"
- **Navigation**: Opens app to `/opportunities` page
- **Additional Data**: `opportunityId`, `companyId`, `type: "new_opportunity"`

### **Cloud Function 2: `notifyStudentOnReviewReply`**
Located in: [functions/index.js](functions/index.js)

**Trigger**: Automatically runs when a new document with a `parentId` is created in the `reviews` collection

**What it does**:
1. ✅ Detects when a reply is posted to a review (has `parentId`)
2. ✅ Fetches the original review to find the student who wrote it
3. ✅ Retrieves the student's FCM token
4. ✅ Sends push notification to the original review author
5. ✅ Creates notification record in Firestore under `student/{studentId}/notifications`
6. ✅ Handles failed tokens and removes invalid ones
7. ✅ Prevents self-notification (if student replies to their own review)
8. ✅ Logs everything for debugging

**Notification Content**:
- **Title**: "New Reply to Your Review"
- **Body**: "Someone replied to your review about [Company Name]"
- **Navigation**: Opens app to `/my-reviews` page
- **Additional Data**: `reviewId`, `replyId`, `companyId`, `type: "review_reply"`

### **Cloud Function 3: `notifyStudentOnApplicationUpdate`**
Located in: [functions/index.js](functions/index.js)

**Trigger**: Automatically runs when an existing document is updated in the `applications` collection

**What it does**:
1. ✅ Detects when an application status changes (compares before and after status)
2. ✅ Fetches the student and their FCM token
3. ✅ Fetches the opportunity and company details
4. ✅ Sends contextual push notification based on new status
5. ✅ Creates notification record in Firestore under `student/{studentId}/notifications`
6. ✅ Handles failed tokens and removes invalid ones
7. ✅ Logs everything for debugging

**Notification Content (varies by status)**:
- **Status: Reviewed**
  - Title: "Application Reviewed"
  - Body: "Your application for [Role] at [Company] has been reviewed"
- **Status: Rejected**
  - Title: "Application Update"
  - Body: "Thank you for your interest in [Role] at [Company]"
- **Status: Hired**
  - Title: "Congratulations!"
  - Body: "You've been selected for [Role] at [Company]!"
- **Status: Interviewing**
  - Title: "Interview Invitation"
  - Body: "[Company] has invited you for an interview for [Role]"
- **Other statuses**: Generic "Application Status Updated" message

**Navigation**: Opens app to `/opportunities` page
**Additional Data**: `applicationId`, `opportunityId`, `status`, `type: "application_status_update"`

### **Test Function: `testNotification`**
HTTP endpoint to test notifications manually

**URL**: `https://[region]-[project-id].cloudfunctions.net/testNotification?userId=[STUDENT_ID]`

---

## 🛠️ Deployment Steps

### **Step 1: Install Firebase CLI (if not already installed)**

```bash
npm install -g firebase-tools
```

### **Step 2: Login to Firebase**

```bash
firebase login
```

### **Step 3: Navigate to Functions Directory**

```bash
cd functions
```

### **Step 4: Install Dependencies**

```bash
npm install
```

### **Step 5: Deploy Functions to Firebase**

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:notifyFollowersOnNewOpportunity
firebase deploy --only functions:notifyStudentOnReviewReply
firebase deploy --only functions:notifyStudentOnApplicationUpdate
```

Expected output:
```
✔  Deploy complete!

Functions:
  notifyFollowersOnNewOpportunity(us-central1):
    https://us-central1-[PROJECT_ID].cloudfunctions.net/notifyFollowersOnNewOpportunity
```

### **Step 6: Verify Deployment**

Check Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Spark project
3. Navigate to **Functions** in the left sidebar
4. You should see `notifyFollowersOnNewOpportunity` listed

---

## 📊 Firestore Data Structure

### **Student Document Structure**
```javascript
student/{studentId}
  ├── following: ["companyId1", "companyId2", ...] // Array of company IDs
  ├── fcmToken: "eXaMpLe_tOkEn_123..."
  └── ... (other student data)
```

### **Notification Records (Created by Cloud Function)**
```javascript
student/{studentId}/notifications/{notificationId}
  ├── title: "New Opportunity at Company X!"
  ├── body: "Company X just posted: Software Engineer Intern"
  ├── type: "new_opportunity"
  ├── opportunityId: "opp123"
  ├── companyId: "comp456"
  ├── companyName: "Company X"
  ├── read: false
  └── createdAt: Timestamp
```

This subcollection allows you to:
- Display notification history in the app
- Mark notifications as read
- Show unread notification count

---

## 🧪 Testing the Notification System

### **Method 1: Create a Test Opportunity (Recommended)**

1. **Follow a company as a student**:
   - Login as a student in the app
   - Navigate to companies page
   - Click "Follow" on a company

2. **Ensure FCM token is saved**:
   ```dart
   // In your Flutter app, after login
   await NotificationService().saveFCMToken(studentId);
   ```

3. **Post an opportunity as that company**:
   - Login as the company
   - Create a new opportunity
   - The Cloud Function will automatically trigger!

4. **Check the student's device**:
   - Student should receive push notification immediately
   - Tapping notification opens app to opportunities page

### **Method 2: Use Test Endpoint**

```bash
# Replace with your actual values
curl "https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/testNotification?userId=STUDENT_USER_ID"
```

### **Method 3: Manual Firestore Insert**

1. Go to Firebase Console → Firestore
2. Navigate to `opportunities` collection
3. Click **Add document**
4. Fill in required fields:
   ```json
   {
     "companyId": "actual_company_id_here",
     "role": "Software Engineer Intern",
     "name": "Company Name",
     "isPaid": true,
     "createdAt": [current timestamp]
   }
   ```
5. Click **Save**
6. Cloud Function triggers automatically!

---

## 📱 Flutter App Integration

The notification system is already integrated in your app via [lib/services/notification_service.dart](lib/services/notification_service.dart).

### **Ensure FCM Token is Saved After Login**

Update your login flow to save the FCM token:

```dart
// In your login screen (lib/studentScreens/login.dart)
import 'package:spark/services/notification_service.dart';

// After successful login
Future<void> _handleSuccessfulLogin(String userId) async {
  // Save FCM token to Firestore
  await NotificationService().saveFCMToken(userId);

  // Navigate to home screen
  Navigator.pushReplacementNamed(context, '/home');
}
```

### **Display Notification History (Optional)**

Create a page to show notification history from Firestore:

```dart
// lib/studentScreens/NotificationsPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatelessWidget {
  final String studentId;

  const NotificationsPage({Key? key, required this.studentId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('student')
            .doc(studentId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final isRead = notification['read'] ?? false;

              return ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: isRead ? Colors.grey : Colors.blue,
                ),
                title: Text(
                  notification['title'] ?? '',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(notification['body'] ?? ''),
                trailing: Text(
                  _formatTimestamp(notification['createdAt']),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  // Mark as read
                  FirebaseFirestore.instance
                      .collection('student')
                      .doc(studentId)
                      .collection('notifications')
                      .doc(notifications[index].id)
                      .update({'read': true});

                  // Navigate to opportunity
                  if (notification['opportunityId'] != null) {
                    Navigator.pushNamed(
                      context,
                      '/opportunities',
                      arguments: notification['opportunityId'],
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
```

---

## 🔍 Monitoring and Debugging

### **View Function Logs**

```bash
# View all function logs
firebase functions:log

# View logs for specific function
firebase functions:log --only notifyFollowersOnNewOpportunity

# Follow logs in real-time
firebase functions:log --only notifyFollowersOnNewOpportunity --follow
```

### **Check Firebase Console Logs**

1. Go to Firebase Console → Functions
2. Click on `notifyFollowersOnNewOpportunity`
3. Click **Logs** tab
4. View execution history and errors

### **What to Look For in Logs**

✅ **Successful execution**:
```
New opportunity created: opp123
Found 5 followers for Company XYZ
Sending notifications to 5 students
Successfully sent 5 notifications
Notification records created in Firestore
```

❌ **Common issues**:
- `No followers found`: No students follow this company
- `No followers have FCM tokens`: Students haven't logged in yet or tokens not saved
- `Failed to send X notifications`: Invalid tokens or device offline

---

## 💰 Cost Considerations

### **Cloud Functions Pricing**
- **Free Tier**: 2 million invocations/month
- Your function triggers only when new opportunities are created
- Typical usage: Very low cost (likely stays in free tier)

### **Firestore Reads**
- Each notification checks:
  - 1 read for company document
  - N reads for follower query (where N = number of followers)
  - N writes for notification records

### **FCM (Firebase Cloud Messaging)**
- **Completely FREE** - No charges for push notifications

---

## 🚨 Important Security Rules

Ensure your Firestore security rules allow the Cloud Function to write notifications:

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow Cloud Functions to write notifications
    match /student/{studentId}/notifications/{notificationId} {
      allow read: if request.auth != null && request.auth.uid == studentId;
      allow write: if request.auth != null; // Allow authenticated writes
    }
  }
}
```

Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

---

## 🎨 Customization Options

### **Change Notification Content**

Edit [functions/index.js](functions/index.js):

```javascript
// Line 106-109
const notificationTitle = `🎉 New Match: ${opportunity.role}`;
const notificationBody = `${companyName} is looking for ${opportunity.role}. Apply now!`;
```

### **Change Navigation Route**

```javascript
// Line 118
route: "/opportunity-details", // Navigate to specific page
```

### **Add More Notification Types**

You can create additional Cloud Functions for:
- ✅ Application status updates (Already implemented!)
- New messages from companies
- Deadline reminders
- Application deadline approaching

---

## 🔧 Troubleshooting

### **Function Not Triggering**

1. Check deployment:
   ```bash
   firebase functions:list
   ```

2. Check function logs for errors:
   ```bash
   firebase functions:log --only notifyFollowersOnNewOpportunity
   ```

3. Verify Firestore path matches:
   - Function listens to: `opportunities/{opportunityId}`
   - Your app writes to: `opportunities` collection

### **Notifications Not Received**

1. **Check FCM token is saved**:
   - Go to Firestore → `student` collection
   - Verify `fcmToken` field exists and is not empty

2. **Check student follows the company**:
   - Verify `following` array contains the `companyId`

3. **Check device permissions**:
   - Ensure notification permissions are granted on the device

4. **Check logs**:
   ```bash
   firebase functions:log --follow
   ```

### **Invalid Token Errors**

The function automatically removes invalid tokens from Firestore. This is normal when:
- User uninstalls the app
- User logs out
- Token expires

---

## 📚 Additional Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Firestore Triggers](https://firebase.google.com/docs/functions/firestore-events)

---

## 🎉 You're All Set!

Your Spark app now has a complete notification system:
- ✅ Automatic notifications when followed companies post opportunities
- ✅ Automatic notifications when someone replies to student reviews
- ✅ Automatic notifications when application status changes
- ✅ Notification history stored in Firestore
- ✅ Invalid token cleanup
- ✅ Comprehensive logging for debugging
- ✅ Test endpoint for manual testing

**Deploy and test**:
```bash
cd functions
firebase deploy --only functions
```

Need help? Check the logs or refer to this guide!
