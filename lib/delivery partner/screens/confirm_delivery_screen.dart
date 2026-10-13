import 'package:flutter/material.dart';
import '../../customer/theme.dart';
import '../orders_data.dart';
import 'assigned_orders_screen.dart';

/// Screen 5 – Confirm Delivery (2h)
/// 4-digit OTP entry from customer, success state "Order Delivered!", Done button.
class ConfirmDeliveryScreen extends StatefulWidget {
  final DeliveryOrder order;
  const ConfirmDeliveryScreen({super.key, required this.order});

  @override
  State<ConfirmDeliveryScreen> createState() => _ConfirmDeliveryScreenState();
}

class _ConfirmDeliveryScreenState extends State<ConfirmDeliveryScreen> {
  static const demoOtp = '1234';
  String otp = '';
  String? error;
  bool delivered = false;

  void _press(String d) {
    if (otp.length >= 4) return;
    setState(() {
      otp += d;
      error = null;
    });
  }

  void _back() {
    if (otp.isEmpty) return;
    setState(() {
      otp = otp.substring(0, otp.length - 1);
      error = null;
    });
  }

  void _confirm() {
    if (otp == demoOtp) {
      updateStatus(widget.order, 'Delivered');
      setState(() => delivered = true);
    } else {
      setState(() {
        error = 'Incorrect OTP. Please ask the customer again.';
        otp = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(delivered ? '' : 'Confirm Delivery'), automaticallyImplyLeading: !delivered),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: delivered ? _success() : _entry(),
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
                CircleAvatar(radius: 24, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(o.customer[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.customer, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text('#${o.id} • ${o.area}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (o.isCod)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Text('Collect ${rupee(o.amount)}', style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          const Text('Enter Delivery OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Ask the customer for the 4-digit OTP\nsent to their phone', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < otp.length;
              final current = i == otp.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 7),
                width: 60,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: error != null ? AppColors.danger : (current ? AppColors.primary : AppColors.border), width: current ? 2 : 1.2),
                ),
                child: Text(filled ? otp[i] : '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              );
            }),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 20,
            child: Text(error ?? '', style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          const Text('Demo OTP: 1234', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
            Row(children: [for (final k in row) _key(k, () => _press(k))]),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              _key('0', () => _press('0')),
              _key('', _back, icon: Icons.backspace_outlined),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: otp.length == 4 ? _confirm : null, child: const Text('Confirm Delivery')),
        ],
      ),
    );
  }

  Widget _key(String label, VoidCallback onTap, {IconData? icon}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 54,
              child: Center(
                child: icon != null ? Icon(icon, color: AppColors.text) : Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 80),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Order Delivered!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('#${o.id} was delivered to ${o.customer}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('+${rupee(o.earning)} earned', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainShell()), (r) => false),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
