import 'package:flutter/material.dart';
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/common.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';

/// Shared look for the delivery partner screens:
/// teal header + rounded light sheet (same as Home / My Deliveries / Profile).
/// Text on the status pill (Picked Up = Out for Delivery, future orders = Scheduled).
String dLabel(DeliveryOrder o) {
  switch (o.status) {
    case 'Picked Up':
      return 'Out for Delivery';
    case 'Assigned':
      return o.isToday ? 'Assigned' : 'Scheduled';
    default:
      return o.status;
  }
}

Color dColor(DeliveryOrder o) {
  if (o.status == 'Cancelled') return AppColors.danger;
  if (o.status == 'Assigned') return o.isToday ? AppColors.info : AppColors.muted;
  return statusColor(o.status);
}

class DPill extends StatelessWidget {
  final String text;
  final Color color;
  const DPill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
  );
}

class DThumb extends StatelessWidget {
  final double size;
  const DThumb({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size * 1.17,
    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
    child: Icon(Icons.smartphone_rounded, color: AppColors.primary, size: size * 0.55),
  );
}

class DPage extends StatelessWidget {
  final String title;
  final bool back;
  final Widget? trailing;
  final Widget child;
  final Widget? bottom;
  const DPage({super.key, required this.title, required this.child, this.back = false, this.trailing, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B5E57), AppColors.primary]),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(back ? 6 : 18, MediaQuery.of(context).padding.top + 10, 16, 14),
              child: Row(
                children: [
                  if (back)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}