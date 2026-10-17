import 'package:flutter/material.dart';
import 'package:phonehub/delivery%20partner/login_screen.dart';

import 'app_theme_notifier.dart';
import 'customer/theme.dart' as customer_theme;
import 'customer/splash_screen.dart' as customer_app;
import 'Admin/auth_screen.dart' as admin_app;
import 'Admin/admin_theme.dart' as admin_theme;
import 'package:phonehub/app_text.dart';
import 'package:phonehub/delivery%20partner/splash_screen.dart'
as delivery_app;

// Each app lives in its own folder; the prefixes avoid name clashes
// (both have AppColors, MainShell, rupee, buildTheme ...).

/// First screen: choose which app to open.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    // One calm entrance when the screen opens.
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // Reset to the neutral theme whenever we come back to this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appTheme.value = neutralTheme();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _open(ThemeData theme, Widget screen) {
    appTheme.value = theme;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Everything scales with screen width, within safe limits,
    // so text never looks oversized on small phones or tiny on tablets.
    final s = (size.width / 390).clamp(0.85, 1.2);

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.1,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0D2E),
        body: Stack(
          children: [
            const _Backdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 22 * s, vertical: 20 * s),
                            child: FadeTransition(
                              opacity: CurvedAnimation(
                                  parent: _intro, curve: Curves.easeOut),
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: _intro,
                                    curve: Curves.easeOutCubic)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _Header(s: s),
                                    SizedBox(height: 28 * s),
                                    _RoleCard(
                                      s: s,
                                      icon: Icons.shopping_bag_rounded,
                                      colors: const [
                                        Color(0xFF818CF8),
                                        Color(0xFF4F46E5)
                                      ],
                                      title: 'Customer',
                                      subtitle:
                                      'Browse, buy and track second-hand phones',
                                      onTap: () => _open(
                                        customer_theme.buildTheme(),
                                        const customer_app.SplashScreen(),
                                      ),
                                    ),
                                    SizedBox(height: 12 * s),
                                    _RoleCard(
                                      s: s,
                                      icon: Icons.two_wheeler_rounded,
                                      colors: const [
                                        Color(0xFF2DD4BF),
                                        Color(0xFF0F766E)
                                      ],
                                      title: 'Delivery Partner',
                                      subtitle:
                                      'Manage deliveries, navigate and track earnings',
                                      onTap: () => _open(
                                        customer_theme.buildTheme(),
                                        delivery_app.SplashScreen(
                                          onFinished: () {
                                            if (!mounted) return;

                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const LoginScreen(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12 * s),
                                    _RoleCard(
                                      s: s,
                                      icon: Icons.admin_panel_settings_rounded,
                                      colors: const [
                                        Color(0xFFFBBF24),
                                        Color(0xFFB45309)
                                      ],
                                      title: 'Admin',
                                      subtitle:
                                      'Manage products, orders, customers and deliveries',
                                      onTap: () => _open(
                                        admin_theme.buildAdminTheme(),
                                        const admin_app.AdminSplashScreen(),
                                      ),
                                    ),
                                    SizedBox(height: 22 * s),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.verified_user_outlined,
                                            size: 13 * s,
                                            color: Colors.white54),
                                        SizedBox(width: 6 * s),
                                        Text(
                                          'Verified, quality-checked phones',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: AppText.small * s,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

/// Soft glowing background: deep indigo with two blurred colour pools.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17144A), Color(0xFF0F0D2E), Color(0xFF0B0A22)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -100,
              child: _Glow(color: const Color(0xFF6D5BFF), size: 320),
            ),
            Positioned(
              bottom: -140,
              left: -120,
              child: _Glow(color: const Color(0xFF0F766E), size: 340),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double s;
  const _Header({required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64 * s,
          height: 64 * s,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20 * s),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFE0E0FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D5BFF).withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.phone_iphone_rounded,
              size: 34 * s, color: const Color(0xFF4F46E5)),
        ),
        SizedBox(height: 14 * s),
        Text(
          'PhoneHub',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26 * s,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 4 * s),
        Text(
          'Choose how you want to continue',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: AppText.body * s,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatefulWidget {
  final double s;
  final IconData icon;
  final List<Color> colors;
  final String title, subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.s,
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final accent = widget.colors.last;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22 * s),
          // Frosted-glass look: translucent fill plus a faint light edge.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22 * s),
            splashColor: accent.withValues(alpha: 0.18),
            highlightColor: Colors.transparent,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.all(14 * s),
              child: Row(
                children: [
                  Container(
                    width: 48 * s,
                    height: 48 * s,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15 * s),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.colors,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 24 * s),
                  ),
                  SizedBox(width: 14 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: AppText.subtitle * s,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3 * s),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppText.small * s,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8 * s),
                  Container(
                    padding: EdgeInsets.all(6 * s),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 15 * s),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}