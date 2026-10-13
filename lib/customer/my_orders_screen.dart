import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';
import 'shared_ui.dart';
import 'order_tracking_screen.dart';

// ---------- Shared styling (same as Home screen) ----------

BoxDecoration _glass({double radius = 18}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFFDCE8FF)),
  boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
);

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF4F8FF), Color(0xFFBBD5FB), Color(0xFF7FADEE)],
);

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob(this.size, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _segs = ['Ongoing', 'Delivered', 'Cancelled'];
  static const _steps = ['Ordered', 'Packed', 'Shipped', 'Delivery'];
  int seg = 0;


  bool _match(Order o) {
    switch (seg) {
      case 0:
        return o.isOngoing;
      case 1:
        return o.isDelivered;
      default:
        return o.cancelled;
    }
  }

  // ---- Header ----
  Widget _header(int total) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Track & manage', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
              const SizedBox(height: 1),
              const Text('My Orders', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: _glass(radius: 14),
          child: Text('$total ${total == 1 ? 'order' : 'orders'}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _glass(radius: 18),
      child: Row(
        children: [
          for (int i = 0; i < _segs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => seg = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: seg == i
                      ? BoxDecoration(
                    gradient: brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))],
                  )
                      : null,
                  alignment: Alignment.center,
                  child: Text(_segs[i], style: TextStyle(color: seg == i ? Colors.white : AppColors.muted, fontWeight: seg == i ? FontWeight.w800 : FontWeight.w700, fontSize: 11)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty() {
    const msgs = ['No ongoing orders', 'No delivered orders yet', 'No cancelled orders'];
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDCE8FF), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(msgs[seg], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('Your orders will show up here', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _orderCard(Order o) {
    final p = o.items.first.phone;
    final done = const [1, 1, 2, 3, 4][o.stage < 0 ? 0 : o.stage];
    final c = o.cancelled ? AppColors.danger : (o.isDelivered ? AppColors.success : AppColors.accent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Tap(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: o))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _glass(radius: 22),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 74, height: 74, child: PhoneImage(phone: p, height: 74, iconSize: 34))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.text)),
                        const SizedBox(height: 3),
                        Text('Order ${o.id}', style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${o.itemCount} ${o.itemCount == 1 ? 'item' : 'items'} • ${rupee(o.total)}', style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(o.cancelled ? Icons.cancel_rounded : (o.isDelivered ? Icons.check_circle_rounded : Icons.local_shipping_rounded), size: 12, color: c),
                              const SizedBox(width: 4),
                              Text(o.statusLabel, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
              if (!o.cancelled) ...[
                const SizedBox(height: 18),
                // Progress tracker
                Row(
                  children: [
                    for (int i = 0; i < _steps.length; i++) ...[
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < done ? AppColors.primary : const Color(0xFFE3ECFB),
                          boxShadow: i < done ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))] : null,
                        ),
                        child: i < done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                      ),
                      if (i != _steps.length - 1)
                        Expanded(child: Container(height: 3, decoration: BoxDecoration(color: i < done - 1 ? AppColors.primary : const Color(0xFFE3ECFB), borderRadius: BorderRadius.circular(2)))),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final s in _steps) Text(s, style: const TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(o.isOngoing ? 'Track Order' : 'View Details', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersFromFirebase() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _header(0),
          const SizedBox(height: 18),
          _segmented(),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: Text('Please log in to view your orders', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700))),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              _header(0),
              const SizedBox(height: 18),
              _segmented(),
              const SizedBox(height: 18),
              const Center(child: Text('Could not load orders. Check your connection and Firestore Rules.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.text))),
              Center(child: TextButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))),
            ],
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              _header(0),
              const SizedBox(height: 18),
              _segmented(),
              const SizedBox(height: 48),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(child: Text('Loading your orders...', style: TextStyle(color: AppColors.muted))),
            ],
          );
        }

        final all = (snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map((doc) => Order.fromFirestore(doc))
            .toList()
          ..sort((a, b) => (b.placedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.placedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        final list = all.where(_match).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            _header(all.length),
            const SizedBox(height: 18),
            _segmented(),
            const SizedBox(height: 18),
            if (list.isEmpty) _empty() else for (final o in list) _orderCard(o),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(gradient: _bgGradient),
          child: Stack(
            children: [
              Positioned(top: -70, right: -80, child: _Blob(240, 0.35)),
              Positioned(top: 420, left: -120, child: _Blob(280, 0.20)),
              SafeArea(
                bottom: false,
                child: _buildOrdersFromFirebase(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}