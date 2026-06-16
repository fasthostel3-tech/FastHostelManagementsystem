const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Trigger when a notification document is created under /notifications/{docId}
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    // Expected fields: userId, title, body, payload
    const userId = data.userId;
    const title = data.title || 'Notification';
    const body = data.body || '';
    const payload = data.payload || {};

    if (!userId) return null;

    try {
      // Read the user's profile to find FCM tokens
      const profileSnap = await admin.firestore().collection('profiles').doc(userId).get();
      if (!profileSnap.exists) return null;
      const profile = profileSnap.data();
      const tokens = (profile && profile.fcmTokens) || [];
      if (!tokens.length) return null;

      const message = {
        notification: {
          title,
          body,
        },
        data: Object.keys(payload).reduce((acc, k) => {
          acc[k] = String(payload[k]);
          return acc;
        }, {}),
        tokens,
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log('FCM send result:', response);

      // Optionally, write back result to the notification doc
      await snap.ref.set({ pushResult: { successCount: response.successCount, failureCount: response.failureCount } }, { merge: true });
    } catch (err) {
      console.error('Error sending push notification:', err);
    }

    return null;
  });
