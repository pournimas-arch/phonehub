import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/Admin/order_details.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

// -----------------------------------------------------------------------------
// Text sizes (same as the Coupons & Offers screen).
// -----------------------------------------------------------------------------
const double _fHeader = 18; // screen title
const double _fTitle = 12; // card titles / section titles
const double _fBody = 10.5; // normal text
const double _fSmall = 9.5; // hints, chips, labels
const double _fTiny = 8.5; // tiny captions

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

bool _inPeriod(DateTime d, String period) {
  final n = DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  switch (period) {
    case 'Today':
      return diff <= 0;
    case 'Last 7 days':
      return diff < 7;
    case 'Last 30 days':
      return diff < 30;
    default:
      return true;
  }
}

const _periods = ['All time', 'Today', 'Last 7 days', 'Last 30 days'];

Widget _searchBox(TextEditingController c, String hint, VoidCallback onChanged) => Padding(
  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
  child: SizedBox(
    height: 42,
    child: TextField(
      controller: c,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: _fBody + 1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 19),
        suffixIcon: c.text.isEmpty
            ? null
            : IconButton(
          tooltip: 'Clear search',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            c.clear();
            onChanged();
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
);

Widget _stat(IconData icon, Color color, String value, String label) => Expanded(
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 2, height: 1.05, color: AC.text)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, maxLines: 1, style: const TextStyle(color: AC.muted, fontSize: _fTiny)),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _statsRow(List<Widget> stats) => Padding(
  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
  child: Row(
    children: [
      for (int i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        stats[i],
      ],
    ],
  ),
);

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.count, required this.selected, required this.onTap});

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
            Text(label, style: TextStyle(fontSize: _fBody, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: .22) : AC.muted.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(fontSize: _fTiny, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _pills(List<String> items, Map<String, int> counts, String selected, ValueChanged<String> onSelect) => SizedBox(
  height: 34,
  child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    children: [
      for (final f in items)
        Padding(
          padding: const EdgeInsets.only(right: 7),
          child: _FilterPill(label: f, count: counts[f] ?? 0, selected: selected == f, onTap: () => onSelect(f)),
        ),
    ],
  ),
);

Widget _popup(IconData icon, String value, List<String> items, ValueChanged<String> onSelected) => PopupMenuButton<String>(
  tooltip: value,
  initialValue: value,
  onSelected: onSelected,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  itemBuilder: (_) => [
    for (final s in items)
      PopupMenuItem(value: s, height: 38, child: Text(s, style: TextStyle(fontSize: _fBody + 1, fontWeight: s == value ? FontWeight.w800 : FontWeight.w500))),
  ],
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AC.primary),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: AC.primary, fontSize: _fSmall, fontWeight: FontWeight.w800)),
      ],
    ),
  ),
);

Widget _listHeader(String title, int shown, List<Widget> actions) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
          ),
          const SizedBox(width: 6),
          Text('$shown shown', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
        ],
      ),
      // filters live in their own row, so they can never overflow the screen
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              actions[i],
            ],
          ],
        ),
      ),
    ],
  ),
);

Widget _statusPill(String status, {Color? color}) {
  final c = color ?? statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(color: c, fontSize: _fSmall, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

Widget _infoChip(IconData icon, String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  decoration: BoxDecoration(color: AC.bg, borderRadius: BorderRadius.circular(6)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: AC.muted),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: _fSmall - .5, color: AC.text, fontWeight: FontWeight.w600)),
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
      Text(label, style: TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600, color: color ?? AC.text)),
    ],
  ),
);

Widget _moreButton(List<PopupMenuItem<String>> items, ValueChanged<String> onSelected) => PopupMenuButton<String>(
  tooltip: 'More',
  padding: EdgeInsets.zero,
  iconSize: 18,
  icon: const Icon(Icons.more_vert_rounded, color: AC.muted),
  constraints: const BoxConstraints(minWidth: 130),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  onSelected: onSelected,
  itemBuilder: (_) => items,
);

Widget _card({required Widget child, VoidCallback? onTap}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  decoration: cardDeco(radius: 16),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Material(
      color: Colors.white,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 6, 8), child: child)),
    ),
  ),
);

Widget _noteBox(IconData icon, String text) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(color: AC.primary.withValues(alpha: .07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.primary.withValues(alpha: .2))),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AC.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: AC.text, fontSize: _fSmall, height: 1.35))),
    ],
  ),
);

void _copy(BuildContext context, String text, String what) {
  Clipboard.setData(ClipboardData(text: text));
  snack(context, '$what copied');
}

void _openOrder(BuildContext context, String orderId) => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
);

// -----------------------------------------------------------------------------
// Main screen: Payments & Refunds
// -----------------------------------------------------------------------------

/// Payments & Refunds: Transactions | Refunds | COD report.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final compactTextTheme = baseTheme.textTheme.apply(fontSizeDelta: -2);
    return Theme(
      data: baseTheme.copyWith(textTheme: compactTextTheme),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: false,
            leadingWidth: 48,
            titleSpacing: 4,
            title: const Text('Payments & Refunds', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.muted.withValues(alpha: .15)))),
                child: const TabBar(
                  isScrollable: false, // 3 tabs share the full width equally
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  labelPadding: EdgeInsets.zero,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AC.primary,
                  unselectedLabelColor: AC.muted,
                  indicatorColor: AC.primary,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1),
                  tabs: [
                    Tab(height: 44, icon: Icon(Icons.receipt_long_outlined, size: 16), text: 'Transactions'),
                    Tab(height: 44, icon: Icon(Icons.currency_rupee_rounded, size: 16), text: 'Refunds'),
                    Tab(height: 44, icon: Icon(Icons.payments_outlined, size: 16), text: 'COD'),
                  ],
                ),
              ),
            ),
          ),
          body: const TabBarView(children: [_TxnTab(), _RefundTab(), _CodTab()]),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 1: Transactions
// -----------------------------------------------------------------------------

class _TxnTab extends StatefulWidget {
  const _TxnTab();

  @override
  State<_TxnTab> createState() => _TxnTabState();
}

class _TxnTabState extends State<_TxnTab> {
  final TextEditingController _search = TextEditingController();
  String _status = 'All';
  String _method = 'All methods';
  String _period = 'All time';
  String _sort = 'Newest first';

  static const _sorts = ['Newest first', 'Oldest first', 'Highest amount'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData _icon(String m) {
    switch (m) {
      case 'UPI':
        return Icons.qr_code_2_rounded;
      case 'Debit/Credit Card':
        return Icons.credit_card_rounded;
      case 'Net Banking':
        return Icons.account_balance_rounded;
      case 'Wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.payments_outlined;
    }
  }

  String _report(List<dynamic> list) {
    final b = StringBuffer('Transaction report ($_period, $_method, $_status)\n');
    for (final t in list) {
      b.writeln('${t.id}, Order ${t.orderId}, ${t.method}, ${t.amount}, ${t.status}, ${fmtDateTime(t.date)}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final all = store.txns;

        int sum(Iterable it) => it.fold<int>(0, (s, t) => s + (t.amount as int));
        final collected = sum(all.where((t) => t.status == 'Success'));
        final pending = sum(all.where((t) => t.status == 'Pending'));
        final refunded = sum(all.where((t) => t.status == 'Refunded'));
        final failedCount = all.where((t) => t.status != 'Success' && t.status != 'Pending' && t.status != 'Refunded').length;

        final statuses = <String>['All', ...{for (final t in all) t.status}];
        final counts = <String, int>{'All': all.length};
        for (final t in all) {
          counts[t.status] = (counts[t.status] ?? 0) + 1;
        }

        final list = all.where((t) {
          final matchesSearch = query.isEmpty ||
              t.id.toLowerCase().contains(query) ||
              t.orderId.toLowerCase().contains(query) ||
              t.method.toLowerCase().contains(query);
          final matchesStatus = _status == 'All' || t.status == _status;
          final matchesMethod = _method == 'All methods' || t.method == _method;
          return matchesSearch && matchesStatus && matchesMethod && _inPeriod(t.date, _period);
        }).toList();

        switch (_sort) {
          case 'Oldest first':
            list.sort((a, b) => a.date.compareTo(b.date));
          case 'Highest amount':
            list.sort((a, b) => b.amount.compareTo(a.amount));
          default:
            list.sort((a, b) => b.date.compareTo(a.date));
        }

        // money by payment method (successful payments only)
        final byMethod = <String, int>{};
        for (final t in all.where((t) => t.status == 'Success')) {
          byMethod[t.method] = (byMethod[t.method] ?? 0) + (t.amount as int);
        }
        final methodTotal = byMethod.values.fold<int>(0, (a, b) => a + b);

        return Column(
          children: [
            _searchBox(_search, 'Search by transaction, order or method', () => setState(() {})),
            _statsRow([
              _stat(Icons.check_circle_rounded, AC.success, inr(collected), 'Collected'),
              _stat(Icons.hourglass_bottom_rounded, AC.warning, inr(pending), 'Pending'),
              _stat(Icons.undo_rounded, AC.danger, inr(refunded), 'Refunded'),
              _stat(Icons.error_outline_rounded, AC.muted, '$failedCount', 'Other'),
            ]),
            _pills(statuses, counts, _status, (v) => setState(() => _status = v)),
            _listHeader('Transactions', list.length, [
              _popup(Icons.account_balance_wallet_outlined, _method, ['All methods', ...paymentMethods], (v) => setState(() => _method = v)),
              _popup(Icons.event_outlined, _period, _periods, (v) => setState(() => _period = v)),
              _popup(Icons.sort_rounded, _sort, _sorts, (v) => setState(() => _sort = v)),
            ]),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                icon: all.isEmpty ? Icons.payments_outlined : Icons.search_off_rounded,
                title: all.isEmpty ? 'No transactions yet' : 'No matching transactions',
                subtitle: all.isEmpty ? 'Payments will show up here' : 'Try another search or filter',
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                children: [
                  if (byMethod.isNotEmpty && query.isEmpty && _status == 'All' && _method == 'All methods' && _period == 'All time')
                    _methodBreakdown(byMethod, methodTotal),
                  Row(
                    children: [
                      Expanded(child: _noteBox(Icons.info_outline_rounded, 'Total of ${list.length} shown: ${inr(sum(list))}')),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10), side: BorderSide(color: AC.primary.withValues(alpha: .4))),
                          onPressed: () => _copy(context, _report(list), 'Report'),
                          icon: const Icon(Icons.copy_all_rounded, size: 14),
                          label: const Text('Copy report', style: TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                  for (final t in list) _txnCard(context, t),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _methodBreakdown(Map<String, int> byMethod, int total) {
    final entries = byMethod.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pie_chart_outline_rounded, size: 14, color: AC.primary),
              SizedBox(width: 6),
              Text('Collected by payment method', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_icon(e.key), size: 13, color: AC.muted),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: _fBody, fontWeight: FontWeight.w600))),
                      Text('${inr(e.value)}  •  ${total == 0 ? 0 : (e.value * 100 / total).round()}%', style: const TextStyle(fontSize: _fSmall, color: AC.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : e.value / total,
                      minHeight: 5,
                      backgroundColor: AC.muted.withValues(alpha: .12),
                      valueColor: const AlwaysStoppedAnimation(AC.primary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _txnCard(BuildContext context, dynamic t) {
    final color = statusColor(t.status);
    return _card(
      onTap: () => _openOrder(context, t.orderId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_icon(t.method), size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inr(t.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 2, color: AC.text)),
                    Text(t.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                  ],
                ),
              ),
              _statusPill(t.status),
              _moreButton([
                _menu('order', Icons.receipt_long_outlined, 'View order'),
                _menu('id', Icons.copy_rounded, 'Copy transaction ID'),
                _menu('oid', Icons.content_copy_rounded, 'Copy order ID'),
              ], (v) {
                if (v == 'order') _openOrder(context, t.orderId);
                if (v == 'id') _copy(context, t.id, t.id);
                if (v == 'oid') _copy(context, t.orderId, 'Order ID');
              }),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _infoChip(_icon(t.method), t.method),
              _infoChip(Icons.shopping_bag_outlined, 'Order ${t.orderId}'),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AC.muted.withValues(alpha: .14)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 13, color: AC.muted),
              const SizedBox(width: 5),
              Expanded(child: Text(fmtDateTime(t.date), style: const TextStyle(color: AC.muted, fontSize: _fSmall))),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AC.muted),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 2: Refunds
// -----------------------------------------------------------------------------

class _RefundTab extends StatefulWidget {
  const _RefundTab();

  @override
  State<_RefundTab> createState() => _RefundTabState();
}

class _RefundTabState extends State<_RefundTab> {
  final TextEditingController _search = TextEditingController();
  String _status = 'All';
  String _period = 'All time';
  String _sort = 'Newest first';

  static const _sorts = ['Newest first', 'Oldest first', 'Highest amount'];
  static const _statuses = ['All', 'Requested', 'Approved', 'Refunded', 'Rejected'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final all = store.refunds;

        int sum(Iterable it) => it.fold<int>(0, (s, r) => s + (r.amount as int));
        final waiting = sum(all.where((r) => r.status == 'Requested' || r.status == 'Approved'));
        final needsAction = all.where((r) => r.status == 'Requested').length;
        final paidOut = sum(all.where((r) => r.status == 'Refunded'));
        final rejected = all.where((r) => r.status == 'Rejected').length;

        final counts = <String, int>{'All': all.length};
        for (final r in all) {
          counts[r.status] = (counts[r.status] ?? 0) + 1;
        }

        final list = all.where((r) {
          final matchesSearch = query.isEmpty ||
              r.id.toLowerCase().contains(query) ||
              r.orderId.toLowerCase().contains(query) ||
              r.reason.toLowerCase().contains(query) ||
              store.customerName(_customerOf(r.orderId)).toLowerCase().contains(query);
          return matchesSearch && (_status == 'All' || r.status == _status) && _inPeriod(r.date, _period);
        }).toList();

        switch (_sort) {
          case 'Oldest first':
            list.sort((a, b) => a.date.compareTo(b.date));
          case 'Highest amount':
            list.sort((a, b) => b.amount.compareTo(a.amount));
          default:
            list.sort((a, b) => b.date.compareTo(a.date));
        }

        return Column(
          children: [
            _searchBox(_search, 'Search by refund, order, customer or reason', () => setState(() {})),
            _statsRow([
              _stat(Icons.hourglass_bottom_rounded, AC.warning, inr(waiting), 'To refund'),
              _stat(Icons.pending_actions_rounded, AC.primary, '$needsAction', 'Need action'),
              _stat(Icons.check_circle_rounded, AC.success, inr(paidOut), 'Refunded'),
              _stat(Icons.block_rounded, AC.muted, '$rejected', 'Rejected'),
            ]),
            _pills(_statuses, counts, _status, (v) => setState(() => _status = v)),
            _listHeader('Refund requests', list.length, [
              _popup(Icons.event_outlined, _period, _periods, (v) => setState(() => _period = v)),
              _popup(Icons.sort_rounded, _sort, _sorts, (v) => setState(() => _sort = v)),
            ]),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                icon: all.isEmpty ? Icons.currency_rupee_rounded : Icons.search_off_rounded,
                title: all.isEmpty ? 'No refund requests' : 'No matching refunds',
                subtitle: all.isEmpty ? 'Customer refund requests appear here' : 'Try another search or filter',
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                children: [
                  _noteBox(Icons.info_outline_rounded, 'Refunds reach the customer in 5-7 working days after you mark them refunded. For second-hand phones, check the return reason and device condition before approving.'),
                  for (final r in list) _refundCard(context, r),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _customerOf(String orderId) {
    for (final o in store.orders) {
      if (o.id == orderId) return o.customerId;
    }
    return '';
  }

  Widget _refundCard(BuildContext context, dynamic r) {
    final customer = store.customerName(_customerOf(r.orderId));
    final open = r.status == 'Requested' || r.status == 'Approved';
    return _card(
      onTap: () => _openOrder(context, r.orderId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AC.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.currency_rupee_rounded, size: 18, color: AC.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inr(r.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 2, color: AC.primary)),
                    Text(r.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                  ],
                ),
              ),
              _statusPill(r.status),
              _moreButton([
                _menu('order', Icons.receipt_long_outlined, 'View order'),
                _menu('id', Icons.copy_rounded, 'Copy refund ID'),
              ], (v) {
                if (v == 'order') _openOrder(context, r.orderId);
                if (v == 'id') _copy(context, r.id, r.id);
              }),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _infoChip(Icons.shopping_bag_outlined, 'Order ${r.orderId}'),
              if (customer.isNotEmpty) _infoChip(Icons.person_outline_rounded, customer),
              _infoChip(Icons.event_outlined, fmtDateTime(r.date)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AC.bg, borderRadius: BorderRadius.circular(8)),
            child: Text('Reason: ${r.reason}', style: const TextStyle(fontSize: _fBody, color: AC.text, height: 1.3)),
          ),
          if (open) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                children: [
                  if (r.status == 'Requested') ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40), foregroundColor: AC.danger, side: const BorderSide(color: AC.danger), textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                        onPressed: () async {
                          final ok = await confirmDialog(context, 'Reject refund?', 'The customer will not receive ${inr(r.amount)}.', yes: 'Reject', danger: true);
                          if (ok) store.setRefund(r, 'Rejected');
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40), textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                        onPressed: () => store.setRefund(r, 'Approved'),
                        child: const Text('Approve'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40), backgroundColor: AC.success, textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                        onPressed: () {
                          store.setRefund(r, 'Refunded');
                          snack(context, '${inr(r.amount)} marked as refunded');
                        },
                        child: const Text('Mark as refunded'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tab 3: COD report
// -----------------------------------------------------------------------------

class _CodTab extends StatefulWidget {
  const _CodTab();

  @override
  State<_CodTab> createState() => _CodTabState();
}

class _CodTabState extends State<_CodTab> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';
  String _sort = 'Highest amount';

  static const _sorts = ['Highest amount', 'Lowest amount'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // A COD order is in one of three states:
  //  * not delivered yet          -> cash will be taken at the door
  //  * delivered, cash pending    -> the delivery partner still holds the cash
  //  * delivered, cash received   -> the admin got the cash (or delivered it himself)
  bool _isOpen(AdminOrder o) => !o.isDelivered;
  bool _isWithPartner(AdminOrder o) => o.cashPending;
  bool _isReceived(AdminOrder o) => o.isDelivered && !o.cashPending;

  int _amount(AdminOrder o) => o.isDelivered ? o.cashDue : o.total;

  /// Asks for confirmation and saves "cash received" for these orders.
  Future<void> _settle(List<AdminOrder> list, String who) async {
    final todo = list.where((o) => o.cashPending).toList();
    if (todo.isEmpty) return;
    final total = todo.fold<int>(0, (s, o) => s + o.cashDue);
    final ok = await confirmDialog(
      context,
      'Cash received?',
      'Confirm that you received ${inr(total)} from $who for ${todo.length} delivered order(s).',
      yes: 'Yes, received',
    );
    if (!ok || !mounted) return;
    final saved = await store.settleCash(todo);
    if (!mounted) return;
    snack(context, saved ? '${inr(total)} marked as received from $who' : 'Could not save. Please check your internet and try again.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final cod = store.orders.where((o) => o.isCod && !o.cancelled).toList();
        final open = cod.where(_isOpen).toList();
        final withPartner = cod.where(_isWithPartner).toList();
        final received = cod.where(_isReceived).toList();

        int sum(Iterable<AdminOrder> it) => it.fold<int>(0, (s, o) => s + _amount(o));
        final receivedTotal = sum(received);
        final withPartnerTotal = sum(withPartner);
        final toDeliverTotal = sum(open);
        final unassigned = open.where((o) => store.partnerById(o.partnerId) == null).length;

        final counts = {'All': cod.length, 'To deliver': open.length, 'With partner': withPartner.length, 'Received': received.length};

        final list = cod.where((o) {
          final partner = store.partnerById(o.partnerId)?.name ?? '';
          final matchesSearch = query.isEmpty ||
              o.id.toLowerCase().contains(query) ||
              store.customerName(o.customerId).toLowerCase().contains(query) ||
              partner.toLowerCase().contains(query);
          final matchesFilter = _filter == 'All' ||
              (_filter == 'To deliver' && _isOpen(o)) ||
              (_filter == 'With partner' && _isWithPartner(o)) ||
              (_filter == 'Received' && _isReceived(o));
          return matchesSearch && matchesFilter;
        }).toList();

        if (_sort == 'Lowest amount') {
          list.sort((a, b) => _amount(a).compareTo(_amount(b)));
        } else {
          list.sort((a, b) => _amount(b).compareTo(_amount(a)));
        }

        // cash that each delivery partner has collected but not yet handed over
        final byPartner = <String, List<AdminOrder>>{};
        for (final o in withPartner) {
          byPartner.putIfAbsent(o.partnerId!, () => <AdminOrder>[]).add(o);
        }

        return Column(
          children: [
            _searchBox(_search, 'Search by order, customer or partner', () => setState(() {})),
            _statsRow([
              _stat(Icons.check_circle_rounded, AC.success, inr(receivedTotal), 'Received'),
              _stat(Icons.hourglass_bottom_rounded, AC.warning, inr(withPartnerTotal), 'With partners'),
              _stat(Icons.local_shipping_outlined, AC.primary, inr(toDeliverTotal), 'To deliver'),
              _stat(Icons.person_off_outlined, AC.danger, '$unassigned', 'No partner'),
            ]),
            _pills(['All', 'To deliver', 'With partner', 'Received'], counts, _filter, (v) => setState(() => _filter = v)),
            _listHeader('Cash on Delivery orders', list.length, [
              _popup(Icons.sort_rounded, _sort, _sorts, (v) => setState(() => _sort = v)),
            ]),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                icon: cod.isEmpty ? Icons.payments_outlined : Icons.search_off_rounded,
                title: cod.isEmpty ? 'No COD orders' : 'No matching orders',
                subtitle: cod.isEmpty ? 'Cash on Delivery orders appear here' : 'Try another search or filter',
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                children: [
                  if (byPartner.isNotEmpty && query.isEmpty && (_filter == 'All' || _filter == 'With partner')) _partnerCash(byPartner),
                  for (final o in list) _codCard(context, o),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _partnerCash(Map<String, List<AdminOrder>> byPartner) {
    final entries = byPartner.entries.toList()
      ..sort((a, b) => b.value.fold<int>(0, (s, o) => s + o.cashDue).compareTo(a.value.fold<int>(0, (s, o) => s + o.cashDue)));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.two_wheeler_rounded, size: 14, color: AC.primary),
              SizedBox(width: 6),
              Text('Cash with delivery partners', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in entries)
            Builder(builder: (context) {
              final name = store.partnerById(e.key)?.name ?? e.key;
              final total = e.value.fold<int>(0, (s, o) => s + o.cashDue);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AC.primary,
                      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: _fSmall, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600)),
                          Text('${e.value.length} delivered order(s)', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                        ],
                      ),
                    ),
                    Text(inr(total), style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w900, color: AC.warning)),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AC.success,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => _settle(e.value, name),
                        child: const Text('Received'),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _codCard(BuildContext context, AdminOrder o) {
    final withPartner = _isWithPartner(o);
    final received = _isReceived(o);
    final color = received ? AC.success : AC.warning;
    final partner = store.partnerById(o.partnerId)?.name;
    final amount = _amount(o);
    final statusText = received ? 'Received' : (withPartner ? 'With partner' : 'To deliver');
    // The partner typed a different cash amount than the order total.
    final mismatch = o.isDelivered && o.cashCollected && o.cashAmount > 0 && o.cashAmount != o.total;

    String footer;
    if (received) {
      footer = o.cashSettledAt != null ? 'Cash received on ${fmtDateTime(o.cashSettledAt!)}' : 'Cash received';
    } else if (withPartner) {
      footer = 'Collected at the door • ${partner ?? 'partner'} has to hand over the cash';
    } else {
      footer = partner == null ? 'Assign a delivery partner' : 'Cash to be collected on delivery';
    }

    return _card(
      onTap: () => _openOrder(context, o.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.payments_outlined, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inr(amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 2, color: AC.text)),
                    Text('#${o.id}', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                  ],
                ),
              ),
              _statusPill(statusText, color: color),
              _moreButton([
                _menu('order', Icons.receipt_long_outlined, 'View order'),
                if (withPartner) _menu('settle', Icons.check_circle_outline_rounded, 'Mark cash received', color: AC.success),
                _menu('id', Icons.copy_rounded, 'Copy order ID'),
              ], (v) {
                if (v == 'order') _openOrder(context, o.id);
                if (v == 'settle') _settle([o], partner ?? 'the partner');
                if (v == 'id') _copy(context, o.id, 'Order ID');
              }),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _infoChip(Icons.person_outline_rounded, store.customerName(o.customerId)),
              _infoChip(Icons.two_wheeler_rounded, partner ?? 'Not assigned'),
              if (o.isDelivered && o.deliveredAt != null) _infoChip(Icons.event_available_outlined, fmtDateTime(o.deliveredAt!)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AC.muted.withValues(alpha: .14)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(received ? Icons.check_circle_outline_rounded : Icons.schedule_rounded, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  footer,
                  style: TextStyle(color: color, fontSize: _fSmall, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AC.muted),
            ],
          ),
          if (mismatch) ...[
            const SizedBox(height: 4),
            Text(
              'Partner entered ${inr(o.cashAmount)} but the order total is ${inr(o.total)}',
              style: const TextStyle(color: AC.danger, fontSize: _fSmall, fontWeight: FontWeight.w700),
            ),
          ],
          if (withPartner) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40), backgroundColor: AC.success, textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                  onPressed: () => _settle([o], partner ?? 'the partner'),
                  child: const Text('Mark cash received'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}