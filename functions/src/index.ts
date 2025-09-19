import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as nodemailer from "nodemailer";

admin.initializeApp();
const db = admin.firestore();

// SMTP config from `firebase functions:config:set smtp.*`
const smtp = (functions.config().smtp as {
  host?: string;
  port?: string | number;
  user?: string;
  pass?: string;
  from?: string;
}) || {};

const transporter = nodemailer.createTransport({
  host: smtp.host,
  port: Number(smtp.port || 465),
  secure: Number(smtp.port || 465) === 465,
  auth: { user: smtp.user, pass: smtp.pass },
});

// Helpers
const OTP_TTL_MIN = 10;
const randomCode = () => String(Math.floor(100000 + Math.random() * 900000));
const hash = (s: string) => crypto.createHash("sha256").update(s).digest("hex");

// Send OTP
export const sendPasswordOtp = onCall(async (request) => {
  const email = String((request.data?.email || "")).trim().toLowerCase();
  if (!email) throw new HttpsError("invalid-argument", "Email is required.");

  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
  } catch {
    throw new HttpsError("not-found", "No account for this email.");
  }

  const code = randomCode();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + OTP_TTL_MIN * 60 * 1000)
  );

  await db.collection("password_resets").doc(user.uid).set({
    email,
    hash: hash(code),
    expiresAt,
    attempts: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await transporter.sendMail({
    from: smtp.from || smtp.user,
    to: email,
    subject: "SPARK password reset code",
    text: `Your verification code is: ${code} (valid for ${OTP_TTL_MIN} minutes)`,
    html: `<p>Your verification code is:</p>
           <h2 style="letter-spacing:3px">${code}</h2>
           <p>It expires in ${OTP_TTL_MIN} minutes.</p>`,
  });

  return { ok: true };
});

// Verify OTP + set new password
export const verifyPasswordOtp = onCall(async (request) => {
  const email = String((request.data?.email || "")).trim().toLowerCase();
  const code = String((request.data?.code || "")).trim();
  const newPassword = String(request.data?.newPassword || "");

  if (!email || !code || !newPassword) {
    throw new HttpsError("invalid-argument", "Missing fields.");
  }

  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
  } catch {
    throw new HttpsError("not-found", "No account for this email.");
  }

  const ref = db.collection("password_resets").doc(user.uid);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("failed-precondition", "No active reset request.");

  const doc = snap.data()!;
  const now = admin.firestore.Timestamp.now();

  if (doc.expiresAt.toMillis() < now.toMillis()) {
    await ref.delete();
    throw new HttpsError("deadline-exceeded", "Code expired.");
  }

  if ((doc.attempts || 0) >= 5) {
    await ref.delete();
    throw new HttpsError("resource-exhausted", "Too many attempts.");
  }

  if (doc.hash !== hash(code)) {
    await ref.update({ attempts: (doc.attempts || 0) + 1 });
    throw new HttpsError("permission-denied", "Invalid code.");
  }

  await admin.auth().updateUser(user.uid, { password: newPassword });
  await ref.delete();

  return { ok: true };
});
