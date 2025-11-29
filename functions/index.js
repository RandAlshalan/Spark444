/**
 * Spark App - Firebase Cloud Functions (Complete v3 - Fully Consistent)
 *
 * All notifications follow the same standard pattern:
 * 1. Validate data
 * 2. Get user FCM token
 * 3. Send push notification
 * 4. Save in-app notification to Firestore
 * 5. Handle invalid tokens
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// HELPER FUNCTION: Send notification (consistent pattern)
// ============================================================================
async function sendNotificationToStudent({
  studentId,
  title,
  body,
  data,
  type,
  additionalData = {},
}) {
  try {
    // Get student
    const studentDoc = await db.collection("student").doc(studentId).get();
    if (!studentDoc.exists) {
      console.error(`❌ Student not found: ${studentId}`);
      return false;
    }

    const student = studentDoc.data();
    const fcmToken = student.fcmToken;

    // Send push notification if token exists
    if (fcmToken) {
      const messaging = admin.messaging();

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            ...data,
            type: type,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "spark_channel",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
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

        console.log(`✅ Push notification sent to student ${studentId}`);
      } catch (sendError) {
        const errorCode = sendError.code;
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          console.log(`🧹 Removing invalid token for student ${studentId}`);
          await db.collection("student").doc(studentId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        } else {
          console.error(`❌ Error sending push: ${sendError}`);
        }
      }
    } else {
      console.log(`⚠️ Student ${studentId} has no FCM token`);
    }

    // ALWAYS save in-app notification
    await db.collection("notifications").add({
      userId: studentId,
      type: type,
      title: title,
      body: body,
      data: data,
      ...additionalData,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ In-app notification saved for student ${studentId}`);
    return true;
  } catch (error) {
    console.error(`❌ Error in sendNotificationToStudent: ${error}`);
    return false;
  }
}

// ============================================================================
// 📢 Notify followers when company posts new opportunity
// ============================================================================
exports.notifyFollowersOnNewOpportunity = functions.firestore
  .document("opportunities/{opportunityId}")
  .onCreate(async (snapshot, context) => {
    try {
      const opportunity = snapshot.data();
      const opportunityId = context.params.opportunityId;

      console.log("🚀 New opportunity created:", {
        opportunityId,
        companyId: opportunity.companyId,
        role: opportunity.role,
      });

      if (!opportunity.companyId) {
        console.error("❌ Opportunity missing companyId");
        return null;
      }

      // Get company details
      const companyDoc = await db
        .collection("companies")
        .doc(opportunity.companyId)
        .get();

      if (!companyDoc.exists) {
        console.error(`❌ Company not found: ${opportunity.companyId}`);
        return null;
      }

      const company = companyDoc.data();
      const companyName = company.companyName || "A company";
      const role = opportunity.role || "a new opportunity";

      // Get followers
      const followersSnapshot = await db
        .collection("student")
        .where("followedCompanies", "array-contains", opportunity.companyId)
        .get();

      if (followersSnapshot.empty) {
        console.log(`ℹ️ No followers found for company ${companyName}`);
        return null;
      }

      console.log(`📋 Found ${followersSnapshot.size} followers`);

      const tokens = [];
      const studentIds = [];

      followersSnapshot.forEach((doc) => {
        const student = doc.data();
        if (student.fcmToken) {
          tokens.push(student.fcmToken);
          studentIds.push(doc.id);
        }
      });

      const notificationTitle = `New Opportunity at ${companyName}!`;
      const notificationBody = `${companyName} just posted: ${role}`;

      // Send push notifications (batch)
      if (tokens.length > 0) {
        const messaging = admin.messaging();
        const message = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            route: "/opportunities",
            opportunityId: opportunityId,
            companyId: opportunity.companyId,
            type: "new_opportunity",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "spark_channel",
              sound: "default",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
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
          tokens: tokens,
        };

        const response = await messaging.sendMulticast(message);
        console.log(
          `✅ Push notifications: ${response.successCount} sent, ${response.failureCount} failed`
        );

        // Remove invalid tokens
        if (response.failureCount > 0) {
          const invalidTokens = [];
          response.responses.forEach((res, idx) => {
            if (!res.success) {
              const errorCode = res.error?.code;
              if (
                errorCode === "messaging/invalid-registration-token" ||
                errorCode === "messaging/registration-token-not-registered"
              ) {
                invalidTokens.push(studentIds[idx]);
              }
            }
          });

          if (invalidTokens.length > 0) {
            console.log(`🧹 Removing ${invalidTokens.length} invalid tokens`);
            const batch = db.batch();
            invalidTokens.forEach((id) => {
              batch.update(db.collection("student").doc(id), {
                fcmToken: admin.firestore.FieldValue.delete(),
              });
            });
            await batch.commit();
          }
        }
      }

      // Save in-app notifications for ALL followers
      const batch = db.batch();
      followersSnapshot.forEach((doc) => {
        const ref = db.collection("notifications").doc();
        batch.set(ref, {
          userId: doc.id,
          type: "new_opportunity",
          title: notificationTitle,
          body: notificationBody,
          data: {
            route: "/opportunities",
            opportunityId: opportunityId,
            companyId: opportunity.companyId,
          },
          companyName: companyName,
          companyId: opportunity.companyId,
          opportunityId: opportunityId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();

      console.log(`✅ In-app notifications saved for ${followersSnapshot.size} students`);
      return null;
    } catch (err) {
      console.error("🔥 Error in notifyFollowersOnNewOpportunity:", err);
      return null;
    }
  });

// ============================================================================
// 💬 Notify student when someone replies to their review
// ============================================================================
exports.notifyStudentOnReviewReply = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snapshot, context) => {
    try {
      const reply = snapshot.data();
      const reviewId = context.params.reviewId;

      // Check if this is a reply (has parentId)
      if (!reply.parentId || !reply.parentId.trim()) {
        console.log("ℹ️ Not a reply, skipping notification");
        return null;
      }

      console.log("💬 New reply created:", {
        reviewId,
        parentId: reply.parentId,
      });

      // Get parent review
      const parentReviewDoc = await db
        .collection("reviews")
        .doc(reply.parentId)
        .get();

      if (!parentReviewDoc.exists) {
        console.error(`❌ Parent review not found: ${reply.parentId}`);
        return null;
      }

      const parentReview = parentReviewDoc.data();
      const originalStudentId = parentReview.studentId;

      if (!originalStudentId) {
        console.error("❌ Parent review missing studentId");
        return null;
      }

      // Don't notify if replying to own review
      if (reply.studentId === originalStudentId) {
        console.log("ℹ️ Student replied to their own review, skipping");
        return null;
      }

      // Get company name
      let companyName = "a company";
      if (reply.companyId) {
        const companyDoc = await db
          .collection("companies")
          .doc(reply.companyId)
          .get();
        if (companyDoc.exists) {
          companyName = companyDoc.data().companyName || "a company";
        }
      }

      const replyText = reply.reviewText || "";
      const replySnippet =
        replyText.length > 100 ? `${replyText.substring(0, 100)}...` : replyText;

      // Use consistent helper function
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
          companyName: companyName,
          companyId: reply.companyId || "",
          reviewId: reply.parentId,
          replyId: reviewId,
          replySnippet: replySnippet,
        },
      });

      return null;
    } catch (err) {
      console.error("🔥 Error in notifyStudentOnReviewReply:", err);
      return null;
    }
  });

// ============================================================================
// 💼 Notify student when company replies to their review (via subcollection)
// ============================================================================
exports.notifyStudentOnCompanyReply = functions.firestore
  .document("reviews/{reviewId}/replies/{replyId}")
  .onCreate(async (snapshot, context) => {
    try {
      const reply = snapshot.data();
      const reviewId = context.params.reviewId;
      const replyId = context.params.replyId;

      console.log("💼 Company reply created:", {
        reviewId,
        replyId,
        companyId: reply.companyId,
      });

      // Get parent review
      const parentReviewDoc = await db.collection("reviews").doc(reviewId).get();

      if (!parentReviewDoc.exists) {
        console.error(`❌ Parent review not found: ${reviewId}`);
        return null;
      }

      const parentReview = parentReviewDoc.data();
      const studentId = parentReview.studentId;

      if (!studentId) {
        console.error("❌ Parent review missing studentId");
        return null;
      }

      const companyName = reply.companyName || "A company";

      // Use consistent helper function
      await sendNotificationToStudent({
        studentId: studentId,
        title: `${companyName} replied to your review`,
        body: "Check out the company's response",
        data: {
          route: "/my-reviews",
          reviewId: reviewId,
          replyId: replyId,
          companyId: reply.companyId || "",
        },
        type: "review_reply",
        additionalData: {
          companyName: companyName,
          companyId: reply.companyId || "",
          reviewId: reviewId,
          replyId: replyId,
        },
      });

      return null;
    } catch (err) {
      console.error("🔥 Error in notifyStudentOnCompanyReply:", err);
      return null;
    }
  });

// ============================================================================
// 📋 Notify student when application status is updated
// ============================================================================
exports.notifyStudentOnApplicationUpdate = functions.firestore
  .document("applications/{applicationId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const applicationId = context.params.applicationId;

      // Check if status changed
      if (before.status === after.status) {
        console.log("ℹ️ No status change, skipping notification");
        return null;
      }

      console.log("📋 Application status changed:", {
        applicationId,
        oldStatus: before.status,
        newStatus: after.status,
      });

      const studentId = after.studentId;
      if (!studentId) {
        console.error("❌ Application missing studentId");
        return null;
      }

      // Get opportunity details
      const opportunityId = after.opportunityId;
      let opportunityTitle = "an opportunity";
      let companyName = "a company";

      if (opportunityId) {
        const opportunityDoc = await db
          .collection("opportunities")
          .doc(opportunityId)
          .get();

        if (opportunityDoc.exists) {
          const opportunity = opportunityDoc.data();
          opportunityTitle = opportunity.role || opportunityTitle;

          if (opportunity.companyId) {
            const companyDoc = await db
              .collection("companies")
              .doc(opportunity.companyId)
              .get();
            if (companyDoc.exists) {
              companyName = companyDoc.data().companyName || companyName;
            }
          }
        }
      }

      // Prepare notification content based on status
      const newStatus = after.status;
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

      // Use consistent helper function
      await sendNotificationToStudent({
        studentId: studentId,
        title: notificationTitle,
        body: notificationBody,
        data: {
          route: "/opportunities",
          applicationId: applicationId,
          opportunityId: opportunityId || "",
          status: newStatus,
        },
        type: "application_status_update",
        additionalData: {
          companyName: companyName,
          opportunityTitle: opportunityTitle,
          opportunityId: opportunityId || "",
          applicationId: applicationId,
          status: newStatus,
          oldStatus: before.status,
        },
      });

      return null;
    } catch (err) {
      console.error("🔥 Error in notifyStudentOnApplicationUpdate:", err);
      return null;
    }
  });

// ============================================================================
// 📅 Send deadline notification when student applies
// ============================================================================
exports.sendDeadlineNotificationOnApply = functions.firestore
  .document("applications/{applicationId}")
  .onCreate(async (snapshot, context) => {
    try {
      const application = snapshot.data();
      const studentId = application.studentId;
      const opportunityId = application.opportunityId;

      console.log("📝 New application created:", {
        applicationId: context.params.applicationId,
        studentId,
        opportunityId,
      });

      if (!studentId || !opportunityId) {
        console.error("❌ Missing studentId or opportunityId");
        return null;
      }

      // Get opportunity
      const opportunityDoc = await db
        .collection("opportunities")
        .doc(opportunityId)
        .get();

      if (!opportunityDoc.exists) {
        console.error(`❌ Opportunity not found: ${opportunityId}`);
        return null;
      }

      const opportunity = opportunityDoc.data();
      const applicationDeadline = opportunity.applicationDeadline;

      if (!applicationDeadline) {
        console.log("ℹ️ Opportunity has no deadline");
        return null;
      }

      // Get company name
      let companyName = "Company";
      if (opportunity.companyId) {
        const companyDoc = await db
          .collection("companies")
          .doc(opportunity.companyId)
          .get();
        if (companyDoc.exists) {
          companyName = companyDoc.data().companyName || companyName;
        }
      }

      // Calculate days until deadline
      const deadlineDate = applicationDeadline.toDate();
      const now = new Date();
      const daysUntil = Math.ceil((deadlineDate - now) / (1000 * 60 * 60 * 24));

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

      const role = opportunity.role || "Position";

      // Use consistent helper function
      await sendNotificationToStudent({
        studentId: studentId,
        title: "📅 Application Deadline",
        body: `The deadline for ${role} at ${companyName} is ${deadlineText}`,
        data: {
          route: "/opportunities",
          opportunityId: opportunityId,
          companyId: opportunity.companyId || "",
        },
        type: "deadline_info",
        additionalData: {
          opportunityId: opportunityId,
          opportunityRole: role,
          companyName: companyName,
          companyId: opportunity.companyId || "",
          deadline: applicationDeadline,
        },
      });

      return null;
    } catch (err) {
      console.error("🔥 Error in sendDeadlineNotificationOnApply:", err);
      return null;
    }
  });

// ============================================================================
// 📌 Send deadline notification when student bookmarks
// ============================================================================
exports.sendDeadlineNotificationOnBookmark = functions.firestore
  .document("bookmarks/{bookmarkId}")
  .onCreate(async (snapshot, context) => {
    try {
      const bookmark = snapshot.data();
      const studentId = bookmark.studentId;
      const opportunityId = bookmark.opportunityId;

      console.log("🔖 New bookmark created:", {
        bookmarkId: context.params.bookmarkId,
        studentId,
        opportunityId,
      });

      if (!studentId || !opportunityId) {
        console.error("❌ Missing studentId or opportunityId");
        return null;
      }

      // Get opportunity
      const opportunityDoc = await db
        .collection("opportunities")
        .doc(opportunityId)
        .get();

      if (!opportunityDoc.exists) {
        console.error(`❌ Opportunity not found: ${opportunityId}`);
        return null;
      }

      const opportunity = opportunityDoc.data();
      const applicationDeadline = opportunity.applicationDeadline;

      if (!applicationDeadline) {
        console.log("ℹ️ Opportunity has no deadline");
        return null;
      }

      // Get company name
      let companyName = "Company";
      if (opportunity.companyId) {
        const companyDoc = await db
          .collection("companies")
          .doc(opportunity.companyId)
          .get();
        if (companyDoc.exists) {
          companyName = companyDoc.data().companyName || companyName;
        }
      }

      // Calculate days until deadline
      const deadlineDate = applicationDeadline.toDate();
      const now = new Date();
      const daysUntil = Math.ceil((deadlineDate - now) / (1000 * 60 * 60 * 24));

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

      const role = opportunity.role || "Position";

      // Use consistent helper function
      await sendNotificationToStudent({
        studentId: studentId,
        title: "📌 Bookmark Reminder",
        body: `The deadline for ${role} at ${companyName} is ${deadlineText}`,
        data: {
          route: "/opportunities",
          opportunityId: opportunityId,
          companyId: opportunity.companyId || "",
        },
        type: "deadline_info",
        additionalData: {
          opportunityId: opportunityId,
          opportunityRole: role,
          companyName: companyName,
          companyId: opportunity.companyId || "",
          deadline: applicationDeadline,
        },
      });

      return null;
    } catch (err) {
      console.error("🔥 Error in sendDeadlineNotificationOnBookmark:", err);
      return null;
    }
  });

// ============================================================================
// ⏰ Check for upcoming deadlines and send reminders (runs every hour)
// ============================================================================
exports.checkDeadlineReminders = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async (context) => {
    try {
      console.log("⏰ Checking for deadline reminders...");

      const tomorrow = new Date();
      tomorrow.setHours(tomorrow.getHours() + 24);
      const dayAfterTomorrow = new Date();
      dayAfterTomorrow.setHours(dayAfterTomorrow.getHours() + 25);

      // Find opportunities with deadlines in 24-25 hours
      const opportunitiesSnapshot = await db
        .collection("opportunities")
        .where(
          "applicationDeadline",
          ">=",
          admin.firestore.Timestamp.fromDate(tomorrow)
        )
        .where(
          "applicationDeadline",
          "<",
          admin.firestore.Timestamp.fromDate(dayAfterTomorrow)
        )
        .where("isActive", "==", true)
        .get();

      if (opportunitiesSnapshot.empty) {
        console.log("✅ No upcoming deadlines found");
        return null;
      }

      console.log(
        `📋 Found ${opportunitiesSnapshot.size} opportunities with upcoming deadlines`
      );

      for (const oppDoc of opportunitiesSnapshot.docs) {
        const opportunity = oppDoc.data();
        const opportunityId = oppDoc.id;

        // Get students who bookmarked or applied
        const studentIds = new Set();

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
          const companyDoc = await db
            .collection("companies")
            .doc(opportunity.companyId)
            .get();
          if (companyDoc.exists) {
            companyName = companyDoc.data().companyName || companyName;
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

          // Use consistent helper function
          await sendNotificationToStudent({
            studentId: studentId,
            title: "⏰ Deadline Reminder",
            body: `Reminder: ${opportunity.role} at ${companyName} deadline is tomorrow!`,
            data: {
              route: "/opportunities",
              opportunityId: opportunityId,
              companyId: opportunity.companyId || "",
            },
            type: "deadline_reminder",
            additionalData: {
              opportunityId: opportunityId,
              opportunityRole: opportunity.role,
              companyName: companyName,
              companyId: opportunity.companyId || "",
            },
          });
        }

        console.log(
          `✅ Sent reminders for ${opportunity.role} to ${studentIds.size} students`
        );
      }

      return null;
    } catch (err) {
      console.error("🔥 Error in checkDeadlineReminders:", err);
      return null;
    }
  });

// ============================================================================
// 🧪 Test notification function
// ============================================================================
exports.testNotification = functions.https.onRequest(async (req, res) => {
  try {
    const { userId } = req.query;
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
    console.error("❌ Error sending test notification:", err);
    res.status(500).send(`Error: ${err.message}`);
  }
});