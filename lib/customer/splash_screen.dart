import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:phonehub/app_text.dart';

/// PhoneHub — Premium Splash Screen
///
/// Preserves the original blue palette, gradient, branding,
/// feature badges, and navigation to LoginScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _navy = Color(0xFF10265F);
  static const Color _blue = Color(0xFF2452B8);
  static const Color _deepNavy = Color(0xFF071538);
  static const Color _cyan = Color(0xFF38D9FF);

  late final AnimationController _floatController;
  late final AnimationController _glowController;
  late final AnimationController _entranceController;

  late final Animation<double> _floatAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: -7,
      end: 7,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.15,
      end: 0.42,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _getStarted() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final logoSize =
    (screenSize.width * 0.38).clamp(128.0, 154.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFD0E1F9),
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // Original gradient intentionally preserved.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCFDFF),
              Color(0xFFE9F1FE),
              Color(0xFFD0E1F9),
            ],
          ),
        ),

        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Ambient background lighting.
            Positioned(
              top: -screenSize.height * 0.10,
              right: -screenSize.width * 0.25,
              child: _GlowOrb(
                size: screenSize.width * 0.92,
                color: const Color(0xFF1E9BFF)
                    .withValues(alpha: 0.18),
              ),
            ),

            Positioned(
              top: screenSize.height * 0.22,
              left: -screenSize.width * 0.43,
              child: _GlowOrb(
                size: screenSize.width * 0.78,
                color: const Color(0xFF1688FF)
                    .withValues(alpha: 0.15),
              ),
            ),

            Positioned(
              bottom: -screenSize.height * 0.09,
              left: -screenSize.width * 0.20,
              child: _GlowOrb(
                size: screenSize.width * 1.02,
                color: const Color(0xFF245DFF)
                    .withValues(alpha: 0.14),
              ),
            ),

            Positioned(
              top: screenSize.height * 0.18,
              right: 25,
              child: const _DotPattern(),
            ),

            Positioned(
              bottom: screenSize.height * 0.29,
              left: 23,
              child: const _DotPattern(),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          25,
                          screenSize.height < 700 ? 12 : 24,
                          25,
                          22,
                        ),
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 4),

                            // Main branding section.
                            FadeTransition(
                              opacity: _entranceAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.07),
                                  end: Offset.zero,
                                ).animate(_entranceAnimation),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: logoSize + 30,
                                      height: logoSize + 30,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Soft outer halo.
                                          AnimatedBuilder(
                                            animation: _glowController,
                                            builder: (context, child) {
                                              return Container(
                                                width: logoSize + 24,
                                                height: logoSize + 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _cyan
                                                          .withValues(
                                                        alpha: reduceMotion
                                                            ? 0.22
                                                            : _glowAnimation
                                                            .value,
                                                      ),
                                                      blurRadius: 38,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),

                                          // Glass-style outer ring.
                                          Container(
                                            width: logoSize + 10,
                                            height: logoSize + 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withValues(
                                                alpha: 0.35,
                                              ),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(
                                                  alpha: 0.75,
                                                ),
                                                width: 1.3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _blue
                                                      .withValues(
                                                    alpha: 0.09,
                                                  ),
                                                  blurRadius: 24,
                                                  offset: const Offset(
                                                    0,
                                                    12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Inner premium logo surface.
                                          Container(
                                            width: logoSize,
                                            height: logoSize,
                                            padding:
                                            const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(
                                                logoSize * 0.29,
                                              ),
                                              gradient:
                                              const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white,
                                                  Color(0xFFE5EEFF),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _navy
                                                      .withValues(
                                                    alpha: 0.08,
                                                  ),
                                                  blurRadius: 20,
                                                  offset: const Offset(
                                                    0,
                                                    8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            child: reduceMotion
                                                ? const _PhoneMark(
                                              color: _navy,
                                            )
                                                : _AnimatedPhoneIcon(
                                              color: _navy,
                                            ),
                                          ),

                                          // Small decorative status dot.
                                          Positioned(
                                            bottom: 12,
                                            right: 8,
                                            child: Container(
                                              width: 25,
                                              height: 25,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFDCE8FF,
                                                  ),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _blue
                                                        .withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    blurRadius: 10,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                color: _blue,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 27),

                                    // Brand name.
                                    ShaderMask(
                                      shaderCallback: (bounds) {
                                        return const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF17356F),
                                            Color(0xFF3D5BB8),
                                          ],
                                        ).createShader(bounds);
                                      },
                                      child: const Text(
                                        'PhoneHub',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 39,
                                          height: 1.08,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.1,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 13),

                                    const Text(
                                      'Quality Phones, Better Prices',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF354A70),
                                        fontSize: AppText.subtitle,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),

                                    const SizedBox(height: 17),

                                    // Gradient accent line.
                                    Container(
                                      width: 68,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        gradient:
                                        const LinearGradient(
                                          colors: [
                                            Color(0xFF38D9FF),
                                            Color(0xFF3675FF),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _blue.withValues(
                                              alpha: 0.20,
                                            ),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 23),

                                    // Supporting brand message.
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        'Find your next favorite phone '
                                            'with confidence.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFF607392),
                                          fontSize: 13,
                                          height: 1.6,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(
                              height: screenSize.height < 700
                                  ? 30
                                  : 48,
                            ),

                            // Trust features and primary action.
                            FadeTransition(
                              opacity: _entranceAnimation,
                              child: Column(
                                children: [
                                  const Text(
                                    'SHOP WITH CONFIDENCE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF607392),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  const Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 10,
                                    children: [
                                      _FeaturePill(
                                        icon: Icons.verified_rounded,
                                        label: 'Verified',
                                      ),
                                      _FeaturePill(
                                        icon: Icons.shield_rounded,
                                        label: 'Warranty',
                                      ),
                                      _FeaturePill(
                                        icon: Icons.history_rounded,
                                        label: '7-day return',
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 30),

                                  // Premium call-to-action.
                                  SizedBox(
                                    width: double.infinity,
                                    height: 58,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF3675FF,
                                            ).withValues(alpha: 0.20),
                                            blurRadius: 25,
                                            offset: const Offset(0, 9),
                                          ),
                                          BoxShadow(
                                            color: _navy.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _getStarted,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: _navy,
                                          elevation: 0,
                                          padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 22,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(18),
                                            side: const BorderSide(
                                              color: Color(0xFFD9E6FF),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Get Started',
                                              style: TextStyle(
                                                fontSize: AppText.body,
                                                fontWeight:
                                                FontWeight.w800,
                                                letterSpacing: 0.25,
                                              ),
                                            ),
                                            const SizedBox(width: 13),
                                            Container(
                                              width: 31,
                                              height: 31,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                BorderRadius.circular(
                                                  10,
                                                ),
                                                gradient:
                                                const LinearGradient(
                                                  colors: [
                                                    Color(0xFF38D9FF),
                                                    Color(0xFF3675FF),
                                                  ],
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons
                                                    .arrow_forward_rounded,
                                                size: 19,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 17),

                                  // Subtle footer branding.
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons
                                            .verified_user_outlined,
                                        size: 14,
                                        color: _blue.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      const Flexible(
                                        child: Text(
                                          'Your next phone starts here',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF7183A1),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Animated phone icon
// -----------------------------------------------------------------------------

class _AnimatedPhoneIcon extends StatefulWidget {
  final Color color;

  const _AnimatedPhoneIcon({
    required this.color,
  });

  @override
  State<_AnimatedPhoneIcon> createState() =>
      _AnimatedPhoneIconState();
}

class _AnimatedPhoneIconState extends State<_AnimatedPhoneIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _tiltAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _tiltAnimation = Tween<double>(
      begin: -0.035,
      end: 0.035,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: Transform.rotate(
            angle: _tiltAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: _PhoneMark(color: widget.color),
            ),
          ),
        );
      },
    );
  }
}

class _PhoneMark extends StatelessWidget {
  final Color color;

  const _PhoneMark({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.phone_iphone_rounded,
      size: 72,
      color: color,
      semanticLabel: 'PhoneHub',
    );
  }
}

// -----------------------------------------------------------------------------
// Ambient glow orbs
// -----------------------------------------------------------------------------

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 70,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Decorative background dots
// -----------------------------------------------------------------------------

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.45,
        child: SizedBox(
          width: 66,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              18,
                  (_) => Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF55CFFF),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Glassmorphism feature badges
// -----------------------------------------------------------------------------

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFDCE8FF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3A9BFF)
                    .withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: const Color(0xFF2452B8),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF17356F),
                  fontSize: AppText.small,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}