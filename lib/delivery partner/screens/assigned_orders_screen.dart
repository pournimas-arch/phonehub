import 'package:flutter/material.dart';
import '../../customer/theme.dart';
import '../common.dart';
import '../orders_data.dart';
import 'delivery_details_screen.dart';
import 'navigation_screen.dart';
import 'earnings_screen.dart';
import '../../role_select_screen.dart';

/// Bottom navigation shell: Orders, Map, Earnings, Profile
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [AssignedOrdersScreen(), MapTab(), EarningsScreen(), ProfileTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        height: 68,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded, color: AppColors.primary), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Screen 2 – Assigned Orders (3h)
/// Today / Upcoming tabs, order cards (ID, customer, area, time slot, status badge),
/// bottom nav (Orders, Map, Earnings, Profile).
class AssignedOrdersScreen extends StatefulWidget {
  const AssignedOrdersScreen({super.key});

  @override
  State<AssignedOrdersScreen> createState() => _AssignedOrdersScreenState();
}

class _AssignedOrdersScreenState extends State<AssignedOrdersScreen> {
  int tab = 0; // 0 Today, 1 Upcoming

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<List<DeliveryOrder>>(
        valueListenable: orders,
        builder: (context, all, _) {
          final today = all.where((o) => o.isToday).toList();
          final upcoming = all.where((o) => !o.isToday).toList();
          final list = tab == 0 ? today : upcoming;
          final pending = today.where((o) => o.status == 'Assigned').length;
          final onTheWay = today.where((o) => o.status == 'Picked Up').length;
          final done = today.where((o) => o.status == 'Delivered').length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Text('R', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, Rahul 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('Have a great day on the road', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 9, color: AppColors.success),
                        SizedBox(width: 6),
                        Text('Online', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Summary
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's deliveries", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
                    const SizedBox(height: 4),
                    Text('${today.length} orders', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _stat('Pending', pending),
                        _stat('On the way', onTheWay),
                        _stat('Delivered', done),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Tabs
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    _tab('Today (${today.length})', 0),
                    _tab('Upcoming (${upcoming.length})', 1),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('No orders here', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
                ),
              for (final o in list) _OrderCard(order: o),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, int n) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text('$n', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
        ],
      ),
    ),
  );

  Widget _tab(String label, int i) {
    final on = tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: TextStyle(color: on ? Colors.white : AppColors.muted, fontWeight: FontWeight.w800, fontSize: 13.5)),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryDetailsScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                StatusBadge(order.status),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
            _line(Icons.person_rounded, order.customer, bold: true),
            const SizedBox(height: 8),
            _line(Icons.location_on_rounded, order.area),
            const SizedBox(height: 8),
            _line(Icons.schedule_rounded, '${order.dateLabel} • ${order.slot}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(order.isCod ? 'Collect ${rupee(order.amount)}' : 'Prepaid', style: TextStyle(color: order.isCod ? AppColors.accent : AppColors.success, fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                const Text('View details', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData i, String t, {bool bold = false}) => Row(
    children: [
      Icon(i, size: 18, color: AppColors.muted),
      const SizedBox(width: 10),
      Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: 14, color: bold ? AppColors.text : AppColors.muted))),
    ],
  );
}

/// Map tab – shows navigation for the next active delivery.
class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DeliveryOrder>>(
      valueListenable: orders,
      builder: (context, all, _) {
        final i = all.indexWhere((o) => o.isToday && o.status != 'Delivered');
        if (i < 0) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 70, color: AppColors.success),
                SizedBox(height: 10),
                Text('No active deliveries', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
          );
        }
        return NavigationScreen(order: all[i], showBack: false);
      },
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool online = true;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.badge_outlined, 'My Documents'),
      (Icons.two_wheeler_rounded, 'Vehicle Details'),
      (Icons.account_balance_outlined, 'Bank Account'),
      (Icons.headset_mic_outlined, 'Help & Support'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDeco(),
            child: Column(
              children: [
                const Row(
                  children: [
                    CircleAvatar(radius: 32, backgroundColor: AppColors.primary, child: Text('R', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rahul Patil', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        SizedBox(height: 2),
                        Text('Delivery Partner • DP-1042', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        SizedBox(height: 4),
                        Row(children: [Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 17), SizedBox(width: 3), Text('4.8 rating', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Icon(Icons.power_settings_new_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(online ? 'You are Online' : 'You are Offline', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Switch(value: online, activeColor: AppColors.primary, onChanged: (v) => setState(() => online = v)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final it in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: cardDeco(radius: 16),
              child: ListTile(
                leading: Icon(it.$1, color: AppColors.primary),
                title: Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ),
            ),
          Container(
            decoration: cardDeco(radius: 16),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Switch Role / Logout', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
              onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectScreen()), (r) => false),
            ),
          ),
        ],
      ),
    );
  }
}
