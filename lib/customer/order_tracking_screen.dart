import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'home_screen.dart';

/// Screen 7 – Order Tracking
/// Order ID and status badge, timeline (Placed → Payment Confirmed → Packed →
/// Out for Delivery → Delivered), map placeholder, delivery partner card with call/chat,
/// full order details, and Cancel / Reorder actions.
class OrderTrackingScreen extends StatefulWidget {
  /// The order to show. When null the latest order is shown.
  final Order? order;
  final bool fromPayment;
  const OrderTrackingScreen({super.key, this.order, this.fromPayment = false});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Timer? _timer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderSubscription;
  bool _firebaseLoading = false;
  String? _firebaseError;
  static const _partnerPhone = '+91 98765 11111';

  @override
  void initState() {
    super.initState();
    _listenForOrderUpdates();
  }

  void _listenForOrderUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _firebaseLoading = true;
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final remoteOrders = snapshot.docs.map(Order.fromFirestore).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      if (remoteOrders.isNotEmpty) {
        orders.value = remoteOrders;
      }
      if (mounted) setState(() { _firebaseLoading = false; _firebaseError = null; });
    }, onError: (Object error) {
      if (mounted) setState(() { _firebaseLoading = false; _firebaseError = error.toString(); });
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Order get _order {
    final requested = widget.order;
    if (requested != null) {
      for (final item in orders.value) { if (item.id == requested.id) return item; }
      return requested;
    }
    if (orders.value.isNotEmpty) return orders.value.first;
    throw StateError('No order is available');
  }

  Color _statusColor(Order o) => o.cancelled ? AppColors.danger : (o.isDelivered ? AppColors.success : AppColors.accent);

  Future<void> _confirmCancel(Order o) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Cancel this order?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Your refund will be sent to the original payment method within 5-7 working days.', style: TextStyle(color: AppColors.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order', style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger))),
        ],
      ),
    );
    if (yes == true && mounted) {
      cancelOrder(o);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try { await FirebaseFirestore.instance.collection('orders').doc(o.id).update({'status': 'Cancelled', 'updatedAt': FieldValue.serverTimestamp()}); }
        catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update order in Firebase. Please check connection and rules.'))); }
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled')));
    }
  }

  void _call() {
    Clipboard.setData(const ClipboardData(text: _partnerPhone));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rahul\'s number copied. Open your dialer to call.')));
  }

  void _chat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const _ChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Order>>(
      valueListenable: orders,
      builder: (context, _, __) {
        if (orders.value.isEmpty) {
          return Scaffold(appBar: AppBar(title: const Text('Order Tracking')), body: Center(child: _firebaseError != null ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 48), const SizedBox(height: 12), const Text('Could not load your order from Firebase.'), const SizedBox(height: 8), Text(_firebaseError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)), const SizedBox(height: 12), ElevatedButton(onPressed: () { setState(() { _firebaseError = null; _firebaseLoading = true; }); _listenForOrderUpdates(); }, child: const Text('Retry'))])) : const CircularProgressIndicator()));
              }
              final o = _order;
              final stage = o.stage;
              final p = o.items.first.phone;
              final statusColor = _statusColor(o);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Order Tracking'),
              automaticallyImplyLeading: !widget.fromPayment,
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (widget.fromPayment)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order placed successfully 🎉', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
                              Text('We will keep you updated on every step.', style: TextStyle(color: AppColors.success, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Order header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDeco(),
                  child: Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 62, height: 62, child: PhoneImage(phone: p, height: 62, iconSize: 30))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Order ID', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                            Text(o.id, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                        child: Text(o.statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (o.cancelled)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: AppColors.danger, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('This order was cancelled. Any amount paid will be refunded in 5-7 working days.', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.35)),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Timeline
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
                    decoration: cardDeco(),
                    child: Column(
                      children: [
                        for (int k = 0; k < orderSteps.length; k++)
                          _Step(
                            orderSteps[k],
                            _subtitle(o, k, stage),
                            stage >= 4 || k < stage ? _S.done : (k == stage ? _S.current : _S.pending),
                            k == orderSteps.length - 1,
                            icon: k == 3 ? Icons.two_wheeler_rounded : Icons.inventory_2_rounded,
                          ),
                      ],
                    ),
                  ),
                ],

                // Map + delivery partner only while the order is on the road
                if (!o.cancelled && stage == 3) ...[
                  const SizedBox(height: 18),
                  Container(
                    height: 210,
                    clipBehavior: Clip.antiAlias,
                    decoration: cardDeco(radius: 24),
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _MapPainter())),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 14)]),
                            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
                            child: const Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('ETA 12 mins • 3.4 km', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Delivery partner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDeco(),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 26, backgroundColor: AppColors.primary, child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rahul Patil', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                  SizedBox(width: 3),
                                  Text('4.8 • Delivery Partner', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _roundBtn(Icons.chat_bubble_rounded, AppColors.primary, _chat),
                        const SizedBox(width: 10),
                        _roundBtn(Icons.call_rounded, AppColors.success, _call),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                _details(o),

                const SizedBox(height: 22),
                if (!o.cancelled && stage < 3)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger, width: 1.4)),
                    onPressed: () => _confirmCancel(o),
                    child: const Text('Cancel Order'),
                  ),
                if (o.isDelivered || o.cancelled)
                  ElevatedButton(
                    onPressed: () {
                      reorder(o);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items added to your cart')));
                    },
                    child: const Text('Reorder'),
                  ),
                if (widget.fromPayment) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (r) => false),
                    child: const Text('Continue Shopping'),
                  ),
                ],
              ],
            ),
          );
        },
    );
  }

  String _subtitle(Order o, int k, int stage) {
    if (stage >= 4 || k < stage) return fmtDateTime(o.stepTime(k));
    if (k == stage) return k == 3 ? o.etaText : 'In progress';
    return 'Pending';
  }

  /// Items, price breakup, address and payment method of the order.
  Widget _details(Order o) {
    Widget row(String l, String v, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 16 : 13.5, color: bold ? AppColors.text : AppColors.muted)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 16 : 13.5, color: color ?? (bold ? AppColors.primary : AppColors.text))),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          for (final it in o.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 44, height: 44, child: PhoneImage(phone: it.phone, height: 44, iconSize: 20))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.phone.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        Text('${it.storage} • ${it.condition} • Qty ${it.qty}', style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Text(rupee(it.phone.price * it.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                ],
              ),
            ),
          const Divider(height: 20),
          row('Items (${o.itemCount})', rupee(o.subtotal)),
          row('Delivery', o.delivery == 0 ? 'FREE' : rupee(o.delivery), color: o.delivery == 0 ? AppColors.success : null),
          if (o.discount > 0) row('Coupon (${o.couponCode})', '- ${rupee(o.discount)}', color: AppColors.success),
          const Divider(height: 20),
          row('Total paid', rupee(o.total), bold: true),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('${o.addressLabel}: ${o.addressLine}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Paid via ${o.paymentMethod}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Placed on ${fmtDateTime(o.placedAt)}', style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData i, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(i, color: c, size: 20),
    ),
  );
}

enum _S { done, current, pending }

class _Step extends StatelessWidget {
  final String title, subtitle;
  final _S state;
  final bool last;
  final IconData icon;
  const _Step(this.title, this.subtitle, this.state, this.last, {this.icon = Icons.two_wheeler_rounded});

  @override
  Widget build(BuildContext context) {
    final color = state == _S.pending ? AppColors.border : (state == _S.current ? AppColors.accent : AppColors.success);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: state == _S.pending ? Colors.white : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: state == _S.current ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)] : null,
                ),
                child: state == _S.done
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : state == _S.current
                    ? Icon(icon, size: 14, color: Colors.white)
                    : null,
              ),
              if (!last) Expanded(child: Container(width: 2.5, color: state == _S.done ? AppColors.success : AppColors.border)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: state == _S.pending ? AppColors.muted : AppColors.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple local chat with the delivery partner (replies are canned until a real chat backend is connected).
class _ChatSheet extends StatefulWidget {
  const _ChatSheet();

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _ctrl = TextEditingController();
  final List<(bool, String)> _msgs = [(false, 'Hi! I\'m Rahul, your delivery partner. I\'m on my way with your order.')];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() => _msgs.add((true, t)));
    _ctrl.clear();
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _msgs.add((false, 'Okay, noted! I\'ll be there in a few minutes.')));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chat with Rahul', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in _msgs)
                  Align(
                    alignment: m.$1 ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(color: m.$1 ? AppColors.primary : AppColors.bg, borderRadius: BorderRadius.circular(16)),
                      child: Text(m.$2, style: TextStyle(color: m.$1 ? Colors.white : AppColors.text, fontSize: 13.5)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _send,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE8EEF9));

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    for (final fy in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(0, s.height * fy), Offset(s.width, s.height * fy), road);
    }
    for (final fx in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(s.width * fx, 0), Offset(s.width * fx, s.height), road);
    }

    final route = Path()
      ..moveTo(s.width * 0.2, s.height * 0.8)
      ..lineTo(s.width * 0.5, s.height * 0.8)
      ..lineTo(s.width * 0.5, s.height * 0.2)
      ..lineTo(s.width * 0.8, s.height * 0.2);
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(Offset(s.width * 0.2, s.height * 0.8), 9, Paint()..color = AppColors.success);
    canvas.drawCircle(Offset(s.width * 0.2, s.height * 0.8), 4, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.2), 11, Paint()..color = AppColors.danger);
    canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.2), 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}