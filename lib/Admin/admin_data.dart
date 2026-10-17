import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phonehub/Admin/phone_extras.dart';

// ============================================================================
// PhoneHub ADMIN data store backed by Firebase Cloud Firestore.
// Existing model names and UI-facing APIs are retained.
// ============================================================================

const List<String> orderSteps = ['Order Placed', 'Payment Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];
const List<String> conditions = ['Like New', 'Good', 'Fair'];
const List<String> storages = ['32 GB', '64 GB', '128 GB', '256 GB', '512 GB'];
const List<String> paymentMethods = ['UPI', 'Debit/Credit Card', 'Net Banking', 'Wallet', 'Cash on Delivery'];

const List<Color> swatches = [
  Color(0xFF1E3A8A), Color(0xFF111827), Color(0xFF2E4A9A), Color(0xFF0F766E), Color(0xFFB91C1C),
  Color(0xFF065F46), Color(0xFFC2410C), Color(0xFF0369A1), Color(0xFFA16207), Color(0xFFBE185D),
  Color(0xFF3B82F6), Color(0xFF6B7280), Color(0xFFC084FC), Color(0xFF2DD4BF), Color(0xFFF87171),
  Color(0xFF34D399), Color(0xFFFB923C), Color(0xFF38BDF8), Color(0xFFFACC15), Color(0xFFF472B6),
];

class Phone {
  final String id;
  String name, brand, storage, condition;
  int price, mrp, battery, stock;
  double rating;
  List<Color> colors;
  List<String> images;
  PhoneDetails details;
  bool active;

  String? get cover => images.isEmpty ? null : images.first;

  Phone({
    required this.id,
    required this.name,
    required this.brand,
    required this.storage,
    required this.condition,
    required this.price,
    required this.mrp,
    required this.battery,
    required this.rating,
    required this.colors,
    List<String>? images,
    PhoneDetails? details,
    this.stock = 5,
    this.active = true,
  })  : images = images ?? <String>[],
        details = details ?? PhoneDetails();

  int get off => mrp <= 0 ? 0 : (((mrp - price) / mrp) * 100).round();
  String get stockLabel => stock == 0 ? 'Out of stock' : (stock <= 3 ? 'Low stock' : 'In stock');
}

class Brand {
  String name;
  Color color;
  bool active;
  Brand(this.name, this.color, {this.active = true});
}

class Customer {
  final String id;
  String name, phone, email;
  bool blocked;
  final DateTime joined;
  final List<String> addresses;
  final List<String> wishlist; // phone ids

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.joined,
    this.blocked = false,
    this.addresses = const [],
    this.wishlist = const [],
  });

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

class OrderLine {
  final String phoneId, name, storage, condition;
  final int qty, price;
  const OrderLine(this.phoneId, this.name, this.storage, this.condition, this.qty, this.price);
}

class AdminOrder {
  final String id, customerId, paymentMethod, address;
  final List<OrderLine> items;
  final int subtotal, delivery, discount, total;
  final String? couponCode;
  final DateTime placedAt;
  int stage; // 0..4
  bool cancelled;
  String? partnerId;
  // Extra data read from Firestore (used for stock restore / refunds / payment status).
  bool stockDeducted, stockRestored;
  String paymentStatus, cancelledBy;
  // Customer's 1-5 star rating of a delivered order (0 = not rated) and the
  // return / refund progress of a delivered order (Requested, Approved, Refunded, Rejected).
  int rating;
  String returnStatus;
  // ---- Delivery partner data (written by the delivery partner app) ----
  // COD cash taken at the door and whether the admin has received it from the partner.
  bool cashCollected, cashSettled;
  int cashAmount;
  DateTime? cashSettledAt;
  // Failed delivery attempts (customer not reachable, wrong address ...).
  int deliveryAttempts;
  String failedReason;
  DateTime? lastAttemptAt;
  // Partner who gave the order back before pickup (+ everyone who did so earlier).
  String rejectedBy, rejectReason;
  DateTime? rejectedAt;
  List<String> rejectedHistory;
  DateTime? deliveredAt;
  // Set by the admin app once a cancelled order has released its coupon use /
  // told the assigned delivery partner (so it is done only once per order).
  bool couponReleased, partnerCancelNotified;
  // ---- Physical RETURN pickup (set by the admin, advanced by the delivery partner) ----
  // returnStatus (above) is the refund progress; returnPickupStatus is the phone's journey back:
  // '' -> Pickup Assigned -> Picked Up -> Received.
  String returnPickupStatus, returnPartnerId, returnPartnerName, returnPartnerPhone;
  DateTime? returnPickedAt, returnReceivedAt;
  // ---- Delivery partner earning of this order and whether the admin has paid it out ----
  int earning;
  bool earningPaid;
  String payoutId;

  AdminOrder({
    required this.id,
    required this.customerId,
    required this.items,
    required this.subtotal,
    required this.delivery,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.address,
    required this.placedAt,
    this.couponCode,
    this.stage = 0,
    this.cancelled = false,
    this.partnerId,
    this.stockDeducted = false,
    this.stockRestored = false,
    this.paymentStatus = '',
    this.cancelledBy = '',
    this.rating = 0,
    this.returnStatus = '',
    this.cashCollected = false,
    this.cashSettled = false,
    this.cashAmount = 0,
    this.cashSettledAt,
    this.deliveryAttempts = 0,
    this.failedReason = '',
    this.lastAttemptAt,
    this.rejectedBy = '',
    this.rejectReason = '',
    this.rejectedAt,
    this.rejectedHistory = const [],
    this.deliveredAt,
    this.couponReleased = false,
    this.partnerCancelNotified = false,
    this.returnPickupStatus = '',
    this.returnPartnerId = '',
    this.returnPartnerName = '',
    this.returnPartnerPhone = '',
    this.returnPickedAt,
    this.returnReceivedAt,
    this.earning = 0,
    this.earningPaid = false,
    this.payoutId = '',
  });

  bool get isCod => paymentMethod == 'Cash on Delivery';

  /// A COD order the partner has delivered but whose cash the admin has not received yet.
  /// (Same rule the partner app uses for its "Cash in hand".)
  bool get cashPending => isCod && isDelivered && partnerId != null && !cashSettled;

  /// The cash amount the partner has to hand over (what he entered at the door, else the order total).
  int get cashDue => cashAmount > 0 ? cashAmount : total;

  /// Order was given back by a partner and is waiting for the admin to assign someone else.
  bool get needsReassign => !cancelled && !isDelivered && partnerId == null && rejectedBy.isNotEmpty;

  bool get hasFailedAttempt => deliveryAttempts > 0 && !isDelivered && !cancelled;

  /// Partners who already gave this order back (they should not be offered again).
  bool rejectedByPartner(String id) {
    final x = id.toLowerCase();
    return rejectedBy.toLowerCase() == x || rejectedHistory.any((e) => e.toLowerCase() == x);
  }
  bool get isDelivered => !cancelled && stage >= 4;
  bool get isOngoing => !cancelled && stage < 4;
  String get statusLabel => cancelled ? 'Cancelled' : orderSteps[stage];
  int get itemCount => items.fold<int>(0, (s, e) => s + e.qty);

  /// The admin approved the return of this delivered order but nobody has been sent to collect the phone yet.
  bool get needsReturnPickup => isDelivered && returnStatus == 'Approved' && returnPartnerId.isEmpty && returnPickupStatus.isEmpty;

  /// A partner has been sent (or has already collected the phone) and the phone is not back at the store yet.
  bool get returnPickupActive => returnPickupStatus == 'Pickup Assigned' || returnPickupStatus == 'Picked Up';
}

class Coupon {
  String code, title, note;
  int flat, percent, maxOff, minOrder;
  bool freeDelivery, firstOrderOnly, active;
  DateTime expiry;
  Coupon({
    required this.code,
    required this.title,
    this.note = '',
    this.flat = 0,
    this.percent = 0,
    this.maxOff = 0,
    this.minOrder = 0,
    this.freeDelivery = false,
    this.firstOrderOnly = false,
    this.active = true,
    required this.expiry,
  });
  bool get expired => expiry.isBefore(DateTime.now());
}

class PromoBanner {
  String title, subtitle;
  Color color;
  bool active;
  PromoBanner(this.title, this.subtitle, this.color, {this.active = true});
}

class Partner {
  final String id;
  String name, phone, vehicle, email;
  double rating;
  bool active;
  bool online;
  /// Firebase login uid of the partner (partners/{email}.uid, set when the partner first logs in).
  /// Notifications for the delivery app are written with userId = this uid.
  String uid;
  Partner({required this.id, required this.name, required this.phone, required this.vehicle, required this.rating, this.email = '', this.active = true, this.online = false, this.uid = ''});

  /// Verification documents (partners/{email}/docs/*): licence / aadhaar / rc -> Pending / Verified / Rejected.
  final Map<String, String> docStatus = <String, String>{};
  bool docsLoaded = false;

  static const List<String> docKeys = ['licence', 'aadhaar', 'rc'];

  /// True when Driving Licence, Aadhaar and RC are all verified by the admin.
  bool get docsVerified => docKeys.every((k) => docStatus[k] == 'Verified');

  /// Documents that are not verified yet (used for the "why can't I assign" message).
  List<String> get docsNotVerified => docKeys.where((k) => docStatus[k] != 'Verified').toList();
}

/// Earnings the admin has paid to a delivery partner (partnerPayouts/{id}).
class PartnerPayout {
  final String id, partnerId, partnerName, note;
  final int amount, orderCount;
  final DateTime date;
  const PartnerPayout(this.id, this.partnerId, this.partnerName, this.amount, this.orderCount, this.note, this.date);
}

/// One reward line of the delivery partner's Incentives screen. [target] = deliveries needed (0 = text only).
class IncentiveRule {
  int target;
  String title, reward;
  IncentiveRule(this.target, this.title, this.reward);
}

class Txn {
  final String id, orderId, method, status;
  final int amount;
  final DateTime date;
  const Txn(this.id, this.orderId, this.method, this.amount, this.status, this.date);
}

class Refund {
  final String id, orderId, reason;
  final int amount;
  String status; // Requested, Approved, Refunded, Rejected
  final DateTime date;
  /// 'return' when the customer asked for a return of a delivered order, '' for a cancelled-order refund.
  final String type;
  Refund(this.id, this.orderId, this.amount, this.reason, this.status, this.date, {this.type = ''});
}

class ChatMsg {
  final bool fromAdmin;
  final String text;
  final DateTime time;
  ChatMsg(this.fromAdmin, this.text, this.time);
}

class Ticket {
  final String id, customerId, subject;
  /// Set for tickets sent by a delivery partner (Help & Support in the delivery app).
  final String partnerId, partnerName;
  String status; // Open, In Progress, Resolved
  final List<ChatMsg> messages;
  final DateTime created;
  Ticket({required this.id, required this.customerId, required this.subject, required this.status, required this.messages, required this.created, this.partnerId = '', this.partnerName = ''});
}

class Faq {
  String q, a;
  String? id; // Firestore document id
  Faq(this.q, this.a);
}

class Staff {
  String name, email, role;
  bool active;
  String? id; // Firestore document id
  Staff(this.name, this.email, this.role, {this.active = true});
}

class SentNotif {
  final String title, body, audience;
  final DateTime time;
  SentNotif(this.title, this.body, this.audience, this.time);
}

class AlertItem {
  final IconData icon;
  final Color color;
  final String title, body;
  final DateTime time;
  const AlertItem(this.icon, this.color, this.title, this.body, this.time);
}

class AdminStore extends ChangeNotifier {
  // ---------------- Admin account & settings ----------------
  String adminName = 'Admin';
  String adminEmail = '';
  String adminPhone = '';
  bool pushAlerts = true;

  // Delivery charge / free-delivery limit are set by the admin in Settings (appConfig/store).
  // 0 = not set yet (the customer app then shows free delivery); nothing is built in.
  int deliveryCharge = 0;
  int freeDeliveryAbove = 0;
  int returnDays = 7;
  // Days the refund takes after a return / cancellation (0 = the customer app shows no number).
  int refundDays = 0;
  // Earning paid to a delivery partner per delivered order. Set by the admin in Settings
  // (saved in admins/{uid}.partnerEarning); there is no built-in amount.
  int partnerEarning = 0;
  String supportPhone = '';
  String supportEmail = '';
  String supportHours = '';
  // Pincodes the store delivers to, comma separated (empty = every pincode is accepted).
  String serviceablePincodes = '';

  // Policy texts are written by the admin in Settings (appConfig/store); nothing is built in.
  String returnsPolicy = '';
  String warrantyPolicy = '';
  String privacyPolicy = '';

  final List<Staff> staff = [];

  // ---------------- Catalogue ----------------
  final List<Brand> brands = [];

  final List<Phone> phones = [];

  // ---------------- People ----------------
  final List<Customer> customers = [];

  final List<Partner> partners = [];

  // ---------------- Orders ----------------
  final List<AdminOrder> orders = [];

  // ---------------- Marketing ----------------
  final List<Coupon> coupons = [];

  final List<PromoBanner> banners = [];

  final List<SentNotif> sentNotifs = [];

  // ---------------- Money & support ----------------
  final List<Refund> refunds = [];
  final List<Ticket> tickets = [];
  final List<Faq> faqs = [];

  // ---------------- Delivery partner money, rewards and legal text ----------------
  // Written by the admin, read live by the delivery app (no sample numbers are built in).
  final List<PartnerPayout> payouts = [];
  // When true, only partners whose Licence, Aadhaar and RC are all Verified can be given an order.
  bool requireVerifiedPartners = true;
  int partnerDailyTarget = 0;
  final List<IncentiveRule> partnerDailyIncentives = [];
  final List<IncentiveRule> partnerWeeklyIncentives = [];
  final List<String> partnerTerms = [];
  final List<String> partnerPrivacy = [];

  AdminStore() {
    loadFromFirebase();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool loading = true;
  String? loadError;

  // Live listeners + change tracking (so every edit made on an admin screen is
  // saved to Firestore, without changing any screen).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderSub, _ticketSub, _refundSub, _productSub, _partnerSub;
  Timer? _syncTimer;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _docSubs = {};
  bool _syncing = false;
  final Map<String, String> _sig = <String, String>{}; // last saved signature per item
  final Map<String, int> _lastStock = <String, int>{}; // last stock value known in Firestore
  final Map<String, DateTime> _stockAt = <String, DateTime>{}; // when each product was last changed in Firestore
  final Map<String, String> _brandDocIds = <String, String>{};
  final Set<String> _restoring = <String>{};
  final Set<String> _refundChecked = <String>{};
  final Set<String> _couponChecked = <String>{};
  final Set<String> _partnerCancelChecked = <String>{};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse('$value') ?? DateTime.now();
  }

  int _int(dynamic value, [int fallback = 0]) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  double _double(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  List<Color> _colors(dynamic value) {
    if (value is List) {
      final result = <Color>[];
      for (final item in value) {
        final n = _int(item, -1);
        if (n >= 0) result.add(Color(n));
      }
      if (result.isNotEmpty) return result;
    }
    return [swatches.first];
  }

  String _enc(Object? o) => jsonEncode(o, toEncodable: (x) => x.toString());

  String _brandId(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  String _brandDocId(String name) => _brandDocIds[name] ?? _brandId(name);
  String _refNo(String orderId) => 'RF${orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase()}';

  // ---------------- Parsers (one place, used by load + live listeners) ----------------
  AdminOrder _orderFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final rawItems = m['items'];
    final items = <OrderLine>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          items.add(OrderLine(
            '${raw['productId'] ?? raw['phoneId'] ?? raw['id'] ?? ''}',
            '${raw['name'] ?? raw['title'] ?? 'Product'}',
            '${raw['storage'] ?? ''}',
            '${raw['condition'] ?? ''}',
            _int(raw['qty'] ?? raw['quantity'], 1),
            _int(raw['price']),
          ));
        }
      }
    }
    final status = '${m['status'] ?? 'Order Placed'}';
    final stage = orderSteps.indexOf(status);
    // Customer app writes addressLine / deliveryCharge; older admin writes address / delivery.
    final rawAddress = m['addressLine'] ?? m['deliveryAddress'] ?? m['address'];
    final address = rawAddress is Map ? '${rawAddress['line'] ?? rawAddress['address'] ?? ''}' : '${rawAddress ?? ''}';
    return AdminOrder(
      id: d.id,
      customerId: '${m['customerId'] ?? m['userId'] ?? ''}',
      items: items,
      subtotal: _int(m['subtotal']),
      delivery: _int(m['deliveryCharge'] ?? m['delivery']),
      discount: _int(m['discount']),
      total: _int(m['total'] ?? m['grandTotal']),
      paymentMethod: '${m['paymentMethod'] ?? 'Unknown'}',
      address: address,
      placedAt: _date(m['placedAt'] ?? m['createdAt']),
      couponCode: m['couponCode']?.toString(),
      stage: stage < 0 ? 0 : stage,
      cancelled: status == 'Cancelled',
      partnerId: (m['partnerId'] == null || '${m['partnerId']}'.isEmpty) ? null : '${m['partnerId']}',
      stockDeducted: m['stockDeducted'] == true,
      stockRestored: m['stockRestored'] == true,
      paymentStatus: '${m['paymentStatus'] ?? ''}',
      cancelledBy: '${m['cancelledBy'] ?? ''}',
      rating: _int(m['rating']),
      returnStatus: '${m['returnStatus'] ?? ''}',
      cashCollected: m['cashCollected'] == true,
      cashSettled: m['cashSettled'] == true,
      cashAmount: _int(m['cashAmount']),
      cashSettledAt: m['cashSettledAt'] == null ? null : _date(m['cashSettledAt']),
      deliveryAttempts: _int(m['deliveryAttempts']),
      failedReason: '${m['failedReason'] ?? ''}',
      lastAttemptAt: m['lastAttemptAt'] == null ? null : _date(m['lastAttemptAt']),
      rejectedBy: '${m['rejectedBy'] ?? ''}',
      rejectReason: '${m['rejectReason'] ?? ''}',
      rejectedAt: m['rejectedAt'] == null ? null : _date(m['rejectedAt']),
      rejectedHistory: m['rejectedHistory'] is List ? (m['rejectedHistory'] as List).map((e) => '$e').toList() : <String>[],
      deliveredAt: m['deliveredAt'] == null ? null : _date(m['deliveredAt']),
      couponReleased: m['couponReleased'] == true,
      partnerCancelNotified: m['partnerCancelNotified'] == true,
      returnPickupStatus: '${m['returnPickupStatus'] ?? ''}',
      returnPartnerId: '${m['returnPartnerId'] ?? ''}',
      returnPartnerName: '${m['returnPartnerName'] ?? ''}',
      returnPartnerPhone: '${m['returnPartnerPhone'] ?? ''}',
      returnPickedAt: m['returnPickedAt'] == null ? null : _date(m['returnPickedAt']),
      returnReceivedAt: m['returnReceivedAt'] == null ? null : _date(m['returnReceivedAt']),
      earning: _int(m['earning']),
      earningPaid: m['earningPaid'] == true,
      payoutId: '${m['payoutId'] ?? ''}',
    );
  }

  Ticket _ticketFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final msgs = <ChatMsg>[];
    final raw = m['messages'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) msgs.add(ChatMsg(e['fromAdmin'] == true, '${e['text'] ?? ''}', _date(e['time'])));
      }
    }
    return Ticket(
      id: d.id,
      customerId: '${m['customerId'] ?? ''}',
      partnerId: '${m['partnerId'] ?? ''}',
      partnerName: '${m['partnerName'] ?? ''}',
      subject: '${m['subject'] ?? 'Support request'}',
      status: '${m['status'] ?? 'Open'}',
      messages: msgs,
      created: _date(m['created'] ?? m['createdAt']),
    );
  }

  Refund _refundFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return Refund('${m['refNo'] ?? d.id}', '${m['orderId'] ?? ''}', _int(m['amount']), '${m['reason'] ?? ''}',
        '${m['status'] ?? 'Requested'}', _date(m['createdAt']), type: '${m['type'] ?? ''}');
  }

  PartnerPayout _payoutFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    return PartnerPayout(d.id, '${m['partnerId'] ?? ''}', '${m['partnerName'] ?? ''}', _int(m['amount']), _int(m['orderCount']),
        '${m['note'] ?? ''}', _date(m['createdAt']));
  }

  List<IncentiveRule> _rules(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => IncentiveRule(_int(e['target']), '${e['title'] ?? ''}', '${e['reward'] ?? ''}')).toList()
      : <IncentiveRule>[];

  List<String> _strings(dynamic raw) =>
      raw is List ? raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() : <String>[];

  // ---------------- Load everything from Firestore ----------------
  Future<QuerySnapshot<Map<String, dynamic>>?> _tryGet(String col, {bool core = false}) async {
    try {
      return await _db.collection(col).get();
    } catch (e) {
      debugPrint('PhoneHub admin: loading "$col" failed: $e');
      if (core) loadError = '$col: $e';
      return null;
    }
  }

  Future<void> loadFromFirebase() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final r = await Future.wait<QuerySnapshot<Map<String, dynamic>>?>([
        _tryGet('products', core: true), // 0
        _tryGet('users', core: true), // 1
        _tryGet('partners'), // 2  (was "deliveryPartners" – not in the rules)
        _tryGet('orders', core: true), // 3
        _tryGet('coupons'), // 4
        _tryGet('broadcasts'), // 5 (sent notification history)
        _tryGet('tickets'), // 6
        _tryGet('refunds'), // 7
        _tryGet('staff'), // 8
        _tryGet('faqs'), // 9
        _tryGet('brands'), // 10
        _tryGet('partnerPayouts'), // 11
      ]);
      const none = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      phones
        ..clear()
        ..addAll((r[0]?.docs ?? none).map((d) {
          final m = d.data();
          _stockAt[d.id] = _date(m['updatedAt']);
          return Phone(
            id: d.id,
            name: '${m['name'] ?? ''}',
            brand: '${m['brand'] ?? ''}',
            storage: '${m['storage'] is List ? (m['storage'] as List).join(', ') : (m['storage'] ?? '')}',
            condition: '${m['condition'] ?? 'Good'}',
            price: _int(m['price']),
            mrp: _int(m['mrp'], _int(m['price'])),
            battery: _int(m['batteryHealth'] ?? m['battery'], 0),
            rating: _double(m['rating']),
            colors: _colors(m['colors']),
            images: m['images'] is List ? (m['images'] as List).map((e) => '$e').toList() : <String>[],
            details: PhoneDetails.fromMap(m['details'] is Map ? Map<String, dynamic>.from(m['details'] as Map) : null),
            stock: _int(m['stock']),
            active: (m['isActive'] ?? m['active'] ?? true) == true,
          );
        }));

      customers
        ..clear()
        ..addAll((r[1]?.docs ?? none).where((d) => (d.data()['role'] ?? 'customer') == 'customer').map((d) {
          final m = d.data();
          final rawAddresses = m['savedAddresses'] ?? m['addresses'];
          final addresses = rawAddresses is List
              ? rawAddresses.map((e) => e is Map ? '${e['label'] ?? ''}: ${e['line'] ?? e['address'] ?? ''}' : '$e').toList()
              : <String>[];
          final rawWishlist = m['wishlist'];
          return Customer(
            id: d.id,
            name: '${m['name'] ?? m['displayName'] ?? ''}',
            phone: '${m['phone'] ?? ''}',
            email: '${m['email'] ?? ''}',
            joined: _date(m['createdAt'] ?? m['joinedAt']),
            blocked: m['blocked'] == true,
            addresses: addresses,
            wishlist: rawWishlist is List ? rawWishlist.map((e) => '$e').toList() : const [],
          );
        }));

      partners
        ..clear()
        ..addAll((r[2]?.docs ?? none).map((d) {
          final m = d.data();
          return Partner(
            id: d.id,
            name: '${m['name'] ?? m['displayName'] ?? ''}',
            phone: '${m['phone'] ?? ''}',
            vehicle: '${m['vehicle'] ?? ''}',
            email: '${m['email'] ?? d.id}',
            rating: _double(m['rating']),
            active: (m['isActive'] ?? m['active'] ?? true) == true,
            online: m['online'] == true,
            uid: '${m['uid'] ?? ''}',
          );
        }));

      orders
        ..clear()
        ..addAll((r[3]?.docs ?? none).map(_orderFrom));

      coupons
        ..clear()
        ..addAll((r[4]?.docs ?? none).map((d) {
          final m = d.data();
          return Coupon(
            code: '${m['code'] ?? d.id}',
            title: '${m['title'] ?? m['name'] ?? d.id}',
            note: '${m['note'] ?? ''}',
            flat: _int(m['flat']),
            percent: _int(m['percent']),
            maxOff: _int(m['maxOff']),
            minOrder: _int(m['minOrder']),
            freeDelivery: m['freeDelivery'] == true,
            firstOrderOnly: m['firstOrderOnly'] == true,
            active: (m['isActive'] ?? m['active'] ?? true) == true,
            expiry: _date(m['expiry']),
          );
        }));

      sentNotifs
        ..clear()
        ..addAll(((r[5]?.docs ?? none).toList()
          ..sort((a, b) => _date(b.data()['createdAt']).compareTo(_date(a.data()['createdAt']))))
            .map((d) {
          final m = d.data();
          return SentNotif('${m['title'] ?? ''}', '${m['body'] ?? ''}', '${m['audience'] ?? 'All customers'}', _date(m['createdAt']));
        }));

      tickets
        ..clear()
        ..addAll((r[6]?.docs ?? none).map(_ticketFrom));
      tickets.sort((a, b) => b.created.compareTo(a.created));

      refunds
        ..clear()
        ..addAll((r[7]?.docs ?? none).map(_refundFrom));
      refunds.sort((a, b) => b.date.compareTo(a.date));

      staff
        ..clear()
        ..addAll((r[8]?.docs ?? none).map((d) {
          final m = d.data();
          return Staff('${m['name'] ?? ''}', '${m['email'] ?? ''}', '${m['role'] ?? 'Staff'}',
              active: (m['isActive'] ?? m['active'] ?? true) == true)
            ..id = d.id;
        }));

      faqs
        ..clear()
        ..addAll((r[9]?.docs ?? none)
            .where((d) => '${d.data()['q'] ?? d.data()['question'] ?? ''}'.isNotEmpty)
            .map((d) {
          final m = d.data();
          return Faq('${m['q'] ?? m['question'] ?? ''}', '${m['a'] ?? m['answer'] ?? ''}')..id = d.id;
        }));

      // Brands come from the `brands` collection (the customer app reads it too).
      brands.clear();
      _brandDocIds.clear();
      final dbBrandKeys = <String>{};
      for (final d in r[10]?.docs ?? none) {
        final m = d.data();
        final n = '${m['name'] ?? ''}';
        if (n.isEmpty) continue;
        final c = m['color'];
        brands.add(Brand(n, c != null ? Color(_int(c)) : swatches[brands.length % swatches.length],
            active: (m['isActive'] ?? m['active'] ?? true) == true));
        _brandDocIds[n] = d.id;
        dbBrandKeys.add('brand:${d.id}');
      }
      // Brands that exist on products but not in the collection yet are created automatically.
      final have = brands.map((b) => b.name.toLowerCase()).toSet();
      for (final p in phones) {
        if (p.brand.isNotEmpty && have.add(p.brand.toLowerCase())) {
          brands.add(Brand(p.brand, swatches[brands.length % swatches.length]));
        }
      }

      payouts
        ..clear()
        ..addAll((r[11]?.docs ?? none).map(_payoutFrom));
      payouts.sort((a, b) => b.date.compareTo(a.date));

      await _loadSettings();

      loading = false;
      _recordSigs();
      _refreshPartnerRatings();
      for (final b in brands) {
        final key = 'brand:${_brandDocId(b.name)}';
        if (!dbBrandKeys.contains(key)) _sig.remove(key); // not in Firestore yet -> will be created
      }
      notifyListeners();
      _scheduleSync();
      unawaited(_loadAddresses());
    } catch (e) {
      loading = false;
      loadError = e.toString();
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _db.collection('appConfig').doc('store').get();
      final m = s.data();
      if (m != null) {
        deliveryCharge = _int(m['deliveryCharge'], deliveryCharge);
        freeDeliveryAbove = _int(m['freeDeliveryAbove'], freeDeliveryAbove);
        returnDays = _int(m['returnDays'], returnDays);
        refundDays = _int(m['refundDays'], refundDays);
        supportPhone = '${m['supportPhone'] ?? supportPhone}';
        supportEmail = '${m['supportEmail'] ?? supportEmail}';
        supportHours = '${m['supportHours'] ?? supportHours}';
        if (m['serviceablePincodes'] is List) {
          serviceablePincodes = (m['serviceablePincodes'] as List).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(', ');
        }
        returnsPolicy = '${m['returnsPolicy'] ?? returnsPolicy}';
        warrantyPolicy = '${m['warrantyPolicy'] ?? warrantyPolicy}';
        privacyPolicy = '${m['privacyPolicy'] ?? privacyPolicy}';
        requireVerifiedPartners = m['requireVerifiedPartners'] is bool ? m['requireVerifiedPartners'] as bool : requireVerifiedPartners;
      }
    } catch (e) {
      debugPrint('PhoneHub admin: appConfig/store failed: $e');
    }
    // Delivery partner rewards and Terms / Privacy text (shown live in the delivery app).
    try {
      final inc = (await _db.collection('appConfig').doc('partnerIncentives').get()).data();
      if (inc != null) {
        partnerDailyTarget = _int(inc['dailyTarget']);
        partnerDailyIncentives
          ..clear()
          ..addAll(_rules(inc['daily']));
        partnerWeeklyIncentives
          ..clear()
          ..addAll(_rules(inc['weekly']));
      }
      final tm = (await _db.collection('appConfig').doc('partnerTerms').get()).data();
      if (tm != null) {
        partnerTerms
          ..clear()
          ..addAll(_strings(tm['terms']));
        partnerPrivacy
          ..clear()
          ..addAll(_strings(tm['privacy']));
      }
    } catch (e) {
      debugPrint('PhoneHub admin: partner config failed: $e');
    }
    // Private admin details (name, email, phone, partner earning) live in admins/{uid}, not in public config.
    final user = FirebaseAuth.instance.currentUser;
    adminEmail = user?.email ?? adminEmail;
    final loginName = (user?.displayName ?? '').trim();
    if (loginName.isNotEmpty && adminName == 'Admin') adminName = loginName;
    if (user != null) {
      try {
        final a = await _db.collection('admins').doc(user.uid).get();
        final m = a.data();
        if (m != null) {
          adminName = '${m['adminName'] ?? m['name'] ?? adminName}';
          adminEmail = '${m['adminEmail'] ?? m['email'] ?? adminEmail}';
          adminPhone = '${m['adminPhone'] ?? m['phone'] ?? adminPhone}';
          pushAlerts = m['pushAlerts'] is bool ? m['pushAlerts'] as bool : pushAlerts;
          partnerEarning = _int(m['partnerEarning'], partnerEarning);
        }
      } catch (e) {
        debugPrint('PhoneHub admin: admins/${user.uid} failed: $e');
      }
    }
  }

  /// Customer addresses live in users/{uid}/addresses (not on the user document).
  Future<void> _loadAddresses() async {
    await Future.wait(customers.map((c) async {
      try {
        final s = await _db.collection('users').doc(c.id).collection('addresses').get();
        final list = s.docs.map((d) {
          final m = d.data();
          final pin = '${m['pincode'] ?? ''}';
          return '${m['label'] ?? ''}: ${m['line'] ?? ''}${pin.isEmpty ? '' : ' - $pin'}';
        }).toList();
        if (list.isNotEmpty) {
          c.addresses
            ..clear()
            ..addAll(list);
        }
      } catch (_) {}
    }));
    notifyListeners();
  }

  // ---------------- Live listeners (new orders / tickets / refunds / stock appear instantly) ----------------
  void _listen() {
    _orderSub?.cancel();
    _ticketSub?.cancel();
    _refundSub?.cancel();
    _productSub?.cancel();
    _partnerSub?.cancel();

    // The delivery partner app flips "online" on partners/{email}. Keep it live here
    // (only that flag is taken from the stream, so the admin's own edits are never overwritten).
    _partnerSub = _db.collection('partners').snapshots().listen((snap) {
      var any = false;
      for (final d in snap.docs) {
        _watchPartnerDocs(d.id);
        final p = partnerById(d.id) ?? partnerById(d.id.toLowerCase());
        if (p == null) continue;
        final on = d.data()['online'] == true;
        if (p.online != on) {
          p.online = on;
          any = true;
        }
        // The partner links his login on first login; keep the uid fresh for notifications.
        p.uid = '${d.data()['uid'] ?? ''}';
      }
      if (any) notifyListeners();
    }, onError: (Object e) => debugPrint('PhoneHub admin partners stream: $e'));

    _orderSub = _db.collection('orders').snapshots().listen((snap) {
      orders
        ..clear()
        ..addAll(snap.docs.map(_orderFrom));
      _refreshPartnerRatings();
      notifyListeners();
      _reconcileOrders();
    }, onError: (Object e) => debugPrint('PhoneHub admin orders stream: $e'));

    _ticketSub = _db.collection('tickets').snapshots().listen((snap) {
      tickets
        ..clear()
        ..addAll(snap.docs.map(_ticketFrom));
      tickets.sort((a, b) => b.created.compareTo(a.created));
      for (final t in tickets) {
        _sig['ticket:${t.id}'] = t.status;
      }
      notifyListeners();
    }, onError: (Object e) => debugPrint('PhoneHub admin tickets stream: $e'));

    _refundSub = _db.collection('refunds').snapshots().listen((snap) {
      refunds
        ..clear()
        ..addAll(snap.docs.map(_refundFrom));
      refunds.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }, onError: (Object e) => debugPrint('PhoneHub admin refunds stream: $e'));

    // Customer orders lower the stock in Firestore; keep the admin inventory in step.
    _productSub = _db.collection('products').snapshots().listen((snap) {
      var any = false;
      for (final d in snap.docs) {
        final p = phoneById(d.id);
        final m = d.data();
        if (p == null || !m.containsKey('stock')) continue;
        final s = _int(m['stock']);
        _stockAt[d.id] = _date(m['updatedAt']);
        if (s != p.stock && _lastStock[p.id] == p.stock) {
          p.stock = s;
          _lastStock[p.id] = s;
          any = true;
        }
      }
      if (any) notifyListeners();
    }, onError: (Object e) => debugPrint('PhoneHub admin products stream: $e'));
  }

  /// Keeps each partner's document verification state live (partners/{email}/docs/*).
  void _watchPartnerDocs(String id) {
    if (_docSubs.containsKey(id)) return;
    _docSubs[id] = _db.collection('partners/$id/docs').snapshots().listen((snap) {
      final p = partnerById(id);
      if (p == null) return;
      p.docStatus.clear();
      for (final d in snap.docs) {
        p.docStatus[d.id] = '${d.data()['status'] ?? 'Pending'}';
      }
      p.docsLoaded = true;
      notifyListeners();
    }, onError: (Object e) {
      // Not readable / not available: do not block the admin, treat as "not loaded".
      debugPrint('PhoneHub admin partner docs stream ($id): $e');
    });
  }

  /// A partner's rating is the average of the stars customers gave to the
  /// delivered orders that partner carried (orders.rating). Partners with no
  /// rated order keep whatever rating is saved on their record.
  void _refreshPartnerRatings() {
    var changed = false;
    for (final p in partners) {
      final id = p.id.toLowerCase();
      var sum = 0, n = 0;
      for (final o in orders) {
        if (o.rating > 0 && !o.cancelled && (o.partnerId ?? '').toLowerCase() == id) {
          sum += o.rating;
          n++;
        }
      }
      if (n == 0) continue;
      final avg = double.parse((sum / n).toStringAsFixed(1));
      if (avg != p.rating) {
        p.rating = avg;
        _sig.remove('partner:${p.id}'); // so the new rating is saved on partners/{email}
        changed = true;
      }
    }
    if (changed) _scheduleSync();
  }

  /// Cancelled orders: put the stock back once and make sure an online-paid order has a refund record.
  void _reconcileOrders() {
    for (final o in orders) {
      if (!o.cancelled) continue;
      if (o.stockDeducted && !o.stockRestored && _restoring.add(o.id)) {
        _restoreStock(o).whenComplete(() => _restoring.remove(o.id));
      }
      if (!o.isCod && _refundChecked.add(o.id)) {
        unawaited(_ensureRefund(o));
      }
      // A coupon used on a cancelled order becomes usable again for that customer.
      final code = (o.couponCode ?? '').trim();
      if (code.isNotEmpty && code.toLowerCase() != 'null' && !o.couponReleased && _couponChecked.add(o.id)) {
        unawaited(_releaseCoupon(o));
      }
      // The delivery partner who had this order must know it is cancelled (customer or admin cancelled).
      if ((o.partnerId ?? '').isNotEmpty && !o.partnerCancelNotified && _partnerCancelChecked.add(o.id)) {
        unawaited(_tellPartnerCancelled(o));
      }
    }
  }

  Future<void> _releaseCoupon(AdminOrder o) async {
    try {
      final code = (o.couponCode ?? '').trim().toUpperCase();
      DocumentReference<Map<String, dynamic>>? ref = _db.collection('coupons').doc(code);
      if (!(await ref.get()).exists) {
        final q = await _db.collection('coupons').where('code', isEqualTo: code).limit(1).get();
        ref = q.docs.isEmpty ? null : q.docs.first.reference;
      }
      if (ref != null && o.customerId.isNotEmpty) {
        final red = ref.collection('redemptions').doc(o.customerId);
        final snap = await red.get();
        // Only remove the record when it was created by THIS order.
        if (snap.exists && '${snap.data()?['orderId'] ?? ''}' == o.id) await red.delete();
      }
      await _db.collection('orders').doc(o.id).update({'couponReleased': true, 'updatedAt': FieldValue.serverTimestamp()});
      o.couponReleased = true;
    } catch (e) {
      _couponChecked.remove(o.id); // retried on the next orders update
      debugPrint('PhoneHub admin: coupon release failed for ${o.id}: $e');
    }
  }

  Future<void> _tellPartnerCancelled(AdminOrder o) async {
    try {
      await _notifyPartner(o.partnerId!, 'Order cancelled • ${o.id}',
          'This order was cancelled${o.cancelledBy == 'customer' ? ' by the customer' : ''}. Do not deliver it.', 'order_cancelled',
          orderId: o.id);
      await _db.collection('orders').doc(o.id).update({'partnerCancelNotified': true, 'updatedAt': FieldValue.serverTimestamp()});
      o.partnerCancelNotified = true;
    } catch (e) {
      _partnerCancelChecked.remove(o.id);
      debugPrint('PhoneHub admin: partner cancel notice failed for ${o.id}: $e');
    }
  }

  Future<void> _restoreStock(AdminOrder o) async {
    if (!o.stockDeducted) return;
    try {
      final restored = <String, int>{};
      await _db.runTransaction((tx) async {
        final oref = _db.collection('orders').doc(o.id);
        final os = await tx.get(oref);
        if (os.data()?['stockRestored'] == true) return;
        final want = <String, int>{};
        for (final it in o.items) {
          if (it.phoneId.isEmpty) continue;
          want[it.phoneId] = (want[it.phoneId] ?? 0) + it.qty;
        }
        final current = <String, int>{};
        for (final id in want.keys) {
          final snap = await tx.get(_db.collection('products').doc(id));
          if (snap.exists) current[id] = _int(snap.data()?['stock']);
        }
        for (final e in current.entries) {
          tx.update(_db.collection('products').doc(e.key), {'stock': e.value + want[e.key]!, 'updatedAt': FieldValue.serverTimestamp()});
          restored[e.key] = want[e.key]!;
        }
        tx.update(oref, {'stockRestored': true, 'updatedAt': FieldValue.serverTimestamp()});
      });
      for (final e in restored.entries) {
        final p = phoneById(e.key);
        if (p != null) {
          p.stock += e.value;
          _lastStock[p.id] = p.stock;
        }
      }
      o.stockRestored = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PhoneHub admin: stock restore failed for ${o.id}: $e');
    }
  }

  Future<void> _ensureRefund(AdminOrder o) async {
    try {
      final ref = _db.collection('refunds').doc('RF_${o.id}');
      if ((await ref.get()).exists) return;
      await ref.set({
        'refNo': _refNo(o.id),
        'orderId': o.id,
        'customerId': o.customerId,
        'amount': o.total,
        'reason': o.cancelledBy == 'admin' ? 'Cancelled by admin' : 'Cancelled by customer',
        'status': 'Requested',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PhoneHub admin: refund create failed for ${o.id}: $e');
    }
  }

  // ---------------- Change tracking: save whatever the admin screens edit ----------------
  Map<String, dynamic> _phoneMap(Phone p) => {
    'name': p.name, 'brand': p.brand, 'storage': p.storage,
    'condition': p.condition, 'price': p.price, 'mrp': p.mrp,
    'batteryHealth': p.battery, 'rating': p.rating,
    'colors': p.colors.map((c) => c.value).toList(),
    'images': p.images,
    'details': p.details.toMap(),
    'isActive': p.active,
  };

  Map<String, dynamic> _publicSettings() => {
    'deliveryCharge': deliveryCharge,
    'freeDeliveryAbove': freeDeliveryAbove,
    'returnDays': returnDays,
    'refundDays': refundDays,
    'supportPhone': supportPhone,
    'supportEmail': supportEmail,
    'supportHours': supportHours,
    'serviceablePincodes': serviceablePincodes
        .split(RegExp(r'[,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(),
    'returnsPolicy': returnsPolicy,
    'warrantyPolicy': warrantyPolicy,
    'privacyPolicy': privacyPolicy,
    'requireVerifiedPartners': requireVerifiedPartners,
  };

  Map<String, dynamic> _privateSettings() => {
    'adminName': adminName,
    'adminEmail': adminEmail,
    'adminPhone': adminPhone,
    'pushAlerts': pushAlerts,
    'partnerEarning': partnerEarning,
  };

  Map<String, _SyncJob> _jobs() {
    final jobs = <String, _SyncJob>{};

    for (final p in phones) {
      final map = _phoneMap(p);
      jobs['phone:${p.id}'] = _SyncJob(_enc(map), () async {
        final data = <String, dynamic>{...map, 'updatedAt': FieldValue.serverTimestamp()};
        if (_lastStock[p.id] != p.stock) data['stock'] = p.stock;
        await _db.collection('products').doc(p.id).set(data, SetOptions(merge: true));
        _lastStock[p.id] = p.stock;
      }, dirty: () => _lastStock[p.id] != p.stock);
    }

    for (final p in partners) {
      final id = p.id.toLowerCase();
      final map = {
        'name': p.name, 'phone': p.phone, 'vehicle': p.vehicle,
        'email': (p.email.isEmpty ? id : p.email).toLowerCase(),
        'rating': p.rating, 'isActive': p.active,
      };
      jobs['partner:${p.id}'] = _SyncJob(_enc(map), () async {
        final ref = _db.collection('partners').doc(id);
        final exists = (await ref.get()).exists;
        await ref.set({
          ...map,
          'updatedAt': FieldValue.serverTimestamp(),
          // Brand-new partner: the delivery app links its login to this record on first login.
          if (!exists) ...{'uid': '', 'online': false, 'createdAt': FieldValue.serverTimestamp()},
        }, SetOptions(merge: true));
      });
    }

    for (final b in brands) {
      final id = _brandDocId(b.name);
      final map = {'name': b.name, 'color': b.color.value, 'isActive': b.active};
      jobs['brand:$id'] = _SyncJob(_enc(map), () async {
        await _db.collection('brands').doc(id).set({...map, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        _brandDocIds[b.name] = id;
      });
    }

    for (final f in faqs) {
      f.id ??= _db.collection('faqs').doc().id;
      final id = f.id!;
      final map = {'q': f.q, 'a': f.a, 'isActive': true};
      jobs['faq:$id'] = _SyncJob(_enc(map), () async {
        await _db.collection('faqs').doc(id).set({...map, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      });
    }

    for (final s in staff) {
      s.id ??= _db.collection('staff').doc().id;
      final id = s.id!;
      final map = {'name': s.name, 'email': s.email, 'role': s.role, 'isActive': s.active};
      jobs['staff:$id'] = _SyncJob(_enc(map), () async {
        await _db.collection('staff').doc(id).set({...map, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      });
    }

    for (final c in customers) {
      jobs['cust:${c.id}'] = _SyncJob('${c.blocked}', () async {
        await _db.collection('users').doc(c.id).update({'blocked': c.blocked, 'updatedAt': FieldValue.serverTimestamp()});
      });
    }

    for (final t in tickets) {
      jobs['ticket:${t.id}'] = _SyncJob(t.status, () async {
        await _db.collection('tickets').doc(t.id).update({'status': t.status, 'updatedAt': FieldValue.serverTimestamp()});
      });
    }

    jobs['settings'] = _SyncJob(_enc([_publicSettings(), _privateSettings()]), _saveStoreSettings);
    return jobs;
  }

  void _recordSigs() {
    _sig.clear();
    _lastStock.clear();
    for (final e in _jobs().entries) {
      _sig[e.key] = e.value.sig;
    }
    for (final p in phones) {
      _lastStock[p.id] = p.stock;
    }
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), _syncDirty);
  }

  Future<void> _syncDirty() async {
    if (loading) return;
    if (_syncing) {
      _scheduleSync();
      return;
    }
    _syncing = true;
    try {
      final jobs = _jobs();
      for (final e in jobs.entries) {
        final job = e.value;
        if (_sig[e.key] == job.sig && !(job.dirty?.call() ?? false)) continue;
        try {
          await job.run();
          _sig[e.key] = job.sig;
        } catch (err) {
          debugPrint('PhoneHub admin: saving ${e.key} failed: $err');
          loadError = 'Could not save changes: $err';
          notifyListeners();
        }
      }
      // Items removed on a screen (brand / FAQ / staff) are removed from Firestore too.
      for (final key in _sig.keys.toList()) {
        if (jobs.containsKey(key)) continue;
        final col = key.startsWith('brand:') ? 'brands' : key.startsWith('faq:') ? 'faqs' : key.startsWith('staff:') ? 'staff' : null;
        if (col == null) continue;
        try {
          await _db.collection(col).doc(key.substring(key.indexOf(':') + 1)).delete();
          _sig.remove(key);
        } catch (err) {
          debugPrint('PhoneHub admin: deleting $key failed: $err');
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _saveStoreSettings() async {
    await _db.collection('appConfig').doc('store').set({
      ..._publicSettings(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final uid = _uid;
    if (uid.isNotEmpty) {
      await _db.collection('admins').doc(uid).set({
        ..._privateSettings(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Writes a notification for one customer (shows in the customer app's Notifications screen).
  Future<void> _notify(String userId, String title, String body, String type, {String orderId = ''}) async {
    if (userId.isEmpty) return;
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        if (orderId.isNotEmpty) 'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PhoneHub admin: notification failed: $e');
    }
  }

  /// Writes a notification for one delivery partner (shows in the delivery app's Notifications screen).
  /// [partnerId] is the partner's record id (his email). The notification is stored with the
  /// partner's login uid, which is the only id the delivery app is allowed to read.
  Future<void> _notifyPartner(String partnerId, String title, String body, String type, {String orderId = ''}) async {
    final id = partnerId.trim();
    if (id.isEmpty) return;
    try {
      var uid = (partnerById(id) ?? partnerById(id.toLowerCase()))?.uid ?? '';
      if (uid.isEmpty) {
        final s = await _db.collection('partners').doc(id.toLowerCase()).get();
        uid = '${s.data()?['uid'] ?? ''}';
      }
      if (uid.isEmpty) return; // the partner has not logged in yet, so there is no app to notify
      await _db.collection('notifications').add({
        'userId': uid,
        'title': title,
        'body': body,
        'type': type,
        'audience': 'partner',
        'isRead': false,
        if (orderId.isNotEmpty) 'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PhoneHub admin: partner notification failed: $e');
    }
  }

  /// For other admin screens (e.g. document verification): tell a delivery partner something.
  Future<void> notifyPartner(String partnerId, String title, String body, {String type = 'partner', String orderId = ''}) =>
      _notifyPartner(partnerId, title, body, type, orderId: orderId);


  // ---------------- Lookups ----------------
  Phone? phoneById(String id) {
    for (final p in phones) {
      if (p.id == id) return p;
    }
    return null;
  }

  Customer? customerById(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Partner? partnerById(String? id) {
    if (id == null) return null;
    for (final p in partners) {
      if (p.id == id) return p;
    }
    return null;
  }

  AdminOrder? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<AdminOrder> ordersOf(String customerId) => orders.where((o) => o.customerId == customerId).toList();

  String customerName(String id) => customerById(id)?.name ?? 'Unknown';

  /// Who sent a support ticket: the customer, or a delivery partner.
  String ticketSender(Ticket t) {
    if (t.partnerId.isEmpty) return customerName(t.customerId);
    final name = t.partnerName.isNotEmpty ? t.partnerName : (partnerById(t.partnerId)?.name ?? t.partnerId);
    return '$name (Delivery partner)';
  }

  // ---------------- Derived numbers ----------------
  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<AdminOrder> get validOrders => orders.where((o) => !o.cancelled).toList();
  int get totalRevenue => validOrders.fold<int>(0, (s, o) => s + o.total);
  int get todayRevenue => validOrders.where((o) => _sameDay(o.placedAt, DateTime.now())).fold<int>(0, (s, o) => s + o.total);
  int get todayOrders => orders.where((o) => _sameDay(o.placedAt, DateTime.now())).length;
  int get newOrders => orders.where((o) => !o.cancelled && o.stage <= 1).length;
  int get lowStockCount => phones.where((p) => p.stock <= 3).length;
  int get openTickets => tickets.where((t) => t.status != 'Resolved').length;
  int get pendingRefunds => refunds.where((r) => r.status == 'Requested' || r.status == 'Approved').length;

  /// Revenue for the last [days] days, oldest first.
  List<double> revenueByDay(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      return validOrders.where((o) => _sameDay(o.placedAt, day)).fold<int>(0, (s, o) => s + o.total).toDouble();
    });
  }

  List<String> dayLabels(int days) {
    const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(days, (i) => d[now.subtract(Duration(days: days - 1 - i)).weekday - 1]);
  }

  Map<String, int> get ordersByStatus {
    final m = <String, int>{for (final s in orderSteps) s: 0, 'Cancelled': 0};
    for (final o in orders) {
      m[o.statusLabel] = (m[o.statusLabel] ?? 0) + 1;
    }
    return m;
  }

  /// Units sold per phone name, best first.
  List<MapEntry<String, int>> get topPhones {
    final m = <String, int>{};
    for (final o in validOrders) {
      for (final it in o.items) {
        m[it.name] = (m[it.name] ?? 0) + it.qty;
      }
    }
    final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return l;
  }

  /// Revenue per brand, best first.
  List<MapEntry<String, int>> get brandRevenue {
    final m = <String, int>{};
    for (final o in validOrders) {
      for (final it in o.items) {
        final b = phoneById(it.phoneId)?.brand ?? 'Other';
        m[b] = (m[b] ?? 0) + it.price * it.qty;
      }
    }
    final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return l;
  }

  int phoneCountOfBrand(String b) => phones.where((p) => p.brand == b).length;

  /// Payments, derived from orders so they always match.
  List<Txn> get txns {
    return orders.map((o) {
      String status;
      if (o.paymentStatus == 'Refunded') {
        status = 'Refunded';
      } else if (o.cancelled) {
        status = o.isCod ? 'Failed' : 'Refunded';
      } else if (o.isCod) {
        status = o.isDelivered ? 'Success' : 'Pending';
      } else {
        status = 'Success';
      }
      return Txn('TXN${o.id.length > 2 ? o.id.substring(2) : o.id}', o.id, o.paymentMethod, o.total, status, o.placedAt);
    }).toList();
  }

  List<AlertItem> get alerts {
    final l = <AlertItem>[];
    for (final o in orders.where((o) => !o.cancelled && o.stage == 0)) {
      l.add(AlertItem(Icons.shopping_bag_rounded, AC_primary, 'New order ${o.id}', '${customerName(o.customerId)} ordered ${o.itemCount} item(s) worth ₹${o.total}', o.placedAt));
    }
    for (final p in phones.where((p) => p.stock <= 3)) {
      l.add(AlertItem(Icons.inventory_2_rounded, p.stock == 0 ? AC_danger : AC_warning, p.stock == 0 ? '${p.name} is out of stock' : 'Low stock: ${p.name}', 'Only ${p.stock} left in inventory', _stockAt[p.id] ?? DateTime.now()));
    }
    for (final r in refunds.where((r) => r.status == 'Requested')) {
      l.add(AlertItem(Icons.currency_rupee_rounded, AC_warning, 'Refund requested', '${r.orderId} • ₹${r.amount} • ${r.reason}', r.date));
    }
    for (final t in tickets.where((t) => t.status == 'Open')) {
      l.add(AlertItem(Icons.headset_mic_rounded, AC_info, 'New support ticket', '${ticketSender(t)}: ${t.subject}', t.created));
    }
    // Orders a delivery partner gave back: the admin must assign another partner.
    for (final o in orders.where((o) => o.needsReassign)) {
      final who = partnerById(o.rejectedBy)?.name ?? o.rejectedBy;
      l.add(AlertItem(Icons.undo_rounded, AC_danger, 'Order ${o.id} needs a new partner', '$who gave it back${o.rejectReason.isEmpty ? '' : ': ${o.rejectReason}'}', o.rejectedAt ?? o.placedAt));
    }
    // Delivery could not be completed (customer not reachable, wrong address ...).
    for (final o in orders.where((o) => o.hasFailedAttempt)) {
      l.add(AlertItem(Icons.report_problem_rounded, AC_warning, 'Delivery attempt failed • ${o.id}', '${o.deliveryAttempts} attempt(s)${o.failedReason.isEmpty ? '' : ' • ${o.failedReason}'}', o.lastAttemptAt ?? o.placedAt));
    }
    // Approved returns: send a partner to collect the phone, then mark it received.
    for (final o in orders.where((o) => o.needsReturnPickup)) {
      l.add(AlertItem(Icons.assignment_return_rounded, AC_warning, 'Return approved • ${o.id}', 'Assign a delivery partner to collect the phone from ${customerName(o.customerId)}', o.deliveredAt ?? o.placedAt));
    }
    for (final o in orders.where((o) => o.returnPickupStatus == 'Picked Up')) {
      l.add(AlertItem(Icons.inventory_rounded, AC_info, 'Returned phone picked up • ${o.id}', '${o.returnPartnerName.isEmpty ? 'The partner' : o.returnPartnerName} has the phone. Mark it received when it reaches the store.', o.returnPickedAt ?? DateTime.now()));
    }
    // Partners who uploaded documents that wait for the admin's check.
    for (final p in partners.where((p) => p.docStatus.values.contains('Pending'))) {
      l.add(AlertItem(Icons.verified_user_rounded, AC_info, '${p.name}: documents to verify', 'Open Delivery Partners to verify or reject the uploaded documents', DateTime.now()));
    }
    // COD cash the partners still have to hand over.
    final cashOrders = orders.where((o) => o.cashPending).toList();
    if (cashOrders.isNotEmpty) {
      final total = cashOrders.fold<int>(0, (s, o) => s + o.cashDue);
      final latest = cashOrders.map((o) => o.deliveredAt ?? o.placedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      l.add(AlertItem(Icons.payments_rounded, AC_warning, 'COD cash to collect', '₹$total from ${cashOrders.length} delivered order(s) is with delivery partners', latest));
    }
    l.sort((a, b) => b.time.compareTo(a.time));
    return l;
  }

  // ---------------- Actions ----------------
  /// Screens call this after editing a phone / partner / brand / FAQ / staff / customer / setting.
  /// The change is shown immediately and saved to Firestore a moment later.
  void changed() {
    notifyListeners();
    _scheduleSync();
  }

  void _fail(Object e) {
    loadError = e.toString();
    notifyListeners();
  }

  void setStage(AdminOrder o, int stage) {
    final old = o.stage;
    final next = stage.clamp(0, 4);
    o.stage = next;
    notifyListeners();
    unawaited(() async {
      try {
        final data = <String, dynamic>{'status': orderSteps[next], 'updatedAt': FieldValue.serverTimestamp()};
        if (next >= 1 && !o.isCod) data['paymentStatus'] = 'Paid';
        if (next == 4) {
          data['deliveryStatus'] = 'Delivered';
          data['deliveredAt'] = FieldValue.serverTimestamp();
          if (o.isCod) data['paymentStatus'] = 'Paid';
        }
        await _db.collection('orders').doc(o.id).update(data);
        // Stages 3 and 4 are already announced by the delivery partner when one is assigned.
        if (next != old && next > 0 && !(next >= 3 && o.partnerId != null)) {
          const titles = ['', 'Payment confirmed', 'Your order is packed', 'Your order is out for delivery', 'Order delivered'];
          const types = ['', 'payment', 'order', 'delivery', 'delivery'];
          await _notify(o.customerId, '${titles[next]} • ${o.id}', 'Order ${o.id} is now: ${orderSteps[next]}.', types[next]);
        }
      } catch (e) {
        o.stage = old;
        _fail(e);
      }
    }());
  }

  /// Active partners who may take this order (the ones who already gave it back are left out).
  /// Partners who are online right now are listed first.
  List<Partner> assignablePartners(AdminOrder o) {
    final list = partners.where((p) => p.active && !o.rejectedByPartner(p.id) && partnerCanTakeOrders(p)).toList();
    list.sort((a, b) {
      if (a.online != b.online) return a.online ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// A partner can be given an order only when the admin has verified his documents
  /// (switch: Settings -> requireVerifiedPartners). While the documents are still loading nobody is blocked.
  bool partnerCanTakeOrders(Partner p) => !requireVerifiedPartners || !p.docsLoaded || p.docsVerified;

  /// Active partners left out of the list only because their documents are not verified yet.
  List<Partner> unverifiedPartners(AdminOrder o) =>
      partners.where((p) => p.active && !o.rejectedByPartner(p.id) && !partnerCanTakeOrders(p)).toList();

  /// Orders a partner is carrying right now (assigned, not delivered, not cancelled).
  int partnerActiveOrders(String partnerId) {
    final id = partnerId.toLowerCase();
    return orders.where((o) => !o.cancelled && !o.isDelivered && (o.partnerId ?? '').toLowerCase() == id).length;
  }

  void assignPartner(AdminOrder o, String partnerId) {
    final chosen = partnerById(partnerId);
    if (chosen != null && !partnerCanTakeOrders(chosen)) {
      _fail('${chosen.name}: documents are not verified yet (${chosen.docsNotVerified.join(', ')}).');
      return;
    }
    final previous = o.partnerId;
    final previousRejectedBy = o.rejectedBy;
    final previousHistory = o.rejectedHistory;
    // Keep a record of who gave the order back, then clear the "needs a new partner" state.
    if (o.rejectedBy.isNotEmpty && !o.rejectedHistory.contains(o.rejectedBy)) {
      o.rejectedHistory = [...o.rejectedHistory, o.rejectedBy];
    }
    o.partnerId = partnerId;
    o.rejectedBy = '';
    notifyListeners();
    final p = partnerById(partnerId);
    unawaited(() async {
      try {
        await _db.collection('orders').doc(o.id).update({
          'partnerId': partnerId,
          'partnerName': p?.name ?? '',
          'partnerPhone': p?.phone ?? '',
          'earning': partnerEarning,
          'deliveryStatus': 'Assigned',
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (previousRejectedBy.isNotEmpty) ...{
            'rejectedHistory': FieldValue.arrayUnion([previousRejectedBy]),
            'rejectedBy': '',
          },
        });
        await _notify(o.customerId, 'Delivery partner assigned • ${o.id}',
            '${(p?.name ?? '').isEmpty ? 'A delivery partner' : p!.name} will deliver your order.', 'delivery');
        // The delivery app gets its own notification: new order, and "taken back" for the one before.
        await _notifyPartner(partnerId, 'New order assigned • ${o.id}',
            '${o.itemCount} item(s) • deliver to ${o.address.isEmpty ? 'the customer address' : o.address}. Your earning: ₹$partnerEarning.', 'order_assigned',
            orderId: o.id);
        if ((previous ?? '').isNotEmpty && previous!.toLowerCase() != partnerId.toLowerCase()) {
          await _notifyPartner(previous, 'Order taken back • ${o.id}', 'The admin gave this order to another partner.', 'order_cancelled', orderId: o.id);
        }
      } catch (e) {
        o.partnerId = previous;
        o.rejectedBy = previousRejectedBy;
        o.rejectedHistory = previousHistory;
        _fail(e);
      }
    }());
  }

  // ---------------- Return pickup (phone goes back from the customer to the store) ----------------
  /// Delivered orders whose return the admin approved and that still need a partner to collect the phone.
  List<AdminOrder> get returnsNeedingPickup => orders.where((o) => o.needsReturnPickup).toList();

  /// Returns that are on their way back (partner assigned / phone picked up, not received yet).
  List<AdminOrder> get returnsOnTheWay => orders.where((o) => o.returnPickupActive).toList();

  /// Sends a delivery partner to collect the phone of an approved return.
  void assignReturnPickup(AdminOrder o, String partnerId) {
    final p = partnerById(partnerId);
    final before = [o.returnPickupStatus, o.returnPartnerId, o.returnPartnerName, o.returnPartnerPhone];
    o.returnPickupStatus = 'Pickup Assigned';
    o.returnPartnerId = partnerId.toLowerCase();
    o.returnPartnerName = p?.name ?? '';
    o.returnPartnerPhone = p?.phone ?? '';
    notifyListeners();
    unawaited(() async {
      try {
        await _db.collection('orders').doc(o.id).update({
          'returnPickupStatus': 'Pickup Assigned',
          'returnPartnerId': o.returnPartnerId,
          'returnPartnerName': o.returnPartnerName,
          'returnPartnerPhone': o.returnPartnerPhone,
          'returnPickupAssignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _notifyPartner(partnerId, 'Return pickup • ${o.id}',
            'Collect the phone from the customer${o.address.isEmpty ? '' : ': ${o.address}'}.', 'return_pickup', orderId: o.id);
        await _notify(o.customerId, 'Return pickup arranged • ${o.id}',
            '${o.returnPartnerName.isEmpty ? 'A delivery partner' : o.returnPartnerName} will collect your phone.', 'return', orderId: o.id);
      } catch (e) {
        o.returnPickupStatus = before[0];
        o.returnPartnerId = before[1];
        o.returnPartnerName = before[2];
        o.returnPartnerPhone = before[3];
        _fail(e);
      }
    }());
  }

  /// The returned phone reached the store (after the partner picked it up): the refund can now be paid.
  void markReturnReceived(AdminOrder o) {
    final before = o.returnPickupStatus;
    final beforeAt = o.returnReceivedAt;
    o.returnPickupStatus = 'Received';
    o.returnReceivedAt = DateTime.now();
    notifyListeners();
    unawaited(() async {
      try {
        await _db.collection('orders').doc(o.id).update({
          'returnPickupStatus': 'Received',
          'returnReceivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _notify(o.customerId, 'Return received • ${o.id}', 'We received your phone. Your refund will be processed now.', 'return', orderId: o.id);
      } catch (e) {
        o.returnPickupStatus = before;
        o.returnReceivedAt = beforeAt;
        _fail(e);
      }
    }());
  }

  // ---------------- Delivery partner earnings & payouts ----------------
  /// What one delivered order pays the partner (the amount saved on the order when it was assigned).
  int earningOf(AdminOrder o) => o.earning > 0 ? o.earning : partnerEarning;

  /// Delivered orders of a partner whose earning has not been paid out yet.
  List<AdminOrder> unpaidEarningOrders(String partnerId) {
    final id = partnerId.toLowerCase();
    return orders.where((o) => o.isDelivered && !o.earningPaid && (o.partnerId ?? '').toLowerCase() == id).toList()
      ..sort((a, b) => (a.deliveredAt ?? a.placedAt).compareTo(b.deliveredAt ?? b.placedAt));
  }

  int partnerUnpaidEarning(String partnerId) => unpaidEarningOrders(partnerId).fold<int>(0, (s, o) => s + earningOf(o));

  List<PartnerPayout> payoutsOf(String partnerId) {
    final id = partnerId.toLowerCase();
    return payouts.where((x) => x.partnerId.toLowerCase() == id).toList();
  }

  int partnerPaidTotal(String partnerId) => payoutsOf(partnerId).fold<int>(0, (s, x) => s + x.amount);

  /// Pays the partner everything he has earned so far: saves one payout record and marks his delivered orders as paid.
  /// Returns true when saved.
  Future<bool> payPartner(String partnerId, {String note = ''}) async {
    final list = unpaidEarningOrders(partnerId);
    final amount = list.fold<int>(0, (s, o) => s + earningOf(o));
    if (list.isEmpty || amount <= 0) return false;
    final id = partnerId.toLowerCase();
    final name = partnerById(partnerId)?.name ?? '';
    try {
      final ref = _db.collection('partnerPayouts').doc();
      var batch = _db.batch();
      batch.set(ref, {
        'partnerId': id,
        'partnerName': name,
        'amount': amount,
        'orderCount': list.length,
        'orderIds': list.map((o) => o.id).toList(),
        'note': note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      var n = 1;
      // A batch can hold 500 writes; pay in groups so a big pile never fails.
      for (final o in list) {
        batch.update(_db.collection('orders').doc(o.id), {
          'earning': earningOf(o),
          'earningPaid': true,
          'payoutId': ref.id,
          'earningPaidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (++n >= 400) {
          await batch.commit();
          batch = _db.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
      for (final o in list) {
        o.earning = earningOf(o);
        o.earningPaid = true;
        o.payoutId = ref.id;
      }
      payouts.insert(0, PartnerPayout(ref.id, id, name, amount, list.length, note.trim(), DateTime.now()));
      notifyListeners();
      await _notifyPartner(partnerId, 'Payout sent', '₹$amount for ${list.length} delivered order(s) has been paid to you.', 'payout');
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  // ---------------- Delivery partner rewards & Terms / Privacy (appConfig) ----------------
  Map<String, dynamic> _ruleMap(IncentiveRule r) => {'target': r.target, 'title': r.title, 'reward': r.reward};

  /// Saves the Incentives and the Terms / Privacy text so the delivery app shows them live.
  /// Returns an error message, or null when saved.
  Future<String?> savePartnerConfig() async {
    try {
      await _db.collection('appConfig').doc('partnerIncentives').set({
        'dailyTarget': partnerDailyTarget,
        'daily': partnerDailyIncentives.where((r) => r.title.trim().isNotEmpty).map(_ruleMap).toList(),
        'weekly': partnerWeeklyIncentives.where((r) => r.title.trim().isNotEmpty).map(_ruleMap).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _db.collection('appConfig').doc('partnerTerms').set({
        'terms': partnerTerms.where((t) => t.trim().isNotEmpty).toList(),
        'privacy': partnerPrivacy.where((t) => t.trim().isNotEmpty).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not save: $e';
    }
  }

  // ---------------- COD cash held by delivery partners ----------------
  /// Delivered COD orders whose cash is still with the partner (all partners, or one partner).
  List<AdminOrder> cashPendingOrders([String? partnerId]) {
    final id = partnerId?.toLowerCase();
    return orders.where((o) => o.cashPending && (id == null || (o.partnerId ?? '').toLowerCase() == id)).toList()
      ..sort((a, b) => (a.deliveredAt ?? a.placedAt).compareTo(b.deliveredAt ?? b.placedAt));
  }

  int partnerCashPending(String partnerId) => cashPendingOrders(partnerId).fold<int>(0, (s, o) => s + o.cashDue);

  int get totalCashPending => cashPendingOrders().fold<int>(0, (s, o) => s + o.cashDue);

  /// Cash already received from partners.
  int get totalCashSettled => orders.where((o) => o.isCod && o.cashSettled && !o.cancelled).fold<int>(0, (s, o) => s + o.cashDue);

  /// The admin received the cash of these orders from the partner. Returns true when saved.
  Future<bool> settleCash(List<AdminOrder> list) async {
    final todo = list.where((o) => o.cashPending).toList();
    if (todo.isEmpty) return true;
    final now = DateTime.now();
    for (final o in todo) {
      o.cashSettled = true;
      o.cashSettledAt = now;
    }
    notifyListeners();
    try {
      // A batch can hold 500 writes; settle in groups so a big pile never fails.
      for (var i = 0; i < todo.length; i += 400) {
        final batch = _db.batch();
        for (final o in todo.skip(i).take(400)) {
          batch.update(_db.collection('orders').doc(o.id), {
            'cashSettled': true,
            'cashSettledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      for (final o in todo) {
        o.cashSettled = false;
        o.cashSettledAt = null;
      }
      _fail(e);
      return false;
    }
  }

  Future<bool> settleCashOf(String partnerId) => settleCash(cashPendingOrders(partnerId));

  /// Cancels an order, puts the stock back and opens a refund for online payments.
  void cancelOrder(AdminOrder o, String reason) {
    if (o.cancelled) return;
    o.cancelled = true;
    o.cancelledBy = 'admin';
    if (!o.isCod) {
      refunds.insert(0, Refund(_refNo(o.id), o.id, o.total, reason, 'Requested', DateTime.now()));
      _refundChecked.add(o.id);
    }
    notifyListeners();
    unawaited(() async {
      try {
        await _db.collection('orders').doc(o.id).update({
          'status': 'Cancelled',
          'cancelledBy': 'admin',
          'cancelReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!o.isCod) {
          final ref = _db.collection('refunds').doc('RF_${o.id}');
          if (!(await ref.get()).exists) {
            await ref.set({
              'refNo': _refNo(o.id),
              'orderId': o.id,
              'customerId': o.customerId,
              'amount': o.total,
              'reason': reason,
              'status': 'Requested',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
        if (_restoring.add(o.id)) {
          await _restoreStock(o);
          _restoring.remove(o.id);
        }
        await _notify(o.customerId, 'Order cancelled • ${o.id}', reason.isEmpty ? 'Your order was cancelled by PhoneHub.' : reason, 'order_cancelled');
      } catch (e) {
        _fail(e);
      }
    }());
  }

  void setRefund(Refund r, String status) {
    r.status = status;
    final o = orderById(r.orderId);
    final isReturn = r.type == 'return';
    if (o != null) {
      if (status == 'Refunded') o.paymentStatus = 'Refunded';
      if (isReturn) o.returnStatus = status;
    }
    notifyListeners();
    unawaited(() async {
      try {
        await _db.collection('refunds').doc('RF_${r.orderId}').update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
        if (o != null) {
          // Keep the order itself in step so the customer / payments screens show the real state.
          final orderUpdate = <String, dynamic>{
            if (status == 'Refunded') 'paymentStatus': 'Refunded',
            if (isReturn) 'returnStatus': status,
          };
          if (orderUpdate.isNotEmpty) {
            orderUpdate['updatedAt'] = FieldValue.serverTimestamp();
            await _db.collection('orders').doc(o.id).update(orderUpdate);
          }
          await _notify(o.customerId, 'Refund $status • ${o.id}', 'Your refund of ₹${r.amount} is now: $status.', 'refund');
        }
      } catch (e) {
        _fail(e);
      }
    }());
  }

  void addPhone(Phone p) {
    phones.insert(0, p);
    notifyListeners();
    unawaited(_createProduct(p));
  }

  Future<void> _createProduct(Phone p) async {
    final map = _phoneMap(p);
    _sig['phone:${p.id}'] = _enc(map);
    _lastStock[p.id] = p.stock;
    try {
      await _db.collection('products').doc(p.id).set({
        ...map,
        'stock': p.stock,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _sig.remove('phone:${p.id}'); // will be retried by the next sync
      _lastStock.remove(p.id);
      _fail(e);
    }
  }

  void deletePhone(Phone p) {
    phones.remove(p);
    _sig.remove('phone:${p.id}');
    _lastStock.remove(p.id);
    notifyListeners();
    _db.collection('products').doc(p.id).delete().catchError((e) {
      _fail(e);
    });
  }

  void setStock(Phone p, int stock) {
    p.stock = stock < 0 ? 0 : stock;
    _lastStock[p.id] = p.stock;
    notifyListeners();
    unawaited(() async {
      try {
        await _db.collection('products').doc(p.id).update({'stock': p.stock, 'updatedAt': FieldValue.serverTimestamp()});
      } catch (e) {
        _lastStock.remove(p.id); // retried by the next sync
        _fail(e);
      }
    }());
  }

  void addTicketReply(Ticket t, String text) {
    t.messages.add(ChatMsg(true, text, DateTime.now()));
    if (t.status == 'Open') t.status = 'In Progress';
    _sig['ticket:${t.id}'] = t.status;
    notifyListeners();
    unawaited(() async {
      try {
        await _db.collection('tickets').doc(t.id).update({
          'messages': FieldValue.arrayUnion([
            {'fromAdmin': true, 'text': text, 'time': Timestamp.now()},
          ]),
          'status': t.status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (t.partnerId.isNotEmpty) {
          await _notifyPartner(t.partnerId, 'Support replied', text, 'support');
        } else {
          await _notify(t.customerId, 'Support replied', text, 'support');
        }
      } catch (e) {
        _fail(e);
      }
    }());
  }

  /// Sends the notification to every customer in the chosen audience and keeps a history entry.
  void sendNotification(String title, String body, String audience) {
    sentNotifs.insert(0, SentNotif(title, body, audience, DateTime.now()));
    notifyListeners();
    unawaited(_broadcast(title, body, audience));
  }

  List<String> _audienceIds(String audience) {
    // Delivery partners: the ids are their login uids (only partners who have logged in).
    if (audience == 'Delivery partners') {
      return partners.where((p) => p.active && p.uid.isNotEmpty).map((p) => p.uid).toList();
    }
    Iterable<Customer> list;
    switch (audience) {
      case 'Customers with orders':
        list = customers.where((c) => ordersOf(c.id).isNotEmpty);
        break;
      case 'New customers (no orders)':
        list = customers.where((c) => ordersOf(c.id).isEmpty);
        break;
      case 'Customers with wishlist items':
        list = customers.where((c) => c.wishlist.isNotEmpty);
        break;
      default:
        list = customers.where((c) => !c.blocked);
    }
    return list.map((c) => c.id).toList();
  }

  Future<void> _broadcast(String title, String body, String audience) async {
    try {
      final ids = _audienceIds(audience);
      await _db.collection('broadcasts').add({
        'title': title,
        'body': body,
        'audience': audience,
        'recipients': ids.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (var i = 0; i < ids.length; i += 400) {
        final batch = _db.batch();
        for (final id in ids.skip(i).take(400)) {
          batch.set(_db.collection('notifications').doc(), {
            'userId': id,
            'title': title,
            'body': body,
            'type': audience == 'Delivery partners' ? 'partner' : 'offer',
            if (audience == 'Delivery partners') 'audience': 'partner',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      _fail(e);
    }
  }

  String nextPhoneId() => 'phone_${DateTime.now().microsecondsSinceEpoch}';

  // Lifecycle for screens that start/stop the shared store (AdminShell).
  void start() {
    if (!loading) {
      loadFromFirebase();
    }
    _listen();
  }

  void stop() {
    _orderSub?.cancel();
    _ticketSub?.cancel();
    _refundSub?.cancel();
    _productSub?.cancel();
    _partnerSub?.cancel();
    _orderSub = _ticketSub = _refundSub = _productSub = _partnerSub = null;
    for (final sub in _docSubs.values) {
      sub.cancel();
    }
    _docSubs.clear();
    _syncTimer?.cancel();
  }

  Future<String?> updateAdminProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      if (name != null) adminName = name;
      if (email != null) adminEmail = email;
      if (phone != null) adminPhone = phone;
      await _saveStoreSettings();
      _sig['settings'] = _enc([_publicSettings(), _privateSettings()]);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not update profile: $e';
    }
  }

  /// Changes the real Firebase Auth password (the old code compared against a
  /// hard-coded password and stored the new one as plain text in Firestore).
  Future<String?> changeAdminPassword(
      String currentPassword,
      String newPassword,
      ) async {
    if (newPassword.length < 6) {
      return 'New password needs at least 6 characters.';
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return 'Please sign in again to change your password.';
    }
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') return 'Current password is incorrect.';
      if (e.code == 'weak-password') return 'New password needs at least 6 characters.';
      return 'Could not change password: ${e.message ?? e.code}';
    } catch (e) {
      return 'Could not change password: $e';
    }
  }
}

/// One pending save for the change tracker.
class _SyncJob {
  final String sig;
  final Future<void> Function() run;
  final bool Function()? dirty;
  _SyncJob(this.sig, this.run, {this.dirty});
}

// Colours used inside the store (kept here so admin_data.dart does not need the theme import).
const AC_primary = Color(0xFF1B2A5C);
const AC_danger = Color(0xFFEF4444);
const AC_warning = Color(0xFFF59E0B);
const AC_info = Color(0xFF2563EB);

/// One shared store for the whole admin app.
final AdminStore store = AdminStore();