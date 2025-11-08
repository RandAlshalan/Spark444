# Automatic Application Status Update Feature

## Overview

The system now automatically updates application statuses from **"Pending"** to **"No Response"** when the response deadline passes.

## How It Works

### Automatic Monitoring

1. **Service starts automatically** when the app launches
2. **Checks every 30 minutes** for expired response deadlines
3. **Finds opportunities** where:
   - `responseDeadline` has passed
   - `isActive` is `true`
4. **Updates all pending applications** for those opportunities to "No Response"

### What Gets Updated

For each expired opportunity:
- All applications with `status: "Pending"` → `status: "No Response"`
- Adds `lastStatusUpdateDate` with current timestamp
- Adds `autoUpdated: true` flag
- Adds `autoUpdatedReason: "Response deadline passed"`
- Marks opportunity as `deadlineProcessed: true`

## Implementation Details

### Service File
`lib/services/application_deadline_service.dart`

### Key Features

1. **Singleton Pattern**: Only one instance runs
2. **Background Timer**: Checks every 30 minutes
3. **Batch Updates**: Efficiently updates up to 500 applications per batch
4. **Error Handling**: Catches and logs errors without crashing
5. **Logging**: Detailed debug logs for monitoring

### Service Methods

```dart
// Start automatic monitoring (called in main.dart)
ApplicationDeadlineService().startMonitoring();

// Stop monitoring
ApplicationDeadlineService().stopMonitoring();

// Manually trigger a check (for testing or immediate updates)
await ApplicationDeadlineService().checkNow();

// Check a specific opportunity
await ApplicationDeadlineService().checkOpportunity(opportunityId);

// Check if service is running
bool isRunning = ApplicationDeadlineService().isRunning;
```

## Integration

### In main.dart

The service starts automatically when the app launches:

```dart
@override
void initState() {
  super.initState();
  _initializeServices();
}

Future<void> _initializeServices() async {
  // Initialize notification service
  await NotificationService().initialize(navKey: _navigatorKey);

  // Start application deadline monitoring
  ApplicationDeadlineService().startMonitoring();
  print('ApplicationDeadlineService started');
}

@override
void dispose() {
  ApplicationDeadlineService().stopMonitoring();
  super.dispose();
}
```

## Database Structure

### Applications Collection

New fields added automatically:
- `autoUpdated`: `true` (boolean) - Flag indicating automatic update
- `autoUpdatedReason`: `"Response deadline passed"` (string) - Reason for update

### Opportunities Collection

New fields added automatically:
- `deadlineProcessed`: `true` (boolean) - Prevents re-processing
- `deadlineProcessedAt`: Timestamp - When deadline was processed

## Monitoring & Logging

### Console Output

When the service runs, you'll see logs like:

```
✅ ApplicationDeadlineService started
🔍 Checking for expired response deadlines...
📋 Found 3 opportunities with expired deadlines
Processing opportunity: opp123
  Updated 15 applications to "No Response"
✅ Total applications updated: 45
```

### Manual Check

For testing or immediate updates:

```dart
// In any Dart file
import 'package:your_app/services/application_deadline_service.dart';

// Trigger manual check
await ApplicationDeadlineService().checkNow();
```

## User Experience

### For Students

When viewing their applications:
- Status changes from "Pending" to "No Response"
- Students know the company didn't respond by the deadline
- Clear indication of auto-update vs manual company update

### For Companies

- No action required - updates happen automatically
- Can still manually update status even after auto-update
- Can see which applications were auto-updated via the `autoUpdated` flag

## Testing

### Test Scenario 1: Manual Trigger

```dart
// Import in a test file or button
import 'package:your_app/services/application_deadline_service.dart';

// Button onPressed
await ApplicationDeadlineService().checkNow();
```

### Test Scenario 2: Create Test Data

1. Create an opportunity with response deadline in the past
2. Create applications with "Pending" status
3. Wait for next check (30 mins) or trigger manually
4. Verify applications change to "No Response"

### Test Scenario 3: Verify Logging

```bash
flutter run --release
# Watch console for:
# ✅ ApplicationDeadlineService started
# 🔍 Checking for expired response deadlines...
```

## Firestore Queries Used

### Find Expired Opportunities
```dart
_firestore
  .collection('opportunities')
  .where('isActive', isEqualTo: true)
  .where('responseDeadline', isLessThan: Timestamp.now())
  .get()
```

### Find Pending Applications
```dart
_firestore
  .collection('applications')
  .where('opportunityId', isEqualTo: opportunityId)
  .where('status', isEqualTo: 'Pending')
  .get()
```

## Performance Considerations

### Optimizations

1. **Batch Updates**: Uses Firestore batches for efficiency
2. **Deadline Processed Flag**: Prevents checking same opportunity multiple times
3. **30-Minute Interval**: Balances timeliness with resource usage
4. **Query Filters**: Only fetches relevant opportunities

### Scalability

- Can handle 500 applications per opportunity (Firestore batch limit)
- For opportunities with >500 applications, processes in multiple batches
- Minimal performance impact - runs in background

## Future Enhancements

### Potential Improvements

1. **Notification to Students**: Send notification when status auto-updates
2. **Email Notification**: Notify students via email about status change
3. **Configurable Check Interval**: Allow admin to set check frequency
4. **Dashboard Stats**: Show how many applications were auto-updated
5. **Grace Period**: Add configurable grace period after deadline
6. **Bulk Manual Trigger**: Allow companies to manually trigger for their opportunities

### Notification Integration

Add to `application_deadline_service.dart`:

```dart
// After updating application status
await NotificationHelper().notifyApplicationStatusUpdate(
  studentId: application.studentId,
  companyName: companyName,
  opportunityRole: opportunityRole,
  status: 'No Response',
  opportunityId: application.opportunityId,
);
```

## Configuration

### Change Check Interval

Edit `application_deadline_service.dart`:

```dart
// Change from 30 minutes to 1 hour
_checkTimer = Timer.periodic(const Duration(hours: 1), (_) {
  _checkExpiredDeadlines();
});
```

### Disable Auto-Updates

In `main.dart`, comment out:

```dart
// ApplicationDeadlineService().startMonitoring();
```

## Troubleshooting

### Service Not Running

Check console for:
```
⚠️ ApplicationDeadlineService already running
```

If you see this but no updates happen, restart the service:

```dart
ApplicationDeadlineService().stopMonitoring();
ApplicationDeadlineService().startMonitoring();
```

### No Applications Updated

Verify:
1. Opportunities have `responseDeadline` field set
2. Response deadline is in the past
3. Opportunities have `isActive: true`
4. Applications have `status: "Pending"`
5. Check console logs for errors

### Firestore Permission Errors

Ensure Firestore security rules allow:

```javascript
match /applications/{applicationId} {
  allow update: if request.auth != null;
}

match /opportunities/{opportunityId} {
  allow read: if request.auth != null;
  allow update: if request.auth != null;
}
```

## FAQ

**Q: How often does it check?**
A: Every 30 minutes, plus immediately when the app starts.

**Q: Can I manually trigger it?**
A: Yes, call `ApplicationDeadlineService().checkNow()`

**Q: Does it work when the app is closed?**
A: No, it only runs when the app is active. For background processing, you'd need Cloud Functions.

**Q: What if I want cloud-based processing?**
A: Implement the same logic as a Firebase Cloud Function triggered by a scheduled function (cron job).

**Q: Can companies override auto-updates?**
A: Yes, companies can manually change status even after auto-update.

**Q: How do I know if an application was auto-updated?**
A: Check the `autoUpdated` field in the application document.

## Cloud Functions Alternative

For production, consider implementing this as a Firebase Cloud Function:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.updateExpiredApplications = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    // Find expired opportunities
    const opportunitiesSnapshot = await admin.firestore()
      .collection('opportunities')
      .where('isActive', '==', true)
      .where('responseDeadline', '<', now)
      .where('deadlineProcessed', '!=', true)
      .get();

    // Update applications...

    return null;
  });
```

Benefits:
- Runs even when app is closed
- Centralized processing
- More reliable
- Better for production

---

**Status**: ✅ Implemented and Active

**Version**: 1.0

**Last Updated**: 2025-01-08
