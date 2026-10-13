import 'package:flutter/material.dart';
import 'package:phonehub/Admin/auth_screen.dart';
import 'package:phonehub/Admin/coupons_screen.dart';
import 'package:phonehub/Admin/customers_screen.dart';
import 'package:phonehub/Admin/delivery_screen.dart';
import 'package:phonehub/Admin/notification_support.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'package:phonehub/Admin/payments_screen.dart';
import 'package:phonehub/Admin/products_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';
import 'dashboard_screen.dart';
import 'reports_settings.dart';

/// Bottom navigation: Dashboard | Orders | Products | Customers | More
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onTab: go),
      const OrdersScreen(),
      const ProductsScreen(),
      const CustomersScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => NavigationBar(
          selectedIndex: index,
          onDestinationSelected: go,
          backgroundColor: Colors.white,
          indicatorColor: AC.primary.withValues(alpha: 0.12),
          height: 68,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded, color: AC.primary), label: 'Dashboard'),
            NavigationDestination(
              icon: Badge(isLabelVisible: store.newOrders > 0, label: Text('${store.newOrders}'), child: const Icon(Icons.receipt_long_outlined)),
              selectedIcon: const Icon(Icons.receipt_long_rounded, color: AC.primary),
              label: 'Orders',
            ),
            const NavigationDestination(icon: Icon(Icons.smartphone_outlined), selectedIcon: Icon(Icons.smartphone_rounded, color: AC.primary), label: 'Products'),
            const NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded, color: AC.primary), label: 'Customers'),
            const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded, color: AC.primary), label: 'More'),
          ],
        ),
      ),
    );
  }
}

/// "More" tab: opens everything that is not in the bottom bar.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _open(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tiles = <(IconData, Color, String, String, Widget, int)>[
          (Icons.sell_rounded, AC.accent, 'Coupons & Offers', 'Coupons and home banners', const CouponsScreen(), 0),
          (Icons.category_rounded, AC.primary, 'Brands', '${store.brands.length} brands', const BrandsScreen(), 0),
          (Icons.two_wheeler_rounded, AC.success, 'Delivery Partners', '${store.partners.where((p) => p.active).length} active partners', const PartnersScreen(), 0),
          (Icons.account_balance_wallet_rounded, AC.info, 'Payments & Refunds', '${store.pendingRefunds} refunds waiting', const PaymentsScreen(), store.pendingRefunds),
          (Icons.notifications_active_rounded, AC.warning, 'Notifications', 'Send push and see alerts', const AdminNotificationsScreen(), store.alerts.length),
          (Icons.headset_mic_rounded, AC.primary, 'Support', '${store.openTickets} open tickets', const SupportScreen(), store.openTickets),
          (Icons.inventory_2_rounded, AC.accent, 'Inventory', '${store.lowStockCount} items low on stock', const InventoryScreen(), store.lowStockCount),
          (Icons.bar_chart_rounded, AC.success, 'Reports', 'Sales, products, customers', const ReportsScreen(), 0),
          (Icons.settings_rounded, AC.muted, 'Settings', 'Delivery, staff, policies', const SettingsScreen(), 0),
        ];
        return Scaffold(
          appBar: AppBar(title: const Text('More')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _open(context, const AdminProfileScreen()),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Text(store.adminName[0].toUpperCase(), style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900, fontSize: 22))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.adminName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                            Text(store.adminEmail, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final t in tiles)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: cardDeco(radius: 16),
                  child: ListTile(
                    onTap: () => _open(context, t.$5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: IconBadge(t.$1, t.$2),
                    title: Text(t.$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(t.$4, style: const TextStyle(color: AC.muted, fontSize: 12)),
                    trailing: t.$6 > 0
                        ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AC.danger, borderRadius: BorderRadius.circular(20)),
                      child: Text('${t.$6}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    )
                        : const Icon(Icons.chevron_right_rounded, color: AC.muted),
                  ),
                ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final ok = await confirmDialog(context, 'Log out?', 'You will need to sign in again to manage the store.', yes: 'Log out', danger: true);
                  if (ok && context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminLoginScreen()), (r) => false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: AC.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: AC.danger, size: 20),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: AC.danger, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(child: Text('PhoneHub Admin v1.0.0', style: TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w600))),
            ],
          ),
        );
      },
    );
  }
}
