import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/app_text.dart';

// ===========================================================================
// Shared helpers
// ===========================================================================

/// Plain text copy of an order (used by "Share" and by the invoice).
String orderInvoiceText(dynamic o) {
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

/// Simple back arrow (no background).
class _BackBtn extends StatelessWidget {
  const _BackBtn();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// App bar: back button first, title right after it (left aligned).
AppBar _appBar(BuildContext context, String title, {List<Widget>? actions}) {
  final bool canPop = Navigator.of(context).canPop();
  return AppBar(
    centerTitle: false,
    titleSpacing: canPop ? 4 : 16,
    leadingWidth: canPop ? 48 : null,
    leading: canPop ? const _BackBtn() : null,
    // Header title stays at 18
    title: Text('  $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    actions: actions,
  );
}

/// Small tappable card: label + value + copy icon.
class _CopyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _CopyCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AC.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AC.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 3), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.copy_rounded, size: 15, color: AC.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Invoice
// ===========================================================================

/// Invoice view. "Print / Share" opens the native share sheet.
class InvoiceScreen extends StatelessWidget {
  final String orderId;
  const InvoiceScreen({super.key, required this.orderId});

  void _copy(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    snack(context, message);
  }

  /// Opens the real mobile share sheet (WhatsApp, Gmail, Instagram, etc.).
  Future<void> _share(BuildContext context, dynamic o) async {
    // Needed on iPad so the share popup knows where to appear.
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(
        orderInvoiceText(o),
        subject: 'PhoneHub Invoice - ${o.id}',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (context.mounted) snack(context, 'Could not open share options.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = store.orderById(orderId);
    if (o == null) {
      return Scaffold(
        appBar: _appBar(context, 'Invoice'),
        body: const EmptyState(icon: Icons.error_outline, title: 'Order not found'),
      );
    }
    final pending = o.isCod && !o.isDelivered;
    final stampColor = o.cancelled ? AC.danger : (pending ? AC.warning : AC.success);
    final stampText = o.cancelled ? 'CANCELLED' : (pending ? 'PAYMENT PENDING' : 'PAID');
    final statusText = o.cancelled ? 'Cancelled' : (pending ? 'Pending (Pay on delivery)' : 'Paid');
    final invoiceNo = 'INV-${o.id.substring(2)}';
    final int totalUnits = o.items.fold<int>(0, (s, it) => s + (it.qty as int));

    return Scaffold(
      appBar: _appBar(
        context,
        'Invoice',
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy invoice',
            onPressed: () => _copy(context, orderInvoiceText(o), 'Invoice copied.'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: cardDeco(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // gradient band
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: const BoxDecoration(gradient: adminGradient),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.phone_iphone_rounded, color: AC.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PhoneHub', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                            Text('Tax invoice', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: (AppText.small - 2))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Text(stampText, style: TextStyle(color: stampColor, fontSize: (AppText.small - 2), fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // long-press to copy
                      GestureDetector(
                        onLongPress: () => _copy(context, invoiceNo, 'Invoice number copied.'),
                        child: KV('Invoice no.', invoiceNo),
                      ),
                      GestureDetector(
                        onLongPress: () => _copy(context, o.id, 'Order ID copied.'),
                        child: KV('Order ID', o.id),
                      ),
                      KV('Date', fmtDateTime(o.placedAt)),
                      KV('Customer', store.customerName(o.customerId)),
                      GestureDetector(
                        onLongPress: () => _copy(context, o.address, 'Address copied.'),
                        child: KV('Ship to', o.address),
                      ),
                      KV('Payment status', statusText, color: stampColor),
                      const Divider(height: 22),
                      const Text('ITEMS', style: TextStyle(color: AC.muted, fontSize: (AppText.small - 2), fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      for (final it in o.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.name, style: const TextStyle(fontSize: (AppText.body - 2), fontWeight: FontWeight.w700)),
                                    Text('${it.storage} • ${it.condition} • Qty ${it.qty}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
                                  ],
                                ),
                              ),
                              Text(inr(it.price * it.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 2))),
                            ],
                          ),
                        ),
                      const Divider(height: 22),
                      KV('Total items', '$totalUnits'),
                      KV('Subtotal', inr(o.subtotal)),
                      KV('Delivery', o.delivery == 0 ? 'FREE' : inr(o.delivery), color: o.delivery == 0 ? AC.success : null),
                      if (o.discount > 0) KV('Discount', '- ${inr(o.discount)}', color: AC.success),
                      const Divider(height: 18),
                      KV('Total', inr(o.total), bold: true),
                      KV('Payment', o.paymentMethod),
                      if (o.discount > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AC.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.savings_rounded, color: AC.success, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You saved ${inr(o.discount)} on this order',
                                  style: const TextStyle(color: AC.success, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (pending && !o.cancelled) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AC.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AC.warning, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cash on delivery: ${inr(o.total)} to be collected at delivery',
                                  style: const TextStyle(color: AC.warning, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Center(child: Text('Thank you for shopping with PhoneHub', style: TextStyle(color: AC.muted, fontSize: (AppText.small - 2), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Opens the real mobile share sheet
          Builder(
            builder: (btnContext) => ElevatedButton.icon(
              onPressed: () => _share(btnContext, o),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Print / Share'),
            ),
          ),
          const SizedBox(height: 10),
          // Small copy cards
          Row(
            children: [
              Expanded(
                child: _CopyCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Invoice No.',
                  value: invoiceNo,
                  onTap: () => _copy(context, invoiceNo, 'Invoice number copied.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CopyCard(
                  icon: Icons.tag_rounded,
                  label: 'Order ID',
                  value: o.id,
                  onTap: () => _copy(context, o.id, 'Order ID copied.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}