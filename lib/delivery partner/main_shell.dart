import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/common.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';
import 'package:phonehub/delivery%20partner/partner_service.dart';
import 'package:phonehub/delivery%20partner/partner_menus.dart';
import 'package:phonehub/role_select_screen.dart';
import 'delivery_details_screen.dart';
import 'navigation_screen.dart';
import 'earnings_screen.dart';

/// Compact type scale (smaller than before) used across this file.
class _T {
  static const double micro = 10;
  static const double small = 11;
  static const double body = 12.5;
  static const double sub = 14;
  static const double title = 16;
  static const double big = 22;
}

/// Shared online/offline state so header + profile stay in sync.
final ValueNotifier<bool> partnerOnline = ValueNotifier<bool>(true);

/// Asks "My Deliveries" to open a tab (0 Current, 1 Completed, 2 Cancelled, 3 Returns).
/// Used by the Home screen cards. -1 = nothing requested.
final ValueNotifier<int> _deliveriesTabRequest = ValueNotifier<int>(-1);

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Real rating: the average of the customers' stars on this partner's delivered orders,
/// otherwise the rating the admin saved on the partner record, otherwise a dash (never a made-up 5.0).
String _ratingText(PartnerProfile? p) {
  final s = partnerRatingStats();
  if (s.count > 0) return s.average.toStringAsFixed(1);
  final r = p?.rating ?? 0;
  return r > 0 ? r.toStringAsFixed(1) : '—';
}

void _snack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Online / Offline switch: saves to Firestore and puts the switch back if saving fails.
Future<void> _toggleOnline(BuildContext context, bool value) async {
  final before = partnerOnline.value;
  partnerOnline.value = value;
  try {
    await PartnerService.instance.setOnline(value);
  } catch (_) {
    partnerOnline.value = before;
    _snack(context, 'Could not update online status. Please try again.');
  }
}

/// Calls the customer (return pickup card).
Future<void> _callNumber(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  var ok = false;
  try {
    ok = number.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    ok = false;
  }
  if (!ok) _snack(context, number.isEmpty ? 'No phone number for this customer.' : 'Could not open the dialer. Number: $phone');
}

/// Opens Google Maps to the customer (saved point if the order has one, otherwise the written address).
Future<void> _openMapsFor(BuildContext context, DeliveryOrder o) async {
  final dest = o.hasLocation ? '${o.lat},${o.lng}' : Uri.encodeComponent(o.address);
  final uris = <Uri>[
    if (o.hasLocation) Uri.parse('google.navigation:q=${o.lat},${o.lng}&mode=d'),
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest&travelmode=driving'),
  ];
  for (final u in uris) {
    try {
      if (await launchUrl(u, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
  }
  _snack(context, 'Could not open Google Maps. Please install or update it.');
}

String _money(double v) => '₹${v.toStringAsFixed(0)}';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "5 min ago" / "2 h ago" / "3 d ago" for the alert list.
String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Bell icon: opens the list of new / cancelled order alerts (see orders_data.dart).
void _showAlerts(BuildContext context) {
  final shown = List<PartnerAlert>.from(partnerAlerts.value);
  final unread = shown.where((a) => !a.read).toSet();
  markAlertsRead();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints:
        BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications',
                  style: TextStyle(
                      fontSize: _T.sub,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 10),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('No new notifications',
                          style: TextStyle(
                              fontSize: _T.body, color: AppColors.muted))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const Divider(height: 14),
                    itemBuilder: (_, i) {
                      final a = shown[i];
                      final cancelled = a.title == 'Order cancelled' ||
                          a.title == 'Order removed';
                      final isReturnAlert = a.type == 'return_pickup' ||
                          a.title.startsWith('Return pickup');
                      final color =
                      cancelled ? AppColors.danger : AppColors.primary;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            child: Icon(
                                cancelled
                                    ? Icons.cancel_outlined
                                    : (isReturnAlert
                                    ? Icons.assignment_return_outlined
                                    : Icons.inventory_2_outlined),
                                size: 16,
                                color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                        child: Text(a.title,
                                            style: const TextStyle(
                                                fontSize: _T.body,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.text))),
                                    if (unread.contains(a))
                                      Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                              color: AppColors.danger,
                                              shape: BoxShape.circle)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(a.body,
                                    style: const TextStyle(
                                        fontSize: _T.small,
                                        color: AppColors.muted,
                                        height: 1.35)),
                                const SizedBox(height: 2),
                                Text(_ago(a.at),
                                    style: const TextStyle(
                                        fontSize: _T.micro,
                                        color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ───────────────────────────── Shared pieces ─────────────────────────────

/// Text shown on the status pill (Picked Up = Out for Delivery, future orders = Scheduled).
String _labelOf(DeliveryOrder o) {
  switch (o.status) {
    case 'Picked Up':
      return 'Out for Delivery';
    case 'Assigned':
      return o.isToday ? 'Assigned' : 'Scheduled';
    default:
      return o.status;
  }
}

Color _colorOf(DeliveryOrder o) {
  if (o.status == 'Cancelled') return AppColors.danger;
  if (o.status == 'Assigned')
    return o.isToday ? AppColors.info : AppColors.muted;
  return statusColor(o.status);
}

String _itemName(DeliveryOrder o) {
  if (o.items.isEmpty) return 'Phone order';

  final name = o.items.first;
  return name.split(' • ').first;
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8)),
    child: Text(text,
        style: TextStyle(
            color: color,
            fontSize: _T.micro + 0.5,
            fontWeight: FontWeight.w800)),
  );
}

/// Phone thumbnail used on the order cards.
class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 54,
    decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.smartphone_rounded,
        color: AppColors.primary, size: 26),
  );
}

/// Bell icon with the unread alert count.
class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PartnerAlert>>(
      valueListenable: partnerAlerts,
      builder: (bellContext, alerts, _) {
        final unread = alerts.where((a) => !a.read).length;
        return InkWell(
          onTap: () => _showAlerts(bellContext),
          borderRadius: BorderRadius.circular(20),
          child: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle),
              child: Icon(
                  unread > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 20),
            ),
          ),
        );
      },
    );
  }
}

/// Teal header + rounded light sheet (same layout on every tab).
class _Page extends StatelessWidget {
  final Widget header;
  final Widget child;

  const _Page({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B5E57), AppColors.primary]),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 12, 16, 16),
            child: header,
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _titleHeader(String title) => Row(
  children: [
    Expanded(
        child: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: _T.title + 4,
                fontWeight: FontWeight.w800))),
    const _Bell(),
  ],
);

Widget _incentiveCard(int done, int target) {
  final progress = target <= 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
  final left = (target - done).clamp(0, target);
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.emoji_events_rounded,
                  size: 17, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            const Expanded(
                child: Text("Today's incentive goal",
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: _T.body))),
            Text('$done / $target',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: _T.body,
                    color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.border,
              color: AppColors.primary),
        ),
        const SizedBox(height: 7),
        Text(
          left == 0
              ? '🎉 Goal achieved! Bonus unlocked'
              : 'Deliver $left more order${left == 1 ? '' : 's'} to unlock today\'s bonus',
          style: const TextStyle(color: AppColors.muted, fontSize: _T.small),
        ),
      ],
    ),
  );
}

Widget _miniCard(IconData icon, String label, String value, Color color) =>
    Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: _T.micro + 0.5)),
                const SizedBox(height: 1),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: _T.sub)),
              ],
            ),
          ),
        ],
      ),
    );

// ───────────────────────────── Bottom nav shell ─────────────────────────────

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;

  // The Online switch shows the REAL value saved on partners/{email}.online.
  void _syncOnline() {
    partnerOnline.value = PartnerService.instance.data.value['online'] == true;
  }

  @override
  void initState() {
    super.initState();
    _syncOnline();
    PartnerService.instance.data.addListener(_syncOnline);
  }

  @override
  void dispose() {
    PartnerService.instance.data.removeListener(_syncOnline);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: index,
        children: [
          HomeTab(onViewAll: () => setState(() => index = 1)),
          const AssignedOrdersScreen(),
          const EarningsScreen(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: _T.small,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.muted,
            )),
          ),
          child: ValueListenableBuilder<List<DeliveryOrder>>(
            valueListenable: orders,
            builder: (context, all, _) => ValueListenableBuilder<List<DeliveryOrder>>(
              valueListenable: returnPickups,
              builder: (context, rets, _) {
                // New deliveries to start + return pickups waiting for pickup.
                final pending =
                    all.where((o) => o.isToday && o.status == 'Assigned').length +
                        rets.where((o) => o.returnWaiting).length;
                return NavigationBar(
                  selectedIndex: index,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                  height: 62,
                  onDestinationSelected: (i) => setState(() => index = i),
                  destinations: [
                    const NavigationDestination(
                        icon: Icon(Icons.home_outlined, size: 22),
                        selectedIcon: Icon(Icons.home_rounded,
                            size: 22, color: AppColors.primary),
                        label: 'Home'),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: pending > 0,
                        label:
                        Text('$pending', style: const TextStyle(fontSize: 9)),
                        child:
                        const Icon(Icons.local_shipping_outlined, size: 22),
                      ),
                      selectedIcon: const Icon(Icons.local_shipping_rounded,
                          size: 22, color: AppColors.primary),
                      label: 'My Deliveries',
                    ),
                    const NavigationDestination(
                        icon:
                        Icon(Icons.account_balance_wallet_outlined, size: 22),
                        selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                            size: 22, color: AppColors.primary),
                        label: 'Earnings'),
                    const NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded, size: 22),
                        selectedIcon: Icon(Icons.person_rounded,
                            size: 22, color: AppColors.primary),
                        label: 'Profile'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Home (dashboard) ─────────────────────────────

class HomeTab extends StatelessWidget {
  final VoidCallback onViewAll;

  const HomeTab({super.key, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final p = PartnerService.instance.current;
    return _Page(
      header: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PhoneHub',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic)),
                Text('Delivery Partner',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: _T.small)),
              ],
            ),
          ),
          const _Bell(),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Text(p?.initial ?? 'P',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: _T.sub)),
          ),
        ],
      ),
      child: ValueListenableBuilder<List<DeliveryOrder>>(
        valueListenable: orders,
        builder: (context, all, _) {
          // "Today" = work due today + orders actually delivered today
          // (older delivered orders are history, they are not counted as today's).
          final now = DateTime.now();
          final today = all.where((o) {
            if (o.status == 'Delivered') {
              return o.deliveredAt != null && _sameDay(o.deliveredAt!, now);
            }
            return o.isToday;
          }).toList();
          final pending = today.where((o) => o.status == 'Assigned').length;
          final onTheWay = today.where((o) => o.status == 'Picked Up').length;
          final done = today.where((o) => o.status == 'Delivered').length;

          double codPending = 0, codCollected = 0;
          for (final o in today) {
            if (!o.isCod) continue;
            if (o.status == 'Delivered') {
              codCollected += o.amount;
            } else {
              codPending += o.amount;
            }
          }
          final recent = all.take(3).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _greetCard(p),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child:
                      _statCard('${today.length}', "Today's\nDeliveries")),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('$onTheWay', 'On the Way')),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('$pending', 'Pending')),
                ],
              ),
              const SizedBox(height: 14),
              // Daily goal = the number the admin saved in Settings (appConfig/partnerIncentives.dailyTarget).
              // No goal set by the admin -> the card is hidden.
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.doc('appConfig/partnerIncentives').snapshots(),
                builder: (context, snap) {
                  final t = snap.data?.data()?['dailyTarget'];
                  final target = t is num ? t.toInt() : 0;
                  if (target <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _incentiveCard(done, target),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                      child: _miniCard(Icons.payments_rounded, 'COD to collect',
                          _money(codPending), AppColors.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _miniCard(Icons.verified_rounded, 'COD collected',
                          _money(codCollected), AppColors.success)),
                ],
              ),
              // Return pickups the admin assigned to this partner (collect the phone back from the customer).
              ValueListenableBuilder<List<DeliveryOrder>>(
                valueListenable: returnPickups,
                builder: (context, rets, _) {
                  final todo = rets.where((o) => !o.returnReceived).length;
                  if (todo == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: () {
                        onViewAll();
                        _deliveriesTabRequest.value = -1;
                        _deliveriesTabRequest.value = 3;
                      },
                      child: _miniCard(Icons.assignment_return_rounded,
                          'Return pickups to collect', '$todo', AppColors.info),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                      child: Text('Recent Orders',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: _T.sub,
                              color: AppColors.text))),
                  GestureDetector(
                    onTap: onViewAll,
                    child: const Text('View All',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: _T.body,
                            color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (recent.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: cardDeco(radius: 16),
                  child: const Center(
                      child: Text('No orders assigned yet',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: _T.body))),
                )
              else
                for (final o in recent) _RecentTile(order: o),
            ],
          );
        },
      ),
    );
  }

  Widget _greetCard(PartnerProfile? p) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.36)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()}, ${p?.firstName ?? 'Partner'} 👋',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: _T.title,
                      color: AppColors.text)),
              const SizedBox(height: 3),
              const Text('Ready for your next delivery?',
                  style:
                  TextStyle(color: AppColors.muted, fontSize: _T.body)),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: partnerOnline,
                builder: (ctx, on, __) => GestureDetector(
                  onTap: () => _toggleOnline(ctx, !on),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (on ? AppColors.success : AppColors.muted)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            size: 8,
                            color:
                            on ? AppColors.success : AppColors.muted),
                        const SizedBox(width: 5),
                        Text(on ? 'Online' : 'Offline',
                            style: TextStyle(
                                color: on
                                    ? AppColors.success
                                    : AppColors.muted,
                                fontWeight: FontWeight.w800,
                                fontSize: _T.small)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle),
          child: const Icon(Icons.two_wheeler_rounded,
              size: 38, color: AppColors.primary),
        ),
      ],
    ),
  );

  Widget _statCard(String value, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
    decoration: cardDeco(radius: 16),
    child: Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: _T.small, color: AppColors.muted, height: 1.25)),
      ],
    ),
  );
}

class _RecentTile extends StatelessWidget {
  final DeliveryOrder order;

  const _RecentTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryDetailsScreen(order: order),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(radius: 16),
        child: Row(
          children: [
            const _Thumb(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name on the first line
                  Text(
                    _itemName(order),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: _T.body + 1,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Order ID in smaller text below
                  Text(
                    'Order ID: ${order.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: _T.small,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupee(order.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: _T.body + 1,
                  ),
                ),
                const SizedBox(height: 8),
                _Pill(_labelOf(order), _colorOf(order)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── My Deliveries ─────────────────────────────

class AssignedOrdersScreen extends StatefulWidget {
  const AssignedOrdersScreen({super.key});

  @override
  State<AssignedOrdersScreen> createState() => _AssignedOrdersScreenState();
}

class _AssignedOrdersScreenState extends State<AssignedOrdersScreen> {
  int tab = 0; // 0 Current, 1 Completed, 2 Cancelled, 3 Returns
  String query = '';

  void _onTabRequest() {
    final t = _deliveriesTabRequest.value;
    if (t >= 0 && t <= 3 && mounted) setState(() => tab = t);
  }

  @override
  void initState() {
    super.initState();
    _deliveriesTabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    _deliveriesTabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return MediaQuery(
      data: media.copyWith(
        textScaler: const TextScaler.linear(0.85),
      ),
      child: _Page(
        header: _titleHeader('My Deliveries'),
        child: ValueListenableBuilder<List<DeliveryOrder>>(
          valueListenable: orders,
          builder: (context, all, _) =>
              ValueListenableBuilder<List<DeliveryOrder>>(
                valueListenable: cancelledOrders,
                builder: (context, cancelled, _) =>
                    ValueListenableBuilder<List<DeliveryOrder>>(
                      valueListenable: returnPickups,
                      builder: (context, returns, _) {
                        final current = all
                            .where((o) =>
                        o.status != 'Delivered' &&
                            o.status != 'Cancelled')
                            .toList()
                          ..sort((a, b) =>
                              (a.isToday ? 0 : 1).compareTo(b.isToday ? 0 : 1));

                        final completed =
                        all.where((o) => o.status == 'Delivered').toList();

                        final lists = [current, completed, cancelled, returns];
                        final q = query.trim().toLowerCase();

                        final list = lists[tab].where((o) {
                          return q.isEmpty ||
                              o.id.toLowerCase().contains(q) ||
                              o.customer.toLowerCase().contains(q) ||
                              o.area.toLowerCase().contains(q);
                        }).toList();

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _tabBtn('Current', 0),
                                      const SizedBox(width: 5),
                                      _tabBtn('Completed', 1),
                                      const SizedBox(width: 5),
                                      _tabBtn('Cancelled', 2),
                                      const SizedBox(width: 5),
                                      _tabBtn(
                                          returns.any((o) => !o.returnReceived)
                                              ? 'Returns (${returns.where((o) => !o.returnReceived).length})'
                                              : 'Returns',
                                          3),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _searchBox(),
                                ],
                              ),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: _refresh,
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                                  children: [
                                    if (list.isEmpty) _empty(),
                                    for (final o in list)
                                      tab == 3
                                          ? _ReturnCard(order: o)
                                          : _DeliveryCard(order: o),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              ),
        ),
      ),
    );
  }



  Widget _tabBtn(String label, int i) {
    final on = tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: on ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: on ? Colors.white : AppColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: _T.small + 0.5)),
        ),
      ),
    );
  }

  Widget _searchBox() => Container(
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
    child: TextField(
      onChanged: (v) => setState(() => query = v),
      style: const TextStyle(fontSize: _T.body),
      decoration: const InputDecoration(
        hintText: 'Search order ID, customer or area',
        hintStyle: TextStyle(fontSize: _T.body, color: AppColors.muted),
        prefixIcon:
        Icon(Icons.search_rounded, size: 19, color: AppColors.muted),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.inbox_rounded,
              size: 36, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(tab == 3 ? 'No return pickups' : 'No orders found',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: _T.sub)),
        const SizedBox(height: 3),
        Text(
            tab == 3
                ? 'Return pickups assigned by the admin will appear here'
                : 'Pull down to refresh or change the search',
            style: const TextStyle(
                color: AppColors.muted, fontSize: _T.small)),
      ],
    ),
  );
}

// ───────────────────────────── Delivery card ─────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final DeliveryOrder order;

  const _DeliveryCard({required this.order});

  void _open(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DeliveryDetailsScreen(order: order)));

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'Cancelled';
    final delivered = order.status == 'Delivered';
    final warn = order.isCod || order.payPending;
    final payColor = warn ? AppColors.accent : AppColors.success;

    return GestureDetector(
      onTap: cancelled ? null : () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: cardDeco(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Thumb(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _itemName(order), // Product name first
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: _T.sub,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _Pill(_labelOf(order), _colorOf(order)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order ID: ${order.id}', // Order ID below in smaller text
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: _T.small,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                            'To: ${order.area.isEmpty ? order.customer : order.area}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: _T.small)),
                        Text('${order.dateLabel} • ${order.slot}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: _T.small)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                                child: Text(
                                    'Order Value: ${rupee(order.amount)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: _T.small + 0.5))),
                            if (!cancelled)
                              InkWell(
                                onTap: () => _open(context),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Text('View Details',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: _T.small)),
                                ),
                              ),
                          ],
                        ),
                        if (!cancelled) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: payColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    order.isCod
                                        ? Icons.payments_rounded
                                        : (order.payPending
                                        ? Icons.schedule_rounded
                                        : Icons.verified_rounded),
                                    size: 12,
                                    color: payColor),
                                const SizedBox(width: 5),
                                Text(
                                  order.isCod
                                      ? 'Collect ${rupee(order.amount)}'
                                      : (order.payPending
                                      ? 'Payment pending'
                                      : 'Prepaid'),
                                  style: TextStyle(
                                      color: payColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: _T.micro + 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!delivered && !cancelled && order.isToday) ...[
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => NavigationScreen(order: order))),
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Navigate',
                          style: TextStyle(
                              fontSize: _T.body, fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 11)),
                    ),
                  ),
                  Container(width: 1, height: 22, color: AppColors.border),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.local_shipping_rounded, size: 16),
                      label: Text(
                          order.status == 'Assigned'
                              ? 'Start pickup'
                              : 'Update status',
                          style: const TextStyle(
                              fontSize: _T.body, fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 11)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Return pickup card ─────────────────────────────

/// A RETURN pickup: the admin approved the customer's return and sent this partner to collect the phone.
/// Pickup Assigned -> (partner taps "Mark as picked up") Picked Up -> (admin) Received.
class _ReturnCard extends StatefulWidget {
  final DeliveryOrder order;

  const _ReturnCard({required this.order});

  @override
  State<_ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends State<_ReturnCard> {
  bool _busy = false;

  DeliveryOrder get order => widget.order;

  String get _label => order.returnReceived
      ? 'Received'
      : (order.returnPicked ? 'Picked up' : 'Pickup pending');

  Color get _color => order.returnReceived
      ? AppColors.success
      : (order.returnPicked ? AppColors.accent : AppColors.info);

  Future<void> _markPicked() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Phone collected?',
            style: TextStyle(fontSize: _T.title, fontWeight: FontWeight.w800)),
        content: Text(
            'Confirm that you collected the phone for order ${order.id} from ${order.customer}.',
            style: const TextStyle(fontSize: _T.body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet', style: TextStyle(fontSize: _T.body))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, collected',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: _T.body))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final error = await markReturnPickedUp(order);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(context, error ?? 'Marked as picked up. Take the phone to the store.');
  }

  @override
  Widget build(BuildContext context) {
    final active = !order.returnReceived;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Thumb(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_itemName(order),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: _T.sub,
                                    color: AppColors.text)),
                          ),
                          const SizedBox(width: 6),
                          _Pill(_label, _color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Order ID: ${order.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: _T.small)),
                      const SizedBox(height: 3),
                      Text('Customer: ${order.customer}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: _T.small)),
                      if (order.address.isNotEmpty)
                        Text('Pickup from: ${order.address}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: _T.small)),
                      Text('Assigned ${order.dateLabel}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: _T.small)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_return_rounded,
                                size: 12, color: _color),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                order.returnReceived
                                    ? 'Phone received by the store'
                                    : (order.returnPicked
                                    ? 'Take the phone to the store'
                                    : 'Collect the phone from the customer'),
                                style: TextStyle(
                                    color: _color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: _T.micro + 0.5),
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
          ),
          if (active) ...[
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _callNumber(context, order.phone),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call',
                        style: TextStyle(
                            fontSize: _T.body, fontWeight: FontWeight.w800)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 11)),
                  ),
                ),
                Container(width: 1, height: 22, color: AppColors.border),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _openMapsFor(context, order),
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: const Text('Navigate',
                        style: TextStyle(
                            fontSize: _T.body, fontWeight: FontWeight.w800)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 11)),
                  ),
                ),
                if (order.returnWaiting) ...[
                  Container(width: 1, height: 22, color: AppColors.border),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _busy ? null : _markPicked,
                      icon: _busy
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Picked up',
                          style: TextStyle(
                              fontSize: _T.body, fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 11)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Map tab (no longer in the bottom bar) ─────────────────────────────

class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DeliveryOrder>>(
      valueListenable: orders,
      builder: (context, all, _) {
        final i = all.indexWhere((o) => o.isToday && o.status != 'Delivered');
        if (i < 0) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      size: 52, color: AppColors.success),
                ),
                const SizedBox(height: 14),
                const Text('No active deliveries',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: _T.title)),
                const SizedBox(height: 4),
                const Text("You're all caught up. New orders will appear here.",
                    style:
                    TextStyle(color: AppColors.muted, fontSize: _T.body)),
              ],
            ),
          );
        }
        return NavigationScreen(order: all[i], showBack: false);
      },
    );
  }
}

// ───────────────────────────── Profile tab ─────────────────────────────

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = PartnerService.instance.current;
    final items = <(IconData, String, String, WidgetBuilder)>[
      (
      Icons.badge_outlined,
      'My Documents',
      'Licence, Aadhaar, RC',
          (_) => const MyDocumentsScreen()
      ),
      (
      Icons.two_wheeler_rounded,
      'Vehicle Details',
      p?.vehicle ?? '',
          (_) => const VehicleDetailsScreen()
      ),
      (
      Icons.account_balance_outlined,
      'Bank Account',
      'Payout & settlements',
          (_) => const BankAccountScreen()
      ),
      (
      Icons.history_rounded,
      'Delivery History',
      'Past orders & trips',
          (_) => const DeliveryHistoryScreen()
      ),
      (
      Icons.card_giftcard_rounded,
      'Incentives & Rewards',
      'Daily & weekly bonuses',
          (_) => const IncentivesScreen()
      ),
      (
      Icons.school_outlined,
      'Training & Safety',
      'Tips to deliver better',
          (_) => const TrainingSafetyScreen()
      ),
      (
      Icons.headset_mic_outlined,
      'Help & Support',
      '24x7 partner support',
          (_) => const HelpSupportScreen()
      ),
      (
      Icons.description_outlined,
      'Terms & Privacy',
      '',
          (_) => const TermsPrivacyScreen()
      ),
    ];

    return _Page(
      header: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(p?.initial ?? 'P',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p?.name ?? 'Delivery Partner',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: _T.title + 1)),
                const SizedBox(height: 2),
                Text(
                    'Delivery Partner${(p?.vehicle ?? '').isEmpty ? '' : ' • ${p!.vehicle}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: _T.small)),
              ],
            ),
          ),
          const _Bell(),
        ],
      ),
      child: ValueListenableBuilder<List<DeliveryOrder>>(
        valueListenable: orders,
        builder: (context, all, _) {
          final deliveredList =
          all.where((o) => o.status == 'Delivered').toList();
          final totalEarn = deliveredList.fold<int>(0, (s, o) => s + o.earning);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: cardDeco(radius: 16),
                child: Row(
                  children: [
                    _pStat('${deliveredList.length}', 'Total Deliveries',
                        AppColors.text),
                    Container(width: 1, height: 30, color: AppColors.border),
                    _pStat(rupee(totalEarn), 'Total Earnings', AppColors.text),
                    Container(width: 1, height: 30, color: AppColors.border),
                    _pStat(_ratingText(p), 'Rating', AppColors.accent),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<bool>(
                valueListenable: partnerOnline,
                builder: (_, on, __) => Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: cardDeco(radius: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: (on ? AppColors.success : AppColors.muted)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.power_settings_new_rounded,
                            size: 18,
                            color: on ? AppColors.success : AppColors.muted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(on ? 'You are Online' : 'You are Offline',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: _T.sub)),
                            Text(
                                on
                                    ? 'Receiving new delivery requests'
                                    : 'Go online to get orders',
                                style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: _T.small)),
                          ],
                        ),
                      ),
                      Switch(
                        value: on,
                        activeColor: AppColors.primary,
                        onChanged: (v) => _toggleOnline(context, v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: cardDeco(radius: 16),
                child: Column(
                  children: [
                    for (var k = 0; k < items.length; k++) ...[
                      ListTile(
                        dense: true,
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: items[k].$4)),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(items[k].$1,
                              color: AppColors.primary, size: 18),
                        ),
                        title: Text(items[k].$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: _T.body + 0.5)),
                        subtitle: items[k].$3.isEmpty
                            ? null
                            : Text(items[k].$3,
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: _T.small)),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.muted, size: 20),
                      ),
                      if (k != items.length - 1)
                        const Divider(height: 1, indent: 62),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: cardDeco(radius: 16),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout_rounded,
                        color: AppColors.danger, size: 18),
                  ),
                  title: const Text('Logout',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                          fontSize: _T.body + 0.5)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted, size: 20),
                  onTap: () => _confirmLogout(context),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                  child: Text('PhoneHub Delivery Partner • v1.0.0',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: _T.micro))),
            ],
          );
        },
      ),
    );
  }

  Widget _pStat(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: _T.sub + 1)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.muted, fontSize: _T.small)),
      ],
    ),
  );

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Logout?',
            style: TextStyle(fontSize: _T.title, fontWeight: FontWeight.w800)),
        content: const Text(
            'You will be signed out of the delivery partner app.',
            style: TextStyle(fontSize: _T.body)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(fontSize: _T.body))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: _T.body)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await PartnerService.instance.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
            (r) => false);
  }
}