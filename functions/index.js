import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import admin from "firebase-admin";
import nodemailer from "nodemailer";

admin.initializeApp();

const EMAIL_USER = defineSecret("EMAIL_USER");
const EMAIL_PASS = defineSecret("EMAIL_PASS");

// ─── sendSosEmail ─────────────────────────────────────────────────────────────
export const sendSosEmail = onCall(
  { secrets: [EMAIL_USER, EMAIL_PASS] },
  async (request) => {
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
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_PASS,
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
    from: `"تطبيق نبيه 🚨" <${process.env.GMAIL_USER}>`,
    to: emails.join(","),
    subject: "🚨 نداء استغاثة عاجل - تطبيق نبيه",
    html: `
      <div dir="rtl" style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:2px solid #e53935;border-radius:12px;overflow:hidden;">
        <div style="background:#e53935;padding:20px;text-align:center;">
          <h1 style="color:white;margin:0;font-size:26px;">🚨 نداء استغاثة</h1>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);

  return { success: true, sent: emails.length };
});


// ════════════════════════════════════════════════════════
//  TRANSPORTER  — Gmail SMTP
//  اضبط هذا بعد ما تشغّل:
//  firebase functions:config:set gmail.user="your@gmail.com" gmail.pass="APP_PASSWORD"
// ════════════════════════════════════════════════════════
function getTransporter() {
  
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user: process.env.GMAIL_USER, pass: process.env.GMAIL_PASS },
  });
}

// ════════════════════════════════════════════════════════
//  LOGO  — base64 inline (بدّل بـ URL لو عندك hosting)
//  أو ضع رابط الصورة مباشرة: const LOGO_URL = "https://..."
// ════════════════════════════════════════════════════════
const LOGO_URL = "https://nabeeh-3d93d.web.app/logo_nabeeh.png";

const SHARED_STYLES = `
  <style>
    *{box-sizing:border-box}html,body{margin:0}
    body{font-family:"IBM Plex Sans Arabic","Tajawal",Arial,sans-serif;background:#2A3173;color:#1B1F2A;direction:rtl;text-align:right;padding:16px;min-height:100vh;}
    .card{background:#fff;border-radius:6px;box-shadow:0 1px 0 rgba(14,20,34,.04),0 24px 48px -24px rgba(14,20,34,.18);overflow:hidden;max-width:560px;margin:0 auto;}
    .hero{background:#2A3173;padding:28px 24px 24px;color:#fff;border-bottom:3px solid #C9A36B;}
    .hero img{height:54px;width:auto;display:inline-block;}
    .pad{padding:26px 24px 8px;direction:rtl;text-align:right;}
    .eyebrow{display:inline-flex;align-items:center;gap:8px;font-size:10px;letter-spacing:.18em;color:#A8854A;font-weight:600;}
    .eyebrow i{width:18px;height:1px;background:#A8854A;display:inline-block;}
    h1{margin:14px 0 14px;font-size:24px;line-height:1.25;font-weight:700;color:#1B1F2A;text-align:right;}
    p.lead{margin:0;color:#5A6273;font-size:14px;line-height:1.85;text-align:right;}
    .btnwrap{padding:22px 24px 4px;text-align:right;}
    .btn{display:inline-block;background:#2A3173;color:#ffffff !important;text-decoration:none;padding:13px 24px;border-radius:4px;font-weight:700;font-size:14px;}
    .urlblock{padding:20px 24px 8px;}
    .url-label{font-size:12px;color:#5A6273;margin-bottom:8px;text-align:right;}
    .url{background:#F7F4EE;border:1px dashed #E7E2D7;border-radius:4px;padding:12px 14px;font-size:11px;color:#5A6273;direction:ltr;text-align:left;word-break:break-all;line-height:1.5;}
    .note{margin:18px 24px 28px;background:#FBF7EE;border-right:3px solid #C9A36B;padding:14px 16px;border-radius:4px;text-align:right;}
    .note b{font-size:12px;font-weight:700;color:#1B1F2A;display:block;margin-bottom:4px;}
    .note span{font-size:12px;color:#5A6273;line-height:1.7;}
    .warn{margin:18px 24px 28px;background:#FCF1ED;border-right:3px solid #B6422C;padding:14px 16px;border-radius:4px;color:#6B2818;text-align:right;}
    .warn b{font-size:12px;font-weight:700;display:block;margin-bottom:4px;}
    .warn span{font-size:12px;line-height:1.7;}
    footer{border-top:1px solid #E7E2D7;padding:18px 24px;background:#FBFAF6;color:#5A6273;font-size:11px;line-height:1.7;direction:rtl;text-align:right;}
    .frow{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;}
    .brand{font-weight:700;font-size:13px;color:#2A3173;}
    .domain{font-size:10px;}
    .fdesc{margin-top:10px;color:#8A8475;}
    .fdesc a{color:#3A4290;text-decoration:none;border-bottom:1px solid #C9A36B;}
    .below{max-width:560px;margin:14px auto 0;text-align:center;font-size:10px;color:#9A9484;}
    .emailbox{margin:20px 24px 4px;background:#FBFAF6;border:1px solid #E7E2D7;border-radius:6px;padding:12px 14px;direction:rtl;text-align:right;}
    .emailbox .lbl{font-size:11px;color:#5A6273;display:block;margin-bottom:6px;}
    .emailbox .val{display:inline-block;direction:ltr;font-size:13px;font-weight:500;color:#1B1F2A;background:#F2EEDF;padding:6px 10px;border-radius:3px;}
    .btnwrap-welcome{padding:22px 24px 4px;text-align:right;}
  </style>
`;

const FOOTER_HTML = `
  <footer>
    <div class="frow">
      <div class="brand">نبيه</div>
      <div class="domain">Nabeeh.appl@gmail.com</div>
    </div>
    <div class="fdesc">
      تلقيتَ هذه الرسالة لأن هذا البريد مرتبط بحساب في تطبيق نبيه.
      للاستفسار: <a href="mailto:Nabeeh.appl@gmail.com">Nabeeh.appl@gmail.com</a>
    </div>
  </footer>
  </div>
  <div class="below">رسالة من نظام نبيه — لا تردّ على هذا البريد</div>
`;

function heroHtml() {
  return `<div class="hero" style="background:#2A3173;padding:28px 24px;border-bottom:3px solid #C9A36B;direction:rtl;text-align:right;"><img src="${LOGO_URL}" alt="نبيه" style="height:81px;width:auto;display:inline-block;"></div>`;
}


// ╔══════════════════════════════════════════════════════╗
//  FUNCTION 1 — sendCustomPasswordReset
//  استبدل في Flutter: FirebaseAuth.instance.sendPasswordResetEmail
// ╚══════════════════════════════════════════════════════╝
export const sendCustomPasswordReset = onCall(async (request) => {
  const { email } = request.data;
  if (!email) throw new HttpsError("invalid-argument", "email مطلوب");

  // توليد رابط إعادة التعيين
  let resetLink;
  try {
    resetLink = await admin.auth().generatePasswordResetLink(email);
  } catch (err) {
    throw new HttpsError("not-found", "البريد غير مسجّل في النظام");
  }

  const html = `<!doctype html><html lang="ar" dir="rtl"><head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>إعادة تعيين كلمة المرور — نبيه</title>
    ${SHARED_STYLES}
  </head><body>
    <div class="card">
      ${heroHtml()}
      <div class="pad">
        <h1>طلبٌ لإنشاء كلمة مرور جديدة</h1>
        <p class="lead">
          مرحباً،<br>
          استلمنا طلباً لإعادة تعيين كلمة المرور لحسابك في
          <strong style="color:#1B1F2A;font-weight:600;">نبيه</strong>
          المرتبط بـ
          <span style="direction:ltr;display:inline-block;color:#1B1F2A;font-weight:500;">${email}</span>.
          اضغط على الزر أدناه لاختيار كلمة مرور جديدة.
        </p>
      </div>
      <div class="btnwrap">
        <a class="btn" href="${resetLink}" style="color:#ffffff !important;">إنشاء كلمة مرور جديدة ←</a>
      </div>
      <div class="urlblock">
        <div class="url-label">إذا لم يعمل الزر، انسخ الرابط التالي:</div>
        <div class="url">${resetLink}</div>
      </div>
      <div class="warn">
        <b>ينتهي هذا الرابط خلال ساعة واحدة.</b>
        <span>إذا لم تطلب إعادة تعيين كلمة المرور، يمكنك تجاهل هذه الرسالة بأمان.</span>
      </div>
      ${FOOTER_HTML}
  </body></html>`;

  await getTransporter().sendMail({
    from: `"نبيه" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: "إعادة تعيين كلمة المرور لحسابك في نبيه",
    html,
  });

  return { success: true };
});


// ╔══════════════════════════════════════════════════════╗
//  FUNCTION 2 — sendVerifyNewEmail
//  استبدل في Flutter: user.verifyBeforeUpdateEmail(newEmail)
// ╚══════════════════════════════════════════════════════╝
export const sendVerifyNewEmail = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const { newEmail } = request.data;
  if (!newEmail) throw new HttpsError("invalid-argument", "newEmail مطلوب");

  // توليد رابط تحقق للإيميل الجديد
  let verifyLink;
  try {
    verifyLink = await admin.auth().generateEmailVerificationLink(newEmail);
  } catch (err) {
    throw new HttpsError("internal", err.message);
  }

  const html = `<!doctype html><html lang="ar" dir="rtl"><head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>تأكيد بريدك الجديد — نبيه</title>
    ${SHARED_STYLES}
  </head><body>
    <div class="card">
      ${heroHtml()}
      <div class="pad">
        <h1>أكّد بريدك الجديد لتفعيل التغيير</h1>
        <p class="lead">
          مرحباً،<br>
          طُلب ربط هذا البريد بحساب في تطبيق
          <strong style="color:#1B1F2A;font-weight:600;">نبيه</strong>.
          اتبع الرابط أدناه للتحقق من ملكيتك لهذا البريد.
        </p>
      </div>
      <div class="emailbox">
        <span class="lbl">البريد الجديد</span>
        <span class="val">${newEmail}</span>
      </div>
      <div class="btnwrap">
        <a class="btn" href="${verifyLink}" style="color:#ffffff !important;">تأكيد البريد ←</a>
      </div>
      <div class="urlblock">
        <div class="url-label">إذا لم يعمل الزر، انسخ الرابط التالي:</div>
        <div class="url">${verifyLink}</div>
      </div>
      <div class="warn">
        <b>إذا لم تطلب هذا التغيير</b>
        <span>تجاهل هذه الرسالة — لن يحدث أي تغيير على أي حساب.</span>
      </div>
      ${FOOTER_HTML}
  </body></html>`;

  await getTransporter().sendMail({
    from: `"نبيه" <${process.env.GMAIL_USER}>`,
    to: newEmail,
    subject: "تأكيد بريدك الجديد في نبيه",
    html,
  });

  return { success: true };
});


// ╔══════════════════════════════════════════════════════╗
//  FUNCTION 3 — sendWelcomeEmail
//  استدعها بعد إنشاء الحساب مباشرة
// ╚══════════════════════════════════════════════════════╝
export const sendWelcomeEmail = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const { email, displayName } = request.data;
  const name = displayName || "بك";

  const html = `<!doctype html><html lang="ar" dir="rtl"><head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>مرحباً بك في نبيه</title>
    ${SHARED_STYLES}
  </head><body>
    <div class="card">
      ${heroHtml()}
      <div class="pad">
        <h1>مرحباً ${name}، يسعدنا انضمامك إلى نبيه</h1>
        <p class="lead">
          تم إنشاء حسابك بنجاح وأصبحت جاهزاً لتجربة
          <strong style="color:#1B1F2A;font-weight:600;">نبيه</strong> —
          رفيقك الذكي في كل لحظة.
        </p>
      </div>
      <div class="btnwrap-welcome">
        <a class="btn" href="nabeeh://open" style="color:#ffffff !important;">افتح نبيه ←</a>
      </div>
      <div class="note">
        <b>نحن هنا لمساعدتك</b>
        <span>أي استفسار أو ملاحظة؟ نسعد بسماعها على
          <a href="mailto:Nabeeh.appl@gmail.com" style="color:#3A4290;border-bottom:1px solid #C9A36B;text-decoration:none;">Nabeeh.appl@gmail.com</a>.
        </span>
      </div>
      ${FOOTER_HTML}
  </body></html>`;

  await getTransporter().sendMail({
    from: `"نبيه" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: "مرحباً بك في نبيه 🎉",
    html,
  });

  return { success: true };
});
