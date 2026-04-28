import { onCall, HttpsError } from "firebase-functions/v2/https";
import admin from "firebase-admin";
import nodemailer from "nodemailer";

admin.initializeApp();

// ─── Dev Credentials (temporary) ─────────────────────────────────────────────
const EMAIL_USER = "your-email@gmail.com";
const EMAIL_PASS = "your-app-password";

// ─── sendSosEmail ─────────────────────────────────────────────────────────────
export const sendSosEmail = onCall(async (request) => {
  const { emails, latitude, longitude } = request.data;

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }

  if (!emails || !Array.isArray(emails) || emails.length === 0) {
    throw new HttpsError("invalid-argument", "لا توجد إيميلات لإرسال النداء إليها");
  }

  const hasLocation = latitude != null && longitude != null;
  const mapsLink = hasLocation
    ? `https://www.google.com/maps?q=${latitude},${longitude}`
    : null;

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: EMAIL_USER,
      pass: EMAIL_PASS,
    },
  });

  const locationSection = hasLocation
    ? `
      <p style="margin:8px 0;">
        <strong>📍 الموقع الحالي:</strong><br/>
        خط العرض: ${latitude}<br/>
        خط الطول: ${longitude}<br/>
        <a href="${mapsLink}" style="color:#1773CF;">عرض على خرائط Google</a>
      </p>`
    : `<p style="color:#888;margin:8px 0;">تعذّر الحصول على الموقع</p>`;

  const mailOptions = {
    from: `"تطبيق نبيه 🚨" <${EMAIL_USER}>`,
    to: emails.join(","),
    subject: "🚨 نداء استغاثة عاجل - تطبيق نبيه",
    html: `
      <div dir="rtl" style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:2px solid #e53935;border-radius:12px;overflow:hidden;">
        <div style="background:#e53935;padding:20px;text-align:center;">
          <h1 style="color:white;margin:0;font-size:26px;">🚨 نداء استغاثة</h1>
        </div>
        <div style="padding:24px;background:#fff;">
          <p style="font-size:16px;color:#333;">
            تلقّيت هذه الرسالة لأن مستخدم تطبيق <strong>نبيه</strong> أرسل نداء استغاثة.
          </p>
          <p style="font-size:15px;color:#555;">
            يرجى التواصل مع المستخدم فوراً أو الاتصال بالجهات المختصة.
          </p>
          <hr style="border:1px solid #eee;margin:16px 0;"/>
          ${locationSection}
          <hr style="border:1px solid #eee;margin:16px 0;"/>
          <p style="font-size:12px;color:#aaa;text-align:center;">
            أُرسلت هذه الرسالة تلقائياً من تطبيق نبيه
          </p>
        </div>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);

  return { success: true, sent: emails.length };
});
