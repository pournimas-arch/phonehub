import 'package:flutter/material.dart';
import '../customer/theme.dart';
import 'package:phonehub/app_text.dart';

Color statusColor(String s) {
  switch (s) {
    case 'Delivered':
      return AppColors.success;
    case 'Picked Up':
      return AppColors.accent;
    default:
      return AppColors.muted;
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: c, fontSize: AppText.small, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const CircleIconButton({super.key, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 21),
      ),
    );
  }
}

/// Map placeholder with a route line and a moving scooter marker.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 16)],
            ),
            child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE6F0EE));

    final park = Paint()..color = const Color(0xFFCFE8D9);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.05, s.height * 0.05, s.width * 0.25, s.height * 0.22), const Radius.circular(14)), park);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.62, s.height * 0.58, s.width * 0.3, s.height * 0.3), const Radius.circular(14)), park);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    for (final fy in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(0, s.height * fy), Offset(s.width, s.height * fy), road);
    }
    for (final fx in [0.2, 0.5, 0.8]) {
      canvas.drawLine(Offset(s.width * fx, 0), Offset(s.width * fx, s.height), road);
    }

    final route = Path()
      ..moveTo(s.width * 0.2, s.height * 0.8)
      ..lineTo(s.width * 0.5, s.height * 0.8)
      ..lineTo(s.width * 0.5, s.height * 0.2)
      ..lineTo(s.width * 0.8, s.height * 0.2);
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(Offset(s.width * 0.2, s.height * 0.8), 10, Paint()..color = AppColors.success);
    canvas.drawCircle(Offset(s.width * 0.2, s.height * 0.8), 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.2), 12, Paint()..color = AppColors.danger);
    canvas.drawCircle(Offset(s.width * 0.8, s.height * 0.2), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}