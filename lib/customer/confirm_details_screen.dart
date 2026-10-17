import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';
import 'checkout_ui.dart';
import 'saved_addresses.dart';
import 'payment_screen.dart';
import 'package:phonehub/app_text.dart';

/// Step 2 of 3 – Confirm details.
/// Delivering-to card, items with quantity, coupon, price details and Continue.
class ConfirmDetailsScreen extends StatefulWidget {
  final SavedAddress address;
  final String? couponCode;
  const ConfirmDetailsScreen({super.key, required this.address, this.couponCode});

  @override
  State<ConfirmDetailsScreen> createState() => _ConfirmDetailsScreenState();
}

class _ConfirmDetailsScreenState extends State<ConfirmDetailsScreen> {
  final _coupon = TextEditingController();
  Coupon? applied;
  String? couponMsg;
  bool couponOk = false;


  @override
  void initState() {
    super.initState();
    final code = widget.couponCode;
    if (code != null) {
      applied = findCoupon(code);
      couponOk = applied != null;
      _coupon.text = code.toUpperCase();
    }
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  void _apply(int subtotal, int delivery) {
    FocusScope.of(context).unfocus();
    if (_coupon.text.trim().isEmpty) {
      setState(() {
        applied = null;
        couponOk = false;
        couponMsg = 'Enter a coupon code or choose one of the available offers.';
      });
      return;
    }
    final c = findCoupon(_coupon.text.trim().toUpperCase());
    setState(() {
      if (c == null) {
        applied = null;
        couponOk = false;
        couponMsg = 'Invalid or unavailable coupon code. Please check the code and try again.';
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cart,
      builder: (context, items, _) {
        final mrpTotal = items.fold<int>(0, (s, e) => s + e.phone.mrp * e.qty);
        final subtotal = items.fold<int>(0, (s, e) => s + e.phone.price * e.qty);
        final delivery = items.isEmpty || subtotal >= 10000 ? 0 : 99;
        // Recalculated on every change so the coupon can never go stale.
        final appliedErr = applied == null ? null : couponError(applied!, subtotal, delivery);
        final disc = (items.isEmpty || applied == null || appliedErr != null) ? 0 : couponDiscount(applied!, subtotal, delivery);
        final total = subtotal + delivery - disc;
        final mrpOff = mrpTotal - subtotal;
        final saved = mrpOff + disc;
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
                  const CheckoutHeader(title: 'Confirm details', step: 'Step 2 of 3'),
                  const CheckoutStepper(current: 1),
                  Expanded(
                    child: items.isEmpty
                        ? _empty()
                        : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        const CheckoutSectionTitle('Delivering to'),
                        const SizedBox(height: 12),
                        _addressCard(delivery),
                        const SizedBox(height: 14),
                        FreeDeliveryBar(subtotal: subtotal),
                        const SizedBox(height: 22),
                        CheckoutSectionTitle('Your items ($count)'),
                        const SizedBox(height: 12),
                        for (final it in items) _itemCard(it),
                        const SizedBox(height: 6),
                        _couponCard(subtotal, delivery, msg, msgOk),
                        const SizedBox(height: 22),
                        const CheckoutSectionTitle('Price Details'),
                        const SizedBox(height: 4),
                        const Text('Updated automatically when you change quantities or offers.', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption)),
                        const SizedBox(height: 10),
                        _priceCard(count, mrpTotal, mrpOff, delivery, disc, total, saved),
                        const SizedBox(height: 16),
                        const TrustBadgesRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: items.isEmpty ? null : _bottomBar(mrpTotal, total, saved, subtotal, delivery, disc),
          ),
        );
      },
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDCE8FF), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text('Your cart is empty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text)),
          const SizedBox(height: 14),
          SizedBox(width: 180, child: GradientButton(onTap: () => Navigator.maybePop(context), child: const Text('Go back'))),
        ],
      ),
    );
  }

  // ---- Delivering to ----
  Widget _addressCard(int delivery) {
    final a = widget.address;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: glassDeco(radius: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(a.label == 'Work' ? Icons.work_outline_rounded : (a.label == 'Other' ? Icons.place_outlined : Icons.home_outlined), color: AppColors.primary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                        child: Text(a.label, style: const TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 8),
                      Text('${a.line} - ${a.pincode}', style: const TextStyle(color: AppColors.text, fontSize: AppText.small, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: AppText.small, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: AppColors.success.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_rounded, size: 17, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text('Delivery by ${deliveryDateText(3)}', style: const TextStyle(color: AppColors.text, fontSize: AppText.caption, fontWeight: FontWeight.w800))),
                Text(delivery == 0 ? 'FREE' : rupee(delivery), style: TextStyle(color: delivery == 0 ? AppColors.success : AppColors.text, fontSize: AppText.caption, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Item card ----
  Widget _perk(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ],
    ),
  );

  Widget _itemCard(CartItem item) {
    final p = item.phone;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: glassDeco(radius: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 82, height: 94, child: PhoneImage(phone: p, height: 94, iconSize: 36))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(p.brand.toUpperCase(), style: const TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8))),
                          GestureDetector(
                            onTap: () => removeItem(item),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 17),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text, height: 1.2)),
                      const SizedBox(height: 3),
                      Text('${item.storage} • ${item.condition}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption)),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${p.rating}', style: const TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w800, color: Colors.white)),
                                const SizedBox(width: 2),
                                const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.verified_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                          const Flexible(child: Text('PhoneHub Assured', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 7,
                        children: [
                          Text(rupee(p.price), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.text, fontSize: AppText.body)),
                          Text(rupee(p.mrp), style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: AppText.caption)),
                          Text('↓${p.off}% off', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: AppText.caption)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('Item total: ${rupee(p.price * item.qty)}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: checkoutLine),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _perk(Icons.replay_rounded, '7-day return'),
                      _perk(Icons.shield_outlined, '6-month warranty'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: checkoutFieldFill, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      _stepBtn(Icons.remove_rounded, () => changeQty(item, -1)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text))),
                      _stepBtn(Icons.add_rounded, () => changeQty(item, 1)),
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

  Widget _stepBtn(IconData i, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(7), child: Icon(i, size: 18, color: AppColors.primary)),
  );

  // ---- Coupon ----
  Widget _couponCard(int subtotal, int delivery, String? msg, bool msgOk) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassDeco(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_offer_rounded, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text('Offers & Coupons', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _coupon,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    filled: true,
                    fillColor: checkoutFieldFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: GradientButton(height: 48, onTap: () => _apply(subtotal, delivery), child: const Text('Apply', style: TextStyle(fontSize: AppText.small)))),
            ],
          ),
          if (msg != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(msg, style: TextStyle(color: msgOk ? AppColors.success : AppColors.danger, fontSize: AppText.small, fontWeight: FontWeight.w600))),
                if (applied != null)
                  GestureDetector(
                    onTap: _removeCoupon,
                    child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 0,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: coupons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = coupons[i];
                final on = applied?.code == c.code;
                return GestureDetector(
                  onTap: () {
                    _coupon.text = c.code;
                    _apply(subtotal, delivery);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: on ? AppColors.success.withValues(alpha: 0.10) : AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: (on ? AppColors.success : AppColors.accent).withValues(alpha: 0.45), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(on ? Icons.check_circle_rounded : Icons.local_offer_rounded, size: 18, color: on ? AppColors.success : AppColors.accent),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.code, style: TextStyle(color: on ? AppColors.success : AppColors.accent, fontSize: AppText.caption, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                            Text(on ? 'Applied' : 'Tap to apply', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Price details ----
  Widget _priceCard(int count, int mrpTotal, int mrpOff, int delivery, int disc, int total, int saved) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: glassDeco(radius: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              children: [
                _row('MRP (incl. of all taxes) · $count', rupee(mrpTotal)),
                _row('Discount on MRP', '- ${rupee(mrpOff)}', valueColor: AppColors.success),
                _row('Delivery', delivery == 0 ? 'FREE' : rupee(delivery), valueColor: delivery == 0 ? AppColors.success : null),
                if (disc > 0) _row('Coupon (${applied!.code})', '- ${rupee(disc)}', valueColor: AppColors.success),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: checkoutLine)),
                _row('Total Amount', rupee(total), bold: true),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.success.withValues(alpha: 0.10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.savings_rounded, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text("You'll Save ${rupee(saved)} on this order", style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: AppText.small)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false, Color? valueColor}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? AppText.body : AppText.small, color: bold ? AppColors.text : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(l, style: style)),
          Text(v, style: style.copyWith(color: valueColor ?? (bold ? AppColors.primary : AppColors.text))),
        ],
      ),
    );
  }

  // ---- Bottom bar ----
  Widget _bottomBar(int mrpTotal, int total, int saved, int subtotal, int delivery, int disc) {
    return Container(
      decoration: checkoutBottomBarDeco(),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saved > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: AppColors.success.withValues(alpha: 0.10),
                alignment: Alignment.center,
                child: Text("You'll save ${rupee(saved)} on this order", style: const TextStyle(color: AppColors.success, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mrpTotal > total) Text(rupee(mrpTotal), style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: AppText.small)),
                      Text(rupee(total), style: const TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w900, color: AppColors.text)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: GradientButton(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(
                            total: total,
                            subtotal: subtotal,
                            delivery: delivery,
                            discount: disc,
                            couponCode: disc > 0 ? applied!.code : null,
                            address: widget.address,
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Text('Continue'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}