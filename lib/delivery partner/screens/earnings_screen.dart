import 'package:flutter/material.dart';
import '../../customer/theme.dart';
import '../common.dart';
import '../orders_data.dart';

/// Screen 6 – Earnings (2h)
/// Total earnings with week filter, per-order earnings list with date and Delivered badge.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int filter = 0;
  static const filters = ['This Week', 'Last Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ValueListenableBuilder<List<DeliveryOrder>>(
        valueListenable: orders,
        builder: (context, orderList, child) {
          final list = earningsFor(filter);
          final total = list.fold<int>(0, (s, e) => s + e.amount);
          final avg = list.isEmpty ? 0 : (total / list.length).round();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              // Filter
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final on = i == filter;
                    return GestureDetector(
                      onTap: () => setState(() => filter = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: on ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(filters[i], style: TextStyle(color: on ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              // Total card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.32), blurRadius: 22, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Earnings • ${filters[filter]}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
                    const SizedBox(height: 6),
                    Text(rupee(total), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _mini(Icons.inventory_2_rounded, '${list.length}', 'Deliveries'),
                        const SizedBox(width: 10),
                        _mini(Icons.trending_up_rounded, rupee(avg), 'Avg / order'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('Earnings per order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No earnings in this period', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
                ),
              for (final e in list)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: cardDeco(radius: 18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('#${e.orderId} • ${e.dayOffset == 0 ? 'Today' : e.dateLabel}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('+${rupee(e.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.success)),
                          const SizedBox(height: 4),
                          const StatusBadge('Delivered'),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _mini(IconData i, String v, String l) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(i, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text(l, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
