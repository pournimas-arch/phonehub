import 'package:flutter/material.dart';
import 'package:phonehub/customer/checkout_ui.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'confirm_details_screen.dart';
import 'saved_addresses.dart';
import 'product_list_screen.dart';
import 'product_detail_screen.dart';
import 'package:phonehub/app_text.dart';

// Same look as Saved Addresses / checkout: shared gradient background, glass
// cards, header tile, bottom bar and gradient buttons all come from checkout_ui.dart.
//
// Text sizes on this screen use the smaller steps of the AppText scale so more
// fits on screen, like Amazon / Flipkart style carts.

const _cardBorder = Color(0xFFDCE8FF);

/// Max units of one item the customer can hold (same rule as changeQty in data.dart).
int _maxQtyFor(Phone p) => p.stock > 0 ? (p.stock < 5 ? p.stock : 5) : 0;

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

/// Screen 5 – Cart & Checkout (3h)
/// Items with qty stepper, save for later, remove with undo, delivery address,
/// free-delivery progress, apply coupon, price details, Proceed to Checkout.
class CartScreen extends StatefulWidget {
  final bool showBack;
  const CartScreen({super.key, this.showBack = true});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _coupon = TextEditingController();
  Coupon? applied;
  String? couponMsg;
  bool couponOk = false;

  @override
  void initState() {
    super.initState();
    // Rebuild when the customer adds / deletes / selects an address.
    savedAddresses.addListener(_refresh);
    defaultAddressId.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// The address that will be used for delivery (the default one).
  SavedAddress? get _address {
    final list = savedAddresses.value;
    for (final a in list) {
      if (a.id == defaultAddressId.value) return a;
    }
    return list.isEmpty ? null : list.first;
  }

  void _apply(int subtotal, int delivery) {
    FocusScope.of(context).unfocus();
    final c = findCoupon(_coupon.text);
    setState(() {
      if (c == null) {
        applied = null;
        couponOk = false;
        couponMsg = 'Invalid coupon code. Please check the code and try again.';
        return;
      }
      final err = couponError(c, subtotal, delivery);
      if (err != null) {
        applied = null;
        couponOk = false;
        couponMsg = err;
        return;
      }
      applied = c;
      couponOk = true;
      couponMsg = 'Coupon applied! You saved ${rupee(couponDiscount(c, subtotal, delivery))}';
    });
  }

  void _removeCoupon() {
    setState(() {
      applied = null;
      couponMsg = null;
      couponOk = false;
      _coupon.clear();
    });
  }

  /// Asks before emptying the whole cart.
  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear cart?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.subtitle, color: AppColors.text)),
        content: const Text('All items will be removed from your cart.', style: TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await clearCart();
      if (mounted) _removeCoupon();
    }
  }

  @override
  void dispose() {
    savedAddresses.removeListener(_refresh);
    defaultAddressId.removeListener(_refresh);
    _coupon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cart,
      builder: (context, items, _) {
        final subtotal = items.fold<int>(0, (s, e) => s + e.phone.price * e.qty);
        // Total MRP (before the store discount) so the customer can see how much they save.
        final mrpTotal = items.fold<int>(0, (s, e) => s + (e.phone.mrp > e.phone.price ? e.phone.mrp : e.phone.price) * e.qty);
        final delivery = items.isEmpty ? 0 : deliveryFor(subtotal);
        // The discount is recalculated on every change (qty, delete) so it can never go stale.
        final appliedErr = applied == null ? null : couponError(applied!, subtotal, delivery);
        final disc = (items.isEmpty || applied == null || appliedErr != null) ? 0 : couponDiscount(applied!, subtotal, delivery);
        final total = subtotal + delivery - disc;
        final mrpDiscount = mrpTotal - subtotal;
        final savings = mrpDiscount + disc;
        final addr = _address;
        final msg = appliedErr ?? couponMsg;
        final msgOk = appliedErr == null && couponOk;
        final count = items.fold<int>(0, (s, e) => s + e.qty);

        return CheckoutBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _header(count),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty ? _emptyState() : _content(items, subtotal, mrpTotal, mrpDiscount, delivery, disc, total, savings, addr, msg, msgOk, count),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: items.isEmpty ? null : _bottomBar(total, savings, subtotal, delivery, disc, addr),
          ),
        );
      },
    );
  }

  // Header in the same style as the Categories screen: glass icon tile (cart icon),
  // title on top with a small subtitle under it, and the item-count pill on the right.
  // The back tile is still shown first when the cart is opened as a pushed screen.
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
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 44,
              height: 44,
              decoration: glassDeco(radius: 14),
              child: const Icon(
                Icons.shopping_cart_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'My Cart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'REVIEW YOUR ITEMS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                ),
                child: Text('$count ${count == 1 ? 'item' : 'items'}', style: const TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              // Clear the whole cart (asks for confirmation first).
              GestureDetector(
                onTap: _confirmClear,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: glassDeco(radius: 12),
                  child: const Icon(Icons.delete_sweep_outlined, size: 19, color: AppColors.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Empty cart ----
  Widget _emptyState() {
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
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.shopping_cart_outlined, size: 46, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text('Your cart is empty', style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Add a phone to get started', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: AppText.small)),
            const SizedBox(height: 18),
            SizedBox(
              width: 180,
              child: GradientButton(
                height: 44,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
                child: const Text('Browse phones', style: TextStyle(fontSize: AppText.small)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Cart content ----
  Widget _content(List<CartItem> items, int subtotal, int mrpTotal, int mrpDiscount, int delivery, int disc, int total, int savings, SavedAddress? addr, String? msg, bool msgOk, int count) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // Free delivery progress (like Amazon / Flipkart "add X more for free delivery")
        _deliveryProgress(subtotal),

        for (final it in items) _CartTile(item: it),
        const SizedBox(height: 2),

        // Delivery address
        _addressCard(addr),
        const SizedBox(height: 14),

        // Coupon
        Container(
          padding: const EdgeInsets.all(14),
          decoration: glassDeco(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Apply Coupon', icon: Icons.local_offer_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coupon,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        filled: true,
                        fillColor: checkoutFieldFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 84,
                    child: GradientButton(
                      height: 44,
                      onTap: () => _apply(subtotal, delivery),
                      child: const Text('Apply', style: TextStyle(fontSize: AppText.small)),
                    ),
                  ),
                ],
              ),
              if (msg != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(msg, style: TextStyle(color: msgOk ? AppColors.success : AppColors.danger, fontSize: AppText.caption, fontWeight: FontWeight.w600))),
                    if (applied != null)
                      GestureDetector(
                        onTap: _removeCoupon,
                        child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in coupons)
                    GestureDetector(
                      onTap: () {
                        _coupon.text = c.code;
                        _apply(subtotal, delivery);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                        ),
                        child: Text(c.code, style: const TextStyle(color: AppColors.accent, fontSize: AppText.caption, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Price details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: glassDeco(radius: 18),
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: _SectionTitle('Price Details')),
              const SizedBox(height: 12),
              _row('Price ($count ${count == 1 ? 'item' : 'items'})', rupee(mrpTotal)),
              if (mrpDiscount > 0) _row('Discount', '- ${rupee(mrpDiscount)}', valueColor: AppColors.success),
              _row('Delivery', delivery == 0 ? 'FREE' : rupee(delivery), valueColor: delivery == 0 ? AppColors.success : null),
              if (disc > 0) _row('Coupon (${applied!.code})', '- ${rupee(disc)}', valueColor: AppColors.success),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE8EFFC))),
              _row('Total Amount', rupee(total), bold: true),
              if (savings > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings_outlined, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('You will save ${rupee(savings)} on this order', style: const TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Trust badges
        _trustRow(),
      ],
    );
  }

  /// "Add ₹X more for FREE delivery" progress card.
  Widget _deliveryProgress(int subtotal) {
    if (deliveryChargeCfg <= 0 || freeDeliveryAboveCfg <= 0) return const SizedBox.shrink();
    final remaining = freeDeliveryAboveCfg - subtotal;
    final unlocked = remaining <= 0;
    final progress = (subtotal / freeDeliveryAboveCfg).clamp(0.0, 1.0).toDouble();
    final color = unlocked ? AppColors.success : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(unlocked ? Icons.check_circle_rounded : Icons.local_shipping_outlined, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  unlocked ? 'Yay! You have unlocked FREE delivery' : 'Add ${rupee(remaining)} more to get FREE delivery',
                  style: TextStyle(color: unlocked ? AppColors.success : AppColors.text, fontSize: AppText.small, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: checkoutFieldFill,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustRow() {
    Widget item(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle, border: Border.all(color: _cardBorder)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w700, height: 1.25)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(Icons.lock_outline_rounded, 'Secure\npayments'),
          item(Icons.verified_outlined, 'Quality\nchecked'),
          item(Icons.local_shipping_outlined, 'Fast\ndelivery'),
        ],
      ),
    );
  }

  // ---- Bottom bar (rounded like the Home nav bar) ----
  Widget _bottomBar(int total, int savings, int subtotal, int delivery, int disc, SavedAddress? addr) {
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
                const Text('Total', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption)),
                Text(rupee(total), style: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w900, color: AppColors.text)),
                if (savings > 0)
                  Text('You save ${rupee(savings)}', style: const TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: GradientButton(
                height: 48,
                onTap: () {
                  // Recheck live cart stock immediately before entering checkout.
                  final currentItems = cart.value;
                  final unavailable = currentItems.where((e) => e.phone.stock <= 0 || e.qty > e.phone.stock).toList();
                  if (unavailable.isNotEmpty) {
                    final names = unavailable.map((e) => e.phone.name).toSet().join(', ');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please update your cart. Out of stock or insufficient stock: $names')),
                    );
                    return;
                  }
                  if (addr == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a delivery address to continue')));
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen()));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConfirmDetailsScreen(address: addr, couponCode: disc > 0 ? applied!.code : null),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Proceed to Checkout', style: TextStyle(fontSize: AppText.small)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(SavedAddress? a) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glassDeco(radius: 18),
      child: Row(
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
                const Text('Deliver to', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (a == null)
                  const Text('No address added yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.small, color: AppColors.danger))
                else ...[
                  Text(a.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text('${a.line} - ${a.pincode}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, height: 1.35)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 13, color: AppColors.success),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text('Delivery by ${deliveryDateText(3)}', style: const TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(a == null ? 'Add' : 'Change', style: const TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
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
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  const _CartTile({required this.item});

  void _openProduct(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: item.phone)));
  }

  /// Remove from cart and offer an Undo (puts the same item + quantity back).
  void _remove(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final p = item.phone;
    final storage = item.storage;
    final condition = item.condition;
    final qty = item.qty;
    removeItem(item);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${p.name} removed from cart'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              addToCart(p, storage, condition);
              for (final e in cart.value) {
                if (e.phone.id == p.id && e.storage == storage && e.condition == condition && e.qty < qty) {
                  changeQty(e, qty - e.qty);
                  break;
                }
              }
            },
          ),
        ),
      );
  }

  /// Move to the wishlist and take it out of the cart.
  void _saveForLater(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final p = item.phone;
    if (!wishlist.value.contains(p.id)) toggleWish(p.id);
    removeItem(item);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('${p.name} moved to your wishlist')));
  }

  @override
  Widget build(BuildContext context) {
    final p = item.phone;
    final maxQty = _maxQtyFor(p);
    final lowStock = p.stock > 0 && p.stock <= 5;
    final outOfStock = p.stock == 0;
    final mrp = p.mrp > p.price ? p.mrp : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassDeco(radius: 18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with discount badge
                GestureDetector(
                  onTap: () => _openProduct(context),
                  child: Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 78, height: 78, child: PhoneImage(phone: p, height: 78, iconSize: 36))),
                      if (p.off > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(14), bottomRight: Radius.circular(10)),
                            ),
                            child: Text('${p.off}% OFF', style: const TextStyle(color: Colors.white, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _openProduct(context),
                        child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text, height: 1.2)),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConditionChip(item.condition),
                          Text(item.storage, style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                          if (p.battery > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.battery_charging_full_rounded, size: 13, color: AppColors.success),
                                const SizedBox(width: 2),
                                Text('${p.battery}%', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Price row: selling price, MRP struck through, % off
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          Text(rupee(p.price * item.qty), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: AppText.body)),
                          if (mrp > 0)
                            Text(rupee(mrp * item.qty), style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: AppText.caption)),
                          if (p.off > 0)
                            Text('${p.off}% off', style: const TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Delivery estimate + stock info + qty stepper
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 13, color: AppColors.muted),
                          const SizedBox(width: 5),
                          Flexible(child: Text('Delivery by ${deliveryDateText(3)}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      if (outOfStock || lowStock) ...[
                        const SizedBox(height: 3),
                        Text(outOfStock ? 'Out of stock' : 'Only ${p.stock} left', style: const TextStyle(color: AppColors.danger, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stepBtn(Icons.remove_rounded, p.stock > 0 && item.qty > 1 ? () => changeQty(item, -1) : null),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text, fontSize: AppText.small)),
                      ),
                      _stepBtn(Icons.add_rounded, p.stock > 0 && item.qty < maxQty ? () => changeQty(item, 1) : null),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action row: Save for later | Remove
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8EFFC)),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(child: _action(Icons.favorite_border_rounded, 'Save for later', AppColors.primary, () => _saveForLater(context))),
                Container(width: 1, height: 22, color: const Color(0xFFE8EFFC)),
                Expanded(child: _action(Icons.delete_outline_rounded, 'Remove', AppColors.danger, () => _remove(context))),
              ],
            ),
          ),
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

  Widget _stepBtn(IconData i, VoidCallback? onTap) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(6), child: Icon(i, size: 17, color: onTap == null ? AppColors.muted.withValues(alpha: 0.5) : AppColors.primary)),
  );
}