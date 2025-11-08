/**
 * Spark App - Notify Followers on New Opportunity
 * ------------------------------------------------
 * Cloud Function that sends FCM notifications to all students
 * who follow a company when it posts a new opportunity.
 */

import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
});

// ============================================================================
// 🔔 Trigger: When a company posts a new opportunity
// ============================================================================
export const notifyFollowersOnNewOpportunity = onDocumentCreated(
  "opportunities/{opportunityId}",
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("No data found in new opportunity event");
        return null;
      }

      const opportunity = snapshot.data();
      const companyId = opportunity.companyId;
      const role = opportunity.role || "new opportunity";

      if (!companyId) {
        logger.error("Missing companyId in opportunity");
        return null;
      }

      const db = getFirestore();

      // Get company details
      const companyDoc = await db.collection("companies").doc(companyId).get();
      if (!companyDoc.exists) {
        logger.error(`Company not found: ${companyId}`);
        return null;
      }

      const companyData = companyDoc.data();
      const companyName = companyData?.companyName || "A company";

      // Find all students following this company
      const followersSnapshot = await db
        .collection("student")
        .where("followedCompanies", "array-contains", companyId)
        .get();

      if (followersSnapshot.empty) {
        logger.info(`No followers found for ${companyName}`);
        return null;
      }

      const tokens: string[] = [];
      const studentIds: string[] = [];

      followersSnapshot.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token) {
          tokens.push(token);
          studentIds.push(doc.id);
        }
      });

      if (tokens.length === 0) {
        logger.info("No valid FCM tokens found.");
        return null;
      }

      // Prepare notification payload
      const message = {
        notification: {
          title: `${companyName} posted a new opportunity!`,
          body: `Check out the ${role} position.`,
        },
        data: {
          route: "/opportunities",
          companyId,
          type: "new_opportunity",
        },
      };

      // Send push notifications
      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast({
        tokens,
        ...message,
      });

      logger.info(`✅ Sent ${response.successCount} notifications, failed ${response.failureCount}`);

      // Save notification in Firestore for in-app listing
      const batch = db.batch();
      const createdAt = admin.firestore.FieldValue.serverTimestamp();

      studentIds.forEach((studentId) => {
        const notifRef = db
          .collection("student")
          .doc(studentId)
          .collection("notifications")
          .doc();

        batch.set(notifRef, {
          title: message.notification.title,
          body: message.notification.body,
          type: "new_opportunity",
          companyId,
          read: false,
          createdAt,
        });
      });

      await batch.commit();
      logger.info("📚 Notification records saved in Firestore");

      return null;
    } catch (error) {
      logger.error("❌ Error sending notifications:", error);
      return null;
    }
  }
);
