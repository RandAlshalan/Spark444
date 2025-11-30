/**
 * Spark App - Firebase Cloud Functions (Complete v2 - TypeScript)
 *
 * All notifications follow the same standard pattern:
 * 1. Validate data
 * 2. Get user FCM token
 * 3. Send push notification
 * 4. Save in-app notification to Firestore
 * 5. Handle invalid tokens
 */

import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
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

const db = getFirestore();

// ============================================================================
// HELPER FUNCTION: Send notification (consistent pattern)
// ============================================================================
async function sendNotificationToStudent(params: {
  studentId: string;
  title: string;
  body: string;
  data: Record<string, string>;
  type: string;
  additionalData?: Record<string, any>;
}): Promise<boolean> {
  try {
    const { studentId, title, body, data, type, additionalData = {} } = params;

    // Get student
    const studentDoc = await db.collection("student").doc(studentId).get();
    if (!studentDoc.exists) {
      logger.error(`❌ Student not found: ${studentId}`);
      return false;
    }

    const student = studentDoc.data();
    const fcmToken = student?.fcmToken;

    // Send push notification if token exists
    if (fcmToken) {
      const messaging = getMessaging();

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title,
            body,
          },
          data: {
            ...data,
            type,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "spark_channel",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });

        logger.info(`✅ Push notification sent to student ${studentId}`);
      } catch (sendError: any) {
        const errorCode = sendError.code;
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          logger.info(`🧹 Removing invalid token for student ${studentId}`);
          await db.collection("student").doc(studentId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        } else {
          logger.error(`❌ Error sending push: ${sendError}`);
        }
      }
    } else {
      logger.warn(`⚠️ Student ${studentId} has no FCM token`);
    }

    // ALWAYS save in-app notification
    await db.collection("notifications").add({
      userId: studentId,
      type,
      title,
      body,
      data,
      ...additionalData,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`✅ In-app notification saved for student ${studentId}`);
    return true;
  } catch (error) {
    logger.error(`❌ Error in sendNotificationToStudent: ${error}`);
    return false;
  }
}

// ============================================================================
// 📢 Notify followers when company posts new opportunity (EXISTING - PRESERVED)
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

// ============================================================================
// 💬 Notify student when someone replies to their review
// ============================================================================
export const notifyStudentOnReviewReply = onDocumentCreated(
  "reviews/{reviewId}",
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) return null;

      const reply = snapshot.data();
      const reviewId = event.params.reviewId;

      // Check if this is a reply (has parentId)
      if (!reply.parentId || !reply.parentId.trim()) {
        logger.info("ℹ️ Not a reply, skipping notification");
        return null;
      }

      logger.info("💬 New reply created:", { reviewId, parentId: reply.parentId });

      // Get parent review
      const parentReviewDoc = await db.collection("reviews").doc(reply.parentId).get();
      if (!parentReviewDoc.exists) {
        logger.error(`❌ Parent review not found: ${reply.parentId}`);
        return null;
      }

      const parentReview = parentReviewDoc.data();
      const originalStudentId = parentReview?.studentId;

      if (!originalStudentId) {
        logger.error("❌ Parent review missing studentId");
        return null;
      }

      // Don't notify if replying to own review
      if (reply.studentId === originalStudentId) {
        logger.info("ℹ️ Student replied to their own review, skipping");
        return null;
      }

      // Get company name
      let companyName = "a company";
      if (reply.companyId) {
        const companyDoc = await db.collection("companies").doc(reply.companyId).get();
        if (companyDoc.exists) {
          companyName = companyDoc.data()?.companyName || "a company";
        }
      }

      const replyText = reply.reviewText || "";
      const replySnippet = replyText.length > 100 ? `${replyText.substring(0, 100)}...` : replyText;

      await sendNotificationToStudent({
        studentId: originalStudentId,
        title: "New Reply to Your Review",
        body: `Someone replied to your review about ${companyName}`,
        data: {
          route: "/my-reviews",
          reviewId: reply.parentId,
          replyId: reviewId,
          companyId: reply.companyId || "",
        },
        type: "review_reply",
        additionalData: {
          companyName,
          companyId: reply.companyId || "",
          reviewId: reply.parentId,
          replyId: reviewId,
          replySnippet,
        },
      });

      return null;
    } catch (err) {
      logger.error("🔥 Error in notifyStudentOnReviewReply:", err);
      return null;
    }
  }
);

// ============================================================================
// 💼 Notify student when company replies to their review (via subcollection)
// ============================================================================
export const notifyStudentOnCompanyReply = onDocumentCreated(
  "reviews/{reviewId}/replies/{replyId}",
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) return null;

      const reply = snapshot.data();
      const reviewId = event.params.reviewId;
      const replyId = event.params.replyId;

      logger.info("💼 Company reply created:", { reviewId, replyId, companyId: reply.companyId });

      // Get parent review
      const parentReviewDoc = await db.collection("reviews").doc(reviewId).get();
      if (!parentReviewDoc.exists) {
        logger.error(`❌ Parent review not found: ${reviewId}`);
        return null;
      }

      const parentReview = parentReviewDoc.data();
      const studentId = parentReview?.studentId;

      if (!studentId) {
        logger.error("❌ Parent review missing studentId");
        return null;
      }

      const companyName = reply.companyName || "A company";

      await sendNotificationToStudent({
        studentId,
        title: `${companyName} replied to your review`,
        body: "Check out the company's response",
        data: {
          route: "/my-reviews",
          reviewId,
          replyId,
          companyId: reply.companyId || "",
        },
        type: "review_reply",
        additionalData: {
          companyName,
          companyId: reply.companyId || "",
          reviewId,
          replyId,
        },
      });

      return null;
    } catch (err) {
      logger.error("🔥 Error in notifyStudentOnCompanyReply:", err);
      return null;
    }
  }
);

// ============================================================================
// 📋 Notify student when application status is updated
// ============================================================================
export const notifyStudentOnApplicationUpdate = onDocumentUpdated(
  "applications/{applicationId}",
  async (event) => {
    try {
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();
      const applicationId = event.params.applicationId;

      if (!beforeData || !afterData) return null;

      // Check if status changed
      if (beforeData.status === afterData.status) {
        logger.info("ℹ️ No status change, skipping notification");
        return null;
      }

      logger.info("📋 Application status changed:", {
        applicationId,
        oldStatus: beforeData.status,
        newStatus: afterData.status,
      });

      const studentId = afterData.studentId;
      if (!studentId) {
        logger.error("❌ Application missing studentId");
        return null;
      }

      // Get opportunity details
      const opportunityId = afterData.opportunityId;
      let opportunityTitle = "an opportunity";
      let companyName = "a company";

      if (opportunityId) {
        const opportunityDoc = await db.collection("opportunities").doc(opportunityId).get();
        if (opportunityDoc.exists) {
          const opportunity = opportunityDoc.data();
          opportunityTitle = opportunity?.role || opportunityTitle;

          if (opportunity?.companyId) {
            const companyDoc = await db.collection("companies").doc(opportunity.companyId).get();
            if (companyDoc.exists) {
              companyName = companyDoc.data()?.companyName || companyName;
            }
          }
        }
      }

      // Prepare notification content based on status
      const newStatus = afterData.status;
      let notificationTitle = "Application Status Updated";
      let notificationBody = `Your application status has been updated to: ${newStatus}`;

      if (newStatus === "Reviewed") {
        notificationTitle = "Application Reviewed";
        notificationBody = `Your application for ${opportunityTitle} at ${companyName} has been reviewed`;
      } else if (newStatus === "Rejected") {
        notificationTitle = "Application Update";
        notificationBody = `Thank you for your interest in ${opportunityTitle} at ${companyName}`;
      } else if (newStatus === "Hired") {
        notificationTitle = "Congratulations!";
        notificationBody = `You've been selected for ${opportunityTitle} at ${companyName}!`;
      } else if (newStatus === "Interviewing") {
        notificationTitle = "Interview Invitation";
        notificationBody = `${companyName} has invited you for an interview for ${opportunityTitle}`;
      }

      await sendNotificationToStudent({
        studentId,
        title: notificationTitle,
        body: notificationBody,
        data: {
          route: "/opportunities",
          applicationId,
          opportunityId: opportunityId || "",
          status: newStatus,
        },
        type: "application_status_update",
        additionalData: {
          companyName,
          opportunityTitle,
          opportunityId: opportunityId || "",
          applicationId,
          status: newStatus,
          oldStatus: beforeData.status,
        },
      });

      return null;
    } catch (err) {
      logger.error("🔥 Error in notifyStudentOnApplicationUpdate:", err);
      return null;
    }
  }
);

// ============================================================================
// 📅 Send deadline notification when student applies
// ============================================================================
export const sendDeadlineNotificationOnApply = onDocumentCreated(
  "applications/{applicationId}",
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) return null;

      const application = snapshot.data();
      const studentId = application.studentId;
      const opportunityId = application.opportunityId;

      logger.info("📝 New application created:", {
        applicationId: event.params.applicationId,
        studentId,
        opportunityId,
      });

      if (!studentId || !opportunityId) {
        logger.error("❌ Missing studentId or opportunityId");
        return null;
      }

      // Get opportunity
      const opportunityDoc = await db.collection("opportunities").doc(opportunityId).get();
      if (!opportunityDoc.exists) {
        logger.error(`❌ Opportunity not found: ${opportunityId}`);
        return null;
      }

      const opportunity = opportunityDoc.data();
      const applicationDeadline = opportunity?.applicationDeadline;

      if (!applicationDeadline) {
        logger.info("ℹ️ Opportunity has no deadline");
        return null;
      }

      // Get company name
      let companyName = "Company";
      if (opportunity?.companyId) {
        const companyDoc = await db.collection("companies").doc(opportunity.companyId).get();
        if (companyDoc.exists) {
          companyName = companyDoc.data()?.companyName || companyName;
        }
      }

      // Calculate days until deadline
      const deadlineDate = applicationDeadline.toDate();
      const now = new Date();
      const daysUntil = Math.ceil((deadlineDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      let deadlineText;
      if (daysUntil === 0) {
        deadlineText = "today";
      } else if (daysUntil === 1) {
        deadlineText = "tomorrow";
      } else if (daysUntil < 0) {
        return null; // Don't send if deadline passed
      } else {
        deadlineText = `in ${daysUntil} days`;
      }

      const role = opportunity?.role || "Position";

      await sendNotificationToStudent({
        studentId,
        title: "📅 Application Deadline",
        body: `The deadline for ${role} at ${companyName} is ${deadlineText}`,
        data: {
          route: "/opportunities",
          opportunityId,
          companyId: opportunity?.companyId || "",
        },
        type: "deadline_info",
        additionalData: {
          opportunityId,
          opportunityRole: role,
          companyName,
          companyId: opportunity?.companyId || "",
          deadline: applicationDeadline,
        },
      });

      return null;
    } catch (err) {
      logger.error("🔥 Error in sendDeadlineNotificationOnApply:", err);
      return null;
    }
  }
);

// ============================================================================
// 📌 Send deadline notification when student bookmarks
// ============================================================================
export const sendDeadlineNotificationOnBookmark = onDocumentCreated(
  "bookmarks/{bookmarkId}",
  async (event) => {
    try {
      const snapshot = event.data;
      if (!snapshot) return null;

      const bookmark = snapshot.data();
      const studentId = bookmark.studentId;
      const opportunityId = bookmark.opportunityId;

      logger.info("🔖 New bookmark created:", {
        bookmarkId: event.params.bookmarkId,
        studentId,
        opportunityId,
      });

      if (!studentId || !opportunityId) {
        logger.error("❌ Missing studentId or opportunityId");
        return null;
      }

      // Get opportunity
      const opportunityDoc = await db.collection("opportunities").doc(opportunityId).get();
      if (!opportunityDoc.exists) {
        logger.error(`❌ Opportunity not found: ${opportunityId}`);
        return null;
      }

      const opportunity = opportunityDoc.data();
      const applicationDeadline = opportunity?.applicationDeadline;

      if (!applicationDeadline) {
        logger.info("ℹ️ Opportunity has no deadline");
        return null;
      }

      // Get company name
      let companyName = "Company";
      if (opportunity?.companyId) {
        const companyDoc = await db.collection("companies").doc(opportunity.companyId).get();
        if (companyDoc.exists) {
          companyName = companyDoc.data()?.companyName || companyName;
        }
      }

      // Calculate days until deadline
      const deadlineDate = applicationDeadline.toDate();
      const now = new Date();
      const daysUntil = Math.ceil((deadlineDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      let deadlineText;
      if (daysUntil === 0) {
        deadlineText = "today";
      } else if (daysUntil === 1) {
        deadlineText = "tomorrow";
      } else if (daysUntil < 0) {
        return null; // Don't send if deadline passed
      } else {
        deadlineText = `in ${daysUntil} days`;
      }

      const role = opportunity?.role || "Position";

      await sendNotificationToStudent({
        studentId,
        title: "📌 Bookmark Reminder",
        body: `The deadline for ${role} at ${companyName} is ${deadlineText}`,
        data: {
          route: "/opportunities",
          opportunityId,
          companyId: opportunity?.companyId || "",
        },
        type: "deadline_info",
        additionalData: {
          opportunityId,
          opportunityRole: role,
          companyName,
          companyId: opportunity?.companyId || "",
          deadline: applicationDeadline,
        },
      });

      return null;
    } catch (err) {
      logger.error("🔥 Error in sendDeadlineNotificationOnBookmark:", err);
      return null;
    }
  }
);

// ============================================================================
// ⏰ Check for upcoming deadlines and send reminders (runs every hour)
// ============================================================================
export const checkDeadlineReminders = onSchedule("every 1 hours", async (event) => {
  try {
    logger.info("⏰ Checking for deadline reminders...");

    const tomorrow = new Date();
    tomorrow.setHours(tomorrow.getHours() + 24);
    const dayAfterTomorrow = new Date();
    dayAfterTomorrow.setHours(dayAfterTomorrow.getHours() + 25);

    // Find opportunities with deadlines in 24-25 hours
    const opportunitiesSnapshot = await db
      .collection("opportunities")
      .where("applicationDeadline", ">=", admin.firestore.Timestamp.fromDate(tomorrow))
      .where("applicationDeadline", "<", admin.firestore.Timestamp.fromDate(dayAfterTomorrow))
      .where("isActive", "==", true)
      .get();

    if (opportunitiesSnapshot.empty) {
      logger.info("✅ No upcoming deadlines found");
      return;
    }

    logger.info(`📋 Found ${opportunitiesSnapshot.size} opportunities with upcoming deadlines`);

    for (const oppDoc of opportunitiesSnapshot.docs) {
      const opportunity = oppDoc.data();
      const opportunityId = oppDoc.id;

      // Get students who bookmarked or applied
      const studentIds = new Set<string>();

      // Get bookmarkers
      const bookmarksSnapshot = await db
        .collection("bookmarks")
        .where("opportunityId", "==", opportunityId)
        .get();

      bookmarksSnapshot.forEach((doc) => {
        studentIds.add(doc.data().studentId);
      });

      // Get applicants (pending only)
      const applicationsSnapshot = await db
        .collection("applications")
        .where("opportunityId", "==", opportunityId)
        .where("status", "==", "Pending")
        .get();

      applicationsSnapshot.forEach((doc) => {
        studentIds.add(doc.data().studentId);
      });

      if (studentIds.size === 0) continue;

      // Get company name
      let companyName = "Company";
      if (opportunity.companyId) {
        const companyDoc = await db.collection("companies").doc(opportunity.companyId).get();
        if (companyDoc.exists) {
          companyName = companyDoc.data()?.companyName || companyName;
        }
      }

      // Send notifications to each student
      for (const studentId of studentIds) {
        // Check if already sent
        const existingReminder = await db
          .collection("notifications")
          .where("userId", "==", studentId)
          .where("type", "==", "deadline_reminder")
          .where("data.opportunityId", "==", opportunityId)
          .get();

        if (!existingReminder.empty) continue;

        await sendNotificationToStudent({
          studentId,
          title: "⏰ Deadline Reminder",
          body: `Reminder: ${opportunity.role} at ${companyName} deadline is tomorrow!`,
          data: {
            route: "/opportunities",
            opportunityId,
            companyId: opportunity.companyId || "",
          },
          type: "deadline_reminder",
          additionalData: {
            opportunityId,
            opportunityRole: opportunity.role,
            companyName,
            companyId: opportunity.companyId || "",
          },
        });
      }

      logger.info(`✅ Sent reminders for ${opportunity.role} to ${studentIds.size} students`);
    }
  } catch (err) {
    logger.error("🔥 Error in checkDeadlineReminders:", err);
  }
});

// ============================================================================
// 🧪 Test notification function
// ============================================================================
export const testNotification = onRequest(async (req, res) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).send("Missing userId parameter");
      return;
    }

    const success = await sendNotificationToStudent({
      studentId: userId,
      title: "Test Notification",
      body: "This is a test notification from Spark!",
      data: {
        route: "/notifications",
      },
      type: "test",
    });

    if (success) {
      res.send("✅ Test notification sent successfully!");
    } else {
      res.status(500).send("❌ Failed to send test notification");
    }
  } catch (err) {
    logger.error("❌ Error sending test notification:", err);
    res.status(500).send(`Error: ${err}`);
  }
});
