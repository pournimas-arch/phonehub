import 'dart:ui';
import 'package:flutter/material.dart';
import 'login_screen.dart';

/// PhoneHub splash screen.
/// Keeps the original brand copy, feature badges, blue palette, and navigation.
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
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.18, end: 0.48).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      // Matched to the Home screen's light-blue gradient background.
      backgroundColor: const Color(0xFF7FADEE),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF4F8FF),
              Color(0xFFBBD5FB),
              Color(0xFF7FADEE),
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Ambient gradient pools and large translucent circles.
            Positioned(
              top: -screenSize.height * 0.11,
              right: -screenSize.width * 0.25,
              child: _GlowOrb(
                size: screenSize.width * 0.92,
                color: const Color(0xFF1E9BFF).withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              top: screenSize.height * 0.17,
              left: -screenSize.width * 0.42,
              child: _GlowOrb(
                size: screenSize.width * 0.76,
                color: const Color(0xFF1688FF).withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              bottom: -screenSize.height * 0.10,
              left: -screenSize.width * 0.18,
              child: _GlowOrb(
                size: screenSize.width * 1.05,
                color: const Color(0xFF245DFF).withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              top: screenSize.height * 0.18,
              right: 28,
              child: const _DotPattern(),
            ),
            Positioned(
              bottom: screenSize.height * 0.31,
              left: 24,
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
                        padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 4),
                            FadeTransition(
                              opacity: _entranceAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(_entranceAnimation),
                                child: Column(
                                  children: [
                                    AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _floatController,
                                        _glowController,
                                      ]),
                                      builder: (context, child) {
                                        return Transform.translate(
                                          offset: Offset(
                                            0,
                                            _floatAnimation.value,
                                          ),
                                          child: Container(
                                            width: 154,
                                            height: 154,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _cyan.withValues(
                                                    alpha: _glowAnimation.value,
                                                  ),
                                                  blurRadius: 42,
                                                  spreadRadius: 2,
                                                ),
                                                BoxShadow(
                                                  color: const Color(0xFF3D5BB8)
                                                      .withValues(alpha: 0.16),
                                                  blurRadius: 30,
                                                  offset: const Offset(0, 18),
                                                ),
                                              ],
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9FBFF),
                                                borderRadius:
                                                BorderRadius.circular(43),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.white,
                                                    Color(0xFFE5EEFF),
                                                  ],
                                                ),
                                              ),
                                              child: const _AnimatedPhoneIcon(
                                                color: _navy,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 30),
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFF17356F),
                                              Color(0xFF3D5BB8),
                                            ],
                                          ).createShader(bounds),
                                      child: const Text(
                                        'PhoneHub',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 38,
                                          height: 1.05,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 13),
                                    const Text(
                                      'Quality Phones, Better Prices',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF354A70),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.25,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      width: 76,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF38D9FF),
                                            Color(0xFF3675FF),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3675FF)
                                                .withValues(alpha: 0.28),
                                            blurRadius: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 54),
                            Column(
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 9,
                                  runSpacing: 12,
                                  children: const [
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
                                const SizedBox(height: 38),
                                SizedBox(
                                  width: double.infinity,
                                  height: 62,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF3675FF)
                                              .withValues(alpha: 0.18),
                                          blurRadius: 28,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 8),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF3D5BB8)
                                              .withValues(alpha: 0.12),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _navy,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(22),
                                          side: const BorderSide(
                                            color: Color(0xFFD9E6FF),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const LoginScreen(),
                                            ),
                                          ),
                                      child: const Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get Started',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.15,
                                            ),
                                          ),
                                          SizedBox(width: 14),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
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

class _AnimatedPhoneIcon extends StatefulWidget {
  final Color color;

  const _AnimatedPhoneIcon({required this.color});

  @override
  State<_AnimatedPhoneIcon> createState() => _AnimatedPhoneIconState();
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
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);

    _tiltAnimation = Tween<double>(begin: -0.045, end: 0.045).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
      builder: (context, child) => Center(
        child: Transform.rotate(
          angle: _tiltAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.phone_iphone_rounded,
              size: 72,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
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
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFDCE8FF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3A9BFF).withValues(alpha: 0.10),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF2452B8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF17356F),
                  fontSize: 11.5,
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
