import 'package:flutter/material.dart';
import '../../customer/theme.dart';
import '../common.dart';
import '../orders_data.dart';
import 'navigation_screen.dart';

/// Screen 3 – Delivery Details (2h)
/// Customer name and call, address with View on Map, order items, order ID,
/// payment status, Mark as Picked Up.
class DeliveryDetailsScreen extends StatelessWidget {
  final DeliveryOrder order;
  const DeliveryDetailsScreen({super.key, required this.order});

  void _openMap(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationScreen(order: order)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DeliveryOrder>>(
      valueListenable: orders,
      builder: (context, orderList, child) {
        final s = order.status;
        final label = s == 'Assigned' ? 'Mark as Picked Up' : (s == 'Picked Up' ? 'Start Navigation' : 'Delivered');
        return Scaffold(
          appBar: AppBar(title: const Text('Delivery Details')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              // Order header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order ID', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                          Text('#${order.id}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text('${order.dateLabel} • ${order.slot}', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: StatusBadge(s),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Customer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Row(
                  children: [
                    CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(order.customer[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 20))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          Text(order.customer, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text(order.phone, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.call_rounded,
                      color: AppColors.success,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('Calling ${order.customer}…'))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Address
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(order.address, style: const TextStyle(color: AppColors.muted, height: 1.45, fontSize: 14)),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      onPressed: () => _openMap(context),
                      icon: const Icon(Icons.map_rounded, size: 20),
                      label: const Text('View on Map', style: TextStyle(fontSize: 14.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Items
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Order Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order Value', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        Text(rupee(order.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Payment status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (order.isCod ? AppColors.accent : AppColors.success).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(order.isCod ? Icons.payments_rounded : Icons.verified_rounded, color: order.isCod ? AppColors.accent : AppColors.success, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Status', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          Text(
                            order.isCod ? 'Cash on Delivery – collect ${rupee(order.amount)}' : 'Paid Online – nothing to collect',
                            style: TextStyle(fontWeight: FontWeight.w800, color: order.isCod ? const Color(0xFFB45309) : AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, -6))]),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: s == 'Delivered'
                    ? null
                    : () {
                  if (s == 'Assigned') updateStatus(order, 'Picked Up');
                  _openMap(context);
                },
                icon: Icon(s == 'Delivered' ? Icons.check_circle_rounded : (s == 'Assigned' ? Icons.inventory_rounded : Icons.navigation_rounded)),
                label: Text(label),
              ),
            ),
          ),
        );
      },
    );
  }
}
