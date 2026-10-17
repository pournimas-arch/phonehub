import 'package:flutter/material.dart';
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';
import 'main_shell.dart';
import 'package:phonehub/app_text.dart';

/// Screen 5 – Confirm Delivery (2h)
/// 4-digit OTP entry from customer, success state "Order Delivered!", Done button.
class ConfirmDeliveryScreen extends StatefulWidget {
  final DeliveryOrder order;

  const ConfirmDeliveryScreen({super.key, required this.order});

  @override
  State<ConfirmDeliveryScreen> createState() => _ConfirmDeliveryScreenState();
}

class _ConfirmDeliveryScreenState extends State<ConfirmDeliveryScreen> {
  String otp = '';
  String? error;
  bool delivered = false;
  bool _busy = false;
  int _wrongTries = 0;
  DateTime? _lockedUntil;

  void _press(String d) {
    if (otp.length >= 4 || _busy) return;
    setState(() {
      otp += d;
      error = null;
    });
  }

  void _back() {
    if (otp.isEmpty || _busy) return;
    setState(() {
      otp = otp.substring(0, otp.length - 1);
      error = null;
    });
  }

  /// Sends the OTP to Firestore. The real code is kept secret on the server side (rules compare it),
  /// so the partner cannot guess it from the app.
  Future<void> _confirm() async {
    if (_busy || delivered) return;

    // Keep the handler safe even if it is triggered outside the keypad flow.
    if (!RegExp(r'^\d{4}$').hasMatch(otp)) {
      setState(() {
        error = 'Please enter the 4-digit OTP.';
      });
      return;
    }

    final until = _lockedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      final secs = until.difference(DateTime.now()).inSeconds + 1;
      setState(() {
        error = 'Too many wrong tries. Wait $secs seconds.';
        otp = '';
      });
      return;
    }
    setState(() => _busy = true);

    String? err;
    try {
      err = await confirmDelivery(widget.order, otp);
    } catch (_) {
      err = 'Could not save. Please check your internet and try again.';
    }

    if (!mounted) return;
    if (err == null) {
      setState(() {
        delivered = true;
        _busy = false;
      });
      return;
    }
    var message = err;
    if (err.startsWith('Incorrect')) {
      _wrongTries++;
      if (_wrongTries >= 5) {
        _wrongTries = 0;
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        message = 'Too many wrong tries. Wait 30 seconds.';
      }
    }
    setState(() {
      error = message;
      otp = '';
      _busy = false;
    });
  }

  /// Back to the live partner home (My Deliveries etc.). The order list is already up to date
  /// because the Firestore listener refreshed it when the delivery was saved.
  void _done() => Navigator.pushAndRemoveUntil(
      context, MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);

  @override
  Widget build(BuildContext context) {
    // After "Delivered" the phone's back button also goes to the partner home
    // (not back to the old order screen, which would show stale data).
    return PopScope(
      canPop: !delivered,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && delivered) _done();
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(delivered ? '' : 'Confirm Delivery'),
            automaticallyImplyLeading: !delivered),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: delivered ? _success() : _entry(),
        ),
      ),
    );
  }

  Widget _entry() {
    final o = widget.order;
    return SingleChildScrollView(
      key: const ValueKey('entry'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(o.customer.isEmpty ? 'C' : o.customer[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: AppText.title))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.customer,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: AppText.subtitle)),
                      Text('#${o.id} • ${o.area}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: AppText.small)),
                    ],
                  ),
                ),
                if (o.isCod)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('Collect ${rupee(o.amount)}',
                        style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                            fontSize: AppText.small)),
                  ),
              ],
            ),
          ),
          if (o.payPending) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text(
                  'Online payment is not confirmed yet. Do not collect cash; the admin will confirm it.',
                  style: TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: AppText.small,
                      fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle),
            child: const Icon(Icons.lock_open_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          const Text('Enter Delivery OTP',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Ask the customer for the 4-digit OTP\nshown in their PhoneHub app',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < otp.length;
              final current = i == otp.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 54,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: error != null
                          ? AppColors.danger
                          : (current ? AppColors.primary : AppColors.border),
                      width: current ? 2 : 1.2),
                ),
                child: Text(filled ? otp[i] : '',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900)),
              );
            }),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 20,
            child: Text(error ?? '',
                style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: AppText.small,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9']
          ])
            Row(children: [for (final k in row) _key(k, () => _press(k))]),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              _key('0', () => _press('0')),
              _key('', _back, icon: Icons.backspace_outlined),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: otp.length == 4 && !_busy ? _confirm : null,
            child: Text(_busy ? 'Checking...' : 'Confirm Delivery'),
          ),
        ],
      ),
    );
  }

  Widget _key(String label, VoidCallback onTap, {IconData? icon}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 46,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: AppColors.text)
                    : Text(label,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success() {
    final o = widget.order;
    return Center(
      key: const ValueKey('success'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 12))
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 80),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Order Delivered!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('#${o.id} was delivered to ${o.customer}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4)),
            // Earning of this order, as set by the admin when the order was assigned.
            // Hidden when the admin has not set one (no "+₹0 earned").
            if (o.earning > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.success),
                    const SizedBox(width: 8),
                    Text('+${rupee(o.earning)} earned',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                            fontSize: AppText.subtitle)),
                  ],
                ),
              ),
            ],
            // Cash on delivery: the cash collected must be handed over; the admin marks it settled.
            if (o.isCod) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_rounded, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('Cash collected ${rupee(o.amount)}. Hand it over to PhoneHub.',
                          style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w800,
                              fontSize: AppText.small)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _done,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}