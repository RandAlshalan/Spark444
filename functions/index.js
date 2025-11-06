/**
 * Spark App - Firebase Cloud Functions
 *
 * This file contains Cloud Functions for the Spark app including:
 * - Notification to students when followed companies post opportunities
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options for all functions
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1", // Change to your preferred region
});

// ============================================================================
// NOTIFY FOLLOWERS WHEN COMPANY POSTS NEW OPPORTUNITY
// ============================================================================
// Triggers when a new opportunity document is created in Firestore
// Sends push notifications to all students who follow that company
// ============================================================================
exports.notifyFollowersOnNewOpportunity = onDocumentCreated(
  "opportunities/{opportunityId}",
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("No data associated with the event");
        return null;
      }

      // Get the newly created opportunity data
      const opportunity = snapshot.data();
      const opportunityId = event.params.opportunityId;

      logger.info(`New opportunity created: ${opportunityId}`, {
        role: opportunity.role,
        companyId: opportunity.companyId,
      });

      // Validate required fields
      if (!opportunity.companyId) {
        logger.error("Opportunity missing companyId");
        return null;
      }

      // Step 1: Get company details
      const db = getFirestore();
      const companyDoc = await db
        .collection("companies")
        .doc(opportunity.companyId)
        .get();

      if (!companyDoc.exists) {
        logger.error(`Company not found: ${opportunity.companyId}`);
        return null;
      }

      const company = companyDoc.data();
      const companyName = company.companyName || "A company";

      logger.info(`Company name: ${companyName}`);

      // Step 2: Find all students who follow this company
      // Query the 'student' collection for users with this company in their following array
      const followersSnapshot = await db
        .collection("student")
        .where("following", "array-contains", opportunity.companyId)
        .get();

      if (followersSnapshot.empty) {
        logger.info(`No followers found for company ${companyName}`);
        return null;
      }

      logger.info(`Found ${followersSnapshot.size} followers for ${companyName}`);

      // Step 3: Collect FCM tokens from followers
      const tokens = [];
      const studentIds = [];

      followersSnapshot.forEach((doc) => {
        const student = doc.data();
        if (student.fcmToken) {
          tokens.push(student.fcmToken);
          studentIds.push(doc.id);
        }
      });

      if (tokens.length === 0) {
        logger.info("No followers have FCM tokens");
        return null;
      }

      logger.info(`Sending notifications to ${tokens.length} students`);

      // Step 4: Prepare notification content
      const notificationTitle = `New Opportunity at ${companyName}!`;
      const notificationBody = opportunity.role
        ? `${companyName} just posted: ${opportunity.role}`
        : `${companyName} just posted a new opportunity`;

      // Step 5: Send notifications using Firebase Cloud Messaging
      const message = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          route: "/opportunities", // Navigate to opportunities page
          opportunityId: opportunityId,
          companyId: opportunity.companyId,
          type: "new_opportunity",
        },
        // Android-specific options
        android: {
          priority: "high",
          notification: {
            channelId: "spark_channel",
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        // iOS-specific options
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      // Send to multiple devices
      const messaging = getMessaging();
      const results = await messaging.sendEachForMulticast({
        tokens: tokens,
        ...message,
      });

      // Step 6: Log results and handle failures
      logger.info(`Successfully sent ${results.successCount} notifications`);
      logger.info(`Failed to send ${results.failureCount} notifications`);

      // Handle failed tokens (remove invalid tokens from Firestore)
      if (results.failureCount > 0) {
        const failedTokens = [];
        results.responses.forEach((response, idx) => {
          if (!response.success) {
            logger.warn(`Failed to send to token: ${tokens[idx]}`, {
              error: response.error,
            });

            // If token is invalid, mark it for removal
            const errorCode = response.error?.code;
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              failedTokens.push({
                studentId: studentIds[idx],
                token: tokens[idx],
              });
            }
          }
        });

        // Remove invalid tokens from Firestore
        if (failedTokens.length > 0) {
          logger.info(`Removing ${failedTokens.length} invalid tokens`);
          const batch = db.batch();

          failedTokens.forEach(({studentId}) => {
            const studentRef = db.collection("student").doc(studentId);
            batch.update(studentRef, {
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          });

          await batch.commit();
          logger.info("Invalid tokens removed successfully");
        }
      }

      // Step 7: Create notification records in Firestore (optional)
      // This allows students to see notification history in the app
      const notificationBatch = db.batch();
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      studentIds.forEach((studentId) => {
        const notificationRef = db
          .collection("student")
          .doc(studentId)
          .collection("notifications")
          .doc();

        notificationBatch.set(notificationRef, {
          title: notificationTitle,
          body: notificationBody,
          type: "new_opportunity",
          opportunityId: opportunityId,
          companyId: opportunity.companyId,
          companyName: companyName,
          read: false,
          createdAt: timestamp,
        });
      });

      await notificationBatch.commit();
      logger.info("Notification records created in Firestore");

      return {
        success: true,
        sentTo: results.successCount,
        failed: results.failureCount,
      };
    } catch (error) {
      logger.error("Error in notifyFollowersOnNewOpportunity:", error);
      return null;
    }
  }
);

// ============================================================================
// ADDITIONAL HELPER FUNCTIONS
// ============================================================================

/**
 * Test function to manually trigger a notification
 * Usage: Call this HTTP endpoint with opportunity data
 */
exports.testNotification = require("firebase-functions/v2/https").onRequest(
  async (request, response) => {
    try {
      const {userId} = request.query;

      if (!userId) {
        response.status(400).send("Missing userId parameter");
        return;
      }

      // Get user's FCM token
      const db = getFirestore();
      const userDoc = await db.collection("student").doc(userId).get();

      if (!userDoc.exists) {
        response.status(404).send("User not found");
        return;
      }

      const fcmToken = userDoc.data().fcmToken;

      if (!fcmToken) {
        response.status(400).send("User has no FCM token");
        return;
      }

      // Send test notification
      const messaging = getMessaging();
      await messaging.send({
        token: fcmToken,
        notification: {
          title: "Test Notification",
          body: "This is a test notification from Spark!",
        },
        data: {
          route: "/notifications",
          type: "test",
        },
      });

      logger.info(`Test notification sent to user: ${userId}`);
      response.send("Test notification sent successfully!");
    } catch (error) {
      logger.error("Error sending test notification:", error);
      response.status(500).send(`Error: ${error.message}`);
    }
  }
);
