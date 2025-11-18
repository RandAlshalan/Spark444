/**
 * Spark App - Firebase Cloud Functions (Stable v1)
 *
 * هذا الملف يرسل إشعارات للطلاب عندما تنشر الشركة فرصة جديدة.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// 📢 إشعار المتابعين عند إنشاء فرصة جديدة
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

      // ✅ تحقق من وجود companyId
      if (!opportunity.companyId) {
        console.error("❌ Opportunity missing companyId");
        return null;
      }

      // 1️⃣ جلب بيانات الشركة
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

      console.log(`🏢 Company: ${companyName}`);

      // 2️⃣ جلب الطلاب المتابعين للشركة
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

      if (tokens.length === 0) {
        console.log("⚠️ No valid FCM tokens found");
        return null;
      }

      // 3️⃣ إعداد محتوى الإشعار
      const notificationTitle = `New Opportunity at ${companyName}!`;
      const notificationBody = `${companyName} just posted: ${role}`;

      // 4️⃣ إرسال الإشعار للجميع
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
        `✅ Notifications sent: ${response.successCount} success, ${response.failureCount} failed`
      );

      // 5️⃣ حذف التوكنات الغير صالحة
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

      // 6️⃣ حفظ الإشعار في قاعدة بيانات الطالب
      const batch = db.batch();
      const timestamp = admin.firestore.FieldValue.serverTimestamp();
      studentIds.forEach((id) => {
        const ref = db
          .collection("student")
          .doc(id)
          .collection("notifications")
          .doc();
        batch.set(ref, {
          title: notificationTitle,
          body: notificationBody,
          companyName,
          companyId: opportunity.companyId,
          opportunityId,
          type: "new_opportunity",
          read: false,
          createdAt: timestamp,
        });
      });
      await batch.commit();

      console.log("📨 Notifications saved in Firestore ✅");
      return null;
    } catch (err) {
      console.error("🔥 Error in notifyFollowersOnNewOpportunity:", err);
      return null;
    }
  });

// ============================================================================
// 💬 إشعار الطالب عند الرد على مراجعته
// ============================================================================
exports.notifyStudentOnReviewReply = functions.firestore
  .document("reviews/{reviewId}")
  .onCreate(async (snapshot, context) => {
    try {
      const reply = snapshot.data();
      const reviewId = context.params.reviewId;

      // تحقق إذا كان هذا رد (يحتوي على parentId)
      if (!reply.parentId || !reply.parentId.trim()) {
        console.log("ℹ️ Not a reply, skipping notification");
        return null;
      }

      console.log("💬 New reply created:", {
        reviewId,
        parentId: reply.parentId,
      });

      // 1️⃣ جلب المراجعة الأصلية
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

      // تحقق أن الرد ليس من نفس الطالب
      if (reply.studentId === originalStudentId) {
        console.log("ℹ️ Student replied to their own review, skipping notification");
        return null;
      }

      // 2️⃣ جلب بيانات الطالب الأصلي
      const studentDoc = await db
        .collection("student")
        .doc(originalStudentId)
        .get();

      if (!studentDoc.exists) {
        console.error(`❌ Student not found: ${originalStudentId}`);
        return null;
      }

      const student = studentDoc.data();
      const fcmToken = student.fcmToken;

      if (!fcmToken) {
        console.log(`⚠️ Student ${originalStudentId} has no FCM token`);
        return null;
      }

      // 3️⃣ جلب بيانات الشركة للحصول على الاسم
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

      // 4️⃣ إعداد محتوى الإشعار
      const replyText = reply.reviewText || "";
      const replySnippet = replyText.length > 100
        ? `${replyText.substring(0, 100)}...`
        : replyText;

      const notificationTitle = "New Reply to Your Review";
      const notificationBody = `Someone replied to your review about ${companyName}`;

      // 5️⃣ إرسال الإشعار
      const messaging = admin.messaging();

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            route: "/my-reviews",
            reviewId: reply.parentId,
            replyId: reviewId,
            companyId: reply.companyId || "",
            type: "review_reply",
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

        console.log(`✅ Reply notification sent to student ${originalStudentId}`);

        // 6️⃣ حفظ الإشعار في قاعدة بيانات الطالب
        await db
          .collection("student")
          .doc(originalStudentId)
          .collection("notifications")
          .add({
            title: notificationTitle,
            body: notificationBody,
            companyName,
            companyId: reply.companyId || "",
            reviewId: reply.parentId,
            replyId: reviewId,
            replySnippet,
            type: "review_reply",
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        console.log("📨 Reply notification saved in Firestore ✅");
      } catch (sendError) {
        const errorCode = sendError.code;
        if (
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/registration-token-not-registered"
        ) {
          console.log(`🧹 Removing invalid token for student ${originalStudentId}`);
          await db.collection("student").doc(originalStudentId).update({
            fcmToken: admin.firestore.FieldValue.delete(),
          });
        } else {
          throw sendError;
        }
      }

      return null;
    } catch (err) {
      console.error("🔥 Error in notifyStudentOnReviewReply:", err);
      return null;
    }
  });

// ============================================================================
// 📋 إشعار الطالب عند تحديث حالة طلبه
// ============================================================================
exports.notifyStudentOnApplicationUpdate = functions.firestore
  .document("applications/{applicationId}")
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const applicationId = context.params.applicationId;

      // تحقق إذا تم تغيير الحالة
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

      // 1️⃣ جلب بيانات الطالب
      const studentDoc = await db.collection("student").doc(studentId).get();
      if (!studentDoc.exists) {
        console.error(`❌ Student not found: ${studentId}`);
        return null;
      }

      const student = studentDoc.data();
      const fcmToken = student.fcmToken;

      if (!fcmToken) {
        console.log(`⚠️ Student ${studentId} has no FCM token`);
        return null;
      }

      // 2️⃣ جلب بيانات الفرصة
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

          // جلب اسم الشركة
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

      // 3️⃣ إعداد محتوى الإشعار بناءً على الحالة الجديدة
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

      // 4️⃣ إرسال الإشعار
      const messaging = admin.messaging();

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            route: "/opportunities",
            applicationId: applicationId,
            opportunityId: opportunityId || "",
            status: newStatus,
            type: "application_status_update",
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

        console.log(`✅ Application status notification sent to student ${studentId}`);

        // 5️⃣ حفظ الإشعار في قاعدة بيانات الطالب
        await db
          .collection("student")
          .doc(studentId)
          .collection("notifications")
          .add({
            title: notificationTitle,
            body: notificationBody,
            companyName,
            opportunityTitle,
            opportunityId: opportunityId || "",
            applicationId,
            status: newStatus,
            oldStatus: before.status,
            type: "application_status_update",
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        console.log("📨 Application status notification saved in Firestore ✅");
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
          throw sendError;
        }
      }

      return null;
    } catch (err) {
      console.error("🔥 Error in notifyStudentOnApplicationUpdate:", err);
      return null;
    }
  });

// ============================================================================
// 🧪 دالة اختبار لإرسال إشعار يدوي
// ============================================================================
exports.testNotification = functions.https.onRequest(async (req, res) => {
  try {
    const {userId} = req.query;
    if (!userId) {
      res.status(400).send("Missing userId parameter");
      return;
    }

    const userDoc = await db.collection("student").doc(userId).get();
    if (!userDoc.exists) {
      res.status(404).send("User not found");
      return;
    }

    const token = userDoc.data().fcmToken;
    if (!token) {
      res.status(400).send("User has no FCM token");
      return;
    }

    await admin.messaging().send({
      token: token,
      notification: {
        title: "Test Notification",
        body: "This is a test notification from Spark!",
      },
      data: {
        route: "/notifications",
      },
    });

    res.send("✅ Test notification sent successfully!");
  } catch (err) {
    console.error("❌ Error sending test notification:", err);
    res.status(500).send(`Error: ${err.message}`);
  }
});