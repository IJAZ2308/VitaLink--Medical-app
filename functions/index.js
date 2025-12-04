// -------------------- Chat Message Push Notification --------------------
// (Merged from your provided final block, converted to V2 correctly)

const { onValueCreated } = require("firebase-functions/v2/database");

exports.onNewChatMessage = onValueCreated(
  {
    ref: "/chatRooms/{roomId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const message = event.data.val();
    if (!message) return null;

    const receiverId = message.receiverId;
    const senderId = message.senderId;
    const text = message.text || "";
    const roomId = event.params.roomId;

    if (!receiverId) return null;

    // Fetch receiver's FCM token
    const userSnap = await admin
      .database()
      .ref(`/users/${receiverId}`)
      .once("value");
    const user = userSnap.val();
    const token = user && user.fcmToken;

    if (!token) {
      console.log("❌ No token for receiver:", receiverId);
      return null;
    }

    // Fetch sender name
    let senderName = "New message";

    const senderSnap = await admin
      .database()
      .ref(`/users/${senderId}`)
      .once("value");

    if (senderSnap.exists()) {
      const s = senderSnap.val();
      senderName = s.firstName || s.name || s.fullName || senderName;
    } else {
      // Try doctors node
      const doctorSnap = await admin
        .database()
        .ref(`/doctors/${senderId}`)
        .once("value");

      if (doctorSnap.exists()) {
        const d = doctorSnap.val();
        senderName = d.firstName || d.name || d.fullName || senderName;
      }
    }

    // Prepare Notification Payload
    const payload = {
      notification: {
        title: `${senderName}`,
        body: text.length > 120 ? text.substring(0, 120) + "…" : text,
      },
      data: {
        roomId: roomId,
        senderId: senderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };

    try {
      await admin.messaging().sendToDevice(token, payload);
      console.log("📩 Chat notification sent successfully!");
    } catch (err) {
      console.error("❌ Error sending chat notification:", err);
    }

    return null;
  }
);
