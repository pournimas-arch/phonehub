import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Customer data models and Firebase-backed state for PhoneHub.
/// UI-facing names and synchronous cart helpers are retained to minimize screen changes.

class Phone {
  final String id, name, brand, storage, condition;
  final int price, mrp, battery;
  final double rating;
  final List<Color> colors;
  /// Firebase Storage URLs for the product gallery, in display order.
  final List<String> imageUrls;
  /// Admin's label for each photo (Front view, Back view ...), same order as [imageUrls].
  final List<String> imageLabels;
  /// Units in stock. -1 = not tracked (older products).
  final int stock;

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
    this.imageUrls = const <String>[],
    this.imageLabels = const <String>[],
    this.stock = -1,
  });

  int get off => mrp <= 0 ? 0 : (((mrp - price) / mrp) * 100).round();

  factory Phone.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final rawColors = d['colors'];
    final rawImages = d['images'] ?? d['imageUrls'];
    final parsedImages = rawImages is List
        ? rawImages.map((v) => v.toString().trim()).where((v) => v.isNotEmpty).toList()
        : <String>[];
    final rawLabels = d['imageLabels'];
    final parsedLabels = rawLabels is List ? rawLabels.map((v) => v.toString().trim()).toList() : <String>[];
    final singleImage = (d['imageUrl'] ?? d['coverImage'] ?? '').toString().trim();
    if (parsedImages.isEmpty && singleImage.isNotEmpty) parsedImages.add(singleImage);
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
      imageUrls: parsedImages,
      imageLabels: parsedLabels,
      stock: d.containsKey('stock') ? _asInt(d['stock']) : -1,
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

/// Loaded from Firestore (`brands` collection) by initializeCustomerData().
final List<String> brands = <String>[];
final Map<String, Color> brandColors = <String, Color>{};

/// Store settings, loaded from Firestore (`appConfig/store`) – set by the admin in Settings.
/// 0 = the admin has not set it yet (delivery is then free); no price is built into the app.
int deliveryChargeCfg = 0;
int freeDeliveryAboveCfg = 0;
int deliveryFor(int subtotal) => subtotal <= 0 || subtotal >= freeDeliveryAboveCfg ? 0 : deliveryChargeCfg;

/// Pincodes the admin delivers to (`appConfig/store.serviceablePincodes`).
/// An empty list means "no restriction" (every pincode is accepted).
List<String> serviceablePincodesCfg = <String>[];
bool isPincodeServiceable(String pin) =>
    serviceablePincodesCfg.isEmpty || serviceablePincodesCfg.contains(pin.trim());

/// "Only 3 left" label from the REAL stock of a phone (null when plenty / not tracked).
String? lowStockLabel(Phone p) => (p.stock > 0 && p.stock <= 5) ? 'Only ${p.stock} left' : null;

/// Home banners, loaded from Firestore (`banners` collection) – managed by the admin.
class HomeBanner {
  final String tag, title, subtitle, cta;
  final Color color;
  const HomeBanner(this.tag, this.title, this.subtitle, this.cta, this.color);
}

final List<HomeBanner> homeBanners = <HomeBanner>[];

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

const String _cartPrefsKey = 'phonehub_customer_cart_v1';
const String _guestWishlistPrefsKey = 'phonehub_guest_wishlist_v1';
bool _cartRestored = false;

void _persistCart() {
  unawaited(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = cart.value.map((item) => <String, dynamic>{
        'productId': item.phone.id,
        'storage': item.storage,
        'condition': item.condition,
        'qty': item.qty,
      }).toList();
      await prefs.setString(_cartPrefsKey, jsonEncode(payload));
    } catch (_) {
      // Cart still works for the current session if local storage is unavailable.
    }
  }());
}

Future<void> _restoreCartIfNeeded() async {
  if (_cartRestored) return;
  _cartRestored = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final restored = <CartItem>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final id = (map['productId'] ?? '').toString();
      Phone? phone;
      for (final candidate in phones) {
        if (candidate.id == id) { phone = candidate; break; }
      }
      if (phone == null || (phone.stock == 0)) continue;
      final requestedQty = _asInt(map['qty']).clamp(1, 5).toInt();
      final safeQty = phone.stock > 0 ? requestedQty.clamp(1, phone.stock).toInt() : requestedQty;
      restored.add(CartItem(
        phone,
        (map['storage'] ?? phone.storage).toString(),
        (map['condition'] ?? phone.condition).toString(),
        qty: safeQty,
      ));
    }
    cart.value = restored;
    _persistCart();
  } catch (_) {
    // Ignore corrupt saved data and keep an empty/current cart.
  }
}

/// Returns a readable reason when a cart addition is blocked; null means allowed.
String? cartAdditionError(Phone p, {int currentQty = 0}) {
  if (p.stock == 0) return '${p.name} is out of stock.';
  if (currentQty >= 5) return 'You can add up to 5 units of one phone option.';
  if (p.stock > 0 && currentQty >= p.stock) {
    return 'Only ${p.stock} unit(s) of ${p.name} are available.';
  }
  return null;
}

void addToCart(Phone p, String storage, String condition) {
  final list = List<CartItem>.from(cart.value);
  final i = list.indexWhere((e) => e.phone.id == p.id && e.storage == storage && e.condition == condition);
  final currentQty = i >= 0 ? list[i].qty : 0;
  if (cartAdditionError(p, currentQty: currentQty) != null) return;
  if (i >= 0) {
    list[i].qty = (list[i].qty + 1).clamp(1, p.stock > 0 ? (p.stock < 5 ? p.stock : 5) : 5).toInt();
  } else {
    list.add(CartItem(p, storage, condition));
  }
  cart.value = list;
  _persistCart();
}

void changeQty(CartItem item, int delta) {
  final requested = item.qty + delta;
  final maxQty = item.phone.stock > 0 ? (item.phone.stock < 5 ? item.phone.stock : 5) : 5;
  item.qty = requested.clamp(1, maxQty).toInt();
  cart.value = List<CartItem>.from(cart.value);
  _persistCart();
}

void removeItem(CartItem item) {
  cart.value = cart.value.where((e) => e != item).toList();
  _persistCart();
}

/// Call after a successful checkout to clear both the UI cart and saved cart.
Future<void> clearCart() async {
  cart.value = <CartItem>[];
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartPrefsKey);
  } catch (_) {}
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
  } else {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_guestWishlistPrefsKey, s.toList());
      } catch (_) {}
    }());
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
  if (c.firstOrderOnly && orders.value.isNotEmpty) return '${c.code} is valid on your first order only';
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

/// Short readable order number, e.g. PH7K2M9QA
String newOrderId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
  return 'PH${t.substring(t.length - 7)}';
}

/// Saves the order AND reduces the stock of every phone in one transaction.
/// Also (same transaction): creates the 4-digit delivery OTP for the customer
/// (`orders/{id}/private/otp`) and records the coupon use
/// (`coupons/{code}/redemptions/{uid}`).
/// Throws a [StateError] with a friendly message when a phone is sold out.
/// [addressLat] / [addressLng] (optional) are saved so the delivery partner can navigate.
Future<void> placeOrderWithStock(
    DocumentReference<Map<String, dynamic>> orderRef,
    Order order,
    String uid, {
      double? addressLat,
      double? addressLng,
    }) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null || currentUser.uid != uid) {
    throw StateError('Your session has expired. Please sign in again.');
  }
  if (order.items.isEmpty) {
    throw StateError('Your cart is empty. Add a phone before checkout.');
  }
  if (order.subtotal < 0 || order.delivery < 0 || order.discount < 0 ||
      order.total < 0 || order.discount > order.subtotal + order.delivery ||
      order.total != order.subtotal + order.delivery - order.discount) {
    throw StateError('The order total is invalid. Please review your cart and try again.');
  }
  if (order.items.any((item) => item.qty < 1 || item.qty > 5 || item.phone.id.trim().isEmpty)) {
    throw StateError('One or more cart items are invalid. Please review your cart.');
  }
  // The delivery partner calls this number, so it must exist.
  if (profile.value.phone.trim().isEmpty) {
    throw StateError('Please add your mobile number in Profile so the delivery partner can contact you.');
  }

  final couponCode = (order.couponCode ?? '').trim().toUpperCase();
  final db = FirebaseFirestore.instance;

  // Resolve the coupon document once, then read its current value inside the
  // transaction. Admin-created coupons normally use the code as their document
  // ID; the query fallback also supports older records whose IDs differ.
  DocumentReference<Map<String, dynamic>>? couponRef;
  if (couponCode.isNotEmpty) {
    final directRef = db.collection('coupons').doc(couponCode);
    final directSnap = await directRef.get();
    if (directSnap.exists) {
      couponRef = directRef;
    } else {
      final matches = await db.collection('coupons')
          .where('code', isEqualTo: couponCode)
          .limit(1)
          .get();
      if (matches.docs.isEmpty) {
        throw StateError('This coupon is no longer available. Please remove it and try again.');
      }
      couponRef = matches.docs.first.reference;
    }
  }

  // 4-digit code the customer tells the delivery partner at the door.
  final deliveryOtp = (1000 + Random.secure().nextInt(9000)).toString();

  await db.runTransaction((tx) async {
    // Verify the customer profile and blocked state inside this transaction.
    final userRef = db.collection('users').doc(uid);
    final userSnap = await tx.get(userRef);
    final userData = userSnap.data();
    if (!userSnap.exists || userData == null) {
      throw StateError('Your customer profile was not found. Please sign in again.');
    }
    if (userData['blocked'] == true) {
      throw StateError('This account is currently blocked. Please contact PhoneHub support.');
    }

    // Re-read the coupon inside the transaction so a coupon disabled or
    // expired after checkout opened cannot be used with stale client state.
    Coupon? currentCoupon;
    DocumentReference<Map<String, dynamic>>? redeemRef;
    var alreadyRedeemed = false;
    if (couponCode.isNotEmpty) {
      if (couponRef == null) {
        throw StateError('This coupon is no longer available. Please remove it and try again.');
      }
      final couponSnap = await tx.get(couponRef);
      final couponData = couponSnap.data();
      if (!couponSnap.exists || couponData == null ||
          (couponData['isActive'] ?? couponData['active'] ?? true) != true) {
        throw StateError('This coupon is no longer active. Please remove it and try again.');
      }
      final expiryValue = couponData['expiry'];
      if (expiryValue is Timestamp && !expiryValue.toDate().isAfter(DateTime.now())) {
        throw StateError('This coupon has expired. Please choose another offer.');
      }
      currentCoupon = Coupon.fromFirestore(couponData);
      if (currentCoupon.code != couponCode) {
        throw StateError('The coupon code could not be verified. Please try again.');
      }
      if (currentCoupon.minOrder > order.subtotal) {
        throw StateError('${currentCoupon.code} needs a minimum order of ${rupee(currentCoupon.minOrder)}.');
      }
      redeemRef = couponRef.collection('redemptions').doc(uid);
      final redeemSnap = await tx.get(redeemRef);
      alreadyRedeemed = redeemSnap.exists;
      if (currentCoupon.firstOrderOnly && alreadyRedeemed) {
        throw StateError('${currentCoupon.code} is valid on your first order only.');
      }
    } else if (order.discount != 0) {
      throw StateError('The discount could not be verified. Please re-apply your coupon.');
    }

    // Merge repeated product IDs so stock is checked against the total quantity.
    final wanted = <String, int>{};
    for (final item in order.items) {
      wanted[item.phone.id] = (wanted[item.phone.id] ?? 0) + item.qty;
    }

    final productRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    final remainingStock = <String, int?>{};
    var verifiedSubtotal = 0;

    // Firestore requires transaction reads to finish before any writes. Use
    // the current Firestore prices, not prices cached by the product screen.
    for (final entry in wanted.entries) {
      final ref = db.collection('products').doc(entry.key);
      final snap = await tx.get(ref);
      final data = snap.data();

      if (!snap.exists || data == null ||
          (data['isActive'] ?? data['active'] ?? true) != true) {
        throw StateError('A phone in your cart is no longer available. Please remove it and try again.');
      }

      final currentPrice = _asInt(data['price'] ?? data['sellingPrice']);
      if (currentPrice < 0) {
        throw StateError('A product has an invalid price. Please contact support.');
      }
      verifiedSubtotal += currentPrice * entry.value;

      if (data.containsKey('stock')) {
        final stockValue = data['stock'];
        if (stockValue is! num || stockValue < 0) {
          throw StateError('Stock information is invalid for ${(data['name'] ?? 'a phone').toString()}. Please contact support.');
        }
        final left = stockValue.toInt();
        if (left < entry.value) {
          final name = (data['name'] ?? data['title'] ?? 'A phone').toString();
          throw StateError(left <= 0 ? '$name is out of stock.' : 'Only $left unit(s) of $name left.');
        }
        remainingStock[entry.key] = left;
      } else {
        // Legacy products without a stock field remain untracked. New products
        // should always have a non-negative integer stock value.
        remainingStock[entry.key] = null;
      }
      productRefs[entry.key] = ref;
    }

    if (verifiedSubtotal != order.subtotal) {
      throw StateError('A product price changed while you were checking out. Please review your cart and try again.');
    }
    if (currentCoupon != null) {
      final verifiedDiscount = couponDiscount(currentCoupon, verifiedSubtotal, order.delivery);
      if (verifiedDiscount != order.discount) {
        throw StateError('Your coupon discount has changed. Please re-apply the coupon and review your total.');
      }
    }

    var stockWasDeducted = false;
    for (final entry in wanted.entries) {
      final left = remainingStock[entry.key];
      if (left != null) {
        tx.update(productRefs[entry.key]!, {
          'stock': left - entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        stockWasDeducted = true;
      }
    }

    tx.set(orderRef, {
      ...order.toFirestoreMap(uid),
      'customerId': uid,
      'userId': uid,
      'status': 'Order Placed',
      'paymentStatus': 'Pending',
      'updatedAt': FieldValue.serverTimestamp(),
      if (stockWasDeducted) 'stockDeducted': true,
      'stockRestored': false,
      if (addressLat != null && addressLng != null) 'addressLat': addressLat,
      if (addressLat != null && addressLng != null) 'addressLng': addressLng,
    });

    // Delivery OTP: only the customer (and admin) can read it; the partner must ask for it.
    tx.set(orderRef.collection('private').doc('otp'), {
      'code': deliveryOtp,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Remember that this customer used the coupon (written once per customer).
    if (redeemRef != null && !alreadyRedeemed) {
      tx.set(redeemRef, {
        'userId': uid,
        'orderId': orderRef.id,
        'code': currentCoupon!.code,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  });
}

/// The delivery OTP of an order (null for older orders that have none).
/// Show it to the customer on the tracking screen.
Stream<String?> deliveryOtpStream(String orderId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .collection('private')
      .doc('otp')
      .snapshots()
      .map<String?>((s) => s.data()?['code']?.toString());
}

const List<String> _etaMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const List<String> orderSteps = ['Order Placed', 'Payment Confirmed', 'Packed', 'Out for Delivery', 'Delivered'];

class Order {
  final String id, paymentMethod, addressLabel, addressLine;
  final List<CartItem> items;
  final int subtotal, delivery, discount, total;
  final String? couponCode;
  final DateTime placedAt;
  bool cancelled;
  String firestoreStatus;
  final String partnerName, partnerPhone;
  /// When the delivery partner marked the order delivered (null until then).
  final DateTime? deliveredAt;
  /// Promised delivery day (orders.deliveryDate, saved at checkout).
  final DateTime? expectedDelivery;
  /// Failed delivery attempts reported by the delivery partner (customer not reachable, wrong address ...).
  final int deliveryAttempts;
  final String failedReason;
  final DateTime? lastAttemptAt;
  /// Payment state written by the admin / delivery partner (Pending, Paid, Refunded).
  final String paymentStatus;

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
    this.cancelled = false,
    this.firestoreStatus = '',
    this.partnerName = '',
    this.partnerPhone = '',
    this.deliveredAt,
    this.expectedDelivery,
    this.deliveryAttempts = 0,
    this.failedReason = '',
    this.lastAttemptAt,
    this.paymentStatus = '',
  });

  int get stage {
    final s = firestoreStatus.toLowerCase().replaceAll('_', ' ');
    // "Out for Delivery" must be checked before "deliver".
    if (s.contains('out for') || s.contains('transit') || s.contains('shipped') || s.contains('picked')) return 3;
    if (s.contains('deliver')) return 4;
    if (s.contains('pack') || s.contains('process')) return 2;
    if (s.contains('payment') || s.contains('paid') || s.contains('confirm')) return 1;
    return 0;
  }

  bool get isDelivered => !cancelled && stage >= 4;
  bool get isOngoing => !cancelled && stage < 4;
  String get statusLabel => cancelled ? 'Cancelled' : (firestoreStatus.isNotEmpty ? _prettyStatus(firestoreStatus) : orderSteps[stage]);
  int get itemCount => items.fold<int>(0, (s, e) => s + e.qty);
  String get title => items.isEmpty ? 'Order' : (items.length == 1 ? items.first.phone.name : '${items.first.phone.name} +${items.length - 1} more');

  /// Time of a step. The last step (Delivered) uses the real delivery time when it is known.
  DateTime stepTime(int k) => (k >= orderSteps.length - 1 && deliveredAt != null) ? deliveredAt! : placedAt;
  /// The last delivery attempt failed and the order is still on its way.
  bool get hasFailedAttempt => !cancelled && !isDelivered && deliveryAttempts > 0;

  /// Cash on delivery: the customer pays the partner at the door.
  bool get isCod => paymentMethod == 'Cash on Delivery';

  String get etaText {
    if (cancelled) return 'Cancelled';
    if (isDelivered) return 'Delivered';
    if (hasFailedAttempt) return 'Delivery attempt failed. We will try again';
    if (stage >= 3) return 'Out for delivery';
    final d = expectedDelivery;
    if (d != null) return 'Expected by ${d.day} ${_etaMonths[d.month - 1]}';
    return 'Delivery status updated by PhoneHub';
  }

  Map<String, dynamic> toFirestoreMap(String uid) => {
    'customerId': uid,
    'userId': uid,
    'customerName': profile.value.name,
    'customerPhone': profile.value.phone,
    'customerEmail': profile.value.email,
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
    // Promised delivery day (same "Delivery by ..." the customer saw at checkout) and time window;
    // the delivery partner app shows both.
    'deliveryDate': Timestamp.fromDate(DateTime(placedAt.year, placedAt.month, placedAt.day + deliveryDaysPromise)),
    'deliverySlot': 'Anytime',
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
        parsedItems.add(CartItem(p, (m['storage'] ?? p.storage).toString(), (m['condition'] ?? p.condition).toString(), qty: _asInt(m['quantity'] ?? m['qty']).clamp(1, 99).toInt()));
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
      partnerName: (d['partnerName'] ?? '').toString(),
      partnerPhone: (d['partnerPhone'] ?? '').toString(),
      deliveredAt: d['deliveredAt'] is Timestamp ? (d['deliveredAt'] as Timestamp).toDate() : null,
      expectedDelivery: d['deliveryDate'] is Timestamp ? (d['deliveryDate'] as Timestamp).toDate() : null,
      deliveryAttempts: _asInt(d['deliveryAttempts']),
      failedReason: (d['failedReason'] ?? '').toString(),
      lastAttemptAt: d['lastAttemptAt'] is Timestamp ? (d['lastAttemptAt'] as Timestamp).toDate() : null,
      paymentStatus: (d['paymentStatus'] ?? '').toString(),
    );
  }
}

String _prettyStatus(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Order Placed';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

final ValueNotifier<List<Order>> orders = ValueNotifier<List<Order>>([]);

/// True when the admin has blocked the signed-in customer (`users/{uid}.blocked`).
/// Days from today that checkout promises ("Delivery by ..."); saved as the order's deliveryDate.
const int deliveryDaysPromise = 3;

/// Set by initializeCustomerData(); the login / splash screen can use it to sign the user out.
bool customerBlocked = false;

/// Bumped whenever the live catalog listener refreshes products, brands or banners,
/// so a screen can rebuild with `ValueListenableBuilder` on it.
final ValueNotifier<int> catalogVersion = ValueNotifier<int>(0);
final List<StreamSubscription<dynamic>> _catalogSubs = <StreamSubscription<dynamic>>[];

void _applyProducts(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final loadedPhones = docs
      .where((doc) => (doc.data()['isActive'] ?? doc.data()['active'] ?? true) == true)
      .map(Phone.fromFirestore)
      .where((p) => p.name.isNotEmpty && p.price >= 0 && p.stock != 0)
      .toList();
  phones
    ..clear()
    ..addAll(loadedPhones);
}

void _applyBrands(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final list = docs.where((d) => (d.data()['isActive'] ?? d.data()['active'] ?? true) == true).toList()
    ..sort((a, b) => (a.data()['name'] ?? '').toString().compareTo((b.data()['name'] ?? '').toString()));
  brands.clear();
  brandColors.clear();
  for (final d in list) {
    final name = (d.data()['name'] ?? '').toString();
    if (name.isEmpty) continue;
    brands.add(name);
    final c = _colorFrom(d.data()['color']);
    if (c != null) brandColors[name] = c;
  }
}

void _applyBanners(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  final list = docs.where((d) => (d.data()['isActive'] ?? d.data()['active'] ?? true) == true).toList()
    ..sort((a, b) => _asInt(a.data()['order']).compareTo(_asInt(b.data()['order'])));
  homeBanners
    ..clear()
    ..addAll(list.map((d) {
      final m = d.data();
      return HomeBanner((m['tag'] ?? 'OFFER').toString(), (m['title'] ?? '').toString(), (m['subtitle'] ?? '').toString(), (m['cta'] ?? 'Shop Now').toString(), _colorFrom(m['color']) ?? const Color(0xFF1B2A5C));
    }));
}

/// Keeps products, brands and banners live: when the admin changes a price, stock or
/// banner, the customer app updates without a restart. Call once after
/// initializeCustomerData() and listen to [catalogVersion] in the screen.
void startCatalogListener() {
  stopCatalogListener();
  final db = FirebaseFirestore.instance;
  void failed(Object e) => debugPrint('PhoneHub catalog listener: $e');
  _catalogSubs.add(db.collection('products').snapshots().listen((snap) {
    _applyProducts(snap.docs);
    catalogVersion.value++;
  }, onError: failed));
  _catalogSubs.add(db.collection('brands').snapshots().listen((snap) {
    _applyBrands(snap.docs);
    catalogVersion.value++;
  }, onError: failed));
  _catalogSubs.add(db.collection('banners').snapshots().listen((snap) {
    _applyBanners(snap.docs);
    catalogVersion.value++;
  }, onError: failed));
}

void stopCatalogListener() {
  for (final s in _catalogSubs) {
    s.cancel();
  }
  _catalogSubs.clear();
}

/// Call after Firebase.initializeApp() and after customer authentication.
/// Expected Firestore collections: products, coupons, users/{uid}, orders.
Future<void> initializeCustomerData() async {
  final db = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  final productSnapshot = await db.collection('products').get();
  _applyProducts(productSnapshot.docs);
  await _restoreCartIfNeeded();

  try {
    final couponSnapshot = await db.collection('coupons').get();
    final loadedCoupons = couponSnapshot.docs
        .where((doc) => (doc.data()['isActive'] ?? doc.data()['active'] ?? true) == true)
        .where((doc) {
      final e = doc.data()['expiry'];
      return e is! Timestamp || e.toDate().isAfter(DateTime.now());
    })
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

  // Brands, banners and store settings (all managed by the admin).
  try {
    final brandSnap = await db.collection('brands').get();
    _applyBrands(brandSnap.docs);
  } on FirebaseException catch (e) {
    if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
  }
  try {
    final bannerSnap = await db.collection('banners').get();
    _applyBanners(bannerSnap.docs);
  } on FirebaseException catch (e) {
    if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
  }
  try {
    final cfg = await db.collection('appConfig').doc('store').get();
    final c = cfg.data();
    if (c != null) {
      if (c.containsKey('deliveryCharge')) deliveryChargeCfg = _asInt(c['deliveryCharge']);
      if (c.containsKey('freeDeliveryAbove')) freeDeliveryAboveCfg = _asInt(c['freeDeliveryAbove']);
      if (c['serviceablePincodes'] is List) {
        serviceablePincodesCfg = (c['serviceablePincodes'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
  } on FirebaseException catch (e) {
    if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
  }

  if (user == null) {
    stopOrdersListener();
    customerBlocked = false;
    profile.value = const UserProfile(name: '', phone: '', email: '');
    orders.value = <Order>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      wishlist.value = (prefs.getStringList(_guestWishlistPrefsKey) ?? const <String>[]).toSet();
    } catch (_) {
      wishlist.value = <String>{};
    }
    return;
  }

  final userDoc = await db.collection('users').doc(user.uid).get();
  final userData = userDoc.data() ?? <String, dynamic>{};
  customerBlocked = userData['blocked'] == true;
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
  // Keep `orders` live from now on (one listener for all screens).
  if (!customerBlocked) startOrdersListener();
}

// ---------------- One live orders listener ----------------
//
// Every screen reads `orders`; this single listener keeps it in step with Firestore
// (admin / partner status changes, cancellations, delivery) without a refresh.

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;

void startOrdersListener() {
  stopOrdersListener();
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final uid = user.uid;
  _ordersSub = FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: uid)
      .snapshots()
      .listen((snap) {
    // The user signed out or another user signed in: stop listening.
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      stopOrdersListener();
      return;
    }
    final list = snap.docs.map(Order.fromFirestore).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    orders.value = list;
  }, onError: (Object _) => stopOrdersListener());
}

void stopOrdersListener() {
  _ordersSub?.cancel();
  _ordersSub = null;
}

/// Cancels an order. The screen updates at once; if Firestore refuses (for example the
/// order is already out for delivery) the change is reverted and `false` is returned.
Future<bool> cancelOrder(Order o) async {
  final oldStatus = o.firestoreStatus;
  o.cancelled = true;
  o.firestoreStatus = 'Cancelled';
  orders.value = List<Order>.from(orders.value);
  try {
    await FirebaseFirestore.instance.collection('orders').doc(o.id).update({
      'status': 'Cancelled',
      'cancelledBy': 'customer',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  } catch (_) {
    o.cancelled = false;
    o.firestoreStatus = oldStatus;
    orders.value = List<Order>.from(orders.value);
    return false;
  }
}

void reorder(Order o) {
  for (final it in o.items) {
    for (int i = 0; i < it.qty; i++) {
      addToCart(it.phone, it.storage, it.condition);
    }
  }
}

// ---------------- Reviews (real customer reviews, `reviews` collection) ----------------

class ProductReview {
  final String id, productId, userId, userName, text;
  final int stars;
  final DateTime date;
  final bool verified;
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.stars,
    required this.date,
    required this.verified,
  });

  factory ProductReview.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final raw = d['createdAt'];
    return ProductReview(
      id: doc.id,
      productId: (d['productId'] ?? '').toString(),
      userId: (d['userId'] ?? '').toString(),
      userName: (d['userName'] ?? 'Customer').toString(),
      text: (d['text'] ?? '').toString(),
      stars: _asInt(d['stars']).clamp(1, 5).toInt(),
      date: raw is Timestamp ? raw.toDate() : DateTime.now(),
      verified: d['verified'] == true,
    );
  }
}

/// Live list of reviews of one phone, newest first.
Stream<List<ProductReview>> reviewsFor(String productId) {
  return FirebaseFirestore.instance
      .collection('reviews')
      .where('productId', isEqualTo: productId)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map(ProductReview.fromFirestore).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  });
}

/// True when the signed-in customer has a DELIVERED order that contains this phone.
bool hasPurchased(String productId) =>
    orders.value.any((o) => o.isDelivered && o.items.any((i) => i.phone.id == productId));

/// Saves (or edits) the customer's review of a phone. One review per customer per phone.
Future<void> submitReview({required Phone phone, required int stars, required String text}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Please sign in to write a review.');
  if (customerBlocked) throw StateError('This account is currently blocked. Please contact PhoneHub support.');
  final clean = text.trim();
  final name = profile.value.name.trim();
  await FirebaseFirestore.instance.collection('reviews').doc('${user.uid}_${phone.id}').set({
    'productId': phone.id,
    'productName': phone.name,
    'userId': user.uid,
    'userName': name.isEmpty ? 'Customer' : name,
    'stars': stars.clamp(1, 5).toInt(),
    'text': clean.length > 500 ? clean.substring(0, 500) : clean,
    'verified': hasPurchased(phone.id),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

String fmtDateTime(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]}, $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}