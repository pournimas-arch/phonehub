import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'theme.dart';
import 'widgets.dart';
import 'data.dart';
import 'package:phonehub/app_text.dart';

// Shared look for the 3-step checkout (Address -> Confirm details -> Payment).
// Same colors, gradient and glass cards as the Home screen.
// NOTE: checkoutBgGradient is now identical to the Home screen's background gradient.

const checkoutBgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFCFDFF), // top: nearly white (same as Home)
    Color(0xFFE9F1FE), // middle
    Color(0xFFD0E1F9), // bottom
  ],
);

const checkoutFieldFill = Color(0xFFEAF1FF);
const checkoutLine = Color(0xFFE8EFFC);

BoxDecoration glassDeco({double radius = 20, Color? borderColor, double borderWidth = 1}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: borderColor ?? const Color(0xFFDCE8FF), width: borderWidth),
  boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
);

/// Home-style rounded bottom bar decoration.
BoxDecoration checkoutBottomBarDeco() => BoxDecoration(
  color: Colors.white,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
  boxShadow: [BoxShadow(color: const Color(0xFF1B2A5C).withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -6))],
);

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

/// Wrap a transparent Scaffold with this to get the Home gradient + soft circles.
class CheckoutBackground extends StatelessWidget {
  final Widget child;
  const CheckoutBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        decoration: const BoxDecoration(gradient: checkoutBgGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(top: -70, right: -80, child: _Blob(240, 0.35)),
            Positioned(top: 420, left: -120, child: _Blob(280, 0.20)),
            child,
          ],
        ),
      ),
    );
  }
}

/// Back button + (optional) "Step x of 3" + title + optional trailing widget.
class CheckoutHeader extends StatelessWidget {
  final String title;
  final String? step;
  final Widget? trailing;
  const CheckoutHeader({super.key, required this.title, this.step, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3)),
                if (step != null) ...[
                  const SizedBox(height: 1),
                  Text(step!, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 3-step progress: Address, Confirm details, Payment. [current] is 0, 1 or 2.
class CheckoutStepper extends StatelessWidget {
  final int current;
  const CheckoutStepper({super.key, required this.current});

  static const _labels = ['Address', 'Confirm details', 'Payment'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: glassDeco(radius: 20),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Container(height: 2.5, color: i == 0 ? Colors.transparent : (i <= current ? AppColors.primary : const Color(0xFFE3ECFB)))),
                      _dot(i),
                      Expanded(child: Container(height: 2.5, color: i == 2 ? Colors.transparent : (i < current ? AppColors.primary : const Color(0xFFE3ECFB)))),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppText.caption, fontWeight: i == current ? FontWeight.w800 : FontWeight.w600, color: i <= current ? AppColors.text : AppColors.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _icons = [Icons.location_on_rounded, Icons.receipt_long_rounded, Icons.payments_rounded];

  Widget _dot(int i) {
    final done = i < current;
    final now = i == current;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (done || now) ? brandGradient : null,
        color: (done || now) ? null : const Color(0xFFE3ECFB),
        boxShadow: now ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Icon(_icons[i], size: 16, color: now ? Colors.white : AppColors.muted),
    );
  }
}

/// Section title with the blue accent bar (same as Home).
class CheckoutSectionTitle extends StatelessWidget {
  final String title;
  const CheckoutSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: AppText.subtitle, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
    ],
  );
}

/// Primary button with the Home brand gradient.
class GradientButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double height;
  const GradientButton({super.key, required this.onTap, required this.child, this.height = 52});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: AppText.body),
            child: IconTheme(data: const IconThemeData(color: Colors.white, size: 18), child: child),
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Extra e-commerce widgets
// ---------------------------------------------------------------------------

/// "Fri, 16 Oct" style date, [days] from today.
String deliveryDateText(int days) {
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = DateTime.now().add(Duration(days: days));
  return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]}';
}

/// Free-delivery progress (free above Rs 10,000, same rule as the cart).
class FreeDeliveryBar extends StatelessWidget {
  final int subtotal;
  const FreeDeliveryBar({super.key, required this.subtotal});

  static const threshold = 10000;

  @override
  Widget build(BuildContext context) {
    final unlocked = subtotal >= threshold;
    final left = threshold - subtotal;
    final c = unlocked ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(unlocked ? Icons.celebration_rounded : Icons.local_shipping_outlined, size: 17, color: c),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  unlocked ? 'Yay! You get FREE delivery on this order' : 'Add ${rupee(left)} more for FREE delivery',
                  style: TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800, color: unlocked ? AppColors.success : AppColors.text),
                ),
              ),
            ],
          ),
          if (!unlocked) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: (subtotal / threshold).clamp(0.0, 1.0).toDouble(), minHeight: 6, backgroundColor: const Color(0xFFE3ECFB), valueColor: const AlwaysStoppedAnimation(AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Secure payments / easy returns / authentic products.
class TrustBadgesRow extends StatelessWidget {
  const TrustBadgesRow({super.key});

  Widget _item(IconData icon, String text) => Expanded(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.25)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: glassDeco(radius: 20),
      child: Row(
        children: [
          _item(Icons.lock_rounded, 'Safe & secure\npayments'),
          _item(Icons.published_with_changes_rounded, '7-day easy\nreturns'),
          _item(Icons.verified_rounded, '100% authentic\nproducts'),
        ],
      ),
    );
  }
}