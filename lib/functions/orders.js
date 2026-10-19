// Server-side order automation (runs even when the Admin app is closed).
//
//  1. deductStockOnOrder  (order created)   -> checks the order against the REAL product prices,
//       delivery charge and coupon (NEW), then takes the stock off the products, server-side.
//       Customers can not change product stock (see firestore.rules), so nobody can empty the
//       inventory without ordering. If the last unit was taken by someone else a moment earlier,
//       OR the prices / discount in the order do not match the store, the order is cancelled
//       automatically and the customer is told.
//  2. onOrderCancelled    (order -> Cancelled) -> puts the stock back, creates the refund record
//       ONLY for an online order that was really paid (CHANGED), gives the coupon back, and tells
//       the delivery partner.
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

// Whole number, never negative (same idea as the apps' _asInt).
function num(v) {
  const n = Math.floor(Number(v));
  return Number.isFinite(n) && n > 0 ? n : 0;
}

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
// Price / discount check helpers (NEW)
// ---------------------------------------------------------------------------

// Delivery settings the admin saved in Settings (appConfig/store).
// Same rule as the customer app: free when the admin has not set it, or the subtotal is high enough.
async function loadDeliveryCfg() {
  const s = await db.doc('appConfig/store').get();
  const d = s.exists ? s.data() || {} : {};
  return { charge: num(d.deliveryCharge), freeAbove: num(d.freeDeliveryAbove) };
}

function expectedDelivery(cfg, subtotal) {
  return subtotal <= 0 || subtotal >= cfg.freeAbove ? 0 : cfg.charge;
}

// The coupon document for a code (doc id = code, or an older record found by its `code` field).
async function loadCoupon(codeRaw) {
  const code = String(codeRaw || '').trim().toUpperCase();
  if (!code || code === 'NULL') return null;
  let snap = await db.doc(`coupons/${code}`).get();
  if (!snap.exists) {
    const q = await db.collection('coupons').where('code', '==', code).limit(1).get();
    if (q.empty) return null;
    snap = q.docs[0];
  }
  return snap.data() || {};
}

// Same maths as the customer app's couponDiscount().
function couponOff(c, subtotal, delivery) {
  const flat = num(c.flat !== undefined ? c.flat : c.flatDiscount);
  const percent = num(c.percent !== undefined ? c.percent : c.discountPercent);
  const maxOff = num(c.maxOff !== undefined ? c.maxOff : c.maxDiscount);
  let d = flat;
  if (percent > 0) {
    d += Math.floor((subtotal * percent) / 100);
    if (maxOff > 0 && d > maxOff) d = maxOff;
  }
  if (c.freeDelivery === true) d += delivery;
  const cap = subtotal + delivery;
  return d > cap ? cap : d;
}

// Returns '' when the order matches the store, otherwise a short reason.
//  prodById : Map(productId -> product data or null)
function checkOrderAgainstStore(o, want, prodById, cfg, coupon) {
  // 1) Product prices: subtotal must equal the CURRENT price x quantity of every phone.
  let realSubtotal = 0;
  for (const id of Object.keys(want)) {
    const p = prodById.get(id);
    if (!p) return 'A phone in this order is no longer available';
    const price = num(p.price !== undefined ? p.price : p.sellingPrice);
    realSubtotal += price * want[id];
  }
  const subtotal = Number(o.subtotal);
  if (subtotal !== realSubtotal) return 'The phone prices in this order did not match the store prices';

  // 2) Delivery charge may not be lower than what the store charges.
  const delivery = Number(o.deliveryCharge || 0);
  if (delivery < expectedDelivery(cfg, subtotal)) return 'The delivery charge did not match the store settings';

  // 3) Discount: none without a coupon, never more than the coupon really gives.
  const discount = Number(o.discount || 0);
  const code = String(o.couponCode || '').trim();
  const hasCoupon = code !== '' && code.toLowerCase() !== 'null';
  if (!hasCoupon) {
    if (discount > 0) return 'A discount was applied without a coupon';
  } else if (discount > 0) {
    if (!coupon) return 'The coupon in this order is not available';
    if ((coupon.isActive !== undefined ? coupon.isActive : coupon.active !== undefined ? coupon.active : true) !== true) {
      return 'The coupon in this order is not active';
    }
    if (discount > couponOff(coupon, subtotal, delivery)) return 'The discount was higher than the coupon allows';
  }

  // 4) Total must add up (the Firestore rules check this too).
  if (Number(o.total) !== subtotal + delivery - discount) return 'The order total did not add up';
  return '';
}

// ---------------------------------------------------------------------------
// 1) New order -> check prices, then deduct stock
// ---------------------------------------------------------------------------
exports.deductStockOnOrder = onDocumentCreated(
  { document: 'orders/{orderId}', region: REGION, retry: true },
  async (event) => {
    const orderId = event.params.orderId;
    const ref = db.doc(`orders/${orderId}`);

    // Reads that do not need to be inside the transaction (settings + coupon).
    const first = await ref.get();
    if (!first.exists) return;
    const cfg = await loadDeliveryCfg();
    const coupon = await loadCoupon(first.get('couponCode'));

    let soldOut = '';
    let mismatch = '';
    let customerId = '';

    await db.runTransaction(async (tx) => {
      soldOut = '';
      mismatch = '';
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

      // NEW: compare the order with the real prices / delivery / coupon.
      const prodById = new Map();
      ids.forEach((id, i) => prodById.set(id, prodSnaps[i].exists ? prodSnaps[i].data() : null));
      mismatch = checkOrderAgainstStore(o, want, prodById, cfg, coupon);
      if (mismatch) {
        tx.update(ref, {
          status: 'Cancelled',
          cancelledBy: 'system',
          cancelReason: mismatch,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

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

    if (mismatch && customerId) {
      await notify(
        customerId,
        `Order ${orderId} cancelled`,
        `We could not confirm this order (${mismatch}). Please check your cart and place the order again.`,
        'order',
        orderId
      );
    } else if (soldOut && customerId) {
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
          ? 'Cancelled: ' + (String(o.cancelReason || '').trim() || 'by the system')
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
    // CHANGED: a refund record is only needed when money was really received.
    // The Admin marks an online order "Paid" at "Payment Confirmed"; an unpaid (Pending)
    // order has nothing to refund, so no fake refund record is created for it.
    const needRefund =
      justCancelled &&
      after.paymentMethod !== 'Cash on Delivery' &&
      String(after.paymentStatus || '') === 'Paid';
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