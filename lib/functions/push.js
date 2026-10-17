// Sends a push notification whenever a document is created in notifications/{id}.
//
// Every app already writes those documents:
//   - Admin  -> customers and delivery partners (order updates, refunds, broadcasts ...)
//   - Partner -> customers ("out for delivery", "delivered", failed attempt ...)
// The `userId` field is the customer's uid, or the delivery partner's login uid.
//
// Add this to your functions/index.js:
//   exports.pushOnNotification = require('./push').pushOnNotification;
//
// IMPORTANT: a Firestore trigger must be deployed in the SAME region as your Firestore database.
// Change REGION below (e.g. 'asia-south1' = Mumbai, 'nam5' databases use 'us-central1').

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const REGION = 'asia-south1';

const DEAD_TOKEN_CODES = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
];

async function findTarget(uid) {
  // Customer: users/{uid}.fcmToken
  const user = await db.doc(`users/${uid}`).get();
  if (user.exists && user.get('fcmToken')) {
    return { token: String(user.get('fcmToken')), ref: user.ref };
  }
  // Delivery partner: partners/{email} where uid == the login uid
  const q = await db.collection('partners').where('uid', '==', uid).limit(1).get();
  if (!q.empty && q.docs[0].get('fcmToken')) {
    return { token: String(q.docs[0].get('fcmToken')), ref: q.docs[0].ref };
  }
  return null;
}

exports.pushOnNotification = onDocumentCreated(
  { document: 'notifications/{id}', region: REGION },
  async (event) => {
    const n = event.data && event.data.data();
    if (!n) return;

    const uid = String(n.userId || '').trim();
    if (!uid) return;

    const target = await findTarget(uid);
    if (!target) return; // that person has no phone registered (not logged in / permission denied)

    const title = String(n.title || 'PhoneHub').slice(0, 120);
    const body = String(n.body || '').slice(0, 300);

    try {
      await admin.messaging().send({
        token: target.token,
        notification: { title, body },
        data: {
          type: String(n.type || ''),
          orderId: String(n.orderId || ''),
          audience: String(n.audience || ''),
          notificationId: event.params.id,
        },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    } catch (e) {
      console.error('push failed for', uid, e.code || e.message);
      // Remove a dead token so we stop trying it.
      if (DEAD_TOKEN_CODES.includes(e.code)) {
        await target.ref.update({ fcmToken: admin.firestore.FieldValue.delete() }).catch(() => {});
      }
    }
  }
);