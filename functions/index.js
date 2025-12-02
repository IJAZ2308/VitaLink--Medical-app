/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */
/*
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
*/

// // Start writing functions
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const functions = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onValueWritten } = require("firebase-functions/v2/database");
const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: "https://drshahin-uk-default-rtdb.firebaseio.com/"
});

setGlobalOptions({ region: "us-central1" });

// -------------------- Email Setup --------------------
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "ijazahmed1507@gmail.com",
    pass: "hida uekb fpxx rnqw"
  }
});

// -------------------- Push Notification Function --------------------
async function sendPushNotification({ tokens, title, body, data }) {
  if (!tokens || tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: data || {}
  };

  for (const token of tokens) {
    try {
      await admin.messaging().send({ ...message, token });
    } catch (err) {
      console.error("❌ Failed sending token:", token, err.message);
    }
  }
  console.log(`📤 Sent notification: ${title}`);
}

// -------------------- Bed Availability Notification --------------------
exports.bedAvailabilityNotification = onValueWritten(
  { ref: "/bedBookings/{hospitalId}/{bedType}/available", region: "us-central1" },
  async (event) => {
    const isAvailable = event.data.after.val();
    if (!isAvailable) return null;

    const usersSnap = await admin.database().ref("/users").orderByChild("role").equalTo("patient").once("value");
    const tokens = [];
    usersSnap.forEach((snap) => {
      const user = snap.val();
      if (user.fcmToken) tokens.push(user.fcmToken);
    });

    await sendPushNotification({
      tokens,
      title: "Bed Available",
      body: `A ${event.params.bedType} bed is now available at ${event.params.hospitalId}`
    });
  }
);

// -------------------- Appointment Reminders --------------------
exports.appointmentReminderScheduler = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Kolkata" },
  async () => {
    const now = Date.now();
    const snapshot = await admin.database().ref("/appointments").once("value");
    if (!snapshot.exists()) return;

    snapshot.forEach(async (appSnap) => {
      const appointment = appSnap.val();
      const patientSnap = await admin.database().ref(`/users/${appointment.patientId}`).once("value");
      const patient = patientSnap.val();
      if (!patient || !patient.fcmToken) return;

      const appointmentTime = new Date(appointment.datetime).getTime();
      const diff = appointmentTime - now;

      // 1 hour before
      if (diff <= 3600000 && diff > 3540000) {
        await sendPushNotification({
          tokens: [patient.fcmToken],
          title: "Appointment Reminder",
          body: `Your appointment with Dr. ${appointment.doctorId} is in 1 hour`
        });
      }

      // 1 day before
      if (diff <= 86400000 && diff > 86340000) {
        await sendPushNotification({
          tokens: [patient.fcmToken],
          title: "Appointment Reminder",
          body: `Your appointment with Dr. ${appointment.doctorId} is tomorrow`
        });
      }
    });
  }
);

// -------------------- Doctor Verification Alert to Admin --------------------
exports.doctorVerificationAlert = onValueWritten(
  { ref: "/doctors/{doctorId}/isVerified", region: "us-central1" },
  async (event) => {
    const isVerified = event.data.after.val();
    if (!isVerified) return null;

    const adminsSnap = await admin.database().ref("/users").orderByChild("role").equalTo("admin").once("value");
    const tokens = [];
    adminsSnap.forEach((snap) => {
      const adminUser = snap.val();
      if (adminUser.fcmToken) tokens.push(adminUser.fcmToken);
    });

    await sendPushNotification({
      tokens,
      title: "Doctor Verified",
      body: `Doctor ${event.params.doctorId} has been verified`
    });
  }
);

// -------------------- Appointment Booked Notification for Doctor --------------------
exports.appointmentBookedNotification = onValueWritten(
  { ref: "/appointments/{appointmentId}", region: "us-central1" },
  async (event) => {
    const appointment = event.data.after.val();
    if (!appointment) return null;

    const doctorSnap = await admin.database().ref(`/doctors/${appointment.doctorId}`).once("value");
    const doctor = doctorSnap.val();
    if (!doctor || !doctor.fcmToken) return null;

    await sendPushNotification({
      tokens: [doctor.fcmToken],
      title: "New Appointment Booked",
      body: `Patient ${appointment.patientId} booked an appointment with you at ${appointment.datetime}`
    });
  }
);

// -------------------- New Report Uploaded Notification --------------------
exports.newReportUploaded = onValueWritten(
  { ref: "/reports/{patientId}/{reportId}", region: "us-central1" },
  async (event) => {
    const report = event.data.after.val();
    if (!report) return null;

    const patientSnap = await admin.database().ref(`/users/${event.params.patientId}`).once("value");
    const patient = patientSnap.val();
    if (!patient || !patient.fcmToken) return null;

    await sendPushNotification({
      tokens: [patient.fcmToken],
      title: "New Report Uploaded",
      body: `A new report has been uploaded. Check your VitaLynk app.`
    });
  }
);

// -------------------- Doctor → Patient Chat Notification --------------------
exports.sendDoctorToPatientNotification = onValueWritten(
  { ref: "/chats/{patientId}/{messageId}", region: "us-central1" },
  async (event) => {
    const snap = event.data.after;
    if (!snap.exists()) return null;

    const { text, doctorId } = snap.val();
    if (!doctorId) return null;

    const patientSnap = await admin.database().ref(`/users/${event.params.patientId}`).once("value");
    const patient = patientSnap.val();
    if (!patient || !patient.fcmToken) return null;

    const doctorSnap = await admin.database().ref(`/doctors/${doctorId}`).once("value");
    const doctor = doctorSnap.val();
    const doctorName = (doctor && doctor.name) ? doctor.name : "Doctor";


    await sendPushNotification({
      tokens: [patient.fcmToken],
      title: `Message from ${doctorName}`,
      body: text
    });
  }
);

// -------------------- Forgot Password Email --------------------
exports.sendForgotPasswordEmail = onCall(async (request) => {
  const { email, name, newPassword } = request.data;
  if (!email) throw new Error("Email missing");

  const mailOptions = {
    from: '"VitaLynk" <yourgmail@gmail.com>',
    to: email,
    subject: "VitaLynk Password Reset",
    text: `Hello ${name},\n\nYour password has been reset. Your new password is: ${newPassword}\n\nPlease change it after logging in.\n\nThanks!`
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: "Forgot Password email sent!" };
  } catch (err) {
    console.error(err);
    return { success: false, message: err.message };
  }
});
