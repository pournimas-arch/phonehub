import 'package:flutter/material.dart';

// ============================================================================
// PhoneHub ADMIN – in-memory data & state (no backend, same approach as the
// customer app). Replace the methods of [AdminStore] with real API calls later.
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
  bool active;

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
    this.stock = 5,
    this.active = true,
  });

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
  });

  bool get isCod => paymentMethod == 'Cash on Delivery';
  bool get isDelivered => !cancelled && stage >= 4;
  bool get isOngoing => !cancelled && stage < 4;
  String get statusLabel => cancelled ? 'Cancelled' : orderSteps[stage];
  int get itemCount => items.fold<int>(0, (s, e) => s + e.qty);
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
  String name, phone, vehicle;
  double rating;
  bool active;
  Partner({required this.id, required this.name, required this.phone, required this.vehicle, required this.rating, this.active = true});
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
  Refund(this.id, this.orderId, this.amount, this.reason, this.status, this.date);
}

class ChatMsg {
  final bool fromAdmin;
  final String text;
  final DateTime time;
  ChatMsg(this.fromAdmin, this.text, this.time);
}

class Ticket {
  final String id, customerId, subject;
  String status; // Open, In Progress, Resolved
  final List<ChatMsg> messages;
  final DateTime created;
  Ticket({required this.id, required this.customerId, required this.subject, required this.status, required this.messages, required this.created});
}

class Faq {
  String q, a;
  Faq(this.q, this.a);
}

class Staff {
  String name, email, role;
  bool active;
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
  String adminEmail = 'admin@phonehub.in';
  String adminPhone = '+91 98765 00000';
  String adminPassword = 'admin@123';
  bool pushAlerts = true;

  int deliveryCharge = 99;
  int freeDeliveryAbove = 10000;
  int returnDays = 7;
  String supportPhone = '+91 98765 43210';
  String supportEmail = 'support@phonehub.in';

  String returnsPolicy = 'Customers can request a return within 7 days of delivery if the phone is not as described.';
  String warrantyPolicy = 'Every phone comes with a 6 month PhoneHub warranty on hardware defects.';
  String privacyPolicy = 'We only use customer data to process orders and never sell it to third parties.';

  final List<Staff> staff = [
    Staff('Admin', 'admin@phonehub.in', 'Super Admin'),
    Staff('Kiran Pawar', 'kiran@phonehub.in', 'Order Manager'),
    Staff('Meera Nair', 'meera@phonehub.in', 'Inventory Manager'),
  ];

  // ---------------- Catalogue ----------------
  final List<Brand> brands = [
    Brand('Apple', const Color(0xFF1B1B2F)),
    Brand('Samsung', const Color(0xFF1D4ED8)),
    Brand('OnePlus', const Color(0xFFDC2626)),
    Brand('Xiaomi', const Color(0xFFEA580C)),
    Brand('Realme', const Color(0xFFCA8A04)),
  ];

  final List<Phone> phones = [
    Phone(id: 'p1', name: 'iPhone 13', brand: 'Apple', storage: '128 GB', condition: 'Like New', price: 42999, mrp: 59900, battery: 92, rating: 4.7, colors: [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)], stock: 6),
    Phone(id: 'p2', name: 'iPhone 12', brand: 'Apple', storage: '64 GB', condition: 'Good', price: 29999, mrp: 45900, battery: 88, rating: 4.5, colors: [const Color(0xFF111827), const Color(0xFF6B7280)], stock: 3),
    Phone(id: 'p3', name: 'Galaxy S21', brand: 'Samsung', storage: '128 GB', condition: 'Good', price: 27999, mrp: 69999, battery: 90, rating: 4.4, colors: [const Color(0xFF2E4A9A), const Color(0xFFC084FC)], stock: 8),
    Phone(id: 'p4', name: 'Galaxy A54', brand: 'Samsung', storage: '128 GB', condition: 'Like New', price: 22499, mrp: 38999, battery: 95, rating: 4.3, colors: [const Color(0xFF0F766E), const Color(0xFF2DD4BF)], stock: 10),
    Phone(id: 'p5', name: 'OnePlus 11R', brand: 'OnePlus', storage: '256 GB', condition: 'Like New', price: 31999, mrp: 44999, battery: 94, rating: 4.6, colors: [const Color(0xFFB91C1C), const Color(0xFFF87171)], stock: 2),
    Phone(id: 'p6', name: 'OnePlus Nord CE 3', brand: 'OnePlus', storage: '128 GB', condition: 'Good', price: 14999, mrp: 26999, battery: 89, rating: 4.2, colors: [const Color(0xFF065F46), const Color(0xFF34D399)], stock: 12),
    Phone(id: 'p7', name: 'Redmi Note 12 Pro', brand: 'Xiaomi', storage: '128 GB', condition: 'Fair', price: 12499, mrp: 27999, battery: 85, rating: 4.1, colors: [const Color(0xFFC2410C), const Color(0xFFFB923C)], stock: 0),
    Phone(id: 'p8', name: 'Xiaomi 11T Pro', brand: 'Xiaomi', storage: '256 GB', condition: 'Good', price: 24999, mrp: 49999, battery: 90, rating: 4.4, colors: [const Color(0xFF0369A1), const Color(0xFF38BDF8)], stock: 5),
    Phone(id: 'p9', name: 'Realme GT Neo 3', brand: 'Realme', storage: '256 GB', condition: 'Good', price: 19999, mrp: 36999, battery: 91, rating: 4.3, colors: [const Color(0xFFA16207), const Color(0xFFFACC15)], stock: 7),
    Phone(id: 'p10', name: 'Realme 11 Pro', brand: 'Realme', storage: '128 GB', condition: 'Like New', price: 17999, mrp: 27999, battery: 96, rating: 4.2, colors: [const Color(0xFFBE185D), const Color(0xFFF472B6)], stock: 1),
  ];

  // ---------------- People ----------------
  final List<Customer> customers = [
    Customer(id: 'c1', name: 'Pournima Salunkhe', phone: '+91 98765 43210', email: 'pournima@gmail.com', joined: DateTime(2026, 1, 12), addresses: ['Home: Flat 302, Shivaji Nagar, Pune - 411005'], wishlist: ['p1', 'p5']),
    Customer(id: 'c2', name: 'Amit Kulkarni', phone: '+91 98220 11223', email: 'amit.k@gmail.com', joined: DateTime(2026, 2, 3), addresses: ['Home: 12 Karve Road, Kothrud, Pune - 411038', 'Office: Hinjewadi Phase 1, Pune - 411057'], wishlist: ['p3']),
    Customer(id: 'c3', name: 'Sneha Deshmukh', phone: '+91 97300 55667', email: 'sneha.d@gmail.com', joined: DateTime(2026, 3, 18), addresses: ['Home: B-14 Baner Heights, Baner, Pune - 411045'], wishlist: ['p10', 'p4']),
    Customer(id: 'c4', name: 'Rohan Patil', phone: '+91 99750 88990', email: 'rohan.p@gmail.com', joined: DateTime(2026, 4, 7), addresses: ['Home: 7 MG Road, Camp, Pune - 411001'], wishlist: []),
    Customer(id: 'c5', name: 'Priya Joshi', phone: '+91 98900 33445', email: 'priya.j@gmail.com', joined: DateTime(2026, 5, 22), addresses: ['Home: 21 Aundh Road, Pune - 411007'], wishlist: ['p2']),
    Customer(id: 'c6', name: 'Vikram Shinde', phone: '+91 98810 77889', email: 'vikram.s@gmail.com', joined: DateTime(2026, 7, 9), addresses: ['Home: 4 Wakad Road, Pune - 411057'], wishlist: ['p8', 'p9'], blocked: true),
  ];

  final List<Partner> partners = [
    Partner(id: 'd1', name: 'Rahul Patil', phone: '+91 90110 12345', vehicle: 'Bike • MH 12 AB 1234', rating: 4.8),
    Partner(id: 'd2', name: 'Sagar More', phone: '+91 90110 23456', vehicle: 'Bike • MH 14 CD 5678', rating: 4.6),
    Partner(id: 'd3', name: 'Imran Shaikh', phone: '+91 90110 34567', vehicle: 'Scooter • MH 12 EF 9012', rating: 4.5),
    Partner(id: 'd4', name: 'Nitin Jadhav', phone: '+91 90110 45678', vehicle: 'Bike • MH 12 GH 3456', rating: 4.3, active: false),
  ];

  // ---------------- Orders ----------------
  late final List<AdminOrder> orders;

  // ---------------- Marketing ----------------
  final List<Coupon> coupons = [
    Coupon(code: 'PHONEHUB500', title: 'Flat ₹500 off on your order', note: 'On orders of ₹5,000 or more', flat: 500, minOrder: 5000, expiry: DateTime(2026, 12, 31)),
    Coupon(code: 'FREEDELIVERY', title: 'Free delivery on any order', note: 'Saves the ₹99 delivery charge', freeDelivery: true, expiry: DateTime(2026, 12, 31)),
    Coupon(code: 'NEWUSER10', title: '10% off on your first order', note: 'Up to ₹2,000 off, first order only', percent: 10, maxOff: 2000, firstOrderOnly: true, expiry: DateTime(2026, 11, 30)),
    Coupon(code: 'DIWALI1000', title: 'Diwali special ₹1,000 off', note: 'On orders of ₹15,000 or more', flat: 1000, minOrder: 15000, expiry: DateTime(2026, 11, 15)),
    Coupon(code: 'SUMMER300', title: 'Summer sale ₹300 off', note: 'Ended', flat: 300, minOrder: 3000, active: false, expiry: DateTime(2026, 6, 30)),
  ];

  final List<PromoBanner> banners = [
    PromoBanner('Festive Sale', 'Up to 60% off on refurbished phones', const Color(0xFF1B2A5C)),
    PromoBanner('iPhone Days', 'Like-new iPhones from ₹29,999', const Color(0xFFFF8A4C)),
    PromoBanner('Free Delivery', 'On all orders above ₹10,000', const Color(0xFF0F766E)),
  ];

  final List<SentNotif> sentNotifs = [
    SentNotif('Festive Sale is live', 'Up to 60% off on refurbished phones. Shop now!', 'All customers', DateTime.now().subtract(const Duration(days: 2))),
    SentNotif('New offer for you', 'Use code PHONEHUB500 to save ₹500 on your next order.', 'All customers', DateTime.now().subtract(const Duration(days: 6))),
  ];

  // ---------------- Money & support ----------------
  final List<Refund> refunds = [];
  final List<Ticket> tickets = [];
  final List<Faq> faqs = [
    Faq('How do I track my order?', 'Open the Orders tab and tap your order to see live delivery status.'),
    Faq('What does the phone condition mean?', 'Like New phones have no visible marks, Good phones have light wear and Fair phones have visible wear but work perfectly.'),
    Faq('Can I return a phone?', 'Yes. You can request a return within 7 days of delivery if the phone is not as described.'),
    Faq('How do I use a coupon?', 'Enter the coupon code in your cart before you pay. Open Coupons & Offers to copy a code.'),
  ];

  AdminStore() {
    _seedOrders();
    _seedSupport();
  }

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

  // ---------------- Seeding ----------------
  AdminOrder _mk(String id, String cust, List<(String, int)> lines, int hoursAgo, String method, int stage, {int discount = 0, String? coupon, bool cancelled = false, String? partner}) {
    final items = <OrderLine>[];
    var sub = 0;
    for (final l in lines) {
      final p = phones.firstWhere((e) => e.id == l.$1);
      items.add(OrderLine(p.id, p.name, p.storage, p.condition, l.$2, p.price));
      sub += p.price * l.$2;
    }
    final del = sub >= freeDeliveryAbove ? 0 : deliveryCharge;
    final c = customers.firstWhere((e) => e.id == cust);
    return AdminOrder(
      id: id,
      customerId: cust,
      items: items,
      subtotal: sub,
      delivery: del,
      discount: discount,
      total: sub + del - discount,
      paymentMethod: method,
      address: c.addresses.first,
      placedAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
      couponCode: coupon,
      stage: stage,
      cancelled: cancelled,
      partnerId: partner,
    );
  }

  void _seedOrders() {
    orders = [
      _mk('PH10248', 'c3', [('p10', 1)], 1, 'UPI', 0),
      _mk('PH10247', 'c2', [('p3', 1)], 3, 'Debit/Credit Card', 1, discount: 500, coupon: 'PHONEHUB500'),
      _mk('PH10246', 'c5', [('p2', 1)], 6, 'Cash on Delivery', 2),
      _mk('PH10245', 'c1', [('p1', 1), ('p6', 1)], 20, 'UPI', 3, partner: 'd1'),
      _mk('PH10244', 'c4', [('p6', 1)], 30, 'Net Banking', 3, partner: 'd2'),
      _mk('PH10243', 'c2', [('p5', 1)], 50, 'UPI', 4, partner: 'd1'),
      _mk('PH10242', 'c3', [('p4', 1)], 74, 'Wallet', 4, partner: 'd3'),
      _mk('PH10241', 'c1', [('p9', 1)], 100, 'Cash on Delivery', 4, partner: 'd2'),
      _mk('PH10240', 'c5', [('p8', 1)], 125, 'UPI', 4, partner: 'd1'),
      _mk('PH10239', 'c4', [('p7', 1)], 150, 'UPI', 1, cancelled: true),
      _mk('PH10238', 'c2', [('p1', 1)], 170, 'Debit/Credit Card', 4, partner: 'd3'),
      _mk('PH10237', 'c3', [('p2', 1), ('p10', 1)], 200, 'UPI', 4, discount: 1000, coupon: 'DIWALI1000', partner: 'd2'),
      _mk('PH10236', 'c1', [('p3', 1)], 240, 'Cash on Delivery', 2, cancelled: true),
    ];
    refunds.addAll([
      Refund('RF2001', 'PH10239', orders.firstWhere((o) => o.id == 'PH10239').total, 'Customer changed mind', 'Requested', DateTime.now().subtract(const Duration(hours: 148))),
      Refund('RF2000', 'PH10231', 22499, 'Phone not as described', 'Refunded', DateTime.now().subtract(const Duration(days: 9))),
    ]);
  }

  void _seedSupport() {
    final now = DateTime.now();
    tickets.addAll([
      Ticket(id: 'T3004', customerId: 'c3', subject: 'Order not yet packed', status: 'Open', created: now.subtract(const Duration(hours: 2)), messages: [
        ChatMsg(false, 'Hi, I placed an order PH10248 an hour ago. When will it be packed?', now.subtract(const Duration(hours: 2))),
      ]),
      Ticket(id: 'T3003', customerId: 'c2', subject: 'Want to change delivery address', status: 'In Progress', created: now.subtract(const Duration(days: 1)), messages: [
        ChatMsg(false, 'Can I change the delivery address to my office?', now.subtract(const Duration(days: 1))),
        ChatMsg(true, 'Sure Amit, please share the new address and pincode.', now.subtract(const Duration(hours: 22))),
      ]),
      Ticket(id: 'T3002', customerId: 'c5', subject: 'Battery health question', status: 'Resolved', created: now.subtract(const Duration(days: 3)), messages: [
        ChatMsg(false, 'The battery shows 88%, is that normal for a Good condition phone?', now.subtract(const Duration(days: 3))),
        ChatMsg(true, 'Yes, 85% and above is normal for Good condition phones.', now.subtract(const Duration(days: 3))),
      ]),
      Ticket(id: 'T3001', customerId: 'c1', subject: 'Refund status', status: 'Resolved', created: now.subtract(const Duration(days: 8)), messages: [
        ChatMsg(false, 'When will I get my refund?', now.subtract(const Duration(days: 8))),
        ChatMsg(true, 'Refunds reach your account in 5-7 working days.', now.subtract(const Duration(days: 8))),
      ]),
    ]);
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
      if (o.cancelled) {
        status = o.isCod ? 'Failed' : 'Refunded';
      } else if (o.isCod) {
        status = o.isDelivered ? 'Success' : 'Pending';
      } else {
        status = 'Success';
      }
      return Txn('TXN${o.id.substring(2)}', o.id, o.paymentMethod, o.total, status, o.placedAt);
    }).toList();
  }

  List<AlertItem> get alerts {
    final l = <AlertItem>[];
    for (final o in orders.where((o) => !o.cancelled && o.stage == 0)) {
      l.add(AlertItem(Icons.shopping_bag_rounded, AC_primary, 'New order ${o.id}', '${customerName(o.customerId)} ordered ${o.itemCount} item(s) worth ₹${o.total}', o.placedAt));
    }
    for (final p in phones.where((p) => p.stock <= 3)) {
      l.add(AlertItem(Icons.inventory_2_rounded, p.stock == 0 ? AC_danger : AC_warning, p.stock == 0 ? '${p.name} is out of stock' : 'Low stock: ${p.name}', 'Only ${p.stock} left in inventory', DateTime.now().subtract(const Duration(hours: 5))));
    }
    for (final r in refunds.where((r) => r.status == 'Requested')) {
      l.add(AlertItem(Icons.currency_rupee_rounded, AC_warning, 'Refund requested', '${r.orderId} • ₹${r.amount} • ${r.reason}', r.date));
    }
    for (final t in tickets.where((t) => t.status == 'Open')) {
      l.add(AlertItem(Icons.headset_mic_rounded, AC_info, 'New support ticket', '${customerName(t.customerId)}: ${t.subject}', t.created));
    }
    l.sort((a, b) => b.time.compareTo(a.time));
    return l;
  }

  // ---------------- Actions ----------------
  void changed() => notifyListeners();

  void setStage(AdminOrder o, int stage) {
    o.stage = stage.clamp(0, 4);
    notifyListeners();
  }

  void assignPartner(AdminOrder o, String partnerId) {
    o.partnerId = partnerId;
    notifyListeners();
  }

  /// Cancels an order, puts the stock back and opens a refund for online payments.
  void cancelOrder(AdminOrder o, String reason) {
    if (o.cancelled) return;
    o.cancelled = true;
    for (final it in o.items) {
      final p = phoneById(it.phoneId);
      if (p != null) p.stock += it.qty;
    }
    if (!o.isCod) {
      refunds.insert(0, Refund('RF${2002 + refunds.length}', o.id, o.total, reason, 'Requested', DateTime.now()));
    }
    notifyListeners();
  }

  void setRefund(Refund r, String status) {
    r.status = status;
    notifyListeners();
  }

  void addPhone(Phone p) {
    phones.insert(0, p);
    notifyListeners();
  }

  void deletePhone(Phone p) {
    phones.remove(p);
    notifyListeners();
  }

  void setStock(Phone p, int stock) {
    p.stock = stock < 0 ? 0 : stock;
    notifyListeners();
  }

  void addTicketReply(Ticket t, String text) {
    t.messages.add(ChatMsg(true, text, DateTime.now()));
    if (t.status == 'Open') t.status = 'In Progress';
    notifyListeners();
  }

  void sendNotification(String title, String body, String audience) {
    sentNotifs.insert(0, SentNotif(title, body, audience, DateTime.now()));
    notifyListeners();
  }

  String nextPhoneId() => 'p${phones.length + 100 + DateTime.now().millisecondsSinceEpoch % 1000}';
}

// Colours used inside the store (kept here so admin_data.dart does not need the theme import).
const AC_primary = Color(0xFF1B2A5C);
const AC_danger = Color(0xFFEF4444);
const AC_warning = Color(0xFFF59E0B);
const AC_info = Color(0xFF2563EB);

/// One shared store for the whole admin app.
final AdminStore store = AdminStore();
