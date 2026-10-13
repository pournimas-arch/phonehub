import 'package:flutter/material.dart';
import 'package:phonehub/Admin/coupons_screen.dart';
import 'package:phonehub/Admin/notification_support.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'package:phonehub/Admin/products_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';
class DashboardScreen extends StatefulWidget {
  final void Function(int tab) onTab;
  const DashboardScreen({super.key, required this.onTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String range = '7 days';

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  (List<String>, List<double>) _chart() {
    if (range == '7 days') return (store.dayLabels(7), store.revenueByDay(7));
    final d = store.revenueByDay(30);
    final now = DateTime.now();
    final labels = <String>[];
    final vals = <double>[];
    for (int b = 0; b < 6; b++) {
      var sum = 0.0;
      for (int i = b * 5; i < b * 5 + 5; i++) {
        sum += d[i];
      }
      vals.add(sum);
      final end = now.subtract(Duration(days: 29 - (b * 5 + 4)));
      labels.add('${end.day}/${end.month}');
    }
    return (labels, vals);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final chart = _chart();
        final status = store.ordersByStatus;
        final maxStatus = status.values.fold<int>(1, (a, b) => a > b ? a : b);
        final recent = store.orders.take(5).toList();
        final top = store.topPhones.take(4).toList();
        final brandRev = store.brandRevenue;
        final totalBrand = brandRev.fold<int>(0, (s, e) => s + e.value);
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back', style: TextStyle(color: AC.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(store.adminName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            actions: [
              Badge(
                isLabelVisible: store.alerts.isNotEmpty,
                label: Text('${store.alerts.length}'),
                alignment: const Alignment(0.5, -0.5),
                child: IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () => _push(const AdminNotificationsScreen(initialTab: 2))),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // Hero revenue card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's revenue", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(inr(store.todayRevenue), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _heroPill(Icons.trending_up_rounded, 'Total ${inr(store.totalRevenue)}'),
                        const SizedBox(width: 8),
                        _heroPill(Icons.receipt_long_rounded, '${store.orders.length} orders'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _stat(Icons.shopping_bag_rounded, AC.primary, '${store.todayOrders}', 'Orders today', () => widget.onTab(1)),
                  _stat(Icons.fiber_new_rounded, AC.accent, '${store.newOrders}', 'Need action', () => widget.onTab(1)),
                  _stat(Icons.people_rounded, AC.success, '${store.customers.length}', 'Customers', () => widget.onTab(3)),
                  _stat(Icons.inventory_2_rounded, AC.danger, '${store.lowStockCount}', 'Low stock', () => _push(const InventoryScreen())),
                ],
              ),

              SectionTitle('Quick actions'),
              Row(
                children: [
                  _quick(Icons.add_circle_rounded, 'Add phone', () => _push(const PhoneFormScreen())),
                  _quick(Icons.receipt_long_rounded, 'View orders', () => widget.onTab(1)),
                  _quick(Icons.sell_rounded, 'Add coupon', () => _push(const CouponFormScreen())),
                  _quick(Icons.campaign_rounded, 'Send push', () => _push(const AdminNotificationsScreen())),
                ],
              ),

              SectionTitle('Sales', trailing: _rangeSwitch()),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                decoration: cardDeco(),
                child: MiniBarChart(labels: chart.$1, values: chart.$2),
              ),

              SectionTitle('Orders by status'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Column(
                  children: [
                    for (final e in status.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 118, child: Text(e.key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(value: e.value / maxStatus, minHeight: 9, backgroundColor: AC.bg, color: statusColor(e.key)),
                              ),
                            ),
                            SizedBox(width: 28, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              SectionTitle('Recent orders', trailing: TextButton(onPressed: () => widget.onTab(1), child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w700)))),
              for (final o in recent) OrderTile(order: o),

              SectionTitle('Top selling phones'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: top.isEmpty
                    ? const Text('No sales yet', style: TextStyle(color: AC.muted))
                    : Column(
                  children: [
                    for (int i = 0; i < top.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 13, backgroundColor: i == 0 ? AC.accent : AC.bg, child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : AC.text))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(top[i].key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                            Text('${top[i].value} sold', style: const TextStyle(color: AC.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              SectionTitle('Top brands'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Column(
                  children: [
                    for (final e in brandRev.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 72, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(value: totalBrand == 0 ? 0 : e.value / totalBrand, minHeight: 9, backgroundColor: AC.bg, color: store.brands.where((b) => b.name == e.key).isEmpty ? AC.primary : store.brands.firstWhere((b) => b.name == e.key).color),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(inr(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroPill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _stat(IconData icon, Color color, String value, String label, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(),
      child: Row(
        children: [
          IconBadge(icon, color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AC.text)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _quick(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: cardDeco(radius: 18),
              child: Icon(icon, color: AC.primary, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AC.text)),
          ],
        ),
      ),
    ),
  );

  Widget _rangeSwitch() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.border)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in ['7 days', '30 days'])
          GestureDetector(
            onTap: () => setState(() => range = r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: range == r ? AC.primary : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Text(r, style: TextStyle(color: range == r ? Colors.white : AC.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    ),
  );
}
