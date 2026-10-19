import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'home_screen.dart';
import 'checkout_ui.dart';
import 'product_detail_screen.dart';
import 'package:phonehub/app_text.dart';

// Same look as the Cart / Orders screens: shared gradient background, glass cards,
// section titles, bottom bar and gradient buttons come from checkout_ui.dart.
// Text sizes use the smaller steps of the AppText scale, same as the Cart screen.
// The header (CheckoutHeader with its back button) is unchanged.

const _cardBorder = Color(0xFFDCE8FF);
const _divider = Color(0xFFE8EFFC);

/// Store policy values come from Firestore (appConfig/store, set by the Admin in Settings).
/// _returnDays only holds the usual 7 until that document has loaded; the refund
/// time is shown only when the Admin has saved one (no made-up "5-7 days").
int _returnDays = 7;
int? _refundDays;
String get _refundWhen => _refundDays == null ? 'once PhoneHub has processed it' : 'within $_refundDays working days';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _dateText(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle(this.title, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: AppText.body, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (icon != null) Icon(icon, color: AppColors.accent, size: 18),
    ],
  );
}

/// Screen 7 – Order Tracking.
/// Status card, tracking timeline, delivery partner, items, price details,
/// address, payment, copy order ID, cancel / reorder in the bottom bar.
/// Also: pull to refresh, expected delivery, refund info, return window,
/// rating, help sheet and copy order summary.
class OrderTrackingScreen extends StatefulWidget {
  final Order? order;
  final bool fromPayment;
  const OrderTrackingScreen({super.key, this.order, this.fromPayment = false});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orderSubscription;
  bool _firebaseLoading = false;
  String? _firebaseError;
  int _rating = 0;
  bool _savingRating = false;
  // Live copy of orders/{id}: rating, delivery date, who cancelled and why.
  Map<String, dynamic> _live = <String, dynamic>{};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSubscription;
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>> _refundStreams = {};

  @override
  void initState() {
    super.initState();
    _listenForOrderUpdates();
    _listenLiveOrder();
    _loadPolicy();
  }

  /// Return window / refund time set by the Admin (appConfig/store).
  Future<void> _loadPolicy() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('appConfig').doc('store').get();
      final c = doc.data();
      if (c == null) return;
      final rd = c['returnDays'];
      final fd = c['refundDays'];
      if (!mounted) return;
      setState(() {
        if (rd is num && rd > 0) _returnDays = rd.toInt();
        _refundDays = (fd is num && fd > 0) ? fd.toInt() : null;
      });
    } catch (_) {}
  }

  void _listenForOrderUpdates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _firebaseLoading = true;
    _orderSubscription?.cancel();
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final remoteOrders = snapshot.docs.map(Order.fromFirestore).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
      if (remoteOrders.isNotEmpty) orders.value = remoteOrders;
      if (mounted) {
        setState(() {
          _firebaseLoading = false;
          _firebaseError = null;
        });
      }
    }, onError: (Object error) {
      if (mounted) {
        setState(() {
          _firebaseLoading = false;
          _firebaseError = error.toString();
        });
      }
    });
  }

  /// Follows orders/{id} live (rating, expected delivery date, cancel details).
  void _listenLiveOrder() {
    final id = widget.order?.id;
    final user = FirebaseAuth.instance.currentUser;
    if (id == null || user == null || id.startsWith('pending-')) return;
    _liveSubscription?.cancel();
    _liveSubscription = FirebaseFirestore.instance.collection('orders').doc(id).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null || !mounted) return;
      final r = data['rating'];
      setState(() {
        _live = data;
        if (!_savingRating && r is num) _rating = r.toInt();
      });
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _liveSubscription?.cancel();
    super.dispose();
  }

  Order get _order {
    final requested = widget.order;
    if (requested != null) {
      for (final item in orders.value) {
        if (item.id == requested.id) return item;
      }
      return requested;
    }
    if (orders.value.isNotEmpty) return orders.value.first;
    throw StateError('No order is available');
  }

  Color _statusColor(Order o) => o.cancelled ? AppColors.danger : (o.isDelivered ? AppColors.success : AppColors.accent);

  IconData _statusIcon(Order o) => o.cancelled ? Icons.cancel_rounded : (o.isDelivered ? Icons.check_circle_rounded : Icons.local_shipping_rounded);

  // ---- Actions ----
  void _copyId(Order o) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: o.id.toString()));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Order ${o.id} copied')));
  }

  /// Copies a short text summary of the order (to paste into chat / email).
  void _copySummary(Order o) {
    HapticFeedback.selectionClick();
    final b = StringBuffer()
      ..writeln('Order ${o.id}')
      ..writeln('Status: ${o.statusLabel}')
      ..writeln('Placed on ${fmtDateTime(o.placedAt)}');
    for (final it in o.items) {
      b.writeln('- ${it.phone.name} (${it.storage}, ${it.condition}) x${it.qty}');
    }
    b
      ..writeln('Total: ${rupee(o.total)}')
      ..writeln('Payment: ${o.paymentMethod}')
      ..write('Deliver to: ${o.addressLabel}, ${o.addressLine}');
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Order summary copied')));
  }

  /// Plain-text invoice of a DELIVERED order: the prices are the ones saved with the order
  /// (not today's catalogue prices). Shared through the phone's share sheet.
  String _invoiceText(Order o) {
    final user = FirebaseAuth.instance.currentUser;
    final name = profile.value.name.trim().isEmpty ? (user?.displayName ?? '') : profile.value.name.trim();
    final phone = profile.value.phone.trim();
    final delivered = o.stepTime(orderSteps.length - 1);
    final b = StringBuffer()
      ..writeln('PhoneHub - Invoice')
      ..writeln('Order: ${o.id}')
      ..writeln('Order date: ${fmtDateTime(o.placedAt)}')
      ..writeln('Delivered on: ${fmtDateTime(delivered)}');
    if (name.isNotEmpty) b.writeln('Customer: $name${phone.isEmpty ? '' : ' • $phone'}');
    b
      ..writeln('Deliver to: ${o.addressLabel.isEmpty ? '' : '${o.addressLabel}: '}${o.addressLine}')
      ..writeln('------------------------');
    final saved = _live['items'];
    if (saved is List && saved.isNotEmpty) {
      for (final r in saved) {
        if (r is! Map) continue;
        final q = r['quantity'] ?? r['qty'] ?? 1;
        final qty = q is num ? q.toInt() : 1;
        final price = r['price'] is num ? (r['price'] as num).toInt() : 0;
        final detail = [r['storage'], r['condition']].where((e) => e != null && e.toString().isNotEmpty).join(', ');
        b.writeln('${r['name'] ?? 'Phone'}${detail.isEmpty ? '' : ' ($detail)'} x$qty  ${rupee(price * qty)}');
      }
    } else {
      for (final it in o.items) {
        b.writeln('${it.phone.name} (${it.storage}, ${it.condition}) x${it.qty}  ${rupee(it.phone.price * it.qty)}');
      }
    }
    b
      ..writeln('------------------------')
      ..writeln('Subtotal: ${rupee(o.subtotal)}')
      ..writeln('Delivery: ${o.delivery == 0 ? 'FREE' : rupee(o.delivery)}');
    if (o.discount > 0) b.writeln('Discount${(o.couponCode ?? '').isEmpty ? '' : ' (${o.couponCode})'}: -${rupee(o.discount)}');
    b
      ..writeln('Total: ${rupee(o.total)}')
      ..writeln('Payment: ${o.paymentMethod}${o.paymentStatus.isEmpty ? '' : ' • ${o.paymentStatus}'}');
    return b.toString();
  }

  Future<void> _shareInvoice(Order o) async {
    HapticFeedback.selectionClick();
    final text = _invoiceText(o);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'PhoneHub invoice ${o.id}', title: 'Invoice ${o.id}', sharePositionOrigin: origin),
      );
    } catch (_) {
      // The share sheet could not open: copy the invoice instead.
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Invoice copied')));
    }
  }

  /// Pull to refresh: re-subscribes to the orders stream.
  Future<void> _refresh() async {
    _listenForOrderUpdates();
    _listenLiveOrder();
    _loadPolicy();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _rate(Order o, int stars) async {
    if (_savingRating) return;
    final previous = _rating;
    HapticFeedback.selectionClick();
    setState(() {
      _rating = stars;
      _savingRating = true;
    });
    try {
      await FirebaseFirestore.instance.collection('orders').doc(o.id.toString()).update({
        'rating': stars,
        'ratedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _rating = previous);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(content: Text('Could not save your rating. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _savingRating = false);
    }
  }

  void _showHelp(Order o) {
    Widget tile(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Need help with this order?', style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('Quick answers about your order', style: TextStyle(color: AppColors.muted, fontSize: AppText.small)),
              const SizedBox(height: 16),
              tile(Icons.cancel_outlined, 'Cancellation & refunds', 'You can cancel until the order is out for delivery. Refunds go to the original payment method $_refundWhen.'),
              tile(Icons.local_shipping_outlined, 'Delivery delays', 'Check the live status on this screen. When the order is out for delivery you can contact the delivery partner.'),
              tile(Icons.assignment_return_outlined, 'Returns & replacements', 'If there is a problem with your phone, you can request a return within $_returnDays days of delivery.'),
              const SizedBox(height: 4),
              GradientButton(
                height: 48,
                onTap: () {
                  Navigator.pop(ctx);
                  _copyId(o);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Copy order ID for support', style: TextStyle(fontSize: AppText.small)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(Order o) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel this order?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.subtitle, color: AppColors.text)),
        content: Text(
          o.paymentMethod.toLowerCase().contains('cash')
              ? 'This is a cash on delivery order, so nothing has been charged.'
              : 'Your refund will be sent to the original payment method $_refundWhen.',
          style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      // One update only (cancelOrder in data.dart). If Firestore refuses, the screen goes back to the old status.
      final ok = await cancelOrder(o);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(ok ? 'Order cancelled' : 'Could not cancel this order. It may already be on its way.')));
    }
  }

  Future<void> _call(Order o) async {
    if (o.partnerPhone.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Delivery partner number is not available yet.')));
      return;
    }
    final number = o.partnerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    var opened = false;
    try {
      opened = number.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {}
    if (opened || !mounted) return;
    // No dialer available: copy the number instead.
    Clipboard.setData(ClipboardData(text: o.partnerPhone));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('${o.partnerName.isEmpty ? 'Partner' : o.partnerName}\'s number copied. Open your dialer to call.')));
  }

  void _reorder(Order o) {
    reorder(o);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Items added to your cart')));
  }

  void _continueShopping() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Order>>(
      valueListenable: orders,
      builder: (context, _, __) {
        if (orders.value.isEmpty) return _emptyScreen();

        final o = _order;
        final stage = o.stage;
        final active = !o.cancelled && !o.isDelivered && stage < 3;

        return CheckoutBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  CheckoutHeader(
                    title: 'Order Tracking',
                    step: widget.fromPayment ? 'Your order has been placed' : null,
                    trailing: const SizedBox(width: 2),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                          if (widget.fromPayment) _successBanner(),
                          _statusCard(o),
                          const SizedBox(height: 14),
                          if (!o.cancelled && !o.isDelivered && stage < 4) ...[
                            _expectedCard(o, stage),
                            const SizedBox(height: 14),
                          ],
                          if (o.cancelled) ...[
                            _cancelledCard(o),
                            const SizedBox(height: 14),
                            _refundCard(o),
                          ] else
                            _timelineCard(o, stage),
                          if (!o.cancelled && stage == 3) ...[
                            const SizedBox(height: 14),
                            _mapCard(o),
                            const SizedBox(height: 14),
                            _partnerCard(o),
                            _DeliveryOtpCard(orderId: o.id),
                          ],
                          if (o.isDelivered && !o.cancelled) ...[
                            const SizedBox(height: 14),
                            _deliveredCard(o),
                            const SizedBox(height: 14),
                            _ratingCard(o),
                            _ReturnCard(order: o),
                          ],
                          const SizedBox(height: 14),
                          _itemsCard(o),
                          const SizedBox(height: 14),
                          _priceCard(o),
                          const SizedBox(height: 14),
                          _addressPaymentCard(o),
                          const SizedBox(height: 14),
                          _helpCard(o),
                          if (widget.fromPayment && active) ...[
                            const SizedBox(height: 14),
                            _cancelRow(o),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _bottomBar(o, active),
          ),
        );
      },
    );
  }

  // ---- Loading / error (no orders yet) ----
  Widget _emptyScreen() {
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const CheckoutHeader(title: 'Order Tracking'),
              Expanded(
                child: Center(
                  child: _firebaseError != null
                      ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: glassDeco(radius: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.danger),
                          const SizedBox(height: 12),
                          const Text('Could not load your order', textAlign: TextAlign.center, style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text)),
                          const SizedBox(height: 4),
                          Text(_firebaseError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppText.caption, color: AppColors.muted)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 140,
                            child: GradientButton(
                              height: 44,
                              onTap: () {
                                setState(() {
                                  _firebaseError = null;
                                  _firebaseLoading = true;
                                });
                                _listenForOrderUpdates();
                              },
                              child: const Text('Retry', style: TextStyle(fontSize: AppText.small)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text('Loading your order...', style: TextStyle(color: AppColors.muted, fontSize: AppText.small)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Cards ----
  Widget _successBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18, borderColor: AppColors.success.withValues(alpha: 0.28)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order placed successfully 🎉', style: TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800, color: AppColors.success)),
                SizedBox(height: 2),
                Text('We will keep you updated on every step.', style: TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top card: image with +N badge, title, order ID (tap to copy), placed date, status chip.
  Widget _statusCard(Order o) {
    final p = o.items.first.phone;
    final c = _statusColor(o);
    final extra = o.itemCount - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 78, height: 78, child: PhoneImage(phone: p, height: 78, iconSize: 36))),
              if (extra > 0)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(14)),
                    ),
                    child: Text('+$extra', style: const TextStyle(color: Colors.white, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text, height: 1.2)),
                const SizedBox(height: 5),

                const SizedBox(height: 2),
                Text('Placed on ${fmtDateTime(o.placedAt)}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(o), size: 12, color: c),
                      const SizedBox(width: 4),
                      Flexible(child: Text(o.statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: AppText.caption, fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small icon tile + label + value card (same pattern as the Cart address card).
  Widget _infoCard({
    required IconData icon,
    required String label,
    required String title,
    String? text,
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18, borderColor: color == null ? null : c.withValues(alpha: 0.25)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: c, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                if (text != null) ...[
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Expected delivery date for orders that are still on the way.
  Widget _expectedCard(Order o, int stage) {
    final eta = o.etaText.toString().trim();
    // The delivery date saved with this order when it was placed (orders/{id}.deliveryDate).
    final saved = _live['deliveryDate'];
    final dateTitle = saved is Timestamp ? _dateText(saved.toDate()) : 'Date will be updated by PhoneHub';
    final title = (stage == 3 && eta.isNotEmpty) ? eta : dateTitle;
    final partner = o.partnerName.trim();
    return _infoCard(
      icon: Icons.local_shipping_outlined,
      label: 'Expected delivery',
      title: title,
      text: stage == 3
          ? 'Your order is out for delivery'
          : (partner.isNotEmpty ? 'Delivery partner assigned: $partner' : 'We will notify you when the status changes'),
      color: AppColors.success,
    );
  }

  Widget _cancelledCard(Order o) {
    final by = (_live['cancelledBy'] ?? '').toString();
    final reason = (_live['cancelReason'] ?? '').toString().trim();
    final cod = o.paymentMethod.toLowerCase().contains('cash') || o.paymentMethod.toLowerCase().contains('cod');
    final who = by == 'admin' ? 'by PhoneHub' : (by == 'customer' ? 'by you' : '');
    final message = 'This order was cancelled${who.isEmpty ? '' : ' $who'}.'
        '${reason.isEmpty ? '' : ' Reason: $reason.'}'
        '${cod ? '' : ' Any amount paid will be refunded $_refundWhen.'}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18, borderColor: AppColors.danger.withValues(alpha: 0.25)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: AppText.small, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Refund info for cancelled orders (no refund for cash on delivery).
  Widget _refundCard(Order o) {
    final m = o.paymentMethod.toString().toLowerCase();
    final cod = m.contains('cash') || m.contains('cod');
    if (cod) {
      return _infoCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Refund',
        title: 'No refund needed',
        text: 'This was a cash on delivery order, so nothing was charged.',
      );
    }
    // Live status of refunds/RF_<orderId> (the Admin approves / completes it).
    final stream = _refundStreams.putIfAbsent(
      o.id,
          () => FirebaseFirestore.instance
          .collection('refunds')
          .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
          .where('orderId', isEqualTo: o.id)
          .snapshots(),
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final d = (snap.data?.docs.isNotEmpty ?? false) ? snap.data!.docs.first : null;
        final status = d != null ? (d.data()['status'] ?? 'Requested').toString() : 'Requested';
        final text = status == 'Approved'
            ? 'Approved. The refund will reach ${o.paymentMethod} soon.'
            : status == 'Refunded'
            ? 'Refunded to ${o.paymentMethod}.'
            : status == 'Rejected'
            ? 'Rejected. Please contact support if you need help.'
            : 'Waiting for PhoneHub to process it ($_refundWhen).';
        return _infoCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Refund',
          title: '${rupee(o.total)} • $status',
          text: text,
          color: status == 'Refunded' ? AppColors.success : (status == 'Rejected' ? AppColors.danger : null),
        );
      },
    );
  }

  /// Delivered date and the return window.
  Widget _deliveredCard(Order o) {
    final DateTime delivered = o.stepTime(orderSteps.length - 1);
    final until = delivered.add(Duration(days: _returnDays));
    final canReturn = DateTime.now().isBefore(until);
    return _infoCard(
      icon: Icons.inventory_2_outlined,
      label: 'Delivered on',
      title: fmtDateTime(delivered),
      text: canReturn ? 'Return or replacement available until ${_dateText(until)}' : 'The return window for this order has ended',
      color: AppColors.success,
    );
  }

  Widget _ratingCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Rate your experience', icon: Icons.star_outline_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => _rate(o, i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_border_rounded, size: 30, color: i <= _rating ? AppColors.accent : AppColors.muted.withValues(alpha: 0.6)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_rating == 0 ? 'Tap a star to rate this order' : 'Thanks for rating this order', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Help + copy summary (same 42px action row as the Cart tiles).
  Widget _helpCard(Order o) {
    return Container(
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: _SectionTitle('Need Help?', icon: Icons.support_agent_rounded),
          ),
          const Divider(height: 1, thickness: 1, color: _divider),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(child: _action(Icons.help_outline_rounded, 'Get help', AppColors.primary, () => _showHelp(o))),
                Container(width: 1, height: 22, color: _divider),
                Expanded(child: _action(Icons.copy_rounded, 'Copy summary', AppColors.muted, () => _copySummary(o))),
                if (o.isDelivered && !o.cancelled) ...[
                  Container(width: 1, height: 22, color: _divider),
                  Expanded(child: _action(Icons.receipt_long_rounded, 'Invoice', AppColors.primary, () => _shareInvoice(o))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard(Order o, int stage) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Order Status', icon: Icons.timeline_rounded),
          const SizedBox(height: 14),
          for (int k = 0; k < orderSteps.length; k++)
            _Step(
              orderSteps[k],
              _subtitle(o, k, stage),
              stage >= 4 || k < stage ? _S.done : (k == stage ? _S.current : _S.pending),
              k == orderSteps.length - 1,
              icon: k == 3 ? Icons.two_wheeler_rounded : Icons.inventory_2_rounded,
            ),
        ],
      ),
    );
  }

  /// Live map: the delivery partner's real position and the customer's address.
  /// Shows the old map picture until the partner's position is known.
  Widget _mapCard(Order o) => _LiveMapCard(orderId: o.id, fallback: _mapPlaceholder());

  Widget _mapPlaceholder() {
    return Container(
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: glassDeco(radius: 18),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 13)]),
              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 5),
                  Text('Out for delivery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.caption, color: AppColors.text)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(o.partnerName.isEmpty ? 'D' : o.partnerName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: AppText.subtitle)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.partnerName.isEmpty ? 'Delivery partner' : o.partnerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 14),
                    SizedBox(width: 4),
                    Text('Delivery Partner', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          _roundBtn(Icons.call_rounded, AppColors.success, () => _call(o)),
        ],
      ),
    );
  }

  Widget _itemsCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Items (${o.itemCount})', icon: Icons.inventory_2_outlined),
          const SizedBox(height: 12),
          for (int i = 0; i < o.items.length; i++) ...[
            if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: _divider)),
            _itemRow(o.items[i]),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(dynamic it) {
    final p = it.phone;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: p))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 56, height: 56, child: PhoneImage(phone: p, height: 56, iconSize: 26))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text, height: 1.2)),
                const SizedBox(height: 3),
                Text('${it.storage} • ${it.condition} • Qty ${it.qty}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(rupee(p.price * it.qty), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: AppText.small, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _priceCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDeco(radius: 18),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: _SectionTitle('Price Details')),
          const SizedBox(height: 12),
          _row('Items (${o.itemCount})', rupee(o.subtotal)),
          _row('Delivery', o.delivery == 0 ? 'FREE' : rupee(o.delivery), valueColor: o.delivery == 0 ? AppColors.success : null),
          if (o.discount > 0) _row('Coupon (${o.couponCode})', '- ${rupee(o.discount)}', valueColor: AppColors.success),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: _divider)),
          _row('Total paid', rupee(o.total), bold: true),
        ],
      ),
    );
  }

  Widget _addressPaymentCard(Order o) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery address', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(o.addressLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(o.addressLine, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: _divider)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.payments_outlined, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Paid via ${o.paymentMethod}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cancel action inside the content (only used when the bottom bar shows Continue Shopping).
  Widget _cancelRow(Order o) {
    return Container(
      decoration: glassDeco(radius: 18),
      child: SizedBox(
        height: 42,
        child: _action(Icons.delete_outline_rounded, 'Cancel order', AppColors.danger, () => _confirmCancel(o)),
      ),
    );
  }

  // ---- Bottom bar (same as Cart) ----
  Widget _bottomBar(Order o, bool active) {
    Widget button;
    if (widget.fromPayment) {
      button = GradientButton(height: 48, onTap: _continueShopping, child: const Text('Continue Shopping', style: TextStyle(fontSize: AppText.small)));
    } else if (o.isDelivered || o.cancelled) {
      button = GradientButton(
        height: 48,
        onTap: () => _reorder(o),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 16),
            SizedBox(width: 6),
            Text('Reorder', style: TextStyle(fontSize: AppText.small)),
          ],
        ),
      );
    } else if (active) {
      button = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger, width: 1.2),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800),
        ),
        onPressed: () => _confirmCancel(o),
        child: const Text('Cancel Order'),
      );
    } else {
      // Out for delivery: cancelling is no longer possible.
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: checkoutBottomBarDeco(),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.cancelled ? 'Order total' : 'Total paid', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption)),
                Text(rupee(o.total), style: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w900, color: AppColors.text)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(child: button),
          ],
        ),
      ),
    );
  }

  // ---- Helpers ----
  String _subtitle(Order o, int k, int stage) {
    if (stage >= 4 || k < stage) return fmtDateTime(o.stepTime(k));
    if (k == stage) return k == 3 ? o.etaText : 'In progress';
    return 'Pending';
  }

  Widget _row(String l, String v, {bool bold = false, Color? valueColor}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? AppText.subtitle : AppText.small, color: bold ? AppColors.text : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: style),
          Text(v, style: style.copyWith(color: valueColor ?? (bold ? AppColors.primary : AppColors.text))),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _roundBtn(IconData i, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(i, color: c, size: 19),
    ),
  );
}

enum _S { done, current, pending }

class _Step extends StatelessWidget {
  final String title, subtitle;
  final _S state;
  final bool last;
  final IconData icon;
  const _Step(this.title, this.subtitle, this.state, this.last, {this.icon = Icons.two_wheeler_rounded});

  @override
  Widget build(BuildContext context) {
    final color = state == _S.pending ? AppColors.border : (state == _S.current ? AppColors.accent : AppColors.success);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: state == _S.pending ? Colors.white : color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.8),
                  boxShadow: state == _S.current ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8)] : null,
                ),
                child: state == _S.done
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : state == _S.current
                    ? Icon(icon, size: 13, color: Colors.white)
                    : null,
              ),
              if (!last) Expanded(child: Container(width: 2, color: state == _S.done ? AppColors.success : AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: state == _S.pending ? AppColors.muted : AppColors.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reads `orders/{id}` live (partnerLat / partnerLng are written by the delivery partner app,
/// addressLat / addressLng by checkout) and draws both points on a Google Map.
class _LiveMapCard extends StatefulWidget {
  final String orderId;
  final Widget fallback;
  const _LiveMapCard({required this.orderId, required this.fallback});

  @override
  State<_LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<_LiveMapCard> {
  gm.GoogleMapController? _map;
  String _lastPartnerKey = '';

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  gm.LatLng? _pt(dynamic lat, dynamic lng) => (lat is num && lng is num) ? gm.LatLng(lat.toDouble(), lng.toDouble()) : null;

  double _km(gm.LatLng a, gm.LatLng b) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude), dLng = rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h.toDouble()));
  }

  /// Keeps both points in view when the partner moves (the map itself is not touch-scrollable,
  /// so it never fights with the page scroll).
  void _follow(gm.LatLng partner, gm.LatLng? dest) {
    final key = '${partner.latitude.toStringAsFixed(4)},${partner.longitude.toStringAsFixed(4)}';
    if (key == _lastPartnerKey) return;
    _lastPartnerKey = key;
    final map = _map;
    if (map == null) return;
    try {
      if (dest == null) {
        map.animateCamera(gm.CameraUpdate.newLatLngZoom(partner, 15)).catchError((Object _) {});
      } else {
        final b = gm.LatLngBounds(
          southwest: gm.LatLng(math.min(partner.latitude, dest.latitude), math.min(partner.longitude, dest.longitude)),
          northeast: gm.LatLng(math.max(partner.latitude, dest.latitude), math.max(partner.longitude, dest.longitude)),
        );
        map.animateCamera(gm.CameraUpdate.newLatLngBounds(b, 60)).catchError((Object _) {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final partner = d == null ? null : _pt(d['partnerLat'], d['partnerLng']);
        if (d == null || partner == null) return widget.fallback;
        final dest = _pt(d['addressLat'], d['addressLng']);

        final at = d['partnerLocationAt'];
        final mins = at is Timestamp ? DateTime.now().difference(at.toDate()).inMinutes : null;
        String label;
        if (dest != null) {
          final km = _km(partner, dest);
          final eta = math.max(1, (km / 25 * 60).ceil());
          label = km < 1 ? '${(km * 1000).round()} m away • ~$eta min' : '${km.toStringAsFixed(1)} km away • ~$eta min';
        } else {
          label = mins == null || mins < 1 ? 'Live location' : 'Updated $mins min ago';
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _follow(partner, dest));

        return Container(
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: glassDeco(radius: 18),
          child: Stack(
            children: [
              Positioned.fill(
                child: gm.GoogleMap(
                  initialCameraPosition: gm.CameraPosition(target: partner, zoom: 14),
                  onMapCreated: (c) {
                    _map = c;
                    _lastPartnerKey = '';
                    _follow(partner, dest);
                  },
                  markers: {
                    gm.Marker(
                      markerId: const gm.MarkerId('partner'),
                      position: partner,
                      icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
                      infoWindow: const gm.InfoWindow(title: 'Delivery partner'),
                    ),
                    if (dest != null)
                      gm.Marker(
                        markerId: const gm.MarkerId('home'),
                        position: dest,
                        icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
                        infoWindow: const gm.InfoWindow(title: 'Delivery address'),
                      ),
                  },
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder)),
                  child: Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.caption, color: AppColors.text)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFEAF1FF));
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    for (final fy in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(0, s.height * fy), Offset(s.width, s.height * fy), road);
    }
    for (final fx in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(s.width * fx, 0), Offset(s.width * fx, s.height), road);
    }
    final route = Path()
      ..moveTo(s.width * 0.2, s.height * 0.8)
      ..lineTo(s.width * 0.5, s.height * 0.8)
      ..lineTo(s.width * 0.5, s.height * 0.2)
      ..lineTo(s.width * 0.8, s.height * 0.2);
    canvas.drawPath(
      route,

      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(s.width * 0.2, s.height * 0.8), 8, Paint()..color = AppColors.success);
    canvas.drawCircle(Offset(s.width * 0.2, s.height * 0.8), 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.2), 10, Paint()..color = AppColors.danger);
    canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.2), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Delivery OTP for the customer (real code from `orders/{id}/private/otp`).
/// The customer tells it to the delivery partner at the door; the partner needs it to mark the order delivered.
class _DeliveryOtpCard extends StatefulWidget {
  final String orderId;
  const _DeliveryOtpCard({required this.orderId});

  @override
  State<_DeliveryOtpCard> createState() => _DeliveryOtpCardState();
}

class _DeliveryOtpCardState extends State<_DeliveryOtpCard> {
  late final Stream<String?> _stream = deliveryOtpStream(widget.orderId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _stream,
      builder: (context, snap) {
        final code = snap.data;
        // Older orders have no OTP: show nothing.
        if (code == null || code.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: glassDeco(radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Delivery OTP', icon: Icons.lock_outline_rounded),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final ch in code.split(''))
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 44,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Text(ch, style: const TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this OTP with the delivery partner only after you have received your phone.',
                  style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Return / replacement request for a DELIVERED order (saved in `refunds/RF_<orderId>`,
/// the same collection the Admin "Payments & Refunds" screen already reads).
/// Shows the live status of the request once it is sent.
class _ReturnCard extends StatefulWidget {
  final Order order;
  const _ReturnCard({required this.order});

  @override
  State<_ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends State<_ReturnCard> {
  // IMPORTANT: a direct read of refunds/RF_<id> is refused by the Firestore rules while that
  // document does not exist yet (the rule reads resource.data), which used to hide this whole card.
  // A query filtered by the customer's own uid is always allowed, and returns nothing until the
  // customer has sent a return request.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = FirebaseFirestore.instance
      .collection('refunds')
      .where('customerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
      .where('orderId', isEqualTo: widget.order.id)
      .snapshots();
  // The order document itself carries the pickup progress (returnPickupStatus ...), written by
  // the Admin (assign / received) and by the delivery partner (picked up).
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream =
  FirebaseFirestore.instance.collection('orders').doc(widget.order.id).snapshots();
  bool _sending = false;

  static const _reasons = <String>[
    'Phone is not as described',
    'Defect or not working properly',
    'Wrong phone received',
    'Changed my mind',
  ];

  bool get _inWindow {
    final delivered = widget.order.stepTime(orderSteps.length - 1);
    return DateTime.now().isBefore(delivered.add(Duration(days: _returnDays)));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Details box rules: the last reason ("Changed my mind") may stay empty, the other reasons
  /// need a short description (10 to 300 characters, with some words, not only numbers / symbols).
  String? _validateDetails(String raw, int selected) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final optional = selected == _reasons.length - 1;
    if (t.isEmpty) return optional ? null : 'Please describe the problem so we can check your return';
    if (t.length < 10) return 'Please write at least 10 characters';
    if (t.length > 300) return 'Details can be at most 300 characters';
    if (!RegExp(r'[A-Za-z\u0900-\u097F]').hasMatch(t)) return 'Please describe the problem in words';
    return null;
  }

  Future<void> _openSheet() async {
    var selected = 0;
    String? detailsError;
    final detailsCtrl = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Request a return', style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('Tell us what went wrong', style: TextStyle(color: AppColors.muted, fontSize: AppText.small)),
                const SizedBox(height: 10),
                for (int i = 0; i < _reasons.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setSheet(() {
                      selected = i;
                      detailsError = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Icon(selected == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: selected == i ? AppColors.primary : AppColors.muted),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_reasons[i], style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.text))),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 3,
                  inputFormatters: [LengthLimitingTextInputFormatter(300)],
                  onChanged: (_) {
                    if (detailsError != null) setSheet(() => detailsError = null);
                  },
                  style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: selected == _reasons.length - 1 ? 'Add details (optional)' : 'Describe the problem',
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
                    errorText: detailsError,
                    errorStyle: const TextStyle(fontSize: AppText.caption),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    filled: true,
                    fillColor: checkoutFieldFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                GradientButton(
                  height: 48,
                  onTap: () {
                    final err = _validateDetails(detailsCtrl.text, selected);
                    if (err != null) {
                      setSheet(() => detailsError = err);
                      return;
                    }
                    final note = detailsCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                    Navigator.pop(ctx, note.isEmpty ? _reasons[selected] : '${_reasons[selected]} - $note');
                  },
                  child: const Text('Submit request', style: TextStyle(fontSize: AppText.small)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // detailsCtrl is not disposed here on purpose: the closing sheet may still be drawing it.
    if (reason != null) await _submit(reason);
  }

  Future<void> _submit(String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _sending) return;
    final o = widget.order;
    if (!_inWindow) {
      _snack('The return window for this order has closed.');
      return;
    }
    setState(() => _sending = true);
    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc(o.id);
      final refundRef = db.collection('refunds').doc('RF_${o.id}');
      // Already requested? Checked with a query on the customer's own refunds: reading the
      // document directly is refused by the Firestore rules while it does not exist yet.
      final existing = await db
          .collection('refunds')
          .where('customerId', isEqualTo: user.uid)
          .where('orderId', isEqualTo: o.id)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw StateError('A return request already exists');
      }
      await db.runTransaction((transaction) async {
        // Re-check server state so a stale screen cannot request a return for
        // an order that was cancelled, not delivered, or belongs to someone else.
        final orderSnapshot = await transaction.get(orderRef);
        if (!orderSnapshot.exists) {
          throw StateError('Order not found');
        }
        final orderData = orderSnapshot.data() ?? <String, dynamic>{};
        final ownerId = (orderData['customerId'] ?? orderData['userId'] ?? '').toString();
        final status = (orderData['status'] ?? orderData['orderStatus'] ?? '').toString().toLowerCase();
        if (ownerId != user.uid || !status.contains('delivered') || status.contains('cancel')) {
          throw StateError('Order is not eligible for return');
        }

        transaction.set(refundRef, {
          'refNo': 'RF${o.id.length >= 6 ? o.id.substring(0, 6).toUpperCase() : o.id.toUpperCase()}',
          'orderId': o.id,
          'customerId': user.uid,
          'amount': (orderData['total'] as num?)?.toInt() ?? o.total,
          'reason': 'Return: $reason',
          'type': 'return',
          'status': 'Requested',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _snack('Return request sent. You can see its status here.');
    } catch (error) {
      final message = error is StateError && error.message == 'A return request already exists'
          ? 'A return request already exists for this order.'
          : error is StateError && error.message == 'The return window for this order has closed.'
          ? error.message
          : 'Could not send your request. Please try again.';
      _snack(message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  DateTime? _when(dynamic v) => v is Timestamp ? v.toDate() : null;

  Future<void> _callPickupPartner(String phone, String name) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    var opened = false;
    try {
      opened = number.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {}
    if (opened || !mounted) return;
    Clipboard.setData(ClipboardData(text: phone));
    _snack('${name.isEmpty ? 'Pickup partner' : name}\'s number copied. Open your dialer to call.');
  }

  /// Journey of the returned phone: requested -> approved -> pickup arranged -> picked up ->
  /// received by PhoneHub -> refunded. Every step comes from Firestore (refund + order documents).
  Widget _pickupTimeline(String status, Map<String, dynamic> od) {
    final pickup = (od['returnPickupStatus'] ?? '').toString();
    final partner = (od['returnPartnerName'] ?? '').toString().trim();
    final phone = (od['returnPartnerPhone'] ?? '').toString().trim();
    final assigned = pickup == 'Pickup Assigned' || pickup == 'Picked Up' || pickup == 'Received';
    final picked = pickup == 'Picked Up' || pickup == 'Received';
    final received = pickup == 'Received';
    final approved = status == 'Approved' || status == 'Refunded';
    final pickedAt = _when(od['returnPickedAt']);
    final receivedAt = _when(od['returnReceivedAt']);
    final assignedAt = _when(od['returnPickupAssignedAt']);

    final steps = <(String, bool, String?)>[
      ('Return requested', true, null),
      ('Return approved', approved, null),
      ('Pickup arranged', assigned, assigned ? (partner.isEmpty ? 'A delivery partner will collect your phone' : '$partner will collect your phone') + (assignedAt == null ? '' : ' • ${fmtDateTime(assignedAt)}') : null),
      ('Phone picked up', picked, pickedAt == null ? null : fmtDateTime(pickedAt)),
      ('Received by PhoneHub', received, receivedAt == null ? null : fmtDateTime(receivedAt)),
      ('Refund completed', status == 'Refunded', null),
    ];
    final current = steps.indexWhere((s) => !s.$2);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    steps[i].$2 ? Icons.check_circle_rounded : (i == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                    size: 16,
                    color: steps[i].$2 ? AppColors.success : (i == current ? AppColors.accent : AppColors.muted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1,
                            style: TextStyle(
                                fontSize: AppText.caption,
                                fontWeight: (steps[i].$2 || i == current) ? FontWeight.w800 : FontWeight.w600,
                                color: (steps[i].$2 || i == current) ? AppColors.text : AppColors.muted)),
                        if (steps[i].$3 != null)
                          Text(steps[i].$3!, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (pickup == 'Pickup Assigned' && phone.isNotEmpty)
            GestureDetector(
              onTap: () => _callPickupPartner(phone, partner),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('Call ${partner.isEmpty ? 'pickup partner' : partner}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: AppText.caption)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _orderStream,
      builder: (context, orderSnap) => _buildCard(orderSnap.data?.data() ?? const <String, dynamic>{}),
    );
  }

  Widget _buildCard(Map<String, dynamic> od) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final data = docs.isEmpty ? null : docs.first;
        if (data != null) {
          final status = (data.data()['status'] ?? 'Requested').toString();
          final color = status == 'Refunded' ? AppColors.success : (status == 'Rejected' ? AppColors.danger : AppColors.accent);
          final pickup = (od['returnPickupStatus'] ?? '').toString();
          final text = status == 'Approved'
              ? (pickup == 'Received'
              ? 'We received your phone. Your refund is being processed.'
              : pickup == 'Picked Up'
              ? 'Your phone was picked up and is on its way to PhoneHub.'
              : pickup == 'Pickup Assigned'
              ? 'Approved. A delivery partner will collect your phone.'
              : 'Approved. PhoneHub will arrange a pickup for your phone.')
              : status == 'Refunded'
              ? 'Refunded to your original payment method.'
              : status == 'Rejected'
              ? 'Rejected. Please contact support if you need help.'
              : 'Waiting for PhoneHub to review your request.';
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: glassDeco(radius: 18, borderColor: color.withValues(alpha: 0.25)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.assignment_return_outlined, color: color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Return request', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(status, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(text, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.35)),
                        if (status != 'Rejected') _pickupTimeline(status, od),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // No request yet: offer it only while the return window is open.
        if (!_inWindow) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: glassDeco(radius: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Return or replacement', icon: Icons.assignment_return_outlined),
                const SizedBox(height: 6),
                const Text('Problem with your phone? You can ask for a return within the return window.', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.35)),
                const SizedBox(height: 10),
                GradientButton(
                  height: 44,
                  onTap: _sending ? () {} : _openSheet,
                  child: Text(_sending ? 'Sending...' : 'Request a return', style: const TextStyle(fontSize: AppText.small)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}