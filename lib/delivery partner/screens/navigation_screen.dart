import 'package:flutter/material.dart';
import '../../customer/theme.dart';
import '../common.dart';
import '../orders_data.dart';
import 'confirm_delivery_screen.dart';

/// Screen 4 – Navigation (3h)
/// Map with route placeholder, ETA and distance, address card, Open in Google Maps button.
class NavigationScreen extends StatelessWidget {
  final DeliveryOrder order;
  final bool showBack;
  const NavigationScreen({super.key, required this.order, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: MapPlaceholder()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (showBack)
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
                              child: const Icon(Icons.arrow_back_rounded, size: 21),
                            ),
                          ),
                        if (showBack) const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
                            child: Row(
                              children: [
                                const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Heading to ${order.area}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -8))],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('12', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary)),
                      const SizedBox(width: 4),
                      const Padding(padding: EdgeInsets.only(top: 12), child: Text('min', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                      const SizedBox(width: 14),
                      Container(width: 1, height: 30, color: AppColors.border),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('3.4 km', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text('Distance', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Text('Fastest route', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customer, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text(order.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Opening Google Maps…'))),
                    icon: const Icon(Icons.map_rounded, size: 20),
                    label: const Text('Open in Google Maps', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmDeliveryScreen(order: order))),
                    child: const Text('Reached • Confirm Delivery'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
