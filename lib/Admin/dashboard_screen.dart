import 'package:flutter/material.dart';
import 'package:phonehub/Admin/coupons_screen.dart';
import 'package:phonehub/Admin/inventory_screen.dart';
import 'package:phonehub/Admin/notification_support.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'package:phonehub/Admin/phone_form_screen.dart';
import 'package:phonehub/Admin/products_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';
import 'package:phonehub/app_text.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tab) onTab;

  const DashboardScreen({super.key, required this.onTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String range = '7 days';

  // 1.0 = full size. Lower = smaller text (0.92 is a little smaller).
  static const double _textScale = 0.92;

  void _push(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  // ---- small helpers -------------------------------------------------------

  String _greeting() {
    final h = DateTime
        .now()
        .hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _todayText() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }

  String _initial() {
    final n = store.adminName.trim();
    return n.isEmpty ? 'A' : n[0].toUpperCase();
  }

  Color _brandColor(String name) {
    for (final b in store.brands) {
      if (b.name == name) return b.color;
    }
    return AC.primary;
  }

  /// Revenue growth of the last 7 days compared with the 7 days before.
  /// Returns null when there is nothing to compare with.
  double? _weekGrowth() {
    final d = store.revenueByDay(14);
    if (d.length < 14) return null;
    final prev = d.sublist(d.length - 14, d.length - 7).fold<double>(
        0, (a, b) => a + b);
    final cur = d.sublist(d.length - 7).fold<double>(0, (a, b) => a + b);
    if (prev <= 0) return null;
    return (cur - prev) / prev * 100;
  }

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

  BoxDecoration _card() => cardDeco();

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: _textScale,
      maxScaleFactor: _textScale,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final chart = _chart();
          final chartTotal = chart.$2.fold<double>(0, (a, b) => a + b);
          final status = store.ordersByStatus;
          final statusTotal = status.values.fold<int>(0, (a, b) => a + b);
          final recent = store.orders.take(5).toList();
          final top = store.topPhones.take(4).toList();
          final maxSold = top.fold<int>(1, (a, e) => e.value > a ? e.value : a);
          final brandRev = store.brandRevenue;
          final totalBrand = brandRev.fold<int>(0, (s, e) => s + e.value);
          final growth = _weekGrowth();
          final aov = store.orders.isEmpty ? 0 : (store.totalRevenue /
              store.orders.length).round();

          return Scaffold(
            appBar: AppBar(
              centerTitle: false,
              automaticallyImplyLeading: false,
              // no back arrow on the dashboard
              toolbarHeight: 64,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, gradient: adminGradient),
                    child: Text(_initial(), style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: AppText.body)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(store.adminName, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800,
                                fontSize: AppText.title)),
                        Text('${_greeting()} · ${_todayText()}', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AC.muted,
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Badge(
                  isLabelVisible: store.alerts.isNotEmpty,
                  label: Text('${store.alerts.length}'),
                  alignment: const Alignment(0.5, -0.5),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () =>
                        _push(const AdminNotificationsScreen(initialTab: 2)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
              children: [
                _hero(growth, aov),
                const SizedBox(height: 10),
                _actionRequired(),
                const SizedBox(height: 10),
                _snapshot(),

                SectionTitle('Quick actions'),
                _quickGrid(),

                SectionTitle('Sales', trailing: _rangeSwitch()),
                Container(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 8),
                  decoration: _card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(inr(chartTotal.round()), style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AC.text)),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text('in last $range',
                                style: const TextStyle(
                                    fontSize: AppText.small, color: AC.muted)),
                          ),
                          const Spacer(),
                          if (range == '7 days' && growth != null) _growthPill(
                              growth, dark: false),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MiniBarChart(labels: chart.$1, values: chart.$2),
                    ],
                  ),
                ),

                SectionTitle('Orders by status',
                    trailing: _seeAll(() => widget.onTab(1))),
                _statusCard(status, statusTotal),

                SectionTitle(
                    'Recent orders', trailing: _seeAll(() => widget.onTab(1))),
                if (recent.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: _card(),
                    child: const Text('No orders yet', style: TextStyle(
                        color: AC.muted, fontSize: AppText.body)),
                  )
                else
                  for (final o in recent) OrderTile(order: o),

                SectionTitle('Top selling phones'),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: _card(),
                  child: top.isEmpty
                      ? const Text('No sales yet',
                      style: TextStyle(color: AC.muted, fontSize: AppText.body))
                      : Column(
                    children: [
                      for (int i = 0; i < top.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: i == 0 ? AC.accent : AC.bg,
                                child: Text('${i + 1}', style: TextStyle(
                                    fontSize: AppText.small,
                                    fontWeight: FontWeight.w800,
                                    color: i == 0 ? Colors.white : AC.text)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 5,
                                child: Text(top[i].key, maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: AppText.body)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                      value: top[i].value / maxSold,
                                      minHeight: 8,
                                      backgroundColor: AC.bg,
                                      color: i == 0 ? AC.accent : AC.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 58,
                                child: Text('${top[i].value} sold',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: AC.muted,
                                        fontSize: AppText.small,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                SectionTitle('Top brands'),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: _card(),
                  child: brandRev.isEmpty
                      ? const Text('No brand sales yet',
                      style: TextStyle(color: AC.muted, fontSize: AppText.body))
                      : Column(
                    children: [
                      for (final e in brandRev.take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: _brandColor(e.key),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              SizedBox(width: 64,
                                  child: Text(e.key, maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: AppText.body))),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                      value: totalBrand == 0 ? 0 : e.value /
                                          totalBrand,
                                      minHeight: 8,
                                      backgroundColor: AC.bg,
                                      color: _brandColor(e.key)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(inr(e.value), style: const TextStyle(
                                  fontSize: AppText.small,
                                  fontWeight: FontWeight.w800)),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  totalBrand == 0 ? '0%' : '${(e.value /
                                      totalBrand * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: AppText.small,
                                      color: AC.muted,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
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
      ),
    );
  }

  // ===========================================================================
  // ORDERS BY STATUS CARD  (paste this whole block inside _DashboardScreenState,
  // for example right above the line:  // ---- hero ----)
  // ===========================================================================

  IconData _statusIcon(String key) {
    final k = key.toLowerCase();
    if (k.contains('cancel')) return Icons.cancel_rounded;
    if (k.contains('out for')) return Icons.local_shipping_rounded;
    if (k.contains('deliver')) return Icons.check_circle_rounded;
    if (k.contains('pack')) return Icons.inventory_2_rounded;
    if (k.contains('payment')) return Icons.payments_rounded;
    if (k.contains('placed')) return Icons.shopping_bag_rounded;
    return Icons.receipt_long_rounded;
  }

  Widget _statusCard(Map<String, int> status, int total) {
    final entries = status.entries.toList();
    final delivered = status['Delivered'] ?? 0;
    final pct = total == 0 ? 0 : (delivered / total * 100).round();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- header: total orders + delivered % ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$total', style: const TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AC.text,
                  height: 1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(total == 1 ? 'order in total' : 'orders in total',
                    style: const TextStyle(fontSize: AppText.small,
                        color: AC.muted,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AC.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 13,
                        color: AC.success),
                    const SizedBox(width: 4),
                    Text('$pct% delivered', style: const TextStyle(
                        fontSize: AppText.small,
                        fontWeight: FontWeight.w700,
                        color: AC.success)),
                  ],
                ),
              ),
            ],
          ),

          // ---- one thin bar showing how orders are split ----
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  for (final e in entries)
                    if (e.value > 0) Expanded(flex: e.value,
                        child: Container(height: 6,
                            margin: const EdgeInsets.only(right: 2),
                            color: statusColor(e.key))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ---- status tiles: 3 per row ----
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 92,
            ),
            itemBuilder: (_, i) =>
                _statusTile(entries[i].key, entries[i].value),
          ),
        ],
      ),
    );
  }

  Widget _statusTile(String label, int count) {
    final c = statusColor(label);
    final active = count > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => widget.onTab(1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.08) : AC.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? c.withValues(alpha: 0.30) : AC.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _statusIcon(label), size: 17, color: active ? c : AC.muted),
                const SizedBox(width: 5),
                Text('$count', style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: active ? c : AC.muted)),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppText.small,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: active ? AC.text : AC.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ---- hero ----------------------------------------------------------------

  Widget _hero(double? growth, int aov) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            gradient: adminGradient, borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            Positioned(top: -34, right: -26, child: _circle(120, 0.07)),
            Positioned(bottom: -44, right: 70, child: _circle(90, 0.06)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      const Text("Today's revenue", style: TextStyle(
                          color: Colors.white70,
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (growth != null) _growthPill(growth, dark: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(inr(store.todayRevenue), style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7)),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        _heroStat('Total revenue', inr(store.totalRevenue)),
                        _heroDivider(),
                        _heroStat('Orders', '${store.orders.length}'),
                        _heroDivider(),
                        _heroStat('Avg. order', inr(aov)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _circle(double size, double alpha) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: alpha)),
      );

  Widget _heroDivider() =>
      Container(width: 1, height: 28, color: Colors.white24);

  Widget _heroStat(String label, String value) =>
      Expanded(
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(color: Colors.white,
                  fontSize: AppText.subtitle,
                  fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
                color: Colors.white70, fontSize: AppText.small)),
          ],
        ),
      );

  Widget _growthPill(double g, {required bool dark}) {
    final up = g >= 0;
    final color = dark ? Colors.white : (up ? AC.success : AC.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.18) : color.withValues(
            alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text('${up ? '+' : ''}${g.toStringAsFixed(1)}% vs last week',
              style: TextStyle(color: color,
                  fontSize: AppText.small,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ---- action required -------------------------------------------------------

  Widget _actionRequired() {
    final cards = <Widget>[];
    if (store.newOrders > 0) {
      cards.add(_alertCard(Icons.pending_actions_rounded, AC.accent,
          '${store.newOrders} new ${store.newOrders == 1 ? 'order' : 'orders'}',
          'Tap to review and confirm', () => widget.onTab(1)));
    }
    if (store.lowStockCount > 0) {
      cards.add(_alertCard(Icons.warning_amber_rounded, AC.danger,
          '${store.lowStockCount} low stock',
          'Restock before they sell out', () =>
              _push(const InventoryScreen())));
    }
    if (cards.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AC.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AC.success.withValues(alpha: 0.25))),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AC.success, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
                'All caught up. No orders or stock need your attention.',
                style: TextStyle(fontSize: AppText.body,
                    fontWeight: FontWeight.w600,
                    color: AC.text))),
          ],
        ),
      );
    }
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          cards[i],
        ],
      ],
    );
  }

  Widget _alertCard(IconData icon, Color color, String title, String sub,
      VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: AppText.body,
                              fontWeight: FontWeight.w800,
                              color: AC.text)),
                      Text(sub, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppText.small, color: AC.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      );

  // ---- snapshot (4 small stat cards) ----------------------------------------


  Widget _snapshot() =>
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          _stat(Icons.shopping_bag_rounded, AC.primary,
              '${store.todayOrders}', 'Orders today'),
          _stat(Icons.fiber_new_rounded, AC.accent,
              '${store.newOrders}', 'Need action'),
          _stat(Icons.people_rounded, AC.success,
              '${store.customers.length}', 'Customers'),
          _stat(Icons.inventory_2_rounded, AC.danger,
              '${store.lowStockCount}', 'Low stock'),
        ],
      );


  Widget _stat(IconData icon,
      Color color,
      String value,
      String label,) =>
      Container(
        padding: const EdgeInsets.all(11),
        decoration: _card(),
        child: Row(
          children: [
            IconBadge(icon, color, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AC.text,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AC.muted,
                      fontSize: AppText.small,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );


  // ---- quick actions (4 x 2 grid) ---------------------------------------------

  Widget _quickGrid() =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: _card(),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 4,
          childAspectRatio: 1.08,
          children: [
            _quick(Icons.add_circle_rounded, AC.primary, 'Add phone', () =>
                _push(const PhoneFormScreen())),
            _quick(Icons.receipt_long_rounded, AC.accent, 'Orders', () =>
                widget.onTab(1)),
            _quick(Icons.sell_rounded, AC.success, 'Add coupon', () =>
                _push(const CouponFormScreen())),
            _quick(Icons.campaign_rounded, AC.primary, 'Send push', () =>
                _push(const AdminNotificationsScreen())),
            _quick(Icons.people_alt_rounded, AC.success, 'Customers', () =>
                widget.onTab(3)),
            _quick(Icons.inventory_2_rounded, AC.danger, 'Inventory', () =>
                _push(const InventoryScreen())),
            _quick(
                Icons.notifications_active_rounded, AC.accent, 'Alerts', () =>
                _push(const AdminNotificationsScreen(initialTab: 2))),
            _quick(Icons.support_agent_rounded, AC.primary, 'Support', () =>
                _push(const AdminNotificationsScreen(initialTab: 1))),
          ],
        ),
      );

  Widget _quick(IconData icon, Color color, String label, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: AppText.small,
                    fontWeight: FontWeight.w700,
                    color: AC.text)),
          ],
        ),
      );

  // ---- small widgets ------------------------------------------------------------

  Widget _seeAll(VoidCallback onTap) =>
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('See all', style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: AppText.body)),
      );

  Widget _rangeSwitch() =>
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AC.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in ['7 days', '30 days'])
              GestureDetector(
                onTap: () => setState(() => range = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: range == r ? AC.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(r, style: TextStyle(
                      color: range == r ? Colors.white : AC.muted,
                      fontSize: AppText.small,
                      fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      );
}