import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Delivery partner orders – live from Firestore (`orders` where
/// partnerId == the signed-in partner). Nothing is hardcoded.
class DeliveryOrder {
  final String id, customer, phone, area, address, slot, payment, dateLabel, customerId;
  final List<String> items;
  final int amount, earning;
  final bool isToday;
  final DateTime? deliveredAt;
  /// Customer's delivery point (saved with the order). Null for older orders.
  final double? lat, lng;
  /// True when the order's paymentStatus is "Paid" (set by the admin / on COD delivery).
  final bool paid;
  /// How many times the partner reported a failed attempt (customer not reachable ...) and the last reason.
  final int attempts;
  final String lastFailedReason;
  /// COD only: true once the admin has marked the cash collected for this order as handed over.
  final bool cashSettled;
  /// Customer's star rating (1-5) for this delivered order. 0 = not rated yet.
  final int rating;
  /// True once the admin has paid this order's earning in a payout (orders/{id}.earningPaid).
  final bool earningPaid;
  /// RETURN PICKUP only (empty for a normal delivery): 'Pickup Assigned' -> 'Picked Up' -> 'Received'.
  /// The admin assigns the pickup (returnPartnerId), this partner marks "Picked Up",
  /// the admin marks "Received" when the phone reaches the store.
  String returnStatus;
  String status; // Assigned -> Picked Up -> Delivered

  DeliveryOrder({
    required this.id,
    required this.customer,
    required this.phone,
    required this.area,
    required this.address,
    required this.slot,
    required this.payment,
    required this.items,
    required this.amount,
    required this.earning,
    required this.isToday,
    required this.dateLabel,
    this.status = 'Assigned',
    this.customerId = '',
    this.deliveredAt,
    this.lat,
    this.lng,
    this.paid = false,
    this.attempts = 0,
    this.lastFailedReason = '',
    this.cashSettled = false,
    this.rating = 0,
    this.earningPaid = false,
    this.returnStatus = '',
  });

  bool get hasLocation => lat != null && lng != null;

  /// This card is a RETURN pickup (collect the phone back from the customer), not a delivery.
  bool get isReturn => returnStatus.isNotEmpty;
  bool get returnWaiting => returnStatus == 'Pickup Assigned';
  bool get returnPicked => returnStatus == 'Picked Up';
  bool get returnReceived => returnStatus == 'Received';

  /// Delivered order whose earning has not been paid out by the admin yet.
  bool get earningPending => status == 'Delivered' && !earningPaid && earning > 0;

  bool get isCod => payment == 'Cash on Delivery';

  /// Online order whose payment is not confirmed yet (nothing for the partner to collect).
  bool get payPending => !isCod && !paid && status != 'Delivered';

  /// Delivered cash-on-delivery order whose money the partner still has to hand over.
  bool get cashInHand => isCod && status == 'Delivered' && !cashSettled;
}

final ValueNotifier<List<DeliveryOrder>> orders = ValueNotifier<List<DeliveryOrder>>([]);

/// Orders that were cancelled (kept apart so the other screens never see them). Used by the "Cancelled" tab.
final ValueNotifier<List<DeliveryOrder>> cancelledOrders = ValueNotifier<List<DeliveryOrder>>([]);

/// RETURN pickups the admin assigned to this partner (orders where returnPartnerId == the partner).
/// Includes finished ones ("Received") so the partner can see the history.
final ValueNotifier<List<DeliveryOrder>> returnPickups = ValueNotifier<List<DeliveryOrder>>([]);

/// Return pickups still to do (waiting for pickup, or picked up and on the way to the store).
List<DeliveryOrder> activeReturnPickups() => returnPickups.value.where((o) => !o.returnReceived).toList();

/// Return pickups already finished (phone received by the store).
List<DeliveryOrder> doneReturnPickups() => returnPickups.value.where((o) => o.returnReceived).toList();

// ---------------- Payouts (money the admin already paid to this partner) ----------------

/// One payout the admin recorded (partnerPayouts/{id}, partnerId == the partner's email).
class PartnerPayoutRecord {
  final String id, note;
  final int amount, orderCount;
  final DateTime? date;
  const PartnerPayoutRecord(this.id, this.amount, this.orderCount, this.note, this.date);
}

final ValueNotifier<List<PartnerPayoutRecord>> payoutHistory = ValueNotifier<List<PartnerPayoutRecord>>([]);

/// Total rupees the admin has already paid to this partner.
int totalPaidOut() => payoutHistory.value.fold<int>(0, (sum, p) => sum + p.amount);

/// Earnings of delivered orders that the admin has not paid yet.
int pendingEarningTotal() => orders.value.where((o) => o.earningPending).fold<int>(0, (sum, o) => sum + o.earning);

// ---------------- Real rating (from the customers' order ratings) ----------------

/// Average of the stars customers gave to this partner's delivered orders (count 0 = no rating yet).
({double average, int count}) partnerRatingStats() {
  var total = 0;
  var count = 0;
  for (final o in orders.value) {
    if (o.status == 'Delivered' && o.rating >= 1 && o.rating <= 5) {
      total += o.rating;
      count++;
    }
  }
  return (average: count == 0 ? 0.0 : total / count, count: count);
}

// ---------------- Partner alerts (bell icon) ----------------
//
// Two sources are merged into one list:
//   1. SAVED notifications: Firestore `notifications` where userId == the partner's login uid.
//      The admin writes them (new order assigned, order cancelled / taken back, document
//      verified / rejected, support reply, broadcast). They stay until the partner reads them,
//      also after the app was closed, and "read" is saved in Firestore (isRead).
//   2. LIVE alerts built from the orders listener below (while the app is open):
//      * an order that newly shows up for this partner  -> "New order assigned"
//      * an order that gets cancelled                   -> "Order cancelled"
//      * an order that disappears (admin re-assigned)   -> "Order removed"
//      If a saved notification exists for the same order and event, it is shown only once.

class PartnerAlert {
  final String title, body;
  final DateTime at;
  bool read;
  /// Same key for the live alert and the saved notification of one event ('assigned:ID', 'cancelled:ID').
  final String key;
  /// Firestore notification id (empty for live alerts).
  final String docId;
  /// Notification type saved by the admin (order_assigned, order_cancelled, document, support, partner ...).
  final String type;
  PartnerAlert(this.title, this.body, {DateTime? at, this.read = false, this.key = '', this.docId = '', this.type = ''})
      : at = at ?? DateTime.now();
}

final ValueNotifier<List<PartnerAlert>> partnerAlerts = ValueNotifier<List<PartnerAlert>>([]);

List<PartnerAlert> _localAlerts = <PartnerAlert>[];
List<PartnerAlert> _remoteAlerts = <PartnerAlert>[];
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;

bool _alertsSeeded = false; // the first server snapshot only fills the list, it never alerts
final Set<String> _activeIds = <String>{}; // ids of the partner's non-cancelled orders last time
final Set<String> _selfRemoved = <String>{}; // orders this partner gave back (no "Order removed" alert for them)
bool _returnSeeded = false; // same idea for the return pickups listener
final Set<String> _returnIds = <String>{}; // return pickups waiting for pickup last time

int get unreadAlertCount => partnerAlerts.value.where((a) => !a.read).length;

void _publishAlerts() {
  final localKeys = _localAlerts.where((a) => a.key.isNotEmpty).map((a) => a.key).toSet();
  final merged = <PartnerAlert>[
    ..._localAlerts,
    ..._remoteAlerts.where((a) => a.key.isEmpty || !localKeys.contains(a.key)),
  ]..sort((a, b) => b.at.compareTo(a.at));
  partnerAlerts.value = merged.length > 50 ? merged.sublist(0, 50) : merged;
}

void markAlertsRead() {
  if (partnerAlerts.value.every((a) => a.read) && _remoteAlerts.every((a) => a.read)) return;
  for (final a in _localAlerts) {
    a.read = true;
  }
  final ids = <String>[];
  for (final a in _remoteAlerts) {
    if (!a.read) {
      a.read = true;
      if (a.docId.isNotEmpty) ids.add(a.docId);
    }
  }
  _publishAlerts();
  if (ids.isNotEmpty) unawaited(_saveRead(ids));
}

/// Saves "read" for the saved notifications (partner may only change isRead / readAt).
Future<void> _saveRead(List<String> ids) async {
  try {
    final db = FirebaseFirestore.instance;
    for (var i = 0; i < ids.length; i += 400) {
      final batch = db.batch();
      for (final id in ids.skip(i).take(400)) {
        batch.update(db.collection('notifications').doc(id), {'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    }
  } catch (e) {
    debugPrint('PhoneHub partner notifications read: $e');
  }
}

void _pushAlert(String title, String body, {String key = ''}) {
  final list = <PartnerAlert>[PartnerAlert(title, body, key: key), ..._localAlerts];
  _localAlerts = list.length > 30 ? list.sublist(0, 30) : list;
  _publishAlerts();
}

PartnerAlert _remoteAlert(String docId, Map<String, dynamic> d) {
  final type = '${d['type'] ?? ''}';
  final orderId = '${d['orderId'] ?? ''}';
  var title = '${d['title'] ?? ''}';
  var body = '${d['body'] ?? ''}';
  var key = '';
  if (type == 'order_assigned' && orderId.isNotEmpty) key = 'assigned:$orderId';
  if (type == 'return_pickup' && orderId.isNotEmpty) key = 'return:$orderId';
  if (type == 'order_cancelled' && orderId.isNotEmpty) {
    key = 'cancelled:$orderId';
    // The bell draws these two titles in red.
    if (title.startsWith('Order cancelled')) {
      title = 'Order cancelled';
      body = body.contains(orderId) ? body : 'Order $orderId: $body';
    } else if (title.startsWith('Order taken back')) {
      title = 'Order removed';
      body = 'Order $orderId is no longer assigned to you.';
    }
  }
  final ts = d['createdAt'];
  return PartnerAlert(title, body,
      at: ts is Timestamp ? ts.toDate() : DateTime.now(), read: d['isRead'] == true, key: key, docId: docId, type: type);
}

/// Listens to the saved notifications of the signed-in partner.
void _startNotificationListener() {
  _notifSub?.cancel();
  _notifSub = null;
  _remoteAlerts = <PartnerAlert>[];
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return;
  _notifSub = FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .listen((snap) {
    _remoteAlerts = snap.docs.map((d) => _remoteAlert(d.id, d.data())).toList();
    _publishAlerts();
  }, onError: (Object e) => debugPrint('PhoneHub partner notifications: $e'));
}

void _detectAlerts(QuerySnapshot<Map<String, dynamic>> snap) {
  final nowActive = <String>{};
  final fresh = <String>[]; // newly assigned
  final cancelled = <String>[]; // cancelled while we knew them
  for (final d in snap.docs) {
    final data = d.data();
    final raw = (data['status'] ?? '').toString().toLowerCase();
    if (raw == 'cancelled') {
      if (_activeIds.contains(d.id)) cancelled.add(d.id);
      continue;
    }
    nowActive.add(d.id);
    if (!_activeIds.contains(d.id) && raw != 'delivered') fresh.add(d.id);
  }
  final removed = _activeIds.where((id) => !nowActive.contains(id) && !cancelled.contains(id)).toList();

  if (!_alertsSeeded) {
    // The first snapshot can come from the local cache: wait for the server one.
    if (!snap.metadata.isFromCache) _alertsSeeded = true;
  } else {
    for (final id in fresh) {
      final doc = snap.docs.firstWhere((e) => e.id == id);
      final o = _fromDoc(id, doc.data());
      final who = o == null ? '' : [o.customer, o.area].where((e) => e.isNotEmpty).join(' • ');
      _pushAlert('New order assigned', who.isEmpty ? 'Order $id' : 'Order $id • $who', key: 'assigned:$id');
    }
    for (final id in cancelled) {
      _pushAlert('Order cancelled', 'Order $id was cancelled. No need to deliver it.', key: 'cancelled:$id');
    }
    for (final id in removed) {
      if (_selfRemoved.remove(id)) continue;
      _pushAlert('Order removed', 'Order $id is no longer assigned to you.', key: 'cancelled:$id');
    }
  }
  _activeIds
    ..clear()
    ..addAll(nowActive);
}

/// New return pickup assigned by the admin -> live bell alert (while the app is open).
void _detectReturnAlerts(QuerySnapshot<Map<String, dynamic>> snap) {
  final waiting = <String>{};
  for (final d in snap.docs) {
    if ((d.data()['returnPickupStatus'] ?? '').toString() == 'Pickup Assigned') waiting.add(d.id);
  }
  if (!_returnSeeded) {
    if (!snap.metadata.isFromCache) _returnSeeded = true;
  } else {
    for (final id in waiting.where((e) => !_returnIds.contains(e))) {
      final doc = snap.docs.firstWhere((e) => e.id == id);
      final o = _fromDoc(id, doc.data(), returnStatus: 'Pickup Assigned');
      final who = o == null ? '' : [o.customer, o.area].where((e) => e.isNotEmpty).join(' \u2022 ');
      _pushAlert('Return pickup assigned', who.isEmpty ? 'Order $id' : 'Order $id \u2022 $who', key: 'return:$id');
    }
  }
  _returnIds
    ..clear()
    ..addAll(waiting);
}

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _returnSub;
StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _payoutSub;

/// Listens to the money the admin paid to [partnerId] (partnerPayouts, read-only for the partner).
void _startPayoutListener(String partnerId) {
  _payoutSub?.cancel();
  payoutHistory.value = [];
  _payoutSub = FirebaseFirestore.instance
      .collection('partnerPayouts')
      .where('partnerId', isEqualTo: partnerId)
      .snapshots()
      .listen((snap) {
    final list = snap.docs.map((d) {
      final m = d.data();
      final ts = m['createdAt'];
      return PartnerPayoutRecord(
        d.id,
        _int(m['amount']),
        _int(m['orderCount']),
        (m['note'] ?? '').toString(),
        ts is Timestamp ? ts.toDate() : null,
      );
    }).toList()
      ..sort((a, b) => (b.date ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.date ?? DateTime.fromMillisecondsSinceEpoch(0)));
    payoutHistory.value = list;
  }, onError: (Object e) => debugPrint('PhoneHub partner payouts: $e'));
}

/// Listens to the RETURN pickups the admin assigned to [partnerId] (orders.returnPartnerId).
void _startReturnListener(String partnerId) {
  _returnSub?.cancel();
  returnPickups.value = [];
  _returnSeeded = false;
  _returnIds.clear();
  _returnSub = FirebaseFirestore.instance
      .collection('orders')
      .where('returnPartnerId', isEqualTo: partnerId)
      .snapshots()
      .listen((snap) {
    final list = <DeliveryOrder>[];
    for (final d in snap.docs) {
      final st = (d.data()['returnPickupStatus'] ?? '').toString();
      if (st != 'Pickup Assigned' && st != 'Picked Up' && st != 'Received') continue;
      final o = _fromDoc(d.id, d.data(), returnStatus: st);
      if (o != null) list.add(o);
    }
    // Waiting first, then on the way, then finished.
    int rank(DeliveryOrder o) => o.returnWaiting ? 0 : (o.returnPicked ? 1 : 2);
    list.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.id.compareTo(b.id));
    returnPickups.value = list;
    _detectReturnAlerts(snap);
  }, onError: (Object e) => debugPrint('PhoneHub return pickups: $e'));
}

/// Starts listening to the orders assigned to [partnerId].
void startDeliveryListener(String partnerId) {
  _sub?.cancel();
  orders.value = [];
  cancelledOrders.value = [];
  _alertsSeeded = false;
  _activeIds.clear();
  _localAlerts = <PartnerAlert>[];
  _remoteAlerts = <PartnerAlert>[];
  partnerAlerts.value = [];
  _startNotificationListener();
  _startReturnListener(partnerId);
  _startPayoutListener(partnerId);
  _sub = FirebaseFirestore.instance.collection('orders').where('partnerId', isEqualTo: partnerId).snapshots().listen((snap) {
    final list = <DeliveryOrder>[];
    final cancelled = <DeliveryOrder>[];
    for (final d in snap.docs) {
      final data = d.data();
      if ((data['status'] ?? '').toString().toLowerCase() == 'cancelled') {
        final c = _fromDoc(d.id, {...data, 'status': 'Assigned', 'deliveryStatus': ''});
        if (c != null) {
          c.status = 'Cancelled';
          cancelled.add(c);
        }
        continue;
      }
      final o = _fromDoc(d.id, data);
      if (o != null) list.add(o);
    }
    cancelledOrders.value = cancelled;
    list.sort((a, b) {
      final ad = a.status == 'Delivered' ? 1 : 0;
      final bd = b.status == 'Delivered' ? 1 : 0;
      return ad != bd ? ad.compareTo(bd) : a.id.compareTo(b.id);
    });
    orders.value = list;
    _detectAlerts(snap);
    // Share the live location while at least one order is "Picked Up".
    _syncLocationSharing(partnerId, list);
  }, onError: (Object e) => debugPrint('PhoneHub delivery orders: $e'));
}

void stopDeliveryListener() {
  _sub?.cancel();
  _sub = null;
  _returnSub?.cancel();
  _returnSub = null;
  _payoutSub?.cancel();
  _payoutSub = null;
  returnPickups.value = [];
  payoutHistory.value = [];
  _returnSeeded = false;
  _returnIds.clear();
  _notifSub?.cancel();
  _notifSub = null;
  _stopLocationSharing();
  orders.value = [];
  cancelledOrders.value = [];
  _alertsSeeded = false;
  _activeIds.clear();
  _localAlerts = <PartnerAlert>[];
  _remoteAlerts = <PartnerAlert>[];
  partnerAlerts.value = [];
}

// ---------------- Live location sharing ----------------
//
// While the partner has an order that is "Picked Up" (= Out for Delivery), the
// phone's GPS position is saved to:
//   partners/{email}            -> lat, lng, locationAt   (Admin Live tracking)
//   orders/{id}                 -> partnerLat, partnerLng, partnerLocationAt   (Customer tracking)
// It stops by itself when there is no order out for delivery any more.
// (Works while the app is open; background tracking needs a foreground service.)

StreamSubscription<Position>? _posSub;
bool _sharing = false;
DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
List<String> _liveOrderIds = [];

void _syncLocationSharing(String partnerId, List<DeliveryOrder> list) {
  _liveOrderIds = list.where((o) => o.status == 'Picked Up').map((o) => o.id).toList();
  if (_liveOrderIds.isEmpty) {
    _stopLocationSharing();
    return;
  }
  if (_sharing) return;
  _sharing = true;
  unawaited(_startLocationSharing(partnerId));
}

Future<void> _startLocationSharing(String partnerId) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _sharing = false;
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      _sharing = false;
      return;
    }
    if (!_sharing) return; // stopped while we were asking for permission
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen(
          (p) => unawaited(_publishLocation(partnerId, p)),
      onError: (Object e) => debugPrint('PhoneHub location stream: $e'),
    );
    final now = await Geolocator.getCurrentPosition();
    await _publishLocation(partnerId, now, force: true);
  } catch (e) {
    debugPrint('PhoneHub location sharing failed: $e');
    if (_posSub == null) _sharing = false;
  }
}

void _stopLocationSharing() {
  _posSub?.cancel();
  _posSub = null;
  _sharing = false;
  _liveOrderIds = [];
}

Future<void> _publishLocation(String partnerId, Position p, {bool force = false}) async {
  final now = DateTime.now();
  if (!force && now.difference(_lastSent).inSeconds < 8) return;
  final ids = List<String>.from(_liveOrderIds);
  if (ids.isEmpty) return;
  _lastSent = now;
  try {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.update(db.collection('partners').doc(partnerId), {
      'lat': p.latitude,
      'lng': p.longitude,
      'locationAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final id in ids) {
      batch.update(db.collection('orders').doc(id), {
        'partnerLat': p.latitude,
        'partnerLng': p.longitude,
        'partnerLocationAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  } catch (e) {
    debugPrint('PhoneHub location publish failed: $e');
  }
}

DeliveryOrder? _fromDoc(String id, Map<String, dynamic> d, {String returnStatus = ''}) {
  final raw = (d['status'] ?? '').toString();
  if (raw.toLowerCase() == 'cancelled') return null;

  final lines = <String>[];
  final items = d['items'];
  if (items is List) {
    for (final r in items) {
      if (r is! Map) continue;
      final q = r['quantity'] ?? r['qty'] ?? 1;
      final parts = [r['name'], r['storage'], r['condition']].where((e) => e != null && e.toString().isNotEmpty).join(' • ');
      lines.add(q is num && q > 1 ? '$parts  ×${q.toInt()}' : parts);
    }
  }

  var status = 'Assigned';
  final ds = (d['deliveryStatus'] ?? '').toString();
  if (raw.toLowerCase() == 'delivered' || ds == 'Delivered') {
    status = 'Delivered';
  } else if (ds == 'Picked Up') {
    status = 'Picked Up';
  }

  final address = (d['addressLine'] ?? d['deliveryAddress'] ?? '').toString();
  final parts = address.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final area = parts.length >= 2 ? parts[parts.length - 2] : (parts.isEmpty ? '' : parts.first);
  final label = (d['addressLabel'] ?? '').toString();

  final now = DateTime.now();
  final dd = d['deliveryDate'];
  final due = dd is Timestamp ? dd.toDate() : null;
  // An order is "today's work" when its delivery date is today (or earlier) or when it is
  // already packed / on the way, so a ready order is never hidden under "Upcoming".
  final ready = raw.toLowerCase() == 'packed' || raw.toLowerCase() == 'out for delivery' || ds == 'Picked Up';
  final today = ready || due == null || !DateTime(due.year, due.month, due.day).isAfter(DateTime(now.year, now.month, now.day));
  final custName = (d['customerName'] ?? '').toString().trim();
  final aLat = d['addressLat'], aLng = d['addressLng'];
  final isReturn = returnStatus.isNotEmpty;
  // A return card shows the day the admin assigned the pickup.
  final assignedAt = d['returnPickupAssignedAt'];
  final returnDate = assignedAt is Timestamp ? assignedAt.toDate() : null;
  final r = d['rating'];

  return DeliveryOrder(
    id: id,
    customerId: (d['customerId'] ?? d['userId'] ?? '').toString(),
    customer: custName.isEmpty ? 'Customer' : custName,
    phone: (d['customerPhone'] ?? '').toString(),
    area: area,
    address: label.isEmpty ? address : '$label: $address',
    slot: (d['deliverySlot'] ?? 'Anytime').toString(),
    payment: (d['paymentMethod'] ?? '').toString() == 'Cash on Delivery' ? 'Cash on Delivery' : 'Paid Online',
    items: lines,
    amount: _int(d['total'] ?? d['grandTotal']),
    earning: _int(d['earning']),
    isToday: isReturn ? true : today,
    dateLabel: isReturn ? (returnDate == null ? 'Today' : formatDate(returnDate)) : (today ? 'Today' : formatDate(due)),
    status: isReturn ? (returnStatus == 'Picked Up' ? 'Picked Up' : (returnStatus == 'Received' ? 'Delivered' : 'Assigned')) : status,
    deliveredAt: d['deliveredAt'] is Timestamp ? (d['deliveredAt'] as Timestamp).toDate() : null,
    lat: aLat is num ? aLat.toDouble() : null,
    lng: aLng is num ? aLng.toDouble() : null,
    paid: (d['paymentStatus'] ?? '').toString().toLowerCase() == 'paid',
    attempts: d['deliveryAttempts'] is num ? (d['deliveryAttempts'] as num).toInt() : 0,
    lastFailedReason: (d['failedReason'] ?? '').toString(),
    cashSettled: d['cashSettled'] == true,
    rating: r is num ? r.round().clamp(0, 5).toInt() : 0,
    earningPaid: d['earningPaid'] == true,
    returnStatus: returnStatus,
  );
}

int _int(dynamic v) => v is num ? v.round() : (int.tryParse('${v ?? ''}') ?? 0);

/// Pickup: marks the order "Picked Up" (the order becomes "Out for Delivery") and tells the customer.
/// Returns false (and shows the old status again) when it could not be saved.
/// "Delivered" is NOT done here any more: it needs the customer's OTP, see [confirmDelivery].
Future<bool> updateStatus(DeliveryOrder o, String s) async {
  if (s != 'Picked Up') return false;
  final before = o.status;
  o.status = s;
  orders.value = List<DeliveryOrder>.from(orders.value);
  try {
    await FirebaseFirestore.instance.collection('orders').doc(o.id).update({
      'deliveryStatus': 'Picked Up',
      'status': 'Out for Delivery',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('PhoneHub delivery status failed: $e');
    o.status = before; // could not save: show the old status again
    orders.value = List<DeliveryOrder>.from(orders.value);
    return false;
  }
  unawaited(_notifyCustomer(o, s));
  return true;
}

/// Marks the order delivered with the 4-digit OTP the customer shows in their app.
/// Firestore rules compare [otp] with the secret code saved with the order, so a wrong OTP is refused.
/// Returns null when it worked, otherwise a message to show the partner.
Future<String?> confirmDelivery(DeliveryOrder o, String otp) async {
  final data = <String, dynamic>{
    'status': 'Delivered',
    'deliveryStatus': 'Delivered',
    'deliveredAt': FieldValue.serverTimestamp(),
    'deliveryOtpEntered': otp,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (o.isCod) {
    data['paymentStatus'] = 'Paid';
    // Cash the partner collected at the door; the admin marks it settled later (cashSettled).
    data['cashCollected'] = true;
    data['cashAmount'] = o.amount;
  }
  try {
    await FirebaseFirestore.instance.collection('orders').doc(o.id).update(data);
  } on FirebaseException catch (e) {
    debugPrint('PhoneHub delivery confirm failed: ${e.code}');
    return e.code == 'permission-denied'
        ? 'Incorrect OTP. Please ask the customer again.'
        : 'Could not save. Please check your internet and try again.';
  } catch (_) {
    return 'Could not save. Please check your internet and try again.';
  }
  o.status = 'Delivered';
  orders.value = List<DeliveryOrder>.from(orders.value);
  unawaited(_notifyCustomer(o, 'Delivered'));
  return null;
}

/// Tells the customer (notification). A failure here never undoes the delivery status.
Future<void> _notifyCustomer(DeliveryOrder o, String s) async {
  if (o.customerId.isEmpty || (s != 'Picked Up' && s != 'Delivered')) return;
  try {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': o.customerId,
      'title': s == 'Delivered' ? 'Order ${o.id} delivered' : 'Order ${o.id} is out for delivery',
      'body': s == 'Delivered' ? 'Your order was delivered. Thank you for shopping with PhoneHub!' : 'Your delivery partner has picked up your order.',
      'type': 'delivery',
      'orderId': o.id,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('PhoneHub delivery notification failed: $e');
  }
}

/// The partner could not deliver this time (customer not reachable, wrong address,
/// asked to reschedule ...). The order stays with the partner; the attempt is counted
/// on the order and the customer is told. Returns null on success, otherwise a message.
Future<String?> reportFailedAttempt(DeliveryOrder o, String reason) async {
  final text = reason.trim();
  if (text.isEmpty) return 'Please choose a reason.';
  if (o.status == 'Delivered') return 'This order is already delivered.';
  try {
    await FirebaseFirestore.instance.collection('orders').doc(o.id).update({
      'deliveryAttempts': FieldValue.increment(1),
      'failedReason': text,
      'lastAttemptAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } on FirebaseException catch (e) {
    debugPrint('PhoneHub failed attempt: ${e.code}');
    return e.code == 'permission-denied'
        ? 'Not allowed for this order any more.'
        : 'Could not save. Please check your internet and try again.';
  } catch (_) {
    return 'Could not save. Please check your internet and try again.';
  }
  if (o.customerId.isNotEmpty) {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': o.customerId,
        'title': 'Delivery attempt unsuccessful \u2022 ${o.id}',
        'body': 'The delivery partner could not deliver your order: $text.',
        'type': 'delivery',
        'orderId': o.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PhoneHub failed-attempt notification failed: $e');
    }
  }
  return null;
}

/// The partner gives an order back BEFORE picking it up (vehicle problem, too far ...).
/// The order becomes unassigned so the admin can give it to someone else, and the admin is
/// told through a support ticket (Admin > Support). Returns null on success, otherwise a message.
Future<String?> rejectOrder(DeliveryOrder o, String partnerId, String partnerName, String reason) async {
  final text = reason.trim();
  if (text.isEmpty) return 'Please choose a reason.';
  if (o.status != 'Assigned') return 'You can only give back an order that is not picked up yet.';
  final db = FirebaseFirestore.instance;
  try {
    _selfRemoved.add(o.id);
    await db.collection('orders').doc(o.id).update({
      'partnerId': '',
      'partnerName': '',
      'partnerPhone': '',
      'earning': 0,
      'deliveryStatus': 'Rejected',
      'rejectedBy': partnerId,
      'rejectReason': text,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } on FirebaseException catch (e) {
    _selfRemoved.remove(o.id);
    debugPrint('PhoneHub reject order: ${e.code}');
    return e.code == 'permission-denied'
        ? 'This order cannot be given back any more.'
        : 'Could not save. Please check your internet and try again.';
  } catch (_) {
    _selfRemoved.remove(o.id);
    return 'Could not save. Please check your internet and try again.';
  }
  try {
    final now = Timestamp.now();
    await db.collection('tickets').add({
      'partnerId': partnerId,
      'partnerName': partnerName,
      'customerId': '',
      'orderId': o.id,
      'subject': 'Order ${o.id} given back by partner',
      'status': 'Open',
      'created': now,
      'messages': [
        {'fromAdmin': false, 'text': 'I cannot deliver order ${o.id}: $text. Please assign it to another partner.', 'time': now},
      ],
      'type': 'order_rejected',
    });
  } catch (e) {
    debugPrint('PhoneHub reject ticket failed: $e');
  }
  return null;
}

// ---------------- Return pickup (collect the phone back from the customer) ----------------

/// The partner has collected the phone from the customer ("Picked Up"). The admin marks it "Received"
/// when it reaches the store, and then pays the refund. Firestore rules allow only
/// returnPickupStatus / returnPickedAt / updatedAt here, and only while the pickup is "Pickup Assigned".
/// Returns null on success, otherwise a message to show the partner.
Future<String?> markReturnPickedUp(DeliveryOrder o) async {
  if (!o.isReturn || !o.returnWaiting) return 'This return is not waiting for pickup.';
  final before = o.returnStatus;
  o.returnStatus = 'Picked Up';
  returnPickups.value = List<DeliveryOrder>.from(returnPickups.value);
  try {
    await FirebaseFirestore.instance.collection('orders').doc(o.id).update({
      'returnPickupStatus': 'Picked Up',
      'returnPickedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } on FirebaseException catch (e) {
    debugPrint('PhoneHub return pickup failed: ${e.code}');
    o.returnStatus = before;
    returnPickups.value = List<DeliveryOrder>.from(returnPickups.value);
    return e.code == 'permission-denied'
        ? 'This return pickup is not assigned to you any more.'
        : 'Could not save. Please check your internet and try again.';
  } catch (_) {
    o.returnStatus = before;
    returnPickups.value = List<DeliveryOrder>.from(returnPickups.value);
    return 'Could not save. Please check your internet and try again.';
  }
  if (o.customerId.isNotEmpty) {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': o.customerId,
        'title': 'Return pickup done \u2022 ${o.id}',
        'body': 'Your delivery partner has collected your phone. We will confirm once it reaches the store.',
        'type': 'delivery',
        'orderId': o.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PhoneHub return pickup notification failed: $e');
    }
  }
  return null;
}

// ---------------- COD cash in hand ----------------

/// Delivered cash-on-delivery orders whose cash has not been marked as handed over by the admin.
List<DeliveryOrder> cashToSettle() => orders.value.where((o) => o.cashInHand).toList();

/// Total of [cashToSettle] (rupees the partner has to hand over).
int cashInHandTotal() => cashToSettle().fold<int>(0, (sum, o) => sum + o.amount);

// ---------------- Earnings ----------------

class EarningRecord {
  final String orderId, customer;
  final int dayOffset; // days ago
  final int amount;
  const EarningRecord(this.orderId, this.customer, this.dayOffset, this.amount);

  String get dateLabel => formatDate(DateTime.now().subtract(Duration(days: dayOffset)));
}

/// filter: 0 = This Week (Monday to today), 1 = Last Week (Monday-Sunday),
/// 2 = This Month (first day to today).
/// Built from the partner's own delivered orders (no sample data).
List<EarningRecord> earningsFor(int filter) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisWeekStart = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  final thisMonthStart = DateTime(today.year, today.month, 1);
  final all = <EarningRecord>[];

  for (final o in orders.value.where((o) => o.status == 'Delivered')) {
    final delivered = o.deliveredAt;
    // Do not attribute legacy records without a delivery timestamp to today.
    if (delivered == null) continue;
    final deliveredDay = DateTime(delivered.year, delivered.month, delivered.day);
    final inRange = switch (filter) {
      0 => !deliveredDay.isBefore(thisWeekStart) && !deliveredDay.isAfter(today),
      1 => !deliveredDay.isBefore(lastWeekStart) && deliveredDay.isBefore(thisWeekStart),
      2 => !deliveredDay.isBefore(thisMonthStart) && !deliveredDay.isAfter(today),
      _ => false,
    };
    if (!inRange) continue;
    final offset = today.difference(deliveredDay).inDays;
    all.add(EarningRecord(o.id, o.customer, offset < 0 ? 0 : offset, o.earning));
  }
  all.sort((a, b) => a.dayOffset.compareTo(b.dayOffset));
  return all;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String formatDate(DateTime? d) => d == null ? '' : '${d.day} ${_months[d.month - 1]}';

String rupee(int v) {
  final s = v.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}