import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashScreen({
    super.key,
    this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color teal = Color(0xFF0F766E);
  static const Color darkTeal = Color(0xFF134E4A);
  static const Color amber = Color(0xFFF59E0B);
  static const Color background = Color(0xFFF4F7F6);

  static const String appVersion = 'v1.0.0';

  late final AnimationController _intro;
  late final AnimationController _loop;

  late final Animation<double> _logoAnimation;
  late final Animation<double> _sceneAnimation;
  late final Animation<double> _textAnimation;

  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _logoAnimation = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
    );

    _sceneAnimation = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOutBack),
    );

    _textAnimation = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    );

    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });

    _intro.forward();
  }

  void _finish() {
    if (_finished || !mounted) return;

    _finished = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  Widget _reveal(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE4F4F0),
              Color(0xFFF8FAF9),
              Color(0xFFE5F1ED),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),

                        // Logo and app name
                        _reveal(
                          _logoAnimation,
                          _buildLogo(),
                        ),

                        const SizedBox(height: 18),

                        // Partner badge
                        _reveal(
                          _logoAnimation,
                          _buildPartnerBadge(),
                        ),

                        // Main illustration
                        Expanded(
                          child: _reveal(
                            _sceneAnimation,
                            _buildDeliveryScene(),
                          ),
                        ),

                        // Tagline
                        _reveal(
                          _textAnimation,
                          _buildTagline(),
                        ),

                        const SizedBox(height: 22),

                        // Feature labels
                        _reveal(
                          _textAnimation,
                          _buildFeatures(),
                        ),

                        const SizedBox(height: 28),

                        // Loading progress
                        _buildProgress(),

                        const SizedBox(height: 14),

                        Text(
                          'PHONEHUB PARTNER  •  $appVersion',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.48),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGO
  // ------------------------------------------------------------

  Widget _buildLogo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [teal, darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: teal.withValues(alpha: 0.20),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'PhoneHub',
              style: TextStyle(
                color: darkTeal,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'SECOND-HAND MOBILE E-COMMERCE',
          style: TextStyle(
            color: teal,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: teal.withValues(alpha: 0.12),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delivery_dining_rounded,
            size: 18,
            color: teal,
          ),
          SizedBox(width: 7),
          Text(
            'DELIVERY PARTNER',
            style: TextStyle(
              color: darkTeal,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DELIVERY ILLUSTRATION
  // ------------------------------------------------------------

  Widget _buildDeliveryScene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        ).clamp(0.0, 340.0);

        return Center(
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, child) {
              final bounce =
                  math.sin(_loop.value * 2 * math.pi) * 4;

              return Transform.translate(
                offset: Offset(0, bounce),
                child: child,
              );
            },
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft circular background
                  Container(
                    width: size * 0.92,
                    height: size * 0.92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFBCE5DB)
                              .withValues(alpha: 0.85),
                          const Color(0xFFE7F4F0)
                              .withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),

                  // Decorative rings
                  Container(
                    width: size * 0.75,
                    height: size * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: teal.withValues(alpha: 0.10),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // Delivery parcel
                  Positioned(
                    top: size * 0.16,
                    left: size * 0.13,
                    child: _buildParcel(size * 0.23),
                  ),

                  // Floating delivery status
                  Positioned(
                    top: size * 0.18,
                    right: size * 0.01,
                    child: _statusBadge(
                      Icons.check_circle_rounded,
                      'Order ready',
                    ),
                  ),

                  // Scooter and rider
                  Center(
                    child: SizedBox(
                      width: size * 0.88,
                      height: size * 0.78,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: CustomPaint(
                          size: const Size(300, 260),
                          painter: _ScooterPainter(),
                        ),
                      ),
                    ),
                  ),

                  // Ground shadow
                  Positioned(
                    bottom: size * 0.10,
                    child: Container(
                      width: size * 0.58,
                      height: 9,
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),

                  // Location badge
                  Positioned(
                    bottom: size * 0.13,
                    left: size * 0.01,
                    child: _statusBadge(
                      Icons.location_on_rounded,
                      'On the way',
                    ),
                  ),

                  // ETA badge
                  Positioned(
                    bottom: size * 0.02,
                    right: size * 0.02,
                    child: _statusBadge(
                      Icons.schedule_rounded,
                      'Fast delivery',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParcel(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [teal, darkTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: teal.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.inventory_2_rounded,
        color: Colors.white,
        size: 35,
      ),
    );
  }

  Widget _statusBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: teal.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: teal),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: darkTeal,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TAGLINE
  // ------------------------------------------------------------


  Widget _buildTagline() {
    return const Text(
      'Delivering Trust, One Phone at a Time',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: teal,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }


  // ------------------------------------------------------------
  // FEATURES
  // ------------------------------------------------------------

  Widget _buildFeatures() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _feature(
          Icons.bolt_rounded,
          'Fast',
        ),
        const SizedBox(width: 9),
        _feature(
          Icons.verified_user_rounded,
          'Secure',
        ),
        const SizedBox(width: 9),
        _feature(
          Icons.workspace_premium_rounded,
          'Rewards',
        ),
      ],
    );
  }

  Widget _feature(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: teal.withValues(alpha: 0.09),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: amber,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: darkTeal,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // LOADING PROGRESS
  // ------------------------------------------------------------

  Widget _buildProgress() {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, _) {
        final progress = _intro.value;

        String message;

        if (progress < 0.30) {
          message = 'Preparing your delivery experience...';
        } else if (progress < 0.60) {
          message = 'Getting everything ready...';
        } else if (progress < 0.90) {
          message = 'Almost ready to ride...';
        } else {
          message = "Let's ride!";
        }

        return Column(
          children: [
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor:
                  teal.withValues(alpha: 0.12),
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(teal),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                message,
                key: ValueKey(message),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// SIMPLE CUSTOM SCOOTER ILLUSTRATION
// ============================================================

class _ScooterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const teal = Color(0xFF0F766E);
    const darkTeal = Color(0xFF134E4A);
    const amber = Color(0xFFF59E0B);
    const skin = Color(0xFFE9B18B);

    Paint fill(Color color) {
      return Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    }

    void oval(
        double x,
        double y,
        double w,
        double h,
        Color color,
        ) {
      canvas.drawOval(
        Rect.fromLTWH(x, y, w, h),
        fill(color),
      );
    }

    void rounded(
        double x,
        double y,
        double w,
        double h,
        double radius,
        Color color,
        ) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        fill(color),
      );
    }

    // Rear wheel
    _drawWheel(canvas, 75, 205, fill);

    // Front wheel
    _drawWheel(canvas, 238, 205, fill);

    // Scooter body
    final bodyPaint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF71D0BE),
          teal,
          darkTeal,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        const Rect.fromLTWH(45, 135, 200, 80),
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(49, 148, 180, 48),
        const Radius.circular(23),
      ),
      bodyPaint,
    );

    // Scooter chassis
    rounded(70, 187, 155, 11, 5, darkTeal);

    // Seat
    rounded(96, 133, 65, 12, 6, darkTeal);

    // Front mudguard
    final mudguard = Path()
      ..moveTo(209, 151)
      ..lineTo(238, 158)
      ..lineTo(249, 190)
      ..lineTo(223, 199)
      ..lineTo(207, 179)
      ..close();

    canvas.drawPath(mudguard, fill(teal));

    // Steering stem
    final stem = Paint()
      ..color = darkTeal
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(218, 151),
      const Offset(231, 103),
      stem,
    );

    canvas.drawLine(
      const Offset(218, 104),
      const Offset(246, 101),
      stem,
    );

    // Rider rear leg
    final trousers = Paint()
      ..color = const Color(0xFF285C91)
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(151, 108),
      const Offset(177, 145),
      trousers,
    );

    canvas.drawLine(
      const Offset(177, 145),
      const Offset(154, 166),
      trousers,
    );

    // Rider shoe
    rounded(139, 163, 28, 11, 5, const Color(0xFF183A50));

    // Rider torso
    final shirt = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF5CC9B7),
          teal,
        ],
      ).createShader(
        const Rect.fromLTWH(125, 55, 55, 75),
      );

    canvas.save();
    canvas.translate(150, 91);
    canvas.rotate(-0.20);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -29, 39, 65),
        const Radius.circular(14),
      ),
      shirt,
    );

    canvas.restore();

    // Rider's arm
    final arm = Paint()
      ..color = skin
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(163, 77),
      const Offset(193, 94),
      arm,
    );

    canvas.drawLine(
      const Offset(193, 94),
      const Offset(230, 102),
      arm,
    );

    // Rider front leg
    canvas.drawLine(
      const Offset(150, 111),
      const Offset(174, 145),
      trousers,
    );

    canvas.drawLine(
      const Offset(174, 145),
      const Offset(201, 155),
      trousers,
    );

    rounded(193, 151, 25, 10, 5, const Color(0xFF183A50));

    // Neck
    rounded(139, 51, 15, 19, 5, skin);

    // Head
    oval(128, 29, 37, 39, skin);

    // Hair
    final hair = Path()
      ..moveTo(129, 47)
      ..quadraticBezierTo(121, 25, 143, 22)
      ..quadraticBezierTo(164, 22, 165, 42)
      ..lineTo(157, 49)
      ..lineTo(150, 37)
      ..lineTo(138, 40)
      ..close();

    canvas.drawPath(hair, fill(darkTeal));

    // Amber helmet
    final helmet = Path()
      ..moveTo(125, 39)
      ..quadraticBezierTo(124, 16, 145, 15)
      ..quadraticBezierTo(164, 17, 167, 35)
      ..lineTo(153, 32)
      ..lineTo(142, 26)
      ..lineTo(134, 37)
      ..close();

    canvas.drawPath(helmet, fill(amber));

    rounded(128, 34, 37, 5, 2, const Color(0xFFD98A05));

    // Face
    oval(154, 45, 3, 3, darkTeal);

    // Delivery parcel
    rounded(56, 91, 57, 49, 7, darkTeal);
    rounded(60, 95, 49, 41, 5, teal);
    rounded(81, 95, 7, 41, 2, const Color(0xFF66B9AD));
    rounded(60, 109, 49, 3, 1, const Color(0xFF8AD5C8));

    // PhoneHub label on parcel
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'PhoneHub',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      const Offset(62, 117),
    );

    // Headlight
    oval(235, 165, 16, 10, const Color(0xFFFFF1C9));

    // Small amber indicator
    oval(220, 176, 8, 6, amber);
  }

  void _drawWheel(
      Canvas canvas,
      double cx,
      double cy,
      Paint Function(Color) fill,
      ) {
    canvas.drawCircle(
      Offset(cx, cy),
      29,
      fill(const Color(0xFF263B40)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      24,
      fill(const Color(0xFF15292D)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      15,
      fill(const Color(0xFFE0F1EC)),
    );

    final spokes = Paint()
      ..color = const Color(0xFF0F766E).withValues(alpha: 0.55)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final angle = i * math.pi / 3;

      canvas.drawLine(
        Offset(
          cx + math.cos(angle) * 14,
          cy + math.sin(angle) * 14,
        ),
        Offset(
          cx - math.cos(angle) * 14,
          cy - math.sin(angle) * 14,
        ),
        spokes,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      9,
      fill(const Color(0xFF0F766E)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      3,
      fill(const Color(0xFFE0F1EC)),
    );
  }

  @override
  bool shouldRepaint(covariant _ScooterPainter oldDelegate) => false;
}