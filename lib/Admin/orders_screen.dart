import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

/// Compact order row used on Orders list, Dashboard and Customer detail.
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(radius: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const Spacer(),
                  StatusChip(o.statusLabel),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const IconBadge(Icons.smartphone_rounded, AC.primary, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${first.name}$extra', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('${store.customerName(o.customerId)} • ${timeAgo(o.placedAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(inr(o.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                      Text(o.isCod ? 'COD' : 'Paid', style: TextStyle(color: o.isCod ? AC.warning : AC.success, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All orders with tabs, search and payment filter.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const tabs = ['All', 'New', 'Ongoing', 'Delivered', 'Cancelled'];
  String tab = 'All';
  String query = '';
  String pay = 'All payments';

  bool _match(AdminOrder o) {
    switch (tab) {
      case 'New':
        return !o.cancelled && o.stage <= 1;
      case 'Ongoing':
        return !o.cancelled && o.stage >= 2 && o.stage <= 3;
      case 'Delivered':
        return o.isDelivered;
      case 'Cancelled':
        return o.cancelled;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = store.orders.where(_match).where((o) {
          if (pay != 'All payments' && o.paymentMethod != pay) return false;
          if (q.isEmpty) return true;
          return o.id.toLowerCase().contains(q) || store.customerName(o.customerId).toLowerCase().contains(q) || o.items.any((i) => i.name.toLowerCase().contains(q));
        }).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Orders'),
            actions: [
              PopupMenuButton<String>(
                icon: Badge(isLabelVisible: pay != 'All payments', smallSize: 8, child: const Icon(Icons.filter_list_rounded)),
                onSelected: (v) => setState(() => pay = v),
                itemBuilder: (_) => [
                  for (final m in ['All payments', ...paymentMethods]) PopupMenuItem(value: m, child: Text(m, style: TextStyle(fontWeight: m == pay ? FontWeight.w800 : FontWeight.w500))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), child: SearchBox(hint: 'Search order ID, customer or phone', onChanged: (v) => setState(() => query = v))),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ChipTabs(items: tabs, selected: tab, onSelect: (v) => setState(() => tab = v)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders found', subtitle: 'Try another tab or search')
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: list.length,
                  itemBuilder: (_, i) => OrderTile(order: list[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One order: customer, items, address, payment, status timeline, partner, actions.
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  Future<void> _assignPartner(BuildContext context, AdminOrder o) async {
    final active = store.partners.where((p) => p.active).toList();
    final picked = await showModalBottomSheet<Partner>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign delivery partner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final p in active)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: AC.primary, child: Text(p.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p.vehicle} • ★ ${p.rating}', style: const TextStyle(fontSize: 12)),
                  trailing: o.partnerId == p.id ? const Icon(Icons.check_circle_rounded, color: AC.success) : null,
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      store.assignPartner(o, picked.id);
      if (context.mounted) snack(context, '${picked.name} assigned to #${o.id}');
    }
  }

  Future<void> _updateStatus(BuildContext context, AdminOrder o) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update order status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('The customer sees this on their order tracking screen.', style: TextStyle(color: AC.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              for (int i = 0; i < orderSteps.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(i <= o.stage ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i <= o.stage ? AC.success : AC.muted),
                  title: Text(orderSteps[i], style: TextStyle(fontWeight: i == o.stage ? FontWeight.w800 : FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked >= 3 && o.partnerId == null) {
      snack(context, 'Assign a delivery partner first');
      await _assignPartner(context, o);
      if (o.partnerId == null) return;
    }
    store.setStage(o, picked);
    if (context.mounted) snack(context, 'Status: ${orderSteps[picked]}');
  }

  Future<void> _cancel(BuildContext context, AdminOrder o) async {
    final reasons = ['Customer asked to cancel', 'Phone out of stock', 'Payment problem', 'Address not serviceable'];
    final r = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cancel this order?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(o.isCod ? 'Pick a reason. Stock will be added back.' : 'Pick a reason. Stock will be added back and a refund of ${inr(o.total)} will be created.', style: const TextStyle(color: AC.muted, fontSize: 12.5)),
              const SizedBox(height: 8),
              for (final x in reasons) ListTile(contentPadding: EdgeInsets.zero, title: Text(x, style: const TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.pop(ctx, x)),
            ],
          ),
        ),
      ),
    );
    if (r == null) return;
    store.cancelOrder(o, r);
    if (context.mounted) snack(context, 'Order #${o.id} cancelled');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final o = store.orderById(orderId);
        if (o == null) return const Scaffold(body: EmptyState(icon: Icons.error_outline, title: 'Order not found'));
        final cust = store.customerById(o.customerId);
        final partner = store.partnerById(o.partnerId);
        return Scaffold(
          appBar: AppBar(
            title: Text('Order #${o.id}'),
            actions: [IconButton(icon: const Icon(Icons.receipt_rounded), tooltip: 'Invoice', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(orderId: o.id))))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Placed on ${fmtDateTime(o.placedAt)}', style: const TextStyle(color: AC.muted, fontSize: 12.5)),
                          const SizedBox(height: 6),
                          Text(inr(o.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    StatusChip(o.statusLabel),
                  ],
                ),
              ),

              SectionTitle('Customer'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: AC.primary, child: Text(cust?.initial ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cust?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(cust?.phone ?? '', style: const TextStyle(color: AC.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_rounded, color: AC.success),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cust?.phone ?? ''));
                        snack(context, 'Number copied. Open your dialer to call.');
                      },
                    ),
                  ],
                ),
              ),

              SectionTitle('Items'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Column(
                  children: [
                    for (final it in o.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const IconBadge(Icons.smartphone_rounded, AC.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('${it.storage} • ${it.condition} • Qty ${it.qty}', style: const TextStyle(color: AC.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(inr(it.price * it.qty), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              SectionTitle('Delivery & payment'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Column(
                  children: [
                    KV('Address', o.address),
                    KV('Payment', o.paymentMethod),
                    const Divider(height: 22),
                    KV('Subtotal', inr(o.subtotal)),
                    KV('Delivery', o.delivery == 0 ? 'FREE' : inr(o.delivery), color: o.delivery == 0 ? AC.success : null),
                    if (o.discount > 0) KV('Coupon ${o.couponCode ?? ''}', '- ${inr(o.discount)}', color: AC.success),
                    const Divider(height: 22),
                    KV('Total', inr(o.total), bold: true),
                  ],
                ),
              ),

              SectionTitle('Order status'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: o.cancelled
                    ? const Row(children: [Icon(Icons.cancel_rounded, color: AC.danger), SizedBox(width: 10), Expanded(child: Text('This order was cancelled.', style: TextStyle(color: AC.danger, fontWeight: FontWeight.w700)))])
                    : Column(
                  children: [
                    for (int i = 0; i < orderSteps.length; i++)
                      _stepRow(i, o.stage, i == orderSteps.length - 1),
                  ],
                ),
              ),

              SectionTitle('Delivery partner'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Row(
                  children: [
                    CircleAvatar(radius: 22, backgroundColor: partner == null ? AC.border : AC.primary, child: partner == null ? const Icon(Icons.person_off_outlined, color: AC.muted) : Text(partner.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(partner?.name ?? 'Not assigned', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(partner == null ? 'Assign a partner before dispatch' : '${partner.vehicle} • ★ ${partner.rating}', style: const TextStyle(color: AC.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!o.cancelled && !o.isDelivered) TextButton(onPressed: () => _assignPartner(context, o), child: Text(partner == null ? 'Assign' : 'Change', style: const TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              if (o.isOngoing) ...[
                ElevatedButton(onPressed: () => _updateStatus(context, o), child: const Text('Update status')),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _cancel(context, o),
                  style: OutlinedButton.styleFrom(foregroundColor: AC.danger, side: const BorderSide(color: AC.danger, width: 1.4)),
                  child: const Text('Cancel order & refund'),
                ),
              ],
              if (o.isDelivered) OutlinedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(orderId: o.id))), child: const Text('View invoice')),
            ],
          ),
        );
      },
    );
  }

  Widget _stepRow(int i, int stage, bool last) {
    final done = i < stage || (i == stage && i == 4);
    final current = i == stage && i != 4;
    final color = done ? AC.success : (current ? AC.accent : AC.border);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: done || current ? color : Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                child: done ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : (current ? const Icon(Icons.more_horiz_rounded, size: 15, color: Colors.white) : null),
              ),
              if (!last) Expanded(child: Container(width: 2, color: i < stage ? AC.success : AC.border)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(orderSteps[i], style: TextStyle(fontWeight: current || done ? FontWeight.w800 : FontWeight.w500, color: current || done ? AC.text : AC.muted, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invoice view. "Print / Share" copies the invoice text (add a pdf/printing package later).
class InvoiceScreen extends StatelessWidget {
  final String orderId;
  const InvoiceScreen({super.key, required this.orderId});

  String _text(AdminOrder o) {
    final b = StringBuffer()
      ..writeln('PhoneHub - Invoice')
      ..writeln('Order: ${o.id}')
      ..writeln('Date: ${fmtDateTime(o.placedAt)}')
      ..writeln('Customer: ${store.customerName(o.customerId)}')
      ..writeln('Address: ${o.address}')
      ..writeln('------------------------');
    for (final it in o.items) {
      b.writeln('${it.name} (${it.storage}, ${it.condition}) x${it.qty}  ${inr(it.price * it.qty)}');
    }
    b
      ..writeln('------------------------')
      ..writeln('Subtotal: ${inr(o.subtotal)}')
      ..writeln('Delivery: ${o.delivery == 0 ? 'FREE' : inr(o.delivery)}');
    if (o.discount > 0) b.writeln('Discount: -${inr(o.discount)}');
    b
      ..writeln('Total: ${inr(o.total)}')
      ..writeln('Paid via: ${o.paymentMethod}');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final o = store.orderById(orderId);
    if (o == null) return const Scaffold(body: EmptyState(icon: Icons.error_outline, title: 'Order not found'));
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smartphone_rounded, color: AC.primary),
                    const SizedBox(width: 8),
                    const Text('PhoneHub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AC.primary)),
                    const Spacer(),
                    StatusChip(o.isCod && !o.isDelivered ? 'Pending' : 'Paid', color: o.isCod && !o.isDelivered ? AC.warning : AC.success),
                  ],
                ),
                const Divider(height: 28),
                KV('Invoice no.', 'INV-${o.id.substring(2)}'),
                KV('Order ID', o.id),
                KV('Date', fmtDateTime(o.placedAt)),
                KV('Customer', store.customerName(o.customerId)),
                KV('Ship to', o.address),
                const Divider(height: 28),
                for (final it in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text('${it.name}\n${it.storage} • ${it.condition} • x${it.qty}', style: const TextStyle(fontSize: 13, height: 1.35))),
                        Text(inr(it.price * it.qty), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                const Divider(height: 28),
                KV('Subtotal', inr(o.subtotal)),
                KV('Delivery', o.delivery == 0 ? 'FREE' : inr(o.delivery)),
                if (o.discount > 0) KV('Discount', '- ${inr(o.discount)}', color: AC.success),
                KV('Total', inr(o.total), bold: true),
                KV('Payment', o.paymentMethod),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _text(o)));
              snack(context, 'Invoice copied. Paste it to print or share.');
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print / Share'),
          ),
        ],
      ),
    );
  }
}