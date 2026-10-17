// Server-side order automation (runs even when the Admin app is closed).
//
//  1. deductStockOnOrder  (order created)   -> takes the stock off the products, server-side.
//       Customers can no longer change product stock (see firestore.rules), so nobody can
//       empty the inventory without ordering. If the last unit was taken by someone else a
//       moment earlier, the order is cancelled automatically and the customer is told.
//  2. onOrderCancelled    (order -> Cancelled) -> puts the stock back, creates the refund record
//       for an online-paid order, gives the coupon back, and tells the delivery partner.
//
// All steps are idempotent (flags on the order: stockDeducted / stockRestored / couponReleased /
// partnerCancelNotified), so the Admin app's old client-side clean-up can keep running as a
// harmless fallback.
//
// Add to functions/index.js:
//   exports.deductStockOnOrder = require('./orders').deductStockOnOrder;
//   exports.onOrderCancelled   = require('./orders').onOrderCancelled;
//
// REGION must be the same as your Firestore database location (same value as in push.js).

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = 'asia-south1';

// { productId: totalQuantity } from the order's items (same field names the apps write).
function qtyMap(items) {
  const m = {};
  for (const it of Array.isArray(items) ? items : []) {
    const id = String(it.productId || it.phoneId || it.id || '').trim();
    const q = Math.floor(Number(it.quantity !== undefined ? it.quantity : it.qty !== undefined ? it.qty : 1));
    if (!id || !(q > 0)) continue;
    m[id] = (m[id] || 0) + q;
  }
  return m;
}

async function notify(userId, title, body, type, orderId, extra = {}) {
  if (!userId) return;
  await db.collection('notifications').add({
    userId,
    title,
    body,
    type,
    ...(orderId ? { orderId } : {}),
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
    ...extra,
  });
}

// ---------------------------------------------------------------------------
// 1) New order -> deduct stock
// ---------------------------------------------------------------------------
exports.deductStockOnOrder = onDocumentCreated(
  { document: 'orders/{orderId}', region: REGION, retry: true },
  async (event) => {
    const orderId = event.params.orderId;
    const ref = db.doc(`orders/${orderId}`);
    let soldOut = '';
    let customerId = '';

    await db.runTransaction(async (tx) => {
      soldOut = '';
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const o = snap.data();
      customerId = String(o.customerId || '');
      // Already handled, or cancelled before we got here: nothing to deduct.
      if (o.stockDeducted === true || o.stockRestored === true || o.status === 'Cancelled') return;

      const want = qtyMap(o.items);
      const ids = Object.keys(want);
      if (!ids.length) return;

      // All reads first (Firestore transaction rule), then the writes.
      const prodSnaps = await Promise.all(ids.map((id) => tx.get(db.doc(`products/${id}`))));
      const updates = [];
      for (let i = 0; i < ids.length; i++) {
        const p = prodSnaps[i];
        if (!p.exists) continue;
        const stock = p.get('stock');
        if (typeof stock !== 'number') continue; // legacy product without a stock field = not tracked
        if (stock < want[ids[i]]) {
          soldOut = String(p.get('name') || p.get('title') || 'A phone');
          break;
        }
        updates.push({ ref: p.ref, stock: stock - want[ids[i]] });
      }

      if (soldOut) {
        tx.update(ref, {
          status: 'Cancelled',
          cancelledBy: 'system',
          cancelReason: `${soldOut} is out of stock`,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      for (const u of updates) {
        tx.update(u.ref, { stock: u.stock, updatedAt: FieldValue.serverTimestamp() });
      }
      if (updates.length) tx.update(ref, { stockDeducted: true, updatedAt: FieldValue.serverTimestamp() });
    });

    if (soldOut && customerId) {
      await notify(
        customerId,
        `Order ${orderId} cancelled`,
        `${soldOut} just went out of stock, so this order was cancelled. Any online payment will be refunded.`,
        'order',
        orderId
      );
    }
  }
);

// ---------------------------------------------------------------------------
// 2) Order cancelled -> restore stock, refund record, coupon, partner notice
// ---------------------------------------------------------------------------
async function restoreStock(orderId, ref) {
  await db.runTransaction(async (tx) => {
    const os = await tx.get(ref);
    if (!os.exists) return;
    const o = os.data();
    if (o.stockRestored === true || o.stockDeducted !== true) return;
    const want = qtyMap(o.items);
    const ids = Object.keys(want);
    const snaps = await Promise.all(ids.map((id) => tx.get(db.doc(`products/${id}`))));
    snaps.forEach((p, i) => {
      if (!p.exists) return;
      const cur = Number(p.get('stock')) || 0;
      tx.update(p.ref, { stock: cur + want[ids[i]], updatedAt: FieldValue.serverTimestamp() });
    });
    tx.update(ref, { stockRestored: true, updatedAt: FieldValue.serverTimestamp() });
  });
}

async function createRefund(orderId, o) {
  const refNo = `RF${orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase()}`;
  try {
    // create() fails when the record already exists, so it is never duplicated.
    await db.doc(`refunds/RF_${orderId}`).create({
      refNo,
      orderId,
      customerId: String(o.customerId || ''),
      amount: Number(o.total) || 0,
      reason:
        o.cancelledBy === 'admin'
          ? 'Cancelled by admin'
          : o.cancelledBy === 'system'
          ? 'Cancelled: out of stock'
          : 'Cancelled by customer',
      status: 'Requested',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    if (e.code !== 6 && !/already exists/i.test(String(e.message))) throw e;
  }
}

async function releaseCoupon(orderId, o) {
  const code = String(o.couponCode || '').trim().toUpperCase();
  const customerId = String(o.customerId || '');
  if (!code || !customerId) return;
  let cref = db.doc(`coupons/${code}`);
  if (!(await cref.get()).exists) {
    const q = await db.collection('coupons').where('code', '==', code).limit(1).get();
    cref = q.empty ? null : q.docs[0].ref;
  }
  if (!cref) return;
  const red = cref.collection('redemptions').doc(customerId);
  const rs = await red.get();
  // Only remove the record that THIS order created.
  if (rs.exists && String(rs.get('orderId') || '') === orderId) await red.delete();
}

async function tellPartner(orderId, o) {
  const partnerId = String(o.partnerId || '').trim().toLowerCase();
  if (!partnerId) return;
  const p = await db.doc(`partners/${partnerId}`).get();
  const uid = p.exists ? String(p.get('uid') || '') : '';
  if (!uid) return; // that partner has not logged in yet
  await notify(
    uid,
    `Order cancelled • ${orderId}`,
    `This order was cancelled${o.cancelledBy === 'customer' ? ' by the customer' : ''}. Do not deliver it.`,
    'order_cancelled',
    orderId,
    { audience: 'partner' }
  );
}

exports.onOrderCancelled = onDocumentUpdated(
  { document: 'orders/{orderId}', region: REGION, retry: true },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data();
    if (!after || after.status !== 'Cancelled') return;

    const orderId = event.params.orderId;
    const ref = db.doc(`orders/${orderId}`);
    const justCancelled = before.status !== 'Cancelled';

    const code = String(after.couponCode || '').trim();
    const hasCoupon = code !== '' && code.toLowerCase() !== 'null';
    const partnerId = String(after.partnerId || '').trim();

    const needStock = after.stockDeducted === true && after.stockRestored !== true;
    const needRefund = justCancelled && after.paymentMethod !== 'Cash on Delivery';
    const needCoupon = hasCoupon && after.couponReleased !== true;
    const needPartner = partnerId !== '' && after.partnerCancelNotified !== true;
    if (!needStock && !needRefund && !needCoupon && !needPartner) return;

    const flags = {};
    if (needStock) await restoreStock(orderId, ref);
    if (needRefund) await createRefund(orderId, after);
    if (needCoupon) {
      await releaseCoupon(orderId, after);
      flags.couponReleased = true;
    }
    if (needPartner) {
      await tellPartner(orderId, after);
      flags.partnerCancelNotified = true;
    }
    if (Object.keys(flags).length) {
      await ref.update({ ...flags, updatedAt: FieldValue.serverTimestamp() });
    }
  }
);