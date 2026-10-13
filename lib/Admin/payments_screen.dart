import 'package:flutter/material.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

/// Payments & Refunds: Transactions | Refunds | COD report.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments & Refunds'),
          bottom: const TabBar(
            labelColor: AC.primary,
            indicatorColor: AC.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: [Tab(text: 'Transactions'), Tab(text: 'Refunds'), Tab(text: 'COD')],
          ),
        ),
        body: const TabBarView(children: [_TxnTab(), _RefundTab(), _CodTab()]),
      ),
    );
  }
}

Widget _summary(String label, String value, Color color) => Expanded(
  child: Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(radius: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AC.muted, fontSize: 12)),
      ],
    ),
  ),
);

class _TxnTab extends StatefulWidget {
  const _TxnTab();

  @override
  State<_TxnTab> createState() => _TxnTabState();
}

class _TxnTabState extends State<_TxnTab> {
  String method = 'All';

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.txns;
        final list = all.where((t) => method == 'All' || t.method == method).toList();
        final collected = all.where((t) => t.status == 'Success').fold<int>(0, (s, t) => s + t.amount);
        final pending = all.where((t) => t.status == 'Pending').fold<int>(0, (s, t) => s + t.amount);
        final refunded = all.where((t) => t.status == 'Refunded').fold<int>(0, (s, t) => s + t.amount);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(children: [_summary('Collected', inr(collected), AC.success), const SizedBox(width: 10), _summary('Pending', inr(pending), AC.warning), const SizedBox(width: 10), _summary('Refunded', inr(refunded), AC.danger)]),
            const SizedBox(height: 14),
            ChipTabs(items: ['All', ...paymentMethods], selected: method, onSelect: (v) => setState(() => method = v)),
            const SizedBox(height: 12),
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.payments_outlined, title: 'No transactions')),
            for (final t in list)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDeco(radius: 16),
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: t.orderId))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: IconBadge(_icon(t.method), statusColor(t.status)),
                  title: Text('${t.id} • ${inr(t.amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text('${t.method}\nOrder ${t.orderId} • ${fmtDateTime(t.date)}', style: const TextStyle(color: AC.muted, fontSize: 12, height: 1.4)),
                  isThreeLine: true,
                  trailing: StatusChip(t.status),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RefundTab extends StatelessWidget {
  const _RefundTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.refunds.isEmpty) return const EmptyState(icon: Icons.currency_rupee_rounded, title: 'No refund requests');
        final waiting = store.refunds.where((r) => r.status == 'Requested' || r.status == 'Approved').fold<int>(0, (s, r) => s + r.amount);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(children: [_summary('To refund', inr(waiting), AC.warning), const SizedBox(width: 10), _summary('Requests', '${store.refunds.length}', AC.primary)]),
            const SizedBox(height: 6),
            const Padding(padding: EdgeInsets.fromLTRB(2, 12, 2, 8), child: Text('Refunds reach the customer in 5-7 working days after you mark them refunded.', style: TextStyle(color: AC.muted, fontSize: 12))),
            for (final r in store.refunds)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Text(inr(r.amount), style: const TextStyle(fontWeight: FontWeight.w900, color: AC.primary)),
                        const Spacer(),
                        StatusChip(r.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Order ${r.orderId} • ${fmtDateTime(r.date)}', style: const TextStyle(color: AC.muted, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text('Reason: ${r.reason}', style: const TextStyle(fontSize: 13)),
                    if (r.status == 'Requested' || r.status == 'Approved') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (r.status == 'Requested') ...[
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: AC.danger, side: const BorderSide(color: AC.danger)),
                                onPressed: () async {
                                  final ok = await confirmDialog(context, 'Reject refund?', 'The customer will not receive ${inr(r.amount)}.', yes: 'Reject', danger: true);
                                  if (ok) store.setRefund(r, 'Rejected');
                                },
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)), onPressed: () => store.setRefund(r, 'Approved'), child: const Text('Approve'))),
                          ] else
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42), backgroundColor: AC.success),
                                onPressed: () {
                                  store.setRefund(r, 'Refunded');
                                  snack(context, '${inr(r.amount)} marked as refunded');
                                },
                                child: const Text('Mark as refunded'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CodTab extends StatelessWidget {
  const _CodTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cod = store.orders.where((o) => o.isCod && !o.cancelled).toList();
        final collected = cod.where((o) => o.isDelivered).fold<int>(0, (s, o) => s + o.total);
        final toCollect = cod.where((o) => !o.isDelivered).fold<int>(0, (s, o) => s + o.total);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(children: [_summary('Cash collected', inr(collected), AC.success), const SizedBox(width: 10), _summary('Yet to collect', inr(toCollect), AC.warning)]),
            const SectionTitle('Cash on Delivery orders'),
            if (cod.isEmpty) const EmptyState(icon: Icons.payments_outlined, title: 'No COD orders'),
            for (final o in cod)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDeco(radius: 16),
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: IconBadge(Icons.payments_outlined, o.isDelivered ? AC.success : AC.warning),
                  title: Text('#${o.id} • ${inr(o.total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text('${store.customerName(o.customerId)}\nPartner: ${store.partnerById(o.partnerId)?.name ?? 'Not assigned'}', style: const TextStyle(color: AC.muted, fontSize: 12, height: 1.4)),
                  isThreeLine: true,
                  trailing: StatusChip(o.isDelivered ? 'Collected' : 'Pending', color: o.isDelivered ? AC.success : AC.warning),
                ),
              ),
          ],
        );
      },
    );
  }
}
