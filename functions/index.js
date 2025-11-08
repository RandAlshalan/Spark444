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