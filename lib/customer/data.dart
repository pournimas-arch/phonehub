import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Customer data models and Firebase-backed state for PhoneHub.
/// UI-facing names and synchronous cart helpers are retained to minimize screen changes.

class Phone {
  final String id, name, brand, storage, condition;
  final int price, mrp, battery;
  final double rating;
  final List<Color> colors;

  const Phone({
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
  });

  int get off => mrp <= 0 ? 0 : (((mrp - price) / mrp) * 100).round();

  factory Phone.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final rawColors = d['colors'];
    final parsedColors = rawColors is List
        ? rawColors.map((v) => _colorFrom(v)).whereType<Color>().toList()
        : <Color>[];
    final storageValue = d['storage'];
    final storageText = storageValue is List
        ? storageValue.map((e) => e.toString()).join(', ')
        : (storageValue?.toString() ?? '');
    return Phone(
      id: doc.id,
      name: (d['name'] ?? d['title'] ?? '').toString(),
      brand: (d['brand'] ?? '').toString(),
      storage: storageText,
      condition: (d['condition'] ?? 'Good').toString(),
      price: _asInt(d['price'] ?? d['sellingPrice']),
      mrp: _asInt(d['mrp'] ?? d['originalPrice'] ?? d['price']),
      battery: _asInt(d['batteryHealth'] ?? d['battery']),
      rating: _asDouble(d['rating']),
      colors: parsedColors.isEmpty
          ? const [Color(0xFF1E3A8A), Color(0xFF3B82F6)]
          : parsedColors,
    );
  }
}

Color? _colorFrom(dynamic value) {
  if (value is int) return Color(value);
  if (value is num) return Color(value.toInt());
  if (value is String) {
    var s = value.trim().replaceFirst('#', '').replaceFirst('0x', '');
    if (s.length == 6) s = 'FF$s';
    final parsed = int.tryParse(s, radix: 16);
    if (parsed != null) return Color(parsed);
  }
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

const brands = ['Apple', 'Samsung', 'OnePlus', 'Xiaomi', 'Realme'];
const brandColors = {
  'Apple': Color(0xFF1B1B2F),
  'Samsung': Color(0xFF1D4ED8),
  'OnePlus': Color(0xFFDC2626),
  'Xiaomi': Color(0xFFEA580C),
  'Realme': Color(0xFFCA8A04),
};

/// Loaded from Firestore by initializeCustomerData(). No sample/demo products.
final List<Phone> phones = <Phone>[];

class CartItem {
  final Phone phone;
  final String storage;
  final String condition;
  int qty;
  CartItem(this.phone, this.storage, this.condition, {this.qty = 1});
}

final ValueNotifier<List<CartItem>> cart = ValueNotifier<List<CartItem>>([]);
final ValueNotifier<Set<String>> wishlist = ValueNotifier<Set<String>>({});

void addToCart(Phone p, String storage, String condition) {
  final list = List<CartItem>.from(cart.value);
  final i = list.indexWhere((e) => e.phone.id == p.id && e.storage == storage && e.condition == condition);
  if (i >= 0) {
    list[i].qty = (list[i].qty + 1).clamp(1, 5);
  } else {
    list.add(CartItem(p, storage, condition));
  }
  cart.value = list;
}

void changeQty(CartItem item, int delta) {
  item.qty = (item.qty + delta).clamp(1, 5);
  cart.value = List<CartItem>.from(cart.value);
}

void removeItem(CartItem item) {
  cart.value = cart.value.where((e) => e != item).toList();
}

void toggleWish(String id) {
  final s = Set<String>.from(wishlist.value);
  if (!s.add(id)) s.remove(id);
  wishlist.value = s;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    unawaited(FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'wishlist': s.toList(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    ).catchError((Object _) {}));
  }
}

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

class UserProfile {
  final String name, phone, email;
  const UserProfile({required this.name, required this.phone, required this.email});
  String get firstName => name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
  String get initial => name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();

  factory UserProfile.fromMap(Map<String, dynamic> d, {String fallbackEmail = ''}) => UserProfile(
    name: (d['name'] ?? d['displayName'] ?? '').toString(),
    phone: (d['phone'] ?? '').toString(),
    email: (d['email'] ?? fallbackEmail).toString(),
  );

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'email': email};
}

/// Kept as a compatibility type for any older screen imports. Authentication
/// must be handled by FirebaseAuth; this map intentionally contains no accounts.
class Account {
  final String password;
  final UserProfile profile;
  const Account(this.password, this.profile);
}

@Deprecated('Use FirebaseAuth and Firestore users/{uid}; no in-memory accounts are used.')
final Map<String, Account> accounts = <String, Account>{};

final ValueNotifier<UserProfile> profile = ValueNotifier<UserProfile>(
  const UserProfile(name: '', phone: '', email: ''),
);

Future<void> updateProfile(UserProfile p) async {
  profile.value = p;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Please sign in before updating your profile.');
  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    ...p.toMap(),
    'uid': user.uid,
    'role': 'customer',
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class Coupon {
  final String code, title, note;
  final int flat, percent, maxOff, minOrder;
  final bool freeDelivery, firstOrderOnly;
  const Coupon({
    required this.code,
    required this.title,
    required this.note,
    this.flat = 0,
    this.percent = 0,
    this.maxOff = 0,
    this.minOrder = 0,
    this.freeDelivery = false,
    this.firstOrderOnly = false,
  });

  factory Coupon.fromFirestore(Map<String, dynamic> d) => Coupon(
    code: (d['code'] ?? '').toString().toUpperCase(),
    title: (d['title'] ?? d['name'] ?? '').toString(),
    note: (d['note'] ?? d['description'] ?? '').toString(),
    flat: _asInt(d['flat'] ?? d['flatDiscount']),
    percent: _asInt(d['percent'] ?? d['discountPercent']),
    maxOff: _asInt(d['maxOff'] ?? d['maxDiscount']),
    minOrder: _asInt(d['minOrder'] ?? d['minimumOrder']),
    freeDelivery: d['freeDelivery'] == true,
    firstOrderOnly: d['firstOrderOnly'] == true,
  );
}

/// Active coupons are loaded from Firestore. No built-in test coupons.
final List<Coupon> coupons = <Coupon>[];

Coupon? findCoupon(String code) {
  final c = code.trim().toUpperCase();
  for (final x in coupons) {
    if (x.code == c) return x;
  }
  return null;
}

String? couponError(Coupon c, int subtotal, int delivery) {
  if (subtotal < c.minOrder) return '${c.code} needs a minimum order of ${rupee(c.minOrder)}';
  if (c.firstOrderOnly && orders.value.any((o) => !o.isDemo)) return '${c.code} is valid on your first order only';
  if (c.freeDelivery && delivery == 0) return 'Delivery is already free on this order';
  return null;
}

int couponDiscount(Coupon c, int subtotal, int delivery) {
  var d = c.flat;
  if (c.percent > 0) {
    d += subtotal * c.percent ~/ 100;
    if (c.maxOff > 0 && d > c.maxOff) d = c.maxOff;
  }
  if (c.freeDelivery) d += delivery;
  final cap = subtotal + delivery;
  return d > cap ? cap : d;
}

const List<String> orderSteps = ['Order Placed', 'Payment Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];

class Order {
  final String id, paymentMethod, addressLabel, addressLine;
  final List<CartItem> items;
  final int subtotal, delivery, discount, total;
  final String? couponCode;
  final DateTime placedAt;
  final bool isDemo;
  final int? fixedStage;
  bool cancelled;
  String firestoreStatus;

  Order({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.delivery,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.addressLabel,
    required this.addressLine,
    required this.placedAt,
    this.couponCode,
    this.isDemo = false,
    this.fixedStage,
    this.cancelled = false,
    this.firestoreStatus = '',
  });

  int get stage {
    if (fixedStage != null) return fixedStage!;
    final s = firestoreStatus.toLowerCase().replaceAll('_', ' ');
    if (s.contains('deliver')) return 4;
    if (s.contains('out for') || s.contains('transit') || s.contains('shipped')) return 3;
    if (s.contains('pack') || s.contains('process') || s.contains('confirm')) return 2;
    if (s.contains('paid')) return 1;
    return 0;
  }

  bool get isDelivered => !cancelled && stage >= 4;
  bool get isOngoing => !cancelled && stage < 4;
  String get statusLabel => cancelled ? 'Cancelled' : (firestoreStatus.isNotEmpty ? _prettyStatus(firestoreStatus) : orderSteps[stage]);
  int get itemCount => items.fold<int>(0, (s, e) => s + e.qty);
  String get title => items.isEmpty ? 'Order' : (items.length == 1 ? items.first.phone.name : '${items.first.phone.name} +${items.length - 1} more');

  DateTime stepTime(int k) => placedAt;
  String get etaText => isDelivered ? 'Delivered' : 'Delivery status updated by PhoneHub';

  Map<String, dynamic> toFirestoreMap(String uid) => {
    'customerId': uid,
    'userId': uid,
    'items': items.map((e) => {
      'productId': e.phone.id,
      'name': e.phone.name,
      'brand': e.phone.brand,
      'storage': e.storage,
      'condition': e.condition,
      'price': e.phone.price,
      'quantity': e.qty,
    }).toList(),
    'subtotal': subtotal,
    'deliveryCharge': delivery,
    'discount': discount,
    'total': total,
    'couponCode': couponCode,
    'paymentMethod': paymentMethod,
    'addressLabel': addressLabel,
    'addressLine': addressLine,
    'status': 'Order Placed',
    'paymentStatus': 'Pending',
    'createdAt': FieldValue.serverTimestamp(),
    'placedAt': Timestamp.fromDate(placedAt),
  };

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final rawItems = d['items'];
    final parsedItems = <CartItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final productId = (m['productId'] ?? m['id'] ?? '').toString();
        Phone? p;
        for (final candidate in phones) {
          if (candidate.id == productId) { p = candidate; break; }
        }
        p ??= Phone(
          id: productId,
          name: (m['name'] ?? m['title'] ?? 'Phone').toString(),
          brand: (m['brand'] ?? '').toString(),
          storage: (m['storage'] ?? '').toString(),
          condition: (m['condition'] ?? 'Good').toString(),
          price: _asInt(m['price']),
          mrp: _asInt(m['mrp'] ?? m['price']),
          battery: _asInt(m['battery']),
          rating: 0,
          colors: const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        );
        parsedItems.add(CartItem(p, (m['storage'] ?? p.storage).toString(), (m['condition'] ?? p.condition).toString(), qty: _asInt(m['quantity'] ?? m['qty']).clamp(1, 99)));
      }
    }
    final rawDate = d['placedAt'] ?? d['createdAt'];
    final placed = rawDate is Timestamp ? rawDate.toDate() : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    final status = (d['status'] ?? d['orderStatus'] ?? 'Order Placed').toString();
    return Order(
      id: doc.id,
      items: parsedItems,
      subtotal: _asInt(d['subtotal']),
      delivery: _asInt(d['deliveryCharge'] ?? d['delivery']),
      discount: _asInt(d['discount']),
      total: _asInt(d['total'] ?? d['grandTotal']),
      paymentMethod: (d['paymentMethod'] ?? '').toString(),
      addressLabel: (d['addressLabel'] ?? 'Delivery').toString(),
      addressLine: (d['addressLine'] ?? d['deliveryAddress'] ?? '').toString(),
      placedAt: placed,
      couponCode: d['couponCode']?.toString(),
      cancelled: status.toLowerCase() == 'cancelled',
      firestoreStatus: status,
    );
  }
}

String _prettyStatus(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Order Placed';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

final ValueNotifier<List<Order>> orders = ValueNotifier<List<Order>>([]);

/// Call after Firebase.initializeApp() and after customer authentication.
/// Expected Firestore collections: products, coupons, users/{uid}, orders.
Future<void> initializeCustomerData() async {
  final db = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  final productSnapshot = await db.collection('products').get();
  final loadedPhones = productSnapshot.docs
      .where((doc) => (doc.data()['isActive'] ?? doc.data()['active'] ?? true) == true)
      .map(Phone.fromFirestore)
      .where((p) => p.name.isNotEmpty && p.price >= 0)
      .toList();
  phones
    ..clear()
    ..addAll(loadedPhones);

  try {
    final couponSnapshot = await db.collection('coupons').get();
    final loadedCoupons = couponSnapshot.docs
        .where((doc) => (doc.data()['isActive'] ?? doc.data()['active'] ?? true) == true)
        .map((doc) => Coupon.fromFirestore(doc.data()))
        .where((c) => c.code.isNotEmpty)
        .toList();
    coupons
      ..clear()
      ..addAll(loadedCoupons);
  } on FirebaseException catch (e) {
    if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
    coupons.clear();
  }

  if (user == null) {
    profile.value = const UserProfile(name: '', phone: '', email: '');
    orders.value = <Order>[];
    wishlist.value = <String>{};
    return;
  }

  final userDoc = await db.collection('users').doc(user.uid).get();
  final userData = userDoc.data() ?? <String, dynamic>{};
  profile.value = UserProfile.fromMap(userData, fallbackEmail: user.email ?? '');
  wishlist.value = Set<String>.from((userData['wishlist'] as List? ?? const []).map((e) => e.toString()));

  try {
    final orderSnapshot = await db.collection('orders').where('customerId', isEqualTo: user.uid).get();
    final loadedOrders = orderSnapshot.docs.map(Order.fromFirestore).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    orders.value = loadedOrders;
  } on FirebaseException catch (e) {
    if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
    orders.value = <Order>[];
  }
}

/// Places an order locally for immediate UI feedback and persists it to Firestore.
/// The caller should show a loading state around checkout and verify the resulting document.
Order placeOrder({
  required List<CartItem> items,
  required int subtotal,
  required int delivery,
  required int discount,
  required int total,
  required String paymentMethod,
  required String addressLabel,
  required String addressLine,
  String? couponCode,
}) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Please sign in before placing an order.');
  final now = DateTime.now();
  final localOrder = Order(
    id: 'pending-${now.microsecondsSinceEpoch}',
    items: items.map((e) => CartItem(e.phone, e.storage, e.condition, qty: e.qty)).toList(),
    subtotal: subtotal,
    delivery: delivery,
    discount: discount,
    total: total,
    couponCode: couponCode,
    paymentMethod: paymentMethod,
    addressLabel: addressLabel,
    addressLine: addressLine,
    placedAt: now,
    firestoreStatus: 'Order Placed',
  );
  orders.value = [localOrder, ...orders.value];
  unawaited(() async {
    try {
      final ref = await FirebaseFirestore.instance.collection('orders').add(localOrder.toFirestoreMap(user.uid));
      final persisted = Order(
        id: ref.id,
        items: localOrder.items,
        subtotal: localOrder.subtotal,
        delivery: localOrder.delivery,
        discount: localOrder.discount,
        total: localOrder.total,
        couponCode: localOrder.couponCode,
        paymentMethod: localOrder.paymentMethod,
        addressLabel: localOrder.addressLabel,
        addressLine: localOrder.addressLine,
        placedAt: localOrder.placedAt,
        firestoreStatus: 'Order Placed',
      );
      orders.value = [persisted, ...orders.value.where((o) => o.id != localOrder.id)];
    } catch (_) {
      orders.value = orders.value.where((o) => o.id != localOrder.id).toList();
      rethrow;
    }
  }());
  return localOrder;
}

void cancelOrder(Order o) {
  o.cancelled = true;
  o.firestoreStatus = 'Cancelled';
  orders.value = List<Order>.from(orders.value);
  if (!o.id.startsWith('pending-')) {
    unawaited(FirebaseFirestore.instance.collection('orders').doc(o.id).update({
      'status': 'Cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((Object _) {}));
  }
}

void reorder(Order o) {
  for (final it in o.items) {
    for (int i = 0; i < it.qty; i++) {
      addToCart(it.phone, it.storage, it.condition);
    }
  }
}

String fmtDateTime(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]}, $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}
