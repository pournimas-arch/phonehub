import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';
import 'checkout_ui.dart';
import 'saved_addresses.dart';
import 'order_tracking_screen.dart';

/// Step 3 of 3 – Payments
/// Collapsible total, UPI (GPay/PhonePe/Paytm), Debit/Credit Card, Net Banking, Wallet,
/// Cash on Delivery, secure-payment note, Pay button. Every method is validated, and a
/// successful payment creates a real order that shows up in the Orders tab.
class PaymentScreen extends StatefulWidget {
  final int total, subtotal, delivery, discount;
  final String? couponCode;
  final SavedAddress address;
  const PaymentScreen({
    super.key,
    required this.total,
    required this.subtotal,
    required this.delivery,
    required this.discount,
    required this.address,
    this.couponCode,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNo = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  int method = 0;
  int upiApp = 0;
  int? bank;
  int? wallet;
  String? pickError;
  bool showSummary = false;

  static const methods = [
    (Icons.qr_code_2_rounded, 'UPI', 'Pay by any UPI app'),
    (Icons.credit_card_rounded, 'Credit / Debit / ATM Card', 'Visa, Mastercard, RuPay'),
    (Icons.account_balance_rounded, 'Net Banking', 'All major banks supported'),
    (Icons.account_balance_wallet_rounded, 'Wallet', 'Paytm, Amazon Pay & more'),
    (Icons.payments_outlined, 'Cash on Delivery', 'Pay when your order arrives'),
  ];
  static const upiApps = [('Google Pay', Color(0xFF1A73E8)), ('PhonePe', Color(0xFF5F259F)), ('Paytm', Color(0xFF00B9F1))];
  static const banks = ['SBI', 'HDFC Bank', 'ICICI Bank', 'Axis Bank', 'Kotak', 'Bank of Maharashtra'];
  static const wallets = ['Paytm', 'Amazon Pay', 'PhonePe', 'Mobikwik'];

  @override
  void initState() {
    super.initState();
    _cardNo.addListener(_refresh);
    _expiry.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cardNo.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  String get _methodLabel {
    switch (method) {
      case 0:
        return 'UPI (${upiApps[upiApp].$1})';
      case 1:
        return 'Debit / Credit Card';
      case 2:
        return 'Net Banking - ${banks[bank ?? 0]}';
      case 3:
        return 'Wallet - ${wallets[wallet ?? 0]}';
      default:
        return 'Cash on Delivery';
    }
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    // Only the fields of the open method are on screen, so validate() checks just those.
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (method == 2 && bank == null) {
      setState(() => pickError = 'Please select your bank');
      return;
    }
    if (method == 3 && wallet == null) {
      setState(() => pickError = 'Please select a wallet');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before placing an order.')),
      );
      return;
    }
    if (cart.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty. Add a phone before checkout.')),
      );
      return;
    }

    setState(() => pickError = null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final now = DateTime.now();
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final order = Order(
        id: orderRef.id,
        items: cart.value.map((e) => CartItem(e.phone, e.storage, e.condition, qty: e.qty)).toList(),
        subtotal: widget.subtotal,
        delivery: widget.delivery,
        discount: widget.discount,
        total: widget.total,
        couponCode: widget.couponCode,
        paymentMethod: _methodLabel,
        addressLabel: widget.address.label,
        addressLine: '${widget.address.line} - ${widget.address.pincode}',
        placedAt: now,
        firestoreStatus: 'Order Placed',
      );

      await orderRef.set(order.toFirestoreMap(user.uid));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      orders.value = [order, ...orders.value];
      cart.value = [];
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order, fromPayment: true)),
            (r) => false,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e.code == 'permission-denied'
          ? 'Order could not be saved. Check Firestore Rules.'
          : 'Order could not be placed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order could not be placed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              CheckoutHeader(
                title: 'Payments',
                step: 'Step 3 of 3',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: glassDeco(radius: 12),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('100% Secure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.success)),
                    ],
                  ),
                ),
              ),
              const CheckoutStepper(current: 2),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _totalCard(),
                      const SizedBox(height: 14),
                      // Delivery address summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: glassDeco(radius: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Deliver to ${widget.address.label}: ${widget.address.line} - ${widget.address.pincode}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.local_shipping_rounded, size: 15, color: AppColors.success),
                                      const SizedBox(width: 6),
                                      Text('Delivery by ${deliveryDateText(3)}', style: const TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const CheckoutSectionTitle('Choose payment method'),
                      const SizedBox(height: 14),
                      for (int i = 0; i < methods.length; i++) _methodTile(i),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: AppColors.success, size: 20),
                            SizedBox(width: 10),
                            Expanded(child: Text('100% secure payments. Your card and bank details are encrypted and never stored.', style: TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const TrustBadgesRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: checkoutBottomBarDeco(),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    Text(rupee(widget.total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.text)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GradientButton(
                    onTap: _pay,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(method == 4 ? Icons.check_circle_outline_rounded : Icons.lock_rounded),
                        const SizedBox(width: 8),
                        Text(method == 4 ? 'Place Order' : 'Pay ${rupee(widget.total)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Collapsible "Total Amount" card ----
  Widget _totalCard() {
    return GestureDetector(
      onTap: () => setState(() => showSummary = !showSummary),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE6EEFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE8FF)),
            boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Total Amount', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(width: 4),
                  Icon(showSummary ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  const Spacer(),
                  Text(rupee(widget.total), style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              if (showSummary) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFCFDCF7)),
                const SizedBox(height: 8),
                _sumRow('Items', rupee(widget.subtotal)),
                _sumRow('Delivery', widget.delivery == 0 ? 'FREE' : rupee(widget.delivery), color: widget.delivery == 0 ? AppColors.success : null),
                if (widget.discount > 0) _sumRow('Coupon (${widget.couponCode})', '- ${rupee(widget.discount)}', color: AppColors.success),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumRow(String l, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(v, style: TextStyle(color: color ?? AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  // ---- Payment method accordion tile ----
  Widget _methodTile(int i) {
    final m = methods[i];
    final on = method == i;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassDeco(radius: 20, borderColor: on ? AppColors.primary : null, borderWidth: on ? 1.6 : 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              method = i;
              pickError = null;
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(m.$1, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text))),
                            if (i == 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                                child: const Text('FASTEST', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(m.$3, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Icon(on ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: on ? AppColors.primary : AppColors.muted),
                ],
              ),
            ),
          ),
          if (on)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _methodBody(i),
            ),
        ],
      ),
    );
  }

  Widget _methodBody(int i) {
    switch (i) {
      case 0:
        return Container(
          decoration: BoxDecoration(color: const Color(0xFFF4F8FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE3ECFB))),
          child: Column(
            children: [
              for (int k = 0; k < upiApps.length; k++) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => upiApp = k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Icon(upiApp == k ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: upiApp == k ? AppColors.primary : AppColors.muted, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(upiApps[k].$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text))),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: upiApps[k].$2.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Text(upiApps[k].$1[0], style: TextStyle(fontWeight: FontWeight.w900, color: upiApps[k].$2, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
                if (k != upiApps.length - 1) const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFE3ECFB)),
              ],
            ],
          ),
        );
      case 1:
        return Column(
          children: [
            _cardPreview(),
            const SizedBox(height: 14),
            _field(
              'Card number',
              Icons.credit_card_rounded,
              _cardNo,
              formatter: _CardNumberFormatter(),
              validator: (v) => (v ?? '').replaceAll(' ', '').length != 16 ? 'Enter a valid 16-digit card number' : null,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field('MM / YY', Icons.calendar_today_rounded, _expiry, formatter: _ExpiryFormatter(), validator: _validateExpiry)),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    'CVV',
                    Icons.lock_outline_rounded,
                    _cvv,
                    obscure: true,
                    formatter: LengthLimitingTextInputFormatter(3),
                    validator: (v) => (v ?? '').length != 3 ? 'Enter 3-digit CVV' : null,
                  ),
                ),
              ],
            ),
          ],
        );
      case 2:
        return _bankGrid();
      case 3:
        return _chips(wallets, wallet, (k) => wallet = k);
      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF4F8FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE3ECFB))),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(child: Text('Pay in cash when your order is delivered. Please keep the exact amount ready.', style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4))),
            ],
          ),
        );
    }
  }

  /// Live preview of the card while the customer types.
  Widget _cardPreview() {
    final digits = _cardNo.text.replaceAll(' ', '');
    final shown = List.generate(16, (i) => i < digits.length ? digits[i] : '•');
    final number = [for (int g = 0; g < 4; g++) shown.sublist(g * 4, g * 4 + 4).join()].join('  ');
    final exp = _expiry.text.isEmpty ? 'MM/YY' : _expiry.text;
    return Container(
      width: double.infinity,
      height: 172,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -40, top: -50, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withValues(alpha: 0.08))),
          Positioned(left: -30, bottom: -60, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.06))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(color: const Color(0xFFFFD86B), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.memory_rounded, size: 18, color: Color(0xFF9A6B00)),
                  ),
                  const Spacer(),
                  const Text('CREDIT / DEBIT', style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
              const Spacer(),
              Text(number, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('PHONEHUB CUSTOMER', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8))),
                  Text(exp, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bank picker as a grid of tiles with the bank initial.
  Widget _bankGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular banks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            for (int k = 0; k < banks.length; k++)
              GestureDetector(
                onTap: () => setState(() {
                  bank = k;
                  pickError = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bank == k ? AppColors.primary.withValues(alpha: 0.10) : checkoutFieldFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: bank == k ? AppColors.primary : Colors.transparent, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Text(banks[k][0], style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 15)),
                      ),
                      const SizedBox(height: 6),
                      Text(banks[k], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: bank == k ? AppColors.primary : AppColors.text, height: 1.15)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (pickError != null) ...[
          const SizedBox(height: 8),
          Text(pickError!, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  /// Wrap of selectable chips used for the wallet list.
  Widget _chips(List<String> items, int? selected, void Function(int) onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int k = 0; k < items.length; k++)
              GestureDetector(
                onTap: () => setState(() {
                  onPick(k);
                  pickError = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == k ? AppColors.primary.withValues(alpha: 0.12) : checkoutFieldFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected == k ? AppColors.primary : Colors.transparent, width: 1.4),
                  ),
                  child: Text(items[k], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: selected == k ? AppColors.primary : AppColors.text)),
                ),
              ),
          ],
        ),
        if (pickError != null) ...[
          const SizedBox(height: 8),
          Text(pickError!, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  String? _validateExpiry(String? v) {
    final t = (v ?? '').trim();
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(t);
    if (m == null) return 'Use MM/YY';
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) return 'Card expired';
    return null;
  }

  Widget _field(
      String hint,
      IconData icon,
      TextEditingController c, {
        required String? Function(String?) validator,
        TextInputFormatter? formatter,
        bool obscure = false,
      }) =>
      TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: TextInputType.number,
        validator: validator,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, if (formatter != null) formatter],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          isDense: true,
          prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
          filled: true,
          fillColor: checkoutFieldFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );
}

/// Groups the card number as 1234 5678 9012 3456.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(d[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Turns 1229 into 12/29.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 4 ? digits.substring(0, 4) : digits;
    final s = d.length >= 3 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}