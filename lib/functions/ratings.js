// Keeps partners/{email}.rating (and ratingCount) up to date on the server.
//
// Customers rate a delivered order (orders/{id}.rating, 1-5). The Admin app already works out the
// average on screen and saves it, but only while the Admin app is open. This function does the same
// calculation with the SAME rule (rating > 0, order not cancelled, same partner), so the value on the
// partner record is always correct, even when nobody has the Admin app open. Both write the same
// number, so they never fight each other.
//
// Add to functions/index.js:
//   exports.updatePartnerRating = require('./ratings').updatePartnerRating;
//
// REGION must be the same as your Firestore database location (same value as in push.js / orders.js).

const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = 'asia-south1';

exports.updatePartnerRating = onDocumentUpdated(
  { document: 'orders/{orderId}', region: REGION, retry: true },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data();
    if (!after) return;

    // Only when the star rating itself changed.
    if (Number(before.rating || 0) === Number(after.rating || 0)) return;

    const pid = String(after.partnerId || '').trim().toLowerCase();
    if (!pid) return;

    const snap = await db.collection('orders').where('partnerId', '==', pid).get();
    let sum = 0;
    let n = 0;
    snap.forEach((d) => {
      const o = d.data();
      const r = Number(o.rating || 0);
      if (r > 0 && o.status !== 'Cancelled') {
        sum += r;
        n++;
      }
    });
    if (n === 0) return;

    const ref = db.doc(`partners/${pid}`);
    if (!(await ref.get()).exists) return;
    await ref.update({
      rating: Math.round((sum / n) * 10) / 10,
      ratingCount: n,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
);