import 'package:flutter/material.dart';
import 'data.dart';
import 'theme.dart';

const _metal = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF5A5A66), Color(0xFF17171C), Color(0xFF45454F)],
);

/// A drawn phone (no image files needed). Uses the phone's own two colours for
/// the wallpaper (front) or the glass back, with brand-style camera layouts.
class PhoneMockup extends StatelessWidget {
  final Phone phone;
  final double height;
  final bool back;
  const PhoneMockup({super.key, required this.phone, required this.height, this.back = false});

  double get _w => height * 0.49;
  double get _r => height * 0.12;

  List<BoxShadow> get _shadow => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: height * 0.10, offset: Offset(0, height * 0.06)),
  ];

  Widget _sideBtn(double h) => Container(
    width: height * 0.012,
    height: h,
    decoration: BoxDecoration(color: const Color(0xFF2C2C34), borderRadius: BorderRadius.circular(2)),
  );

  List<Widget> _buttons() => [
    Positioned(right: -height * 0.008, top: height * 0.26, child: _sideBtn(height * 0.11)),
    Positioned(left: -height * 0.008, top: height * 0.20, child: _sideBtn(height * 0.06)),
    Positioned(left: -height * 0.008, top: height * 0.28, child: _sideBtn(height * 0.06)),
  ];

  String get _time {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  String get _date {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${n.day} ${months[n.month - 1]}';
  }

  Widget _round(IconData icon) => Container(
    width: height * 0.075,
    height: height * 0.075,
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
    child: Icon(icon, color: Colors.white, size: height * 0.04),
  );

  Widget _lens(double s) => Container(
    width: s,
    height: s,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF0A0A10),
      border: Border.all(color: const Color(0xFF9A9AA6), width: s * 0.09),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: s * 0.25, offset: Offset(0, s * 0.1))],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: s * 0.42,
          height: s * 0.42,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFF2B3A8C), Color(0xFF05050A)])),
        ),
        Positioned(
          top: s * 0.2,
          left: s * 0.24,
          child: Container(width: s * 0.1, height: s * 0.1, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.7))),
        ),
      ],
    ),
  );

  Widget _cameraModule() {
    final w = _w;
    switch (phone.brand) {
      case 'Apple':
        final plate = w * 0.46;
        return Container(
          width: plate,
          height: plate,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(plate * 0.27),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Stack(
            children: [
              Positioned(left: plate * 0.12, top: plate * 0.12, child: _lens(plate * 0.36)),
              Positioned(right: plate * 0.12, bottom: plate * 0.12, child: _lens(plate * 0.36)),
              Positioned(
                right: plate * 0.16,
                top: plate * 0.16,
                child: Container(width: plate * 0.10, height: plate * 0.10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF3C4))),
              ),
            ],
          ),
        );
      case 'Samsung':
        final lens = w * 0.19;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [_lens(lens), SizedBox(height: lens * 0.35), _lens(lens), SizedBox(height: lens * 0.35), _lens(lens)],
        );
      case 'OnePlus':
        final plate = w * 0.50;
        return Container(
          width: plate,
          height: plate,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF111116),
            border: Border.all(color: const Color(0xFF8A8A95), width: plate * 0.04),
          ),
          child: Stack(
            children: [
              Positioned(left: plate * 0.12, top: plate * 0.14, child: _lens(plate * 0.36)),
              Positioned(right: plate * 0.12, top: plate * 0.14, child: _lens(plate * 0.36)),
              Positioned(left: plate * 0.32, bottom: plate * 0.12, child: _lens(plate * 0.36)),
            ],
          ),
        );
      default:
        final pw = w * 0.34;
        final ph = w * 0.62;
        return Container(
          width: pw,
          height: ph,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(pw * 0.4)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_lens(pw * 0.62), _lens(pw * 0.62), _lens(pw * 0.62)],
          ),
        );
    }
  }

  Widget _front() {
    final w = _w;
    final bezel = height * 0.022;
    final mini = height < 140;
    final apple = phone.brand == 'Apple';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._buttons(),
        Container(
          padding: EdgeInsets.all(bezel),
          decoration: BoxDecoration(gradient: _metal, borderRadius: BorderRadius.circular(_r), boxShadow: _shadow),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_r - bezel),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [phone.colors.last, phone.colors.first]),
                  ),
                ),
                Positioned(top: -w * 0.25, right: -w * 0.3, child: Container(width: w * 0.9, height: w * 0.9, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)))),
                Positioned(bottom: -w * 0.3, left: -w * 0.3, child: Container(width: w * 0.9, height: w * 0.9, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                if (!mini) ...[
                  Positioned(
                    top: height * 0.026,
                    left: w * 0.09,
                    right: w * 0.09,
                    child: Row(
                      children: [
                        Text(_time, style: TextStyle(color: Colors.white, fontSize: height * 0.034, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: height * 0.036),
                        Icon(Icons.wifi_rounded, color: Colors.white, size: height * 0.036),
                        Icon(Icons.battery_full_rounded, color: Colors.white, size: height * 0.036),
                      ],
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -0.45),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_date, style: TextStyle(color: Colors.white70, fontSize: height * 0.036, fontWeight: FontWeight.w600)),
                        Text(_time, style: TextStyle(color: Colors.white, fontSize: height * 0.15, fontWeight: FontWeight.w300, height: 1.05)),
                      ],
                    ),
                  ),
                  Positioned(bottom: height * 0.045, left: w * 0.10, child: _round(Icons.flashlight_on_rounded)),
                  Positioned(bottom: height * 0.045, right: w * 0.10, child: _round(Icons.camera_alt_rounded)),
                  Positioned(
                    bottom: height * 0.014,
                    left: 0,
                    right: 0,
                    child: Center(child: Container(width: w * 0.34, height: height * 0.008, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(4)))),
                  ),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: const Alignment(0.2, 0.2), colors: [Colors.white.withValues(alpha: 0.20), Colors.white.withValues(alpha: 0)]),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: height * 0.016),
                    child: apple
                        ? Container(width: w * 0.30, height: height * 0.030, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)))
                        : Container(width: height * 0.022, height: height * 0.022, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _back() {
    final w = _w;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._buttons(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: phone.colors),
            borderRadius: BorderRadius.circular(_r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: height * 0.006 < 1 ? 1 : height * 0.006),
            boxShadow: _shadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: const Alignment(0.3, 0.3), colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)]),
                  ),
                ),
                Positioned(top: height * 0.04, left: w * 0.08, child: _cameraModule()),
                if (height >= 140)
                  Align(
                    alignment: const Alignment(0, 0.4),
                    child: Text(phone.brand.toLowerCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w700, fontSize: height * 0.05, letterSpacing: 1)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: _w, height: height, child: back ? _back() : _front());
  }
}

/// Retail box with a charger and warranty card (used for the "In the box" photo).
class PhoneBoxMockup extends StatelessWidget {
  final Phone phone;
  final double height;
  const PhoneBoxMockup({super.key, required this.phone, required this.height});

  @override
  Widget build(BuildContext context) {
    final h = height;
    return SizedBox(
      width: h * 1.25,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: h * 0.08,
            width: h * 0.80,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFEAF1FF)]),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: h * 0.10, offset: Offset(0, h * 0.06))],
              ),
              child: Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: phone.colors),
                      ),
                      child: Center(child: Icon(Icons.smartphone_rounded, size: h * 0.28, color: Colors.white)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(phone.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: h * 0.065, color: AppColors.text)),
                          Text('Certified pre-owned', style: TextStyle(color: AppColors.muted, fontSize: h * 0.04)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: h * 0.02,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: h * 0.24,
                height: h * 0.24,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 5))]),
                child: Icon(Icons.electrical_services_rounded, color: AppColors.primary, size: h * 0.12),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: h * 0.12,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: h * 0.30,
                height: h * 0.20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B2A5C), Color(0xFF3D5BB8)]),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: h * 0.075),
                    Text('6M Warranty', style: TextStyle(color: Colors.white, fontSize: h * 0.034, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}