import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'confirm_details_screen.dart';
import 'saved_addresses.dart';

// ---------- Shared styling (same as Home screen) ----------

BoxDecoration _glass({double radius = 18}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFFDCE8FF)),
  boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
);

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF4F8FF), Color(0xFFBBD5FB), Color(0xFF7FADEE)],
);

const _fieldFill = Color(0xFFEAF1FF);

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob(this.size, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle(this.title, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (icon != null) Icon(icon, color: AppColors.accent, size: 20),
    ],
  );
}

/// Screen 5 – Cart & Checkout (3h)
/// Items with qty stepper and delete, delivery address, apply coupon, price details, Proceed to Checkout.
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
        final delivery = items.isEmpty || subtotal >= 10000 ? 0 : 99;
        // The discount is recalculated on every change (qty, delete) so it can never go stale.
        final appliedErr = applied == null ? null : couponError(applied!, subtotal, delivery);
        final disc = (items.isEmpty || applied == null || appliedErr != null) ? 0 : couponDiscount(applied!, subtotal, delivery);
        final total = subtotal + delivery - disc;
        final addr = _address;
        final msg = appliedErr ?? couponMsg;
        final msgOk = appliedErr == null && couponOk;
        final count = items.fold<int>(0, (s, e) => s + e.qty);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Container(
            decoration: const BoxDecoration(gradient: _bgGradient),
            child: Stack(
              children: [
                Positioned(top: -70, right: -80, child: _Blob(240, 0.35)),
                Positioned(top: 420, left: -120, child: _Blob(280, 0.20)),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    centerTitle: false,
                    titleSpacing: widget.showBack ? 0 : 20,
                    leadingWidth: widget.showBack ? 64 : 0,
                    leading: widget.showBack
                        ? Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          decoration: _glass(radius: 14),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.text),
                        ),
                      ),
                    )
                        : const SizedBox.shrink(),
                    title: Row(
                      children: [
                        const Text('My Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.text, letterSpacing: -0.3)),
                        if (items.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20)),
                            child: Text('$count ${count == 1 ? 'item' : 'items'}', style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  body: items.isEmpty ? _emptyState() : _content(items, subtotal, delivery, disc, total, addr, msg, msgOk, count),
                  bottomNavigationBar: items.isEmpty ? null : _bottomBar(total, subtotal, delivery, disc, addr),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Empty cart ----
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDCE8FF), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 54, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('Add a phone to get started', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  // ---- Cart content ----
  Widget _content(List<CartItem> items, int subtotal, int delivery, int disc, int total, SavedAddress? addr, String? msg, bool msgOk, int count) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (final it in items) _CartTile(item: it),
        const SizedBox(height: 4),

        // Delivery address
        _addressCard(addr),
        const SizedBox(height: 16),

        // Coupon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _glass(radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Apply Coupon', icon: Icons.local_offer_rounded),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _coupon,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        filled: true,
                        fillColor: _fieldFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(90, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => _apply(subtotal, delivery),
                      child: const Text('Apply', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
              if (msg != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(msg, style: TextStyle(color: msgOk ? AppColors.success : AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600))),
                    if (applied != null)
                      GestureDetector(
                        onTap: _removeCoupon,
                        child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
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
                        child: Text(c.code, style: const TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Price details
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _glass(radius: 22),
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: _SectionTitle('Price Details')),
              const SizedBox(height: 14),
              _row('Items ($count)', rupee(subtotal)),
              _row('Delivery', delivery == 0 ? 'FREE' : rupee(delivery), valueColor: delivery == 0 ? AppColors.success : null),
              if (disc > 0) _row('Coupon (${applied!.code})', '- ${rupee(disc)}', valueColor: AppColors.success),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFE8EFFC))),
              _row('Total', rupee(total), bold: true),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Bottom bar (rounded like the Home nav bar) ----
  Widget _bottomBar(int total, int subtotal, int delivery, int disc, SavedAddress? addr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: const Color(0xFF1B2A5C).withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                Text(rupee(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text)),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Tap(
                onTap: () {
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
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: brandGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Proceed to Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
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
      padding: const EdgeInsets.all(14),
      decoration: _glass(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deliver to', style: TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (a == null)
                  const Text('No address added yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.danger))
                else ...[
                  Text(a.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text('${a.line} - ${a.pincode}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(a == null ? 'Add' : 'Change', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false, Color? valueColor}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 17 : 14.5, color: bold ? AppColors.text : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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

  @override
  Widget build(BuildContext context) {
    final p = item.phone;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: _glass(radius: 22),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 86, height: 86, child: PhoneImage(phone: p, height: 86, iconSize: 40))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.text))),
                    GestureDetector(
                      onTap: () => removeItem(item),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${item.storage} • ${item.condition}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(rupee(p.price * item.qty), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 16)),
                    Container(
                      decoration: BoxDecoration(color: _fieldFill, borderRadius: BorderRadius.circular(12)),
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
}