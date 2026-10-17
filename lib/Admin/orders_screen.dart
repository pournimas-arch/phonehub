import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/Admin/order_details.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/app_text.dart';

// ===========================================================================
// Shared helpers
// ===========================================================================

/// Small rounded label (used for payment type, counts, etc.).
Widget _pill(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
      Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ],
  ),
);

/// One-line notice at the bottom of an order card (same size as "This order was cancelled").
Widget _flag(IconData icon, Color color, String text) => Padding(
  padding: const EdgeInsets.only(top: 6),
  child: Row(
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700))),
    ],
  ),
);

/// Order status label (Payment Confirmed, Cancelled, Delivered...). Same text size as the Paid label.
Widget _statusChip(dynamic o) {
  final Color c = o.cancelled ? AC.danger : statusColor(o.statusLabel);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(o.statusLabel, maxLines: 1, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ===========================================================================
// Order card (Orders list, Dashboard and Customer detail)
// ===========================================================================

/// Order card: phone name on top, then customer, time, amount and payment type.
class OrderTile extends StatelessWidget {
  // dynamic on purpose: accepts an AdminOrder even if admin_data.dart is imported
  // under two different paths in your project (avoids the "argument type can't be assigned" error).
  final dynamic order;
  const OrderTile({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final first = o.items.first;
    final extra = o.items.length > 1 ? ' +${o.items.length - 1} more' : '';
    final bool cancelled = o.cancelled;
    final String name = store.customerName(o.customerId).toString();
    final String customer = name.trim().isEmpty ? 'Unknown customer' : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(radius: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // top: phone icon + phone name, status on the right
              Row(
                children: [
                  const IconBadge(Icons.smartphone_rounded, AC.primary, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${first.name}$extra', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  _statusChip(o),
                ],
              ),
              const SizedBox(height: 0),
              // below: customer name + time on the left, amount + payment on the right
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 12, color: AC.muted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(customer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 11, color: AC.muted),
                              const SizedBox(width: 4),
                              Text(timeAgo(o.placedAt), maxLines: 1, style: const TextStyle(color: AC.muted, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(inr(o.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        const SizedBox(height: 3),
                        _pill(o.isCod ? 'COD' : 'Paid', o.isCod ? AC.warning : AC.success, icon: o.isCod ? Icons.payments_outlined : Icons.verified_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              if (cancelled) ...[
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.cancel_rounded, size: 12, color: AC.danger),
                    SizedBox(width: 6),
                    Text('This order was cancelled', style: TextStyle(color: AC.danger, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
              // Delivery problems the admin has to act on (data written by the delivery partner app).
              if (!cancelled && o.needsReassign == true)
                _flag(Icons.undo_rounded, AC.danger, '${store.partnerById(o.rejectedBy)?.name ?? o.rejectedBy} gave it back. Assign a new partner'),
              if (!cancelled && o.hasFailedAttempt == true)
                _flag(Icons.report_problem_rounded, AC.warning, '${o.deliveryAttempts} failed ${o.deliveryAttempts == 1 ? 'attempt' : 'attempts'}${(o.failedReason as String).isEmpty ? '' : ': ${o.failedReason}'}'),
              if (!cancelled && o.cashPending == true)
                _flag(Icons.payments_rounded, AC.warning, '${inr(o.cashDue)} cash is with ${store.partnerById(o.partnerId)?.name ?? 'the partner'}'),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Orders list
// ===========================================================================

/// All orders with summary, tabs with counts, search, filters and sorting.
class OrdersScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const OrdersScreen({super.key, this.onBack});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}
class _OrdersScreenState extends State<OrdersScreen> {
  static const tabs = ['All', 'New', 'Ongoing', 'Attention', 'Delivered', 'Cancelled'];
  static const dates = ['All time', 'Today', 'Last 7 days', 'Last 30 days'];
  static const sorts = ['Newest first', 'Oldest first', 'Amount: high to low', 'Amount: low to high'];

  String tab = 'All';
  String query = '';
  String pay = 'All payments';
  String date = 'All time';
  String sort = 'Newest first';

  bool _matchTab(AdminOrder o, String t) {
    switch (t) {
      case 'New':
        return !o.cancelled && o.stage <= 1;
      case 'Ongoing':
        return !o.cancelled && o.stage >= 2 && o.stage <= 3;
      case 'Attention':
      // Given back by a partner, or a delivery attempt failed: the admin must act.
        return o.needsReassign || o.hasFailedAttempt;
      case 'Delivered':
        return o.isDelivered;
      case 'Cancelled':
        return o.cancelled;
    }
    return true;
  }

  bool _inDate(AdminOrder o) {
    final now = DateTime.now();
    DateTime from;
    switch (date) {
      case 'Today':
        from = DateTime(now.year, now.month, now.day);
        break;
      case 'Last 7 days':
        from = now.subtract(const Duration(days: 7));
        break;
      case 'Last 30 days':
        from = now.subtract(const Duration(days: 30));
        break;
      default:
        return true;
    }
    return !o.placedAt.isBefore(from);
  }

  int _count(String t) => store.orders.where((o) => _matchTab(o, t)).length;

  bool get _filtersOn => pay != 'All payments' || date != 'All time' || sort != 'Newest first';
  int get _filterCount => (pay != 'All payments' ? 1 : 0) + (date != 'All time' ? 1 : 0) + (sort != 'Newest first' ? 1 : 0);

  void _resetFilters() => setState(() {
    pay = 'All payments';
    date = 'All time';
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

          Widget group(String title, List<String> items, String value, void Function(String) onPick) => Column(
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
                      onSelected: (_) => pick(() => onPick(x)),
                    ),
                ],
              ),
            ],
          );

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
                  group('Payment', ['All payments', ...paymentMethods], pay, (v) => pay = v),
                  group('Date', dates, date, (v) => date = v),
                  group('Sort by', sorts, sort, (v) => sort = v),
                  const SizedBox(height: 18),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Show orders')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary() {
    final all = store.orders;
    // COD money not in the admin's hands yet: orders still to deliver + cash the partners hold.
    final cod = all.where((o) => !o.cancelled && !o.isDelivered && o.isCod).fold<num>(0, (a, o) => a + o.total) + store.totalCashPending;
    Widget stat(IconData icon, String label, String value) => Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: (AppText.subtitle - 2), fontWeight: FontWeight.w900))),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 1)))),
        ],
      ),
    );
    Widget divider() => Container(width: 1, height: 38, color: Colors.white24);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          stat(Icons.receipt_long_rounded, 'Orders', '${all.length}'),
          divider(),
          stat(Icons.trending_up_rounded, 'Revenue', inr(store.totalRevenue)),
          divider(),
          stat(Icons.payments_rounded, 'COD to collect', inr(cod.round())),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = store.orders.where((o) => _matchTab(o, tab)).where(_inDate).where((o) {
          if (pay != 'All payments' && o.paymentMethod != pay) return false;
          if (q.isEmpty) return true;
          final phone = (store.customerById(o.customerId)?.phone ?? '').replaceAll(' ', '');
          final partner = (store.partnerById(o.partnerId)?.name ?? '').toLowerCase();
          return o.id.toLowerCase().contains(q) ||
              store.customerName(o.customerId).toLowerCase().contains(q) ||
              phone.contains(q.replaceAll(' ', '')) ||
              partner.contains(q) ||
              o.items.any((i) => i.name.toLowerCase().contains(q));
        }).toList();

        switch (sort) {
          case 'Oldest first':
            list.sort((a, b) => a.placedAt.compareTo(b.placedAt));
            break;
          case 'Amount: high to low':
            list.sort((a, b) => b.total.compareTo(a.total));
            break;
          case 'Amount: low to high':
            list.sort((a, b) => a.total.compareTo(b.total));
            break;
          default:
            list.sort((a, b) => b.placedAt.compareTo(a.placedAt));
        }

        final listTotal = list.where((o) => !o.cancelled).fold<num>(0, (a, o) => a + o.total);
        final bool canPop = Navigator.of(context).canPop();

        return Scaffold(
          appBar: AppBar(
            // Title sits right after the back button (left aligned, not centered).
            centerTitle: false,
            titleSpacing: canPop ? 0 : 16,
            leadingWidth: canPop ? 40 : null,
            leading: canPop
                ? IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            )
                : null,
            title: const Text('Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                child: SearchBox(hint: 'Search order ID, customer, phone or partner', onChanged: (v) => setState(() => query = v)),
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
                      if (pay != 'All payments') _activeChip(pay, () => setState(() => pay = 'All payments')),
                      if (date != 'All time') _activeChip(date, () => setState(() => date = 'All time')),
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
                    Text('${list.length} ${list.length == 1 ? 'order' : 'orders'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1))),
                    const Spacer(),
                    if (list.isNotEmpty) Text('Worth ${inr(listTotal.round())}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders found', subtitle: 'Try another tab, search or filter'),
                )
              else
                for (final o in list) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: OrderTile(order: o)),
            ],
          ),
        );
      },
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) => Chip(
    label: Text(label, style: const TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: AC.primary)),
    backgroundColor: AC.primary.withValues(alpha: 0.08),
    side: BorderSide.none,
    deleteIcon: const Icon(Icons.close_rounded, size: 15, color: AC.primary),
    onDeleted: onRemove,
    visualDensity: VisualDensity.compact,
  );
}