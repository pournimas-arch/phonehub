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
import 'package:phonehub/app_text.dart';

/// Step 3 of 3 – Payment selection and order placement.
/// Uses the existing PhoneHub checkout models and Firestore order flow.
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
  bool _isPlacingOrder = false;

  static const methods = [
    (Icons.qr_code_2_rounded, 'UPI', 'Pay by any UPI app'),
    (Icons.credit_card_rounded, 'Credit / Debit / ATM Card', 'Visa, Mastercard, RuPay'),
    (Icons.account_balance_rounded, 'Net Banking', 'All major banks supported'),
    (Icons.account_balance_wallet_rounded, 'Wallet', 'Paytm, Amazon Pay & more'),
    (Icons.payments_outlined, 'Cash on Delivery', 'Pay when your order arrives'),
  ];
  static const upiApps = [
    ('Google Pay', Color(0xFF1A73E8)),
    ('PhonePe', Color(0xFF5F259F)),
    ('Paytm', Color(0xFF00B9F1)),
  ];
  static const banks = [
    'SBI',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Kotak',
    'Bank of Maharashtra',
  ];
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
    _cardNo.removeListener(_refresh);
    _expiry.removeListener(_refresh);
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
    if (_isPlacingOrder) return;
    FocusScope.of(context).unfocus();

    if (method == 1 && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (method == 2 && bank == null) {
      setState(() => pickError = 'Please select your bank.');
      return;
    }
    if (method == 3 && wallet == null) {
      setState(() => pickError = 'Please select a wallet.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before placing an order.')),
      );
      return;
    }
    // Take one snapshot so the order items cannot drift if the cart changes
    // while Firestore is processing the checkout.
    final cartSnapshot = cart.value.toList(growable: false);
    if (cartSnapshot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty. Add a phone before checkout.')),
      );
      return;
    }

    // Fail fast on inconsistent checkout totals before opening the loader.
    if (widget.subtotal < 0 ||
        widget.delivery < 0 ||
        widget.discount < 0 ||
        widget.discount > widget.subtotal + widget.delivery ||
        widget.total != widget.subtotal + widget.delivery - widget.discount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The order total is invalid. Please review your cart and try again.')),
      );
      return;
    }

    // Blocked customers cannot order (the admin blocked this account).
    if (customerBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account is currently blocked. Please contact PhoneHub support.')),
      );
      return;
    }
    // Only deliver to pincodes the admin serves (no restriction if the admin set none).
    if (!isPincodeServiceable(widget.address.pincode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sorry, we do not deliver to pincode ${widget.address.pincode} yet. Please choose another address.')),
      );
      return;
    }

    setState(() {
      pickError = null;
      _isPlacingOrder = true;
    });

    var loadingShown = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
      loadingShown = true;

      final now = DateTime.now();
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final order = Order(
        id: orderRef.id,
        items: cartSnapshot
            .map((e) => CartItem(e.phone, e.storage, e.condition, qty: e.qty))
            .toList(growable: false),
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

      // Saves the order AND reduces the stock in one transaction, creates the
      // delivery OTP and records the coupon use.
      await placeOrderWithStock(orderRef, order, user.uid);
      // Clears the cart on screen AND the saved copy, so it does not come back after a restart.
      await clearCart();
      if (!mounted) return;

      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      orders.value = [order, ...orders.value];
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(order: order, fromPayment: true),
        ),
            (route) => false,
      );
    } on StateError catch (e) {
      // Friendly reasons from placeOrderWithStock: sold out, coupon used, phone number missing...
      if (!mounted) return;
      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final message = e.code == 'permission-denied'
          ? 'Order could not be saved. Please check your Firestore Rules.'
          : 'Order could not be placed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order could not be placed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
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
                      Icon(Icons.lock_outline_rounded,
                          size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Secure checkout',
                        style: TextStyle(
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const CheckoutStepper(current: 2),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                    children: [
                      _totalCard(),
                      const SizedBox(height: 14),
                      _addressCard(),
                      const SizedBox(height: 23),
                      _sectionHeading('Choose payment method',
                          subtitle: 'Select how you would like to pay',
                          icon: Icons.payments_outlined),
                      const SizedBox(height: 13),
                      for (int i = 0; i < methods.length; i++) _methodTile(i),
                      if (pickError != null && method >= 2) ...[
                        const SizedBox(height: 2),
                        _errorMessage(pickError!),
                      ],
                      const SizedBox(height: 5),
                      _secureNote(),
                      const SizedBox(height: 16),
                      const TrustBadgesRow(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  Widget _sectionHeading(
      String title, {
        required IconData icon,
        String? subtitle,
      }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFDCE8FF)),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                color: AppColors.text,
                fontSize: AppText.body,
                fontWeight: FontWeight.w900,
              )),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: AppText.caption,
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _addressCard() {
    final address = widget.address;
    final icon = address.label == 'Work'
        ? Icons.work_outline_rounded
        : address.label == 'Other'
        ? Icons.place_outlined
        : Icons.home_outlined;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: glassDeco(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEAF2FF), Color(0xFFD7E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivering to ${address.label}',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: AppText.small,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 5),
                Text(
                  '${address.line} - ${address.pincode}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: AppText.caption,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded,
                        size: 15, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Estimated delivery by ${deliveryDateText(3)}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w800,
                          )),
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
            gradient: const LinearGradient(
              colors: [Color(0xFFF9FBFF), Color(0xFFE5EEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFDCE8FF)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.09),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Total amount',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: AppText.body,
                        )),
                  ),
                  Text(rupee(widget.total),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(width: 3),
                  Icon(
                    showSummary
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
              if (showSummary) ...[
                const SizedBox(height: 13),
                const Divider(height: 1, color: Color(0xFFCFDCF7)),
                const SizedBox(height: 9),
                _sumRow('Items subtotal', rupee(widget.subtotal)),
                _sumRow(
                  'Delivery',
                  widget.delivery == 0 ? 'FREE' : rupee(widget.delivery),
                  color: widget.delivery == 0 ? AppColors.success : null,
                ),
                if (widget.discount > 0)
                  _sumRow(
                    'Coupon (${widget.couponCode ?? 'Offer'})',
                    '- ${rupee(widget.discount)}',
                    color: AppColors.success,
                  ),
                const Divider(height: 15, color: Color(0xFFCFDCF7)),
                _sumRow('Payable total', rupee(widget.total),
                    color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: AppText.small,
                fontWeight: FontWeight.w600,
              )),
        ),
        Text(value,
            style: TextStyle(
              color: color ?? AppColors.text,
              fontSize: AppText.small,
              fontWeight: FontWeight.w800,
            )),
      ],
    ),
  );

  Widget _methodTile(int index) {
    final item = methods[index];
    final selected = method == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 11),
      decoration: glassDeco(
        radius: 20,
        borderColor: selected ? AppColors.primary : null,
        borderWidth: selected ? 1.5 : 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() {
              method = index;
              pickError = null;
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                        colors: [Color(0xFFEAF2FF), Color(0xFFD7E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : null,
                      color: selected
                          ? null
                          : AppColors.primary.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.$1, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(item.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: AppText.small,
                                  color: AppColors.text,
                                )),
                            if (index == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('QUICK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    )),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(item.$3,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: AppText.caption,
                              height: 1.25,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? AppColors.primary : AppColors.muted,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 15),
              child: _methodBody(index),
            ),
        ],
      ),
    );
  }

  Widget _methodBody(int index) {
    switch (index) {
      case 0:
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3ECFB)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < upiApps.length; i++) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => setState(() => upiApp = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          upiApp == i
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: upiApp == i
                              ? AppColors.primary
                              : AppColors.muted,
                          size: 21,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(upiApps[i].$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.small,
                                color: AppColors.text,
                              )),
                        ),
                        _upiLogo(i),
                      ],
                    ),
                  ),
                ),
                if (i != upiApps.length - 1)
                  const Divider(
                      height: 1,
                      indent: 12,
                      endIndent: 12,
                      color: Color(0xFFE3ECFB)),
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
              validator: (value) {
                final digits = (value ?? '').replaceAll(' ', '');
                if (digits.length != 16) return 'Enter a valid 16-digit card number';
                if (!_passesLuhn(digits)) return 'Check the card number';
                return null;
              },
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    'MM / YY',
                    Icons.calendar_today_rounded,
                    _expiry,
                    formatter: _ExpiryFormatter(),
                    validator: _validateExpiry,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    'CVV',
                    Icons.lock_outline_rounded,
                    _cvv,
                    obscure: true,
                    formatter: LengthLimitingTextInputFormatter(4),
                    validator: (value) {
                      final digits = value ?? '';
                      if (digits.length < 3 || digits.length > 4) {
                        return 'Enter 3 or 4 digits';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.muted, size: 15),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Demo checkout only: do not enter real card details. No card data is sent to a payment gateway.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case 2:
        return _bankGrid();
      case 3:
        return _chips(wallets, wallet, (index) => wallet = index);
      default:
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F8FF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE3ECFB)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Pay in cash when your order is delivered. Please keep the payable amount ready.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: AppText.caption,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  bool _passesLuhn(String value) {
    var sum = 0;
    var doubleDigit = false;
    for (var i = value.length - 1; i >= 0; i--) {
      var digit = int.tryParse(value[i]) ?? 0;
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  Widget _cardPreview() {
    final digits = _cardNo.text.replaceAll(' ', '');
    final visibleDigits = List.generate(
      16,
          (index) => index < digits.length ? digits[index] : '•',
    );
    final grouped = [
      for (int group = 0; group < 4; group++)
        visibleDigits.sublist(group * 4, group * 4 + 4).join(),
    ].join('  ');
    final expiry = _expiry.text.isEmpty ? 'MM/YY' : _expiry.text;

    return Container(
      width: double.infinity,
      height: 166,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: brandGradient,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 17,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -55,
            child: CircleAvatar(
              radius: 72,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -62,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 27,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD86B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.memory_rounded,
                        size: 18, color: Color(0xFF9A6B00)),
                  ),
                  const Spacer(),
                  const Text('CARD PAYMENT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      )),
                ],
              ),
              const Spacer(),
              Text(grouped,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  )),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('PHONEHUB CUSTOMER',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        )),
                  ),
                  Text(expiry,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppText.small,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _upiLogo(int index) {
    final name = upiApps[index].$1;
    if (name == 'Google Pay') {
      return Container(
        width: 33,
        height: 33,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3ECFB)),
        ),
        child: const Text('G',
            style: TextStyle(
              fontSize: AppText.title,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4285F4),
            )),
      );
    }
    if (name == 'PhonePe') {
      return Container(
        width: 33,
        height: 33,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF5F259F),
          shape: BoxShape.circle,
        ),
        child: const Text('पे',
            style: TextStyle(
              fontSize: AppText.subtitle,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            )),
      );
    }
    return Container(
      width: 33,
      height: 33,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF00B9F1).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('paytm',
          style: TextStyle(
            fontSize: AppText.caption,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0087C9),
          )),
    );
  }

  Widget _bankGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose your bank',
            style: TextStyle(
              fontSize: AppText.caption,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
            )),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 0.98,
          children: [
            for (int index = 0; index < banks.length; index++)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() {
                  bank = index;
                  pickError = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bank == index
                        ? AppColors.primary.withValues(alpha: 0.09)
                        : checkoutFieldFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: bank == index
                          ? AppColors.primary
                          : const Color(0xFFDCE8FF),
                      width: bank == index ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _bankShortName(banks[index]),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        banks[index],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.w800,
                          color: bank == index
                              ? AppColors.primary
                              : AppColors.text,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _bankShortName(String name) {
    switch (name) {
      case 'Bank of Maharashtra':
        return 'BOM';
      case 'HDFC Bank':
        return 'HDFC';
      case 'ICICI Bank':
        return 'ICICI';
      default:
        return name.split(' ').first;
    }
  }

  Widget _chips(
      List<String> items,
      int? selected,
      void Function(int) onPick,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a wallet',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: AppText.caption,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int index = 0; index < items.length; index++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  onPick(index);
                  pickError = null;
                }),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == index
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : checkoutFieldFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected == index
                          ? AppColors.primary
                          : const Color(0xFFDCE8FF),
                      width: selected == index ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected == index) ...[
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 15),
                        const SizedBox(width: 5),
                      ],
                      Text(items[index],
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppText.caption,
                            color: selected == index
                                ? AppColors.primary
                                : AppColors.text,
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String? _validateExpiry(String? value) {
    final text = (value ?? '').trim();
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
    if (match == null) return 'Use MM/YY';

    final month = int.tryParse(match.group(1)!) ?? 0;
    final year = 2000 + (int.tryParse(match.group(2)!) ?? 0);
    if (month < 1 || month > 12) return 'Invalid month';

    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'Card expired';
    }
    return null;
  }

  Widget _field(
      String hint,
      IconData icon,
      TextEditingController controller, {
        required String? Function(String?) validator,
        TextInputFormatter? formatter,
        bool obscure = false,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      validator: validator,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        if (formatter != null) formatter,
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: AppText.small,
        ),
        isDense: true,
        prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
        filled: true,
        fillColor: checkoutFieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE8FF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE8FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.3),
        ),
      ),
    );
  }

  Widget _errorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: AppColors.danger),
          const SizedBox(width: 7),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: AppText.caption,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }

  Widget _secureNote() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.success, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Your order details are saved securely. This screen is a demo checkout; UPI, card, net banking and wallet selections do not initiate a real payment without a payment gateway integration.',
              style: TextStyle(
                color: AppColors.success,
                fontSize: AppText.caption,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: checkoutBottomBarDeco(),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 13),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total payable',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: AppText.caption,
                        )),
                    Text(
                      rupee(widget.total),
                      style: const TextStyle(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: GradientButton(
                  onTap: _isPlacingOrder ? null : _pay,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isPlacingOrder) ...[
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Icon(method == 4
                            ? Icons.check_circle_outline_rounded
                            : Icons.lock_rounded),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          _isPlacingOrder
                              ? 'Placing order...'
                              : method == 4
                              ? 'Place order'
                              : 'Pay ${rupee(widget.total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
}

/// Groups the card number as 1234 5678 9012 3456.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final value = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (int index = 0; index < value.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(value[index]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}


/// Turns 1229 into 12/29.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final value = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted =
    value.length >= 3 ? '${value.substring(0, 2)}/${value.substring(2)}' : value;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}