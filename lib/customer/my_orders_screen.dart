import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:phonehub/customer/checkout_ui.dart';
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';
import 'shared_ui.dart';
import 'product_list_screen.dart';
import 'order_tracking_screen.dart';
import 'package:phonehub/app_text.dart';

// Same look as the Cart / Saved Addresses / checkout screens: shared gradient
// background, glass cards, header tile and gradient buttons come from checkout_ui.dart.
// Text sizes use the smaller steps of the AppText scale, same as the Cart screen.

const _cardBorder = Color(0xFFDCE8FF);
const _divider = Color(0xFFE8EFFC);
const _trackOff = Color(0xFFE3ECFB);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String _dateText(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Orders screen
/// Header, search, status tabs with counts, order cards with progress tracker,
/// track / details, copy order ID, buy again, loading / error / empty states.
class OrdersScreen extends StatefulWidget {
  final bool showBack;

  const OrdersScreen({super.key, this.showBack = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _segs = ['Ongoing', 'Delivered', 'Cancelled'];

  // static const _steps = ['Ordered', 'Packed', 'Shipped', 'Delivery'];

  final _search = TextEditingController();
  int seg = 0;
  String query = '';
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final user = FirebaseAuth.instance.currentUser;
    _stream = user == null
        ? null
        : FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchSeg(Order o, int s) {
    switch (s) {
      case 0:
        return o.isOngoing;
      case 1:
        return o.isDelivered;
      default:
        return o.cancelled;
    }
  }

  bool _matchQuery(Order o) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (o.id.toString().toLowerCase().contains(q)) return true;
    if (o.title.toLowerCase().contains(q)) return true;
    for (final it in o.items) {
      if (it.phone.name.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  // ---- Actions ----
  void _copyId(Order o) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: o.id.toString()));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Order ${o.id} copied')));
  }

  /// Puts every item of an old order back in the cart with the same options and quantity.
  void _buyAgain(Order o) {
    int added = 0;
    int skipped = 0;
    int limited = 0;

    for (final it in o.items) {
      final stock = it.phone.stock;
      if (stock <= 0 || it.qty <= 0) {
        skipped++;
        continue;
      }

      final existingIndex = cart.value.indexWhere((e) =>
      e.phone.id == it.phone.id &&
          e.storage == it.storage &&
          e.condition == it.condition);
      final maxQty = stock.clamp(1, 5).toInt();
      final currentQty = existingIndex >= 0
          ? cart.value[existingIndex].qty
          : 0;
      final targetQty = (currentQty + it.qty).clamp(1, maxQty).toInt();

      if (currentQty >= maxQty) {
        limited++;
        continue;
      }

      if (existingIndex >= 0) {
        changeQty(cart.value[existingIndex], targetQty - currentQty);
      } else {
        addToCart(it.phone, it.storage, it.condition);
        final addedItemIndex = cart.value.indexWhere((e) =>
        e.phone.id == it.phone.id &&
            e.storage == it.storage &&
            e.condition == it.condition);
        if (addedItemIndex >= 0 && targetQty > cart.value[addedItemIndex].qty) {
          changeQty(cart.value[addedItemIndex],
              targetQty - cart.value[addedItemIndex].qty);
        }
      }
      added++;
      if (targetQty < currentQty + it.qty) limited++;
    }

    final parts = <String>[];
    if (added > 0) parts.add('$added ${added == 1 ? 'item' : 'items'} added');
    if (limited > 0) parts.add('$limited limited by cart/stock limits');
    if (skipped > 0) parts.add('$skipped out of stock');
    final text = parts.isEmpty
        ? 'These items are already at the cart quantity limit'
        : parts.join(', ');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _openOrder(Order o) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: o)));
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: _stream == null
              ? _body(const [], loading: false, error: false, loggedIn: false)
              : _streamBody(),
        ),
      ),
    );
  }

  Widget _streamBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _body(const [], loading: false, error: true, loggedIn: true);
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _body(const [], loading: true, error: false, loggedIn: true);
        }
        final all = (snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map((doc) => Order.fromFirestore(doc))
            .toList()
          ..sort((a, b) => (b.placedAt ??
              DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.placedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        return _body(all, loading: false, error: false, loggedIn: true);
      },
    );
  }

  Widget _body(List<Order> all,
      {required bool loading, required bool error, required bool loggedIn}) {
    final counts = [
      for (int i = 0; i < _segs.length; i++)
        all.where((o) => _matchSeg(o, i)).length
    ];
    final list = all.where((o) => _matchSeg(o, seg) && _matchQuery(o)).toList();

    Widget content;
    if (!loggedIn) {
      content = _message(Icons.lock_outline_rounded, 'Please log in',
          'Log in to view and track your orders');
    } else if (loading) {
      content = _loading();
    } else if (error) {
      content = _errorState();
    } else if (list.isEmpty) {
      content = _emptyState(hasOrders: all.isNotEmpty);
    } else {
      content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [for (final o in list) _orderCard(o)],
      );
    }

    return Column(
      children: [
        _header(all.length),
        const SizedBox(height: 12),
        if (loggedIn && !loading && !error) ...[
          _searchField(),
          const SizedBox(height: 10),
          _segmented(counts),
          const SizedBox(height: 12),
        ],
        Expanded(child: content),
      ],
    );
  }

  // Header: same layout as the Cart screen.
  Widget _header(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (widget.showBack) ...[
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: glassDeco(radius: 14),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 44,
              height: 44,
              decoration: glassDeco(radius: 14),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'My Orders',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppText.subtitle,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.3),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'TRACK & MANAGE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                ),
                child: Text('$count ${count == 1 ? 'order' : 'orders'}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  // Search by order ID or phone name (same input style as the coupon field in Cart).
  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => query = v),
        textInputAction: TextInputAction.search,
        style: const TextStyle(
            fontSize: AppText.small,
            fontWeight: FontWeight.w700,
            color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Search by order ID or phone name',
          hintStyle:
          const TextStyle(color: AppColors.muted, fontSize: AppText.small),
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: checkoutFieldFill,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 19, color: AppColors.muted),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.muted),
            onPressed: () {
              _search.clear();
              setState(() => query = '');
            },
          ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _segmented(List<int> counts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: glassDeco(radius: 18),
        child: Row(
          children: [
            for (int i = 0; i < _segs.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => seg = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: seg == i
                        ? BoxDecoration(
                      gradient: brandGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color:
                            AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    )
                        : null,
                    alignment: Alignment.center,
                    child: Text(
                      '${_segs[i]} (${counts[i]})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: seg == i ? Colors.white : AppColors.muted,
                          fontWeight:
                          seg == i ? FontWeight.w800 : FontWeight.w700,
                          fontSize: AppText.small),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- States ----
  Widget _emptyState({required bool hasOrders}) {
    const msgs = [
      'No ongoing orders',
      'No delivered orders yet',
      'No cancelled orders'
    ];
    final searching = query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Icon(
                  searching
                      ? Icons.search_off_rounded
                      : Icons.receipt_long_outlined,
                  size: 46,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(searching ? 'No matching orders' : msgs[seg],
                style: const TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              searching
                  ? 'Try a different order ID or phone name'
                  : 'Your orders will show up here',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: AppText.small),
            ),
            if (!searching && !hasOrders) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: GradientButton(
                  height: 44,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProductListScreen())),
                  child: const Text('Browse phones',
                      style: TextStyle(fontSize: AppText.small)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Icon(icon, size: 46, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: AppText.small)),
          ],
        ),
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Loading your orders...',
              style:
              TextStyle(color: AppColors.muted, fontSize: AppText.small)),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            const Text('Could not load orders',
                style: TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Check your connection and try again',
                textAlign: TextAlign.center,
                style:
                TextStyle(color: AppColors.muted, fontSize: AppText.small)),
            const SizedBox(height: 16),
            SizedBox(
              width: 140,
              child: GradientButton(
                height: 44,
                onTap: () => setState(_initStream),
                child: const Text('Retry',
                    style: TextStyle(fontSize: AppText.small)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Order card (same structure as the Cart item card) ----
  Widget _orderCard(Order o) {
    // Older or partially migrated order records may not contain item details.
    // Keep the order visible and openable instead of crashing the entire list.
    if (o.items.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: glassDeco(radius: 18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openOrder(o),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    size: 42, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: AppText.body,
                              color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text('Order ID: ${o.id}',
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: AppText.caption)),
                      const SizedBox(height: 4),
                      Text('${rupee(o.total)} • ${o.statusLabel}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: AppText.small)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted),
              ],
            ),
          ),
        ),
      );
    }
    final p = o.items.first.phone;
    // final done = const [1, 1, 2, 3, 4][o.stage < 0 ? 0 : o.stage];
    final c = o.cancelled
        ? AppColors.danger
        : (o.isDelivered ? AppColors.success : AppColors.accent);
    final extra = o.itemCount - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassDeco(radius: 18),
      child: Column(
        children: [
          // Tap area: image + info
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () => _openOrder(o),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                              width: 78,
                              height: 78,
                              child: PhoneImage(
                                  phone: p, height: 78, iconSize: 36))),
                      if (extra > 0)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(14)),
                            ),
                            child: Text('+$extra',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppText.caption,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.body,
                                color: AppColors.text,
                                height: 1.2)),
                        const SizedBox(height: 4),
                        if (o.placedAt != null) ...[
                          const SizedBox(height: 2),
                          Text('Placed on ${_dateText(o.placedAt!)}',
                              style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: AppText.caption,
                                  fontWeight: FontWeight.w600)),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(rupee(o.total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    fontSize: AppText.body)),
                            Text(
                                '${o.itemCount} ${o.itemCount == 1 ? 'item' : 'items'}',
                                style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: AppText.caption,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border:
                            Border.all(color: c.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  o.cancelled
                                      ? Icons.cancel_rounded
                                      : (o.isDelivered
                                      ? Icons.check_circle_rounded
                                      : Icons.local_shipping_rounded),
                                  size: 12,
                                  color: c),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: Text(o.statusLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: c,
                                          fontSize: AppText.caption,
                                          fontWeight: FontWeight.w800))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.muted),
                ],
              ),
            ),
          ),

          // // Progress tracker
          // if (!o.cancelled)
          //   Padding(
          //     padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          //     child: Column(
          //       children: [
          //         Row(
          //           children: [
          //             for (int i = 0; i < _steps.length; i++) ...[
          //               Container(
          //                 width: 18,
          //                 height: 18,
          //                 decoration: BoxDecoration(
          //                   shape: BoxShape.circle,
          //                   color: i < done ? AppColors.primary : _trackOff,
          //                   boxShadow: i < done ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))] : null,
          //                 ),
          //                 child: i < done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
          //               ),
          //               if (i != _steps.length - 1)
          //                 Expanded(child: Container(height: 3, decoration: BoxDecoration(color: i < done - 1 ? AppColors.primary : _trackOff, borderRadius: BorderRadius.circular(2)))),
          //             ],
          //           ],
          //         ),
          //         const SizedBox(height: 6),
          //         Row(
          //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //           children: [
          //             for (final s in _steps) Text(s, style: const TextStyle(fontSize: AppText.caption, color: AppColors.muted, fontWeight: FontWeight.w600)),
          //           ],
          //         ),
          //       ],
          //     ),
          //   ),

          // Action row (same as Cart: Save for later | Remove)
          const Divider(height: 1, thickness: 1, color: _divider),
          // SizedBox(
          //   height: 42,
          //   child: Row(
          //     children: [
          //       // Expanded(
          //       //   child: _action(
          //       //     o.isOngoing ? Icons.local_shipping_outlined : Icons.receipt_long_outlined,
          //       //     o.isOngoing ? 'Track order' : 'View details',
          //       //     AppColors.primary,
          //       //         () => _openOrder(o),
          //       //   ),
          //       // ),
          //       if (!o.isOngoing) ...[
          //         Container(width: 1, height: 22, color: _divider),
          //         Expanded(child: _action(Icons.refresh_rounded, 'Buy again', AppColors.accent, () => _buyAgain(o))),
          //       ],
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _action(
      IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
