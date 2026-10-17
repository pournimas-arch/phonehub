import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/Admin/phone_shared_widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'package:phonehub/Admin/products_screen.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/Admin/product_detail_screen.dart';

// ===========================================================================
// Shared helpers (same style as the Orders screen)
// ===========================================================================

/// App bar: same as Orders screen (18 / w800, left aligned, back arrow 40px).
AppBar _appBar(BuildContext context, String title, {List<Widget>? actions}) {
  final bool canPop = Navigator.of(context).canPop();
  return AppBar(
    centerTitle: false,
    titleSpacing: canPop ? 0 : 16,
    leadingWidth: canPop ? 40 : null,
    leading: canPop
        ? IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
    )
        : null,
    title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    actions: actions,
  );
}

/// Small rounded label.
Widget _pill(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
      Text(text, maxLines: 1, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ],
  ),
);

/// Gradient summary strip (Orders style).
Widget _summaryCard(List<Widget> stats) => Container(
  margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
  decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(18)),
  child: Row(children: stats),
);

Widget _stat(IconData icon, String label, String value) => Expanded(
  child: Column(
    children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(height: 4),
      FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: (AppText.subtitle - 2), fontWeight: FontWeight.w900))),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 1)))),
    ],
  ),
);

Widget _statDivider() => Container(width: 1, height: 38, color: Colors.white24);

/// Chip group used inside the filter sheet.
Widget _filterGroup(String title, List<String> items, String value, void Function(String) onPick) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1))),
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final x in items)
          ChoiceChip(
            label: Text(x, style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: x == value ? Colors.white : AC.text)),
            selected: x == value,
            showCheckmark: false,
            selectedColor: AC.primary,
            backgroundColor: AC.bg,
            side: BorderSide(color: x == value ? AC.primary : AC.border),
            onSelected: (_) => onPick(x),
          ),
      ],
    ),
  ],
);

/// Removable chip showing an active filter.
Widget _activeChip(String label, VoidCallback onRemove) => Chip(
  label: Text(label, style: const TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: AC.primary)),
  backgroundColor: AC.primary.withValues(alpha: 0.08),
  side: BorderSide.none,
  deleteIcon: const Icon(Icons.close_rounded, size: 15, color: AC.primary),
  onDeleted: onRemove,
  visualDensity: VisualDensity.compact,
);

/// Section heading used on detail screens.
Widget _heading(String text, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
  child: Row(
    children: [
      Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1)))),
      if (trailing != null) trailing,
    ],
  ),
);

void _copyText(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  snack(context, message);
}

/// Total spent by a customer (cancelled orders not counted).
int _spentBy(dynamic c) => store.ordersOf(c.id).where((o) => !o.cancelled).fold<int>(0, (s, o) => s + (o.total as int));

// ===========================================================================
// Customers list
// ===========================================================================

/// Customer list: summary, tabs with counts, search, filter & sort.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const tabs = ['All', 'Active', 'Blocked', 'Repeat', 'No orders'];
  static const joins = ['Any time', 'Last 7 days', 'Last 30 days'];
  static const sorts = ['Newest first', 'Oldest first', 'Name A-Z', 'Most spent', 'Most orders'];

  String tab = 'All';
  String query = '';
  String joined = 'Any time';
  String sort = 'Newest first';

  bool _matchTab(dynamic c, String t) {
    switch (t) {
      case 'Active':
        return !c.blocked;
      case 'Blocked':
        return c.blocked;
      case 'Repeat':
        return store.ordersOf(c.id).length >= 2;
      case 'No orders':
        return store.ordersOf(c.id).isEmpty;
    }
    return true;
  }

  bool _inJoin(dynamic c) {
    final now = DateTime.now();
    switch (joined) {
      case 'Last 7 days':
        return !(c.joined as DateTime).isBefore(now.subtract(const Duration(days: 7)));
      case 'Last 30 days':
        return !(c.joined as DateTime).isBefore(now.subtract(const Duration(days: 30)));
    }
    return true;
  }

  int _count(String t) => store.customers.where((c) => _matchTab(c, t)).length;

  bool get _filtersOn => joined != 'Any time' || sort != 'Newest first';
  int get _filterCount => (joined != 'Any time' ? 1 : 0) + (sort != 'Newest first' ? 1 : 0);

  void _resetFilters() => setState(() {
    joined = 'Any time';
    sort = 'Newest first';
  });

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          void pick(VoidCallback f) {
            setState(f);
            setM(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Filter & sort', style: TextStyle(fontSize: (AppText.title - 2), fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(onPressed: () => pick(_resetFilters), child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800))),
                    ],
                  ),
                  _filterGroup('Joined', joins, joined, (v) => pick(() => joined = v)),
                  _filterGroup('Sort by', sorts, sort, (v) => pick(() => sort = v)),
                  const SizedBox(height: 18),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Show customers')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary() {
    final all = store.customers;
    final active = all.where((c) => !c.blocked).length;
    final revenue = all.fold<int>(0, (s, c) => s + _spentBy(c));
    return _summaryCard([
      _stat(Icons.people_alt_rounded, 'Customers', '${all.length}'),
      _statDivider(),
      _stat(Icons.verified_user_rounded, 'Active', '$active'),
      _statDivider(),
      _stat(Icons.trending_up_rounded, 'Total spent', inr(revenue)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = store.customers.where((c) => _matchTab(c, tab)).where(_inJoin).where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q) || c.phone.contains(q);
        }).toList();

        switch (sort) {
          case 'Oldest first':
            list.sort((a, b) => (a.joined as DateTime).compareTo(b.joined as DateTime));
            break;
          case 'Name A-Z':
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            break;
          case 'Most spent':
            list.sort((a, b) => _spentBy(b).compareTo(_spentBy(a)));
            break;
          case 'Most orders':
            list.sort((a, b) => store.ordersOf(b.id).length.compareTo(store.ordersOf(a.id).length));
            break;
          default:
            list.sort((a, b) => (b.joined as DateTime).compareTo(a.joined as DateTime));
        }

        final listSpent = list.fold<int>(0, (s, c) => s + _spentBy(c));

        return Scaffold(
          appBar: _appBar(
            context,
            'Customers',
            actions: [
              Badge(
                isLabelVisible: _filtersOn,
                label: Text('$_filterCount'),
                alignment: const Alignment(0.5, -0.5),
                child: IconButton(icon: const Icon(Icons.tune_rounded), tooltip: 'Filter & sort', onPressed: _openFilters),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              _summary(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SearchBox(hint: 'Search name, email or phone', onChanged: (v) => setState(() => query = v)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ChipTabs(
                  items: [for (final t in tabs) '$t ${_count(t)}'],
                  selected: '$tab ${_count(tab)}',
                  onSelect: (v) => setState(() => tab = tabs.firstWhere((t) => v.startsWith('$t '), orElse: () => 'All')),
                ),
              ),
              if (_filtersOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (joined != 'Any time') _activeChip(joined, () => setState(() => joined = 'Any time')),
                      if (sort != 'Newest first') _activeChip(sort, () => setState(() => sort = 'Newest first')),
                      ActionChip(
                        label: const Text('Clear all', style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w800, color: AC.danger)),
                        backgroundColor: AC.danger.withValues(alpha: 0.08),
                        side: BorderSide.none,
                        onPressed: _resetFilters,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    Text('${list.length} ${list.length == 1 ? 'customer' : 'customers'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1))),
                    const Spacer(),
                    if (list.isNotEmpty) Text('Spent ${inr(listSpent)}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyState(icon: Icons.people_outline_rounded, title: 'No customers found', subtitle: 'Try another tab, search or filter'),
                )
              else
                for (final c in list) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _tile(c)),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(dynamic c) {
    final orders = store.ordersOf(c.id);
    final spent = _spentBy(c);
    final bool repeat = orders.length >= 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(radius: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.blocked ? AC.muted : AC.primary,
                child: Text(c.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: AppText.body)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded, size: 11, color: AC.muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(c.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 11, color: AC.muted),
                        const SizedBox(width: 4),
                        Text('${orders.length} ${orders.length == 1 ? 'order' : 'orders'}', style: const TextStyle(color: AC.muted, fontSize: 10)),
                        if (orders.isNotEmpty) ...[
                          const Text('  •  ', style: TextStyle(color: AC.muted, fontSize: 10)),
                          Text('last ${timeAgo(orders.first.placedAt)}', maxLines: 1, style: const TextStyle(color: AC.muted, fontSize: 10)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(inr(spent), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 3),
                  if (c.blocked)
                    _pill('Blocked', AC.danger, icon: Icons.block_rounded)
                  else if (repeat)
                    _pill('Repeat', AC.success, icon: Icons.repeat_rounded)
                  else if (orders.isEmpty)
                      _pill('New', AC.warning, icon: Icons.fiber_new_rounded)
                    else
                      _pill('Active', AC.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Customer detail
// ===========================================================================

/// Customer detail: profile, stats, addresses, wishlist, order history, block / unblock.
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  bool _showAllOrders = false;

  String _shareText(dynamic c, int orders, int spent) => [
    'PhoneHub - Customer',
    'Name: ${c.name}',
    'Phone: ${c.phone}',
    'Email: ${c.email}',
    'Orders: $orders',
    'Total spent: ${inr(spent)}',
    if ((c.addresses as List).isNotEmpty) 'Address: ${c.addresses.first}',
  ].join('\n');

  Widget _hero(String v, String l) => Expanded(
    child: Column(
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: (AppText.subtitle - 2)))),
        const SizedBox(height: 2),
        FittedBox(fit: BoxFit.scaleDown, child: Text(l, style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 1)))),
      ],
    ),
  );

  Widget _mini(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: cardDeco(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1))),
        ],
      ),
    ),
  );

  Widget _emptyCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(radius: 12),
    child: Text(text, style: const TextStyle(color: AC.muted, fontSize: AppText.small)),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.customerById(widget.customerId);
        if (c == null) {
          return Scaffold(
            appBar: _appBar(context, 'Customer'),
            body: const EmptyState(icon: Icons.error_outline, title: 'Customer not found'),
          );
        }
        final orders = store.ordersOf(c.id);
        final valid = orders.where((o) => !o.cancelled).toList();
        final spent = valid.fold<int>(0, (s, o) => s + (o.total as int));
        final avg = valid.isEmpty ? 0 : (spent / valid.length).round();
        final delivered = orders.where((o) => o.isDelivered).length;
        final cancelled = orders.where((o) => o.cancelled).length;
        final ongoing = orders.length - delivered - cancelled;
        final codDue = orders.where((o) => !o.cancelled && !o.isDelivered && o.isCod).fold<int>(0, (s, o) => s + (o.total as int));
        final wish = c.wishlist.map(store.phoneById).whereType<Phone>().toList();
        final shown = _showAllOrders ? orders : orders.take(3).toList();

        return Scaffold(
          appBar: _appBar(
            context,
            'Customer',
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share',
                onPressed: () => Share.share(_shareText(c, orders.length, spent), subject: 'PhoneHub customer - ${c.name}'),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // profile card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 26, backgroundColor: Colors.white, child: Text(c.initial, style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900, fontSize: 22))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: AppText.body)),
                              Text(c.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 1))),
                              Text(c.phone, style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 1))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text(c.blocked ? 'BLOCKED' : (orders.length >= 2 ? 'REPEAT' : (orders.isEmpty ? 'NEW' : 'ACTIVE')),
                              style: TextStyle(color: c.blocked ? AC.danger : AC.primary, fontSize: (AppText.small - 2), fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _hero('${orders.length}', 'Orders'),
                        Container(width: 1, height: 32, color: Colors.white24),
                        _hero(inr(spent), 'Spent'),
                        Container(width: 1, height: 32, color: Colors.white24),
                        _hero(fmtDate(c.joined), 'Joined'),
                      ],
                    ),
                  ],
                ),
              ),
              if (c.blocked) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AC.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: const [
                      Icon(Icons.block_rounded, size: 18, color: AC.danger),
                      SizedBox(width: 8),
                      Expanded(child: Text('This customer is blocked and cannot place new orders.', style: TextStyle(color: AC.danger, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // quick actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyText(context, c.phone, 'Number copied'),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyText(context, c.email, 'Email copied'),
                      icon: const Icon(Icons.email_rounded, size: 18),
                      label: const Text('Email'),
                    ),
                  ),
                ],
              ),
              // insights
              _heading('Insights'),
              Row(
                children: [
                  _mini('Avg order', inr(avg), AC.primary),
                  const SizedBox(width: 8),
                  _mini('Delivered', '$delivered', AC.success),
                  const SizedBox(width: 8),
                  _mini('Ongoing', '$ongoing', AC.warning),
                  const SizedBox(width: 8),
                  _mini('Cancelled', '$cancelled', AC.danger),
                ],
              ),
              if (codDue > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AC.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_rounded, size: 18, color: AC.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Cash on delivery to collect: ${inr(codDue)}', style: const TextStyle(color: AC.warning, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
              ],
              // addresses
              _heading('Saved addresses (${c.addresses.length})'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: cardDeco(radius: 12),
                child: c.addresses.isEmpty
                    ? const Text('No saved addresses', style: TextStyle(color: AC.muted, fontSize: AppText.small))
                    : Column(
                  children: [
                    for (final a in c.addresses)
                      InkWell(
                        onTap: () => _copyText(context, a, 'Address copied'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, color: AC.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(a, style: const TextStyle(fontSize: (AppText.body - 1), height: 1.35))),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, size: 14, color: AC.muted),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // wishlist
              _heading('Wishlist (${wish.length})'),
              if (wish.isEmpty)
                _emptyCard('Nothing saved')
              else
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wish.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: wish[i]))),
                      child: Container(
                        width: 190,
                        padding: const EdgeInsets.all(8),
                        decoration: cardDeco(radius: 12),
                        child: Row(
                          children: [
                            PhoneThumb(wish[i], size: 44),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(wish[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(inr(wish[i].price), style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // order history
              _heading(
                'Order history (${orders.length})',
                trailing: orders.length > 3
                    ? TextButton(
                  onPressed: () => setState(() => _showAllOrders = !_showAllOrders),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: Text(_showAllOrders ? 'Show less' : 'View all', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.small - 1))),
                )
                    : null,
              ),
              if (orders.isEmpty) _emptyCard('No orders yet'),
              for (final o in shown) OrderTile(order: o),
              const SizedBox(height: 14),
              Container(
                decoration: cardDeco(radius: 12),
                child: SwitchListTile(
                  value: c.blocked,
                  activeColor: AC.danger,
                  onChanged: (v) async {
                    final ok = await confirmDialog(context, v ? 'Block ${c.name}?' : 'Unblock ${c.name}?', v ? 'They will not be able to place new orders until you unblock them.' : 'They can place orders again.', yes: v ? 'Block' : 'Unblock', danger: v);
                    if (ok) {
                      c.blocked = v;
                      store.changed();
                      if (context.mounted) snack(context, v ? '${c.name} blocked' : '${c.name} unblocked');
                    }
                  },
                  title: const Text('Block customer', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Stops new orders from this account', style: TextStyle(fontSize: AppText.small, color: AC.muted)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Brands  (same look as the Coupons & Offers screen)
// ===========================================================================

// Text sizes used on the Brands screen.
const double _bHeader = 18; // screen title
const double _bTitle = 12; // card / section titles
const double _bBody = 10.5; // normal text
const double _bSmall = 9.5; // hints, chips, labels
const double _bTiny = 8.5; // tiny captions

String _brandInitial(String n) => n.trim().isEmpty ? '?' : n.trim()[0].toUpperCase();

/// Brands: summary, search, filter pills with counts, sort, add / edit / view phones / delete.
class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  static const tabs = ['All', 'Active', 'Hidden'];
  static const _sorts = ['Default order', 'Name A-Z', 'Most phones', 'Most stock'];

  final TextEditingController _search = TextEditingController();
  String tab = 'All';
  String sort = 'Default order';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchTab(Brand b, String t) => t == 'All' || (t == 'Active' && b.active) || (t == 'Hidden' && !b.active);
  int _count(String t) => store.brands.where((b) => _matchTab(b, t)).length;
  int _phonesOf(Brand b) => store.phones.where((p) => p.brand == b.name).length;
  int _unitsOf(Brand b) => store.phones.where((p) => p.brand == b.name).fold<int>(0, (s, p) => s + p.stock);

  Future<void> _edit({Brand? brand}) async {
    // The editor is its own widget: it creates AND disposes its text controller,
    // so it is never disposed while the closing sheet is still using it.
    final result = await showModalBottomSheet<({String name, Color color})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BrandEditor(brand: brand),
    );
    if (result == null || !mounted) return;

    final n = result.name;
    if (brand == null) {
      store.brands.add(Brand(n, result.color));
    } else {
      final old = brand.name;
      brand
        ..name = n
        ..color = result.color;
      for (final p in store.phones.where((p) => p.brand == old)) {
        p.brand = n;
      }
    }
    store.changed();
    snack(context, brand == null ? '$n added' : '$n updated');
  }

  /// Bottom sheet listing all phones of a brand.
  Future<void> _showPhones(Brand b) async {
    final phones = store.phones.where((p) => p.brand == b.name).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(8)),
                      child: Text(_brandInitial(b.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Text('${b.name} phones', style: const TextStyle(fontSize: _bHeader - 2, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('${phones.length}', style: const TextStyle(color: AC.muted, fontSize: _bBody, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                if (phones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No phones in this brand yet', style: TextStyle(color: AC.muted, fontSize: _bBody + 1))),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: phones.length,
                      itemBuilder: (_, i) {
                        final p = phones[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: cardDeco(radius: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: p)));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  PhoneThumb(p, size: 38),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _bTitle)),
                                        const SizedBox(height: 2),
                                        Text('${p.storage} • ${p.condition} • ${inr(p.price)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _bSmall)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _bChip('${p.stock} left', statusColor(p.stockLabel)),
                                ],
                              ),
                            ),
                          ),
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

  Future<void> _delete(Brand b) async {
    final count = store.phoneCountOfBrand(b.name);
    if (count > 0) {
      snack(context, 'Remove or move the $count ${b.name} phones first');
      return;
    }
    final ok = await confirmDialog(context, 'Delete ${b.name}?', 'This brand will be removed from the customer app.', yes: 'Delete', danger: true);
    if (ok) {
      store.brands.remove(b);
      store.changed();
      if (mounted) snack(context, '${b.name} deleted');
    }
  }

  void _toggle(Brand b, bool v) {
    b.active = v;
    store.changed();
    snack(context, v ? '${b.name} is visible to customers' : '${b.name} is hidden from customers');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = _search.text.trim().toLowerCase();
        final all = store.brands;
        final list = all.where((b) => _matchTab(b, tab)).where((b) => q.isEmpty || b.name.toLowerCase().contains(q)).toList();

        switch (sort) {
          case 'Name A-Z':
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          case 'Most phones':
            list.sort((a, b) => _phonesOf(b).compareTo(_phonesOf(a)));
          case 'Most stock':
            list.sort((a, b) => _unitsOf(b).compareTo(_unitsOf(a)));
          default:
            break;
        }

        final counts = {for (final t in tabs) t: _count(t)};

        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            leadingWidth: 48, // brings the title closer to the back arrow
            titleSpacing: 4, // small gap between back arrow and title
            title: const Text('Brands', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _bHeader)),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(),
            backgroundColor: AC.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add brand', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _bBody + 1)),
          ),
          body: Column(
            children: [
              // ---- search ----
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: _bBody + 1),
                    decoration: InputDecoration(
                      hintText: 'Search brands',
                      hintStyle: const TextStyle(fontSize: _bBody, color: AC.muted),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .18))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .18))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.2)),
                    ),
                  ),
                ),
              ),

             

              // ---- filter pills ----
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final t in tabs)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _BrandFilterPill(label: t, count: counts[t] ?? 0, selected: tab == t, onTap: () => setState(() => tab = t)),
                      ),
                  ],
                ),
              ),

              // ---- count + sort ----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    const Text('Your brands', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _bTitle)),
                    const SizedBox(width: 6),
                    Text('${list.length} shown', style: const TextStyle(color: AC.muted, fontSize: _bSmall)),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Sort',
                      initialValue: sort,
                      onSelected: (v) => setState(() => sort = v),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => [
                        for (final s in _sorts)
                          PopupMenuItem(value: s, height: 38, child: Text(s, style: TextStyle(fontSize: _bBody + 1, fontWeight: s == sort ? FontWeight.w800 : FontWeight.w500))),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort_rounded, size: 15, color: AC.primary),
                            const SizedBox(width: 4),
                            Text(sort, style: const TextStyle(color: AC.primary, fontSize: _bSmall, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- list ----
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                  icon: Icons.apartment_outlined,
                  title: all.isEmpty ? 'No brands yet' : 'No brands found',
                  subtitle: all.isEmpty ? 'Tap "Add brand" to create your first one' : 'Try another tab or search',
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final b = list[i];
                    return _BrandCard(
                      brand: b,
                      onTap: () => _edit(brand: b),
                      onEdit: () => _edit(brand: b),
                      onPhones: () => _showPhones(b),
                      onDelete: () => _delete(b),
                      onToggle: (v) => _toggle(b, v),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bStat(IconData icon, Color color, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: cardDeco(radius: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _bTitle + 2, height: 1.05, color: AC.text)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _bTiny)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Small rounded label used on the Brands screen.
Widget _bChip(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 10, color: color), const SizedBox(width: 4)],
      Text(text, maxLines: 1, style: TextStyle(color: color, fontSize: _bSmall, fontWeight: FontWeight.w800)),
    ],
  ),
);

class _BrandFilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _BrandFilterPill({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AC.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AC.primary : AC.muted.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: _bBody, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: .22) : AC.muted.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(fontSize: _bTiny, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ticket style brand card (same structure as the coupon card)
// ---------------------------------------------------------------------------

class _BrandCard extends StatelessWidget {
  final Brand brand;
  final bool preview; // true = live preview inside the editor (no actions)
  final VoidCallback? onTap, onEdit, onPhones, onDelete;
  final ValueChanged<bool>? onToggle;

  const _BrandCard({
    required this.brand,
    this.preview = false,
    this.onTap,
    this.onEdit,
    this.onPhones,
    this.onDelete,
    this.onToggle,
  });

  static const double _leftW = 86;

  @override
  Widget build(BuildContext context) {
    final b = brand;
    final phones = store.phones.where((p) => p.brand == b.name).toList();
    final units = phones.fold<int>(0, (s, p) => s + p.stock);
    final low = phones.where((p) => p.stock <= 3).length;

    final Gradient leftGradient = b.active
        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [b.color, Color.lerp(b.color, Colors.black, .30)!])
        : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB9BECB), Color(0xFF9096A8)]);

    final statusColor0 = b.active ? AC.success : AC.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(radius: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: preview ? null : onTap,
            child: Stack(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------- left: the brand logo ----------
                      Container(
                        width: _leftW,
                        decoration: BoxDecoration(gradient: leftGradient),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        child: Stack(
                          children: [
                            Positioned(right: -26, top: -26, child: _bubble(70, .08)),
                            Positioned(left: -22, bottom: -28, child: _bubble(64, .07)),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(12)),
                                    child: Text(_brandInitial(b.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${phones.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1)),
                                  const SizedBox(height: 2),
                                  Text(phones.length == 1 ? 'PHONE' : 'PHONES', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: _bTiny, letterSpacing: .4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ---------- dashed tear line ----------
                      SizedBox(width: 1, child: CustomPaint(painter: _BrandDashPainter(AC.muted.withValues(alpha: .35)))),
                      // ---------- right: the details ----------
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.name.isEmpty ? 'Brand name' : b.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: _bTitle + 1, color: b.name.isEmpty ? AC.muted : AC.text),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor0.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 5, height: 5, decoration: BoxDecoration(color: statusColor0, shape: BoxShape.circle)),
                                        const SizedBox(width: 4),
                                        Text(b.active ? 'Visible' : 'Hidden', style: TextStyle(color: statusColor0, fontSize: _bSmall, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                  if (!preview)
                                    PopupMenuButton<String>(
                                      tooltip: 'More',
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      icon: const Icon(Icons.more_vert_rounded, color: AC.muted),
                                      constraints: const BoxConstraints(minWidth: 130),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (v) {
                                        if (v == 'phones') onPhones?.call();
                                        if (v == 'edit') onEdit?.call();
                                        if (v == 'delete') onDelete?.call();
                                      },
                                      itemBuilder: (_) => [
                                        _menu('phones', Icons.smartphone_rounded, 'View phones'),
                                        _menu('edit', Icons.edit_outlined, 'Edit brand'),
                                        _menu('delete', Icons.delete_outline_rounded, 'Delete', color: AC.danger),
                                      ],
                                    )
                                  else
                                    const SizedBox(width: 8),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  _infoChip(Icons.inventory_2_outlined, '$units ${units == 1 ? 'unit' : 'units'} in stock'),
                                  if (low > 0) _infoChip(Icons.warning_amber_rounded, '$low low stock', color: AC.warning),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Divider(height: 1, color: AC.muted.withValues(alpha: .14)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(b.active ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 13, color: AC.muted),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      b.active ? 'Shown to customers' : 'Hidden from customers',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AC.muted, fontSize: _bSmall),
                                    ),
                                  ),
                                  if (!preview)
                                    Transform.scale(
                                      scale: .72,
                                      child: Switch(
                                        value: b.active,
                                        activeColor: AC.success,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: onToggle,
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 28),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ticket notches on the tear line
                Positioned(left: _leftW - 5, top: -6, child: _notch()),
                Positioned(left: _leftW - 5, bottom: -6, child: _notch()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notch() => Container(width: 11, height: 11, decoration: const BoxDecoration(color: AC.bg, shape: BoxShape.circle));

  Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );

  Widget _infoChip(IconData icon, String text, {Color color = AC.muted}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: color == AC.muted ? AC.bg : color.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: _bSmall - .5, color: color == AC.muted ? AC.text : color, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  PopupMenuItem<String> _menu(String v, IconData icon, String label, {Color? color}) => PopupMenuItem(
    value: v,
    height: 38,
    child: Row(
      children: [
        Icon(icon, size: 16, color: color ?? AC.text),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: _bBody + 1, fontWeight: FontWeight.w600, color: color ?? AC.text)),
      ],
    ),
  );
}

class _BrandDashPainter extends CustomPainter {
  final Color color;
  _BrandDashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    double y = 8;
    while (y < size.height - 8) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + 4), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _BrandDashPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Add / edit brand sheet
// ---------------------------------------------------------------------------

class _BrandEditor extends StatefulWidget {
  final Brand? brand;
  const _BrandEditor({required this.brand});

  @override
  State<_BrandEditor> createState() => _BrandEditorState();
}

class _BrandEditorState extends State<_BrandEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.brand?.name ?? '');
  late Color _color = widget.brand?.color ?? swatches[0];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.brand == null ? 'Add brand' : 'Edit brand', style: const TextStyle(fontSize: _bHeader - 2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // live preview (same card as the list)
          _BrandCard(brand: Brand(_name.text.trim(), _color, active: widget.brand?.active ?? true), preview: true),
          const SizedBox(height: 4),
          TextField(
            controller: _name,
            autofocus: widget.brand == null,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: _bBody + 1, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Brand name',
              errorText: _error,
              isDense: true,
              labelStyle: const TextStyle(fontSize: _bBody, color: AC.muted),
              errorStyle: const TextStyle(fontSize: _bSmall),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Brand colour (also used as logo colour)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _bBody + 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final s in swatches)
                GestureDetector(
                  onTap: () => setState(() => _color = s),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: s, shape: BoxShape.circle, border: Border.all(color: s == _color ? AC.text : Colors.transparent, width: 2.5)),
                    child: s == _color ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), textStyle: const TextStyle(fontSize: _bBody + 2, fontWeight: FontWeight.w800)),
            onPressed: () {
              final n = _name.text.trim();
              if (n.isEmpty) {
                setState(() => _error = 'Enter a brand name');
                return;
              }
              final dup = store.brands.any((b) => b != widget.brand && b.name.toLowerCase() == n.toLowerCase());
              if (dup) {
                setState(() => _error = 'This brand already exists');
                return;
              }
              Navigator.pop(context, (name: n, color: _color));
            },
            child: Text(widget.brand == null ? 'Add brand' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}