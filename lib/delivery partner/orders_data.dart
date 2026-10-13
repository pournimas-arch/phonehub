import 'package:flutter/material.dart';

class DeliveryOrder {
  final String id, customer, phone, area, address, slot, payment, dateLabel;
  final List<String> items;
  final int amount, earning;
  final bool isToday;
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
  });

  bool get isCod => payment == 'Cash on Delivery';
}

final ValueNotifier<List<DeliveryOrder>> orders = ValueNotifier<List<DeliveryOrder>>([
  DeliveryOrder(
    id: 'PH-4821', customer: 'Rohan Mehta', phone: '+91 98220 11234', area: 'Kothrud',
    address: 'Flat 402, Sai Heights, Karve Road, Kothrud, Pune 411038',
    slot: '10:00 AM – 12:00 PM', payment: 'Paid Online',
    items: ['iPhone 13 • 128 GB • Like New', 'Original charger & box'],
    amount: 42999, earning: 80, isToday: true, dateLabel: 'Today',
  ),
  DeliveryOrder(
    id: 'PH-4822', customer: 'Sneha Kulkarni', phone: '+91 98900 45612', area: 'Baner',
    address: 'B-12, Orchid Residency, Baner Road, Pune 411045',
    slot: '12:00 PM – 02:00 PM', payment: 'Cash on Delivery',
    items: ['Galaxy A54 • 128 GB • Like New', 'Tempered glass'],
    amount: 22499, earning: 70, isToday: true, dateLabel: 'Today',
  ),
  DeliveryOrder(
    id: 'PH-4823', customer: 'Amit Deshmukh', phone: '+91 97300 88721', area: 'Viman Nagar',
    address: '7th Floor, Skyline Towers, Viman Nagar, Pune 411014',
    slot: '02:00 PM – 04:00 PM', payment: 'Paid Online',
    items: ['OnePlus 11R • 256 GB • Like New', 'Back cover'],
    amount: 31999, earning: 90, isToday: true, dateLabel: 'Today',
  ),
  DeliveryOrder(
    id: 'PH-4824', customer: 'Priya Joshi', phone: '+91 99220 70345', area: 'Hinjewadi',
    address: 'Wing C, Blue Ridge Society, Phase 1, Hinjewadi, Pune 411057',
    slot: '04:00 PM – 06:00 PM', payment: 'Cash on Delivery',
    items: ['Realme 11 Pro • 128 GB • Like New'],
    amount: 17999, earning: 100, isToday: true, dateLabel: 'Today',
  ),
  DeliveryOrder(
    id: 'PH-4830', customer: 'Vikas Pawar', phone: '+91 98500 33210', area: 'Wakad',
    address: '12, Green Park Colony, Wakad Road, Pune 411057',
    slot: '10:00 AM – 12:00 PM', payment: 'Paid Online',
    items: ['Redmi Note 12 Pro • 128 GB • Fair'],
    amount: 12499, earning: 60, isToday: false, dateLabel: 'Sat, 10 Oct',
  ),
  DeliveryOrder(
    id: 'PH-4831', customer: 'Neha Shah', phone: '+91 99701 66780', area: 'Aundh',
    address: 'A-204, Prestige Park, ITI Road, Aundh, Pune 411007',
    slot: '01:00 PM – 03:00 PM', payment: 'Cash on Delivery',
    items: ['iPhone 12 • 64 GB • Good'],
    amount: 29999, earning: 85, isToday: false, dateLabel: 'Sat, 10 Oct',
  ),
  DeliveryOrder(
    id: 'PH-4832', customer: 'Karan Patil', phone: '+91 98230 99015', area: 'Kharadi',
    address: 'Tower 3, EON Residency, Kharadi, Pune 411014',
    slot: '11:00 AM – 01:00 PM', payment: 'Paid Online',
    items: ['Xiaomi 11T Pro • 256 GB • Good'],
    amount: 24999, earning: 75, isToday: false, dateLabel: 'Sun, 11 Oct',
  ),
]);

void updateStatus(DeliveryOrder o, String s) {
  o.status = s;
  orders.value = List<DeliveryOrder>.from(orders.value);
}

// ---------------- Earnings ----------------

class EarningRecord {
  final String orderId, customer;
  final int dayOffset; // days ago
  final int amount;
  const EarningRecord(this.orderId, this.customer, this.dayOffset, this.amount);

  String get dateLabel => formatDate(DateTime.now().subtract(Duration(days: dayOffset)));
}

const historicalEarnings = [
  EarningRecord('PH-4801', 'Aditya Rao', 1, 80),
  EarningRecord('PH-4802', 'Pooja Nair', 1, 70),
  EarningRecord('PH-4803', 'Sameer Khan', 2, 90),
  EarningRecord('PH-4799', 'Manisha Gore', 3, 100),
  EarningRecord('PH-4796', 'Tushar Jadhav', 4, 60),
  EarningRecord('PH-4794', 'Isha Bhosale', 5, 85),
  EarningRecord('PH-4790', 'Nikhil Shinde', 6, 75),
  EarningRecord('PH-4781', 'Ritu Sharma', 8, 80),
  EarningRecord('PH-4779', 'Omkar Deshpande', 9, 95),
  EarningRecord('PH-4775', 'Anjali Menon', 10, 70),
  EarningRecord('PH-4770', 'Harsh Verma', 12, 60),
  EarningRecord('PH-4766', 'Kavita More', 13, 90),
  EarningRecord('PH-4752', 'Sagar Thorat', 16, 80),
  EarningRecord('PH-4741', 'Meera Iyer', 20, 100),
  EarningRecord('PH-4730', 'Yash Gaikwad', 25, 70),
];

/// filter: 0 = This Week, 1 = Last Week, 2 = This Month
List<EarningRecord> earningsFor(int filter) {
  final today = orders.value
      .where((o) => o.status == 'Delivered')
      .map((o) => EarningRecord(o.id, o.customer, 0, o.earning));
  final all = [...today, ...historicalEarnings];
  bool ok(int d) => filter == 0 ? d <= 6 : (filter == 1 ? (d >= 7 && d <= 13) : d <= 29);
  final list = all.where((e) => ok(e.dayOffset)).toList();
  list.sort((a, b) => a.dayOffset.compareTo(b.dayOffset));
  return list;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

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