import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/Admin/invoice.dart';
import 'package:phonehub/app_text.dart';

// ===========================================================================
// Shared helpers (same look as the Orders screen)
// ===========================================================================

/// Small rounded label (used for payment type, counts, etc.).
Widget _pill(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
      Text(text, style: TextStyle(color: color, fontSize: (AppText.small - 2), fontWeight: FontWeight.w800)),
    ],
  ),
);

/// Compact white card (same size and radius as the order card).
Widget _card(Widget child) => Container(
  padding: const EdgeInsets.all(10),
  decoration: cardDeco(radius: 12),
  child: child,
);

/// Smaller button style for the bottom bar (Cancel / Mark: Packed / View invoice).
/// Change Size(0, 38) to make the buttons taller or shorter.
ButtonStyle _btnStyle({Color? fg, Color? borderColor}) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
  textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  foregroundColor: fg == null ? null : WidgetStatePropertyAll(fg),
  side: borderColor == null ? null : WidgetStatePropertyAll(BorderSide(color: borderColor, width: 1.2)),
);

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

/// App bar: back button first, title after a small gap (left aligned).
/// App bar: back button first, title after a small gap (left aligned).
AppBar _appBar(BuildContext context, String title, {List<Widget>? actions}) {
  final bool canPop = Navigator.of(context).canPop();
  return AppBar(
    centerTitle: false,
    titleSpacing: canPop ? 3 : 16, // <- gap between back arrow and title
    leadingWidth: canPop ? 48 : null,
    leading: canPop ? const _BackBtn() : null,
    title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    actions: actions,
  );
}

/// Snack bar with an Undo button.
void _snackUndo(BuildContext context, String msg, VoidCallback onUndo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  final c = m.showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 4),
    action: SnackBarAction(label: 'Undo', onPressed: onUndo),
  ));
  // A snack bar that has an action stays on screen until it is closed, so close it ourselves.
  var gone = false;
  c.closed.then((_) => gone = true);
  Future<void>.delayed(const Duration(seconds: 4), () {
    if (!gone) c.close();
  });
}

/// Yes / No confirmation dialog.
Future<bool> _confirm(BuildContext context, String title, String msg, String yes) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: (AppText.title - 3), fontWeight: FontWeight.w800)),
      content: Text(msg, style: const TextStyle(fontSize: (AppText.body - 2), color: AC.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes, style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return r ?? false;
}

// ===========================================================================
// Order detail
// ===========================================================================

/// One order: header, tracking, customer, address, items, payment, partner, actions.
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  Future<void> _assignPartner(BuildContext context, AdminOrder o) async {
    // Changing the partner of an order that is already on the road needs a second look.
    if (o.partnerId != null && o.stage >= 3) {
      final name = store.partnerById(o.partnerId)?.name ?? 'the partner';
      final ok = await _confirm(context, 'Change delivery partner?', 'This order is already out for delivery with $name.', 'Change');
      if (!ok || !context.mounted) return;
    }
    // Partners who already gave this order back are not offered again; online partners come first.
    final active = store.assignablePartners(o)..sort((a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0));
    final hidden = store.partners.where((p) => p.active && o.rejectedByPartner(p.id)).map((p) => p.name).toList();
    // Partners whose documents are not verified yet cannot take orders (Delivery Partners > documents).
    final unverified = store.unverifiedPartners(o).map((p) => p.name).toList();
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
              const Text('Assign delivery partner', style: TextStyle(fontSize: (AppText.title - 3), fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (active.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No active delivery partners', style: TextStyle(color: AC.muted, fontSize: (AppText.small - 2)))),
              for (final p in active)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: AC.primary, child: Text(p.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: (AppText.body - 2))),
                  subtitle: Text('${p.vehicle} • ★ ${p.rating} • ${p.online ? 'Online' : 'Offline'} • ${store.partnerActiveOrders(p.id)} active', style: const TextStyle(fontSize: (AppText.small - 2))),
                  trailing: o.partnerId == p.id ? const Icon(Icons.check_circle_rounded, color: AC.success) : null,
                  onTap: () => Navigator.pop(ctx, p),
                ),
              if (hidden.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not shown (gave this order back): ${hidden.join(', ')}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
                ),
              if (unverified.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not shown (documents not verified): ${unverified.join(', ')}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
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

  /// Return approved: the admin sends a delivery partner to collect the phone from the customer.
  Future<void> _assignReturnPickup(BuildContext context, AdminOrder o) async {
    final list = store.partners.where((p) => p.active && store.partnerCanTakeOrders(p)).toList()
      ..sort((a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0));
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
              const Text('Who collects the phone?', style: TextStyle(fontSize: (AppText.title - 3), fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('The partner gets a pickup task in the delivery app.', style: TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
              const SizedBox(height: 10),
              if (list.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No active delivery partners', style: TextStyle(color: AC.muted, fontSize: (AppText.small - 2)))),
              for (final p in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: AC.primary, child: Text(p.name.isEmpty ? '?' : p.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: (AppText.body - 2))),
                  subtitle: Text('${p.vehicle} • ★ ${p.rating} • ${p.online ? 'Online' : 'Offline'} • ${store.partnerActiveOrders(p.id)} active', style: const TextStyle(fontSize: (AppText.small - 2))),
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    store.assignReturnPickup(o, picked.id);
    snack(context, '${picked.name} will collect the phone of #${o.id}');
  }

  /// The returned phone reached the store.
  Future<void> _markReturnReceived(BuildContext context, AdminOrder o) async {
    final ok = await _confirm(context, 'Phone received?', 'Confirm that the returned phone of order #${o.id} reached the store. The customer will be told the refund is being processed.', 'Yes, received');
    if (!ok || !context.mounted) return;
    store.markReturnReceived(o);
    snack(context, 'Return marked as received');
  }

  /// Moves the order to [target]. Handles the partner rule, a confirmation
  /// before "Delivered", and shows an Undo button afterwards.
  Future<void> _applyStage(BuildContext context, AdminOrder o, int target) async {
    if (target == o.stage || target < 0 || target >= orderSteps.length) return;
    // A delivery partner is needed before the order can move on (Payment Confirmed, Packed, ...).
    if (target >= 1 && o.partnerId == null) {
      snack(context, 'Assign a delivery partner first');
      await _assignPartner(context, o);
      if (o.partnerId == null || !context.mounted) return;
    }
    // With a delivery partner the pickup belongs to the partner: "Out for Delivery" is set when the
    // partner taps "Mark as Picked Up" in the delivery app, and only after that can the order be delivered.
    if (o.partnerId != null && target >= 3 && o.stage < 3) {
      snack(context, 'Waiting for the delivery partner to mark this order as picked up');
      return;
    }
    if (target == orderSteps.length - 1) {
      final ok = await _confirm(
        context,
        'Mark as delivered?',
        o.isCod
            ? (o.partnerId != null
            ? 'The partner has to hand over ${inr(o.total)} in cash. You can mark it as received in Payments > COD.'
            : 'Make sure you collected ${inr(o.total)} in cash.')
            : 'The customer will see this order as delivered.',
        'Delivered',
      );
      if (!ok || !context.mounted) return;
    }
    final prev = o.stage;
    store.setStage(o, target);
    if (context.mounted) _snackUndo(context, 'Status: ${orderSteps[target]}', () => store.setStage(o, prev));
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
              const Text('Update order status', style: TextStyle(fontSize: (AppText.title - 3), fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('The customer sees this on their order tracking screen.', style: TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
              const SizedBox(height: 10),
              for (int i = 0; i < orderSteps.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(i <= o.stage ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i <= o.stage ? AC.success : AC.muted),
                  title: Text(orderSteps[i], style: TextStyle(fontSize: (AppText.body - 2), fontWeight: i == o.stage ? FontWeight.w800 : FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _applyStage(context, o, picked);
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
              const Text('Cancel this order?', style: TextStyle(fontSize: (AppText.title - 3), fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(o.isCod ? 'Pick a reason. Stock will be added back.' : 'Pick a reason. Stock will be added back and a refund of ${inr(o.total)} will be created.', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
              const SizedBox(height: 8),
              for (final x in reasons)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(x, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: (AppText.body - 2))),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(ctx, x),
                ),
            ],
          ),
        ),
      ),
    );
    if (r == null) return;
    store.cancelOrder(o, r);
    if (context.mounted) snack(context, 'Order #${o.id} cancelled');
  }

  void _copy(BuildContext context, String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    snack(context, msg);
  }

  /// Opens the phone dialer. If it cannot be opened the number is copied instead.
  Future<void> _dial(BuildContext context, String phone, String who) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) {
      snack(context, '$who has no phone number saved.');
      return;
    }
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: number))) return;
    } catch (_) {}
    if (context.mounted) _copy(context, number, 'Number copied. Open your dialer to call.');
  }

  /// The admin received the COD cash of this order from the partner.
  Future<void> _settleCash(BuildContext context, AdminOrder o) async {
    final who = store.partnerById(o.partnerId)?.name ?? 'the partner';
    final ok = await _confirm(context, 'Cash received?', 'Confirm that you received ${inr(o.cashDue)} from $who for this order.', 'Yes, received');
    if (!ok || !context.mounted) return;
    final saved = await store.settleCash([o]);
    if (context.mounted) snack(context, saved ? '${inr(o.cashDue)} marked as received' : 'Could not save. Please check your internet and try again.');
  }

  /// Notice box in the same style as the "cash to collect" box.
  Widget _notice(IconData icon, Color color, String title, {String? body, Widget? action}) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: (AppText.small - 2), fontWeight: FontWeight.w800)),
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2), height: 1.3)),
              ],
            ],
          ),
        ),
        if (action != null) action,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final o = store.orderById(orderId);
        if (o == null) {
          return Scaffold(
            appBar: _appBar(context, 'Order Details'),
            body: const EmptyState(icon: Icons.error_outline, title: 'Order not found'),
          );
        }
        final cust = store.customerById(o.customerId);
        final partner = store.partnerById(o.partnerId);
        final int stage = o.stage.clamp(0, orderSteps.length - 1).toInt();
        final String? nextLabel = o.isOngoing && stage + 1 < orderSteps.length ? orderSteps[stage + 1] : null;

        Widget? bottom;
        if (o.isOngoing) {
          bottom = Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => _cancel(context, o),
                  style: _btnStyle(fg: AC.danger, borderColor: AC.danger),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: (partner != null && nextLabel != null && stage + 1 == 3)
                // Packed, partner assigned: the partner picks it up (Out for Delivery) from the delivery app.
                    ? ElevatedButton.icon(
                  onPressed: null,
                  style: _btnStyle(),
                  icon: const Icon(Icons.hourglass_top_rounded, size: 16),
                  label: const Text('Waiting for partner pickup', maxLines: 1, overflow: TextOverflow.ellipsis),
                )
                    : (partner == null && nextLabel != null)
                // Step 1: no delivery partner yet -> assign one first. Then "Mark: Payment Confirmed" appears.
                    ? ElevatedButton.icon(
                  onPressed: () => _assignPartner(context, o),
                  style: _btnStyle(),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Assign partner', maxLines: 1, overflow: TextOverflow.ellipsis),
                )
                    : ElevatedButton.icon(
                  onPressed: nextLabel == null ? null : () => _applyStage(context, o, stage + 1),
                  style: _btnStyle(),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(nextLabel == null ? 'Done' : 'Mark: $nextLabel', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          );
        } else if (o.isDelivered) {
          bottom = ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(orderId: o.id))),
            style: _btnStyle(),
            icon: const Icon(Icons.receipt_rounded, size: 16),
            label: const Text('View invoice'),
          );
        }

        return Scaffold(
          appBar: _appBar(
            context,
            'Order Details',
            actions: [
              IconButton(icon: const Icon(Icons.ios_share_rounded), tooltip: 'Copy order summary', onPressed: () => _copy(context, orderInvoiceText(o), 'Order summary copied')),
              IconButton(icon: const Icon(Icons.receipt_rounded), tooltip: 'Invoice', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(orderId: o.id)))),
              const SizedBox(width: 6),
            ],
          ),
          bottomNavigationBar: bottom == null
              ? null
              : SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AC.border))),
              child: bottom,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              // ---- header ----
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: o.cancelled ? LinearGradient(colors: [AC.danger, AC.danger.withValues(alpha: 0.75)]) : adminGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Flexible + ellipsis fixes the overflow with the status chip
                        Flexible(
                          child: Text(
                            'Order #${o.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: (AppText.body - 2), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _copy(context, o.id, 'Order ID copied'),
                          child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.copy_rounded, size: 13, color: Colors.white70)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text(o.statusLabel, maxLines: 1, style: TextStyle(color: o.cancelled ? AC.danger : statusColor(o.statusLabel), fontSize: (AppText.small - 2), fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(inr(o.total), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 3),
                    Text('Placed on ${fmtDateTime(o.placedAt)} · ${timeAgo(o.placedAt)}', style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 2))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _glass(Icons.shopping_bag_outlined, '${o.items.length} ${o.items.length == 1 ? 'item' : 'items'}'),
                        _glass(Icons.credit_card_rounded, o.paymentMethod),
                        _glass(o.isCod ? Icons.payments_outlined : Icons.verified_rounded, o.isCod ? 'Cash on delivery' : 'Paid online'),
                      ],
                    ),
                  ],
                ),
              ),

              // ---- given back by a delivery partner: the admin must pick someone else ----
              if (o.needsReassign)
                _notice(
                  Icons.undo_rounded,
                  AC.danger,
                  '${store.partnerById(o.rejectedBy)?.name ?? o.rejectedBy} gave this order back',
                  body: [
                    if (o.rejectReason.isNotEmpty) 'Reason: ${o.rejectReason}',
                    if (o.rejectedAt != null) fmtDateTime(o.rejectedAt!),
                  ].join(' · '),
                  action: TextButton(onPressed: () => _assignPartner(context, o), child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                ),

              // ---- delivery could not be completed ----
              if (o.hasFailedAttempt)
                _notice(
                  Icons.report_problem_rounded,
                  AC.warning,
                  '${o.deliveryAttempts} delivery ${o.deliveryAttempts == 1 ? 'attempt' : 'attempts'} failed',
                  body: [
                    if (o.failedReason.isNotEmpty) o.failedReason,
                    if (o.lastAttemptAt != null) 'Last try ${fmtDateTime(o.lastAttemptAt!)}',
                  ].join(' · '),
                ),

              // ---- COD cash after delivery: with the partner, or received ----
              if (o.isCod && o.isDelivered) ...[
                if (o.cashPending)
                  _notice(
                    Icons.payments_rounded,
                    AC.warning,
                    '${inr(o.cashDue)} cash is with ${store.partnerById(o.partnerId)?.name ?? 'the partner'}',
                    body: o.cashCollected && o.cashAmount > 0 && o.cashAmount != o.total
                        ? 'Partner entered ${inr(o.cashAmount)} but the order total is ${inr(o.total)}.'
                        : 'Delivered. Mark it received when the partner hands over the cash.',
                    action: TextButton(onPressed: () => _settleCash(context, o), child: const Text('Received', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                  )
                else
                  _notice(
                    Icons.check_circle_rounded,
                    AC.success,
                    '${inr(o.cashDue)} cash received',
                    body: o.cashSettledAt != null ? fmtDateTime(o.cashSettledAt!) : null,
                  ),
              ],

              // ---- return of a delivered order: pickup by a delivery partner, then received at the store ----
              if (o.needsReturnPickup)
                _notice(
                  Icons.assignment_return_rounded,
                  AC.warning,
                  'Return approved: send a partner to collect the phone',
                  body: o.address.isEmpty ? null : 'Collect from: ${o.address}',
                  action: TextButton(onPressed: () => _assignReturnPickup(context, o), child: const Text('Assign', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                ),
              if (o.returnPickupStatus == 'Pickup Assigned')
                _notice(
                  Icons.two_wheeler_rounded,
                  AC.info,
                  'Waiting for ${o.returnPartnerName.isEmpty ? 'the partner' : o.returnPartnerName} to pick up the phone',
                  body: 'The partner marks it as picked up in the delivery app.',
                  action: TextButton(onPressed: () => _assignReturnPickup(context, o), child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                ),
              if (o.returnPickupStatus == 'Picked Up')
                _notice(
                  Icons.inventory_rounded,
                  AC.info,
                  '${o.returnPartnerName.isEmpty ? 'The partner' : o.returnPartnerName} picked up the phone',
                  body: [
                    if (o.returnPickedAt != null) fmtDateTime(o.returnPickedAt!),
                    'Mark it received when it reaches the store.',
                  ].join(' · '),
                  action: TextButton(onPressed: () => _markReturnReceived(context, o), child: const Text('Received', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                ),
              if (o.returnPickupStatus == 'Received')
                _notice(
                  Icons.check_circle_rounded,
                  AC.success,
                  'Returned phone received',
                  body: o.returnReceivedAt != null ? fmtDateTime(o.returnReceivedAt!) : null,
                ),

              // ---- cash to collect (COD, not yet delivered) ----
              if (o.isCod && o.isOngoing) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AC.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_rounded, size: 16, color: AC.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Collect ${inr(o.total)} in cash on delivery', style: const TextStyle(color: AC.warning, fontSize: (AppText.small - 2), fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],

              // ---- tracking ----
              SectionTitle('Order tracking', trailing: o.isOngoing ? TextButton(onPressed: () => _updateStatus(context, o), child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))) : null),
              Container(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                decoration: cardDeco(radius: 12),
                child: o.cancelled
                    ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_rounded, size: 18, color: AC.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.isCod ? 'This order was cancelled. No payment was collected.' : 'This order was cancelled. A refund of ${inr(o.total)} has been created.',
                          style: const TextStyle(color: AC.danger, fontWeight: FontWeight.w700, fontSize: (AppText.body - 2), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                )
                    : Column(
                  children: [
                    _hTracker(stage),
                    const SizedBox(height: 8),
                    Text('Step ${stage + 1} of ${orderSteps.length} · ${orderSteps[stage]}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // ---- customer ----
              SectionTitle('Customer'),
              _card(
                Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: AC.primary, child: Text(cust?.initial ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cust?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 2))),
                              Text(cust?.phone ?? '', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _action(Icons.call_rounded, 'Call', AC.success, () => _dial(context, cust?.phone ?? '', 'The customer')),
                        const SizedBox(width: 8),
                        _action(Icons.copy_rounded, 'Copy number', AC.primary, () => _copy(context, cust?.phone ?? '', 'Number copied')),
                      ],
                    ),
                  ],
                ),
              ),

              // ---- address ----
              SectionTitle('Delivery address'),
              _card(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBadge(Icons.location_on_rounded, AC.danger, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text(o.address, style: const TextStyle(fontSize: (AppText.body - 2), height: 1.4, fontWeight: FontWeight.w600))),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AC.muted),
                      tooltip: 'Copy address',
                      onPressed: () => _copy(context, o.address, 'Address copied'),
                    ),
                  ],
                ),
              ),

              // ---- items ----
              SectionTitle('Items (${o.items.length})'),
              _card(
                Column(
                  children: [
                    for (int i = 0; i < o.items.length; i++) ...[
                      if (i > 0) const Divider(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconBadge(Icons.smartphone_rounded, AC.primary, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.items[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: (AppText.body - 2))),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _pill(o.items[i].storage, AC.primary),
                                    _pill(o.items[i].condition, AC.accent),
                                    _pill('Qty ${o.items[i].qty}', AC.muted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(inr(o.items[i].price * o.items[i].qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 2))),
                              if (o.items[i].qty > 1) Text('${inr(o.items[i].price)} each', style: const TextStyle(color: AC.muted, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ---- payment ----
              SectionTitle('Payment summary'),
              _card(
                Column(
                  children: [
                    KV('Payment method', o.paymentMethod),
                    const Divider(height: 18),
                    KV('Subtotal', inr(o.subtotal)),
                    KV('Delivery', o.delivery == 0 ? 'FREE' : inr(o.delivery), color: o.delivery == 0 ? AC.success : null),
                    if (o.discount > 0) KV('Coupon ${o.couponCode ?? ''}', '- ${inr(o.discount)}', color: AC.success),
                    const Divider(height: 18),
                    KV('Total', inr(o.total), bold: true),
                  ],
                ),
              ),

              // ---- delivery partner ----
              SectionTitle('Delivery partner'),
              _card(
                Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: partner == null ? AC.border : AC.primary,
                          child: partner == null ? const Icon(Icons.person_off_outlined, size: 18, color: AC.muted) : Text(partner.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(partner?.name ?? 'Not assigned', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 2))),
                              Text(partner == null ? 'Assign a partner before dispatch' : '${partner.vehicle} • ★ ${partner.rating}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2))),
                            ],
                          ),
                        ),
                        if (!o.cancelled && !o.isDelivered) TextButton(onPressed: () => _assignPartner(context, o), child: Text(partner == null ? 'Assign' : 'Change', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                      ],
                    ),
                    if (partner != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _action(Icons.call_rounded, 'Call', AC.success, () => _dial(context, partner.phone, partner.name)),
                          const SizedBox(width: 8),
                          _action(Icons.copy_rounded, 'Copy number', AC.primary, () => _copy(context, partner.phone, 'Number copied')),
                        ],
                      ),
                    ],
                    if (partner != null && o.isDelivered) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Partner earning: ${inr(store.earningOf(o))} • ${o.earningPaid ? 'Paid' : 'Not paid yet'}',
                          style: TextStyle(color: o.earningPaid ? AC.success : AC.muted, fontSize: (AppText.small - 2), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    if (o.returnPartnerId.isNotEmpty) ...[
                      const Divider(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Return pickup: ${o.returnPartnerName.isEmpty ? o.returnPartnerId : o.returnPartnerName} • ${o.returnPickupStatus}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: (AppText.body - 2)),
                        ),
                      ),
                      if (o.returnPartnerPhone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _action(Icons.call_rounded, 'Call', AC.success, () => _dial(context, o.returnPartnerPhone, o.returnPartnerName.isEmpty ? 'The partner' : o.returnPartnerName)),
                            const SizedBox(width: 8),
                            _action(Icons.copy_rounded, 'Copy number', AC.primary, () => _copy(context, o.returnPartnerPhone, 'Number copied')),
                          ],
                        ),
                      ],
                    ],
                    if (o.rejectedHistory.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Gave this order back earlier: ${o.rejectedHistory.map((id) => store.partnerById(id)?.name ?? id).join(', ')}',
                          style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 2)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glass(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: (AppText.small - 2), fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: (AppText.small - 2), fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );

  /// Horizontal 5-step tracker (Flipkart / Amazon style).
  Widget _hTracker(int stage) {
    final n = orderSteps.length;
    Widget dot(int i) {
      final done = i < stage || (i == stage && i == n - 1);
      final current = i == stage && i != n - 1;
      final color = done ? AC.success : (current ? AC.accent : AC.border);
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: done || current ? color : Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : (current ? const Icon(Icons.more_horiz_rounded, size: 12, color: Colors.white) : null),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < n; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : (i <= stage ? AC.success : AC.border))),
                    dot(i),
                    Expanded(child: Container(height: 2, color: i == n - 1 ? Colors.transparent : (i < stage ? AC.success : AC.border))),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  orderSteps[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, height: 1.2, fontWeight: i <= stage ? FontWeight.w700 : FontWeight.w500, color: i <= stage ? AC.text : AC.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}