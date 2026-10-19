import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';
import 'admin_shell.dart';
import 'admin_auth_service.dart';
import 'package:phonehub/app_text.dart';

// ---------------------------------------------------------------------------
// Shared helpers (colors come only from AC.* and adminGradient)
// ---------------------------------------------------------------------------

const Color _pageBg = Color(0xFFF7F8FD);

/// Scale factor so sizes follow the screen width without getting too big/small.
double _scale(BuildContext context) => (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.2).toDouble();

/// Keeps system font scaling in a sensible range.
Widget _fit(Widget child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.1, child: child);

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

final RegExp _emailFormat = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

bool _validEmail(String? v) {
  if (v == null) return false;
  final s = v.trim();
  if (s.isEmpty || s.length > 254 || s.contains('..') || s.contains(' ')) return false;
  final local = s.split('@').first;
  if (local.length > 64 || local.startsWith('.') || local.endsWith('.')) return false;
  return _emailFormat.hasMatch(s);
}

final RegExp _nameFormat = RegExp(r"^\p{L}[\p{L}\p{M} .'\-]*$", unicode: true);

String? _checkAdminName(String? v) {
  final s = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return 'Enter your full name';
  if (s.length < 2) return 'Name is too short';
  if (s.length > 50) return 'Name can be at most 50 characters';
  if (!_nameFormat.hasMatch(s)) return 'Use letters only (spaces, . \' - allowed)';
  if (RegExp(r'(.)\1{3,}').hasMatch(s)) return 'Enter your real name';
  return null;
}

String? _checkAdminMobile(String? v) {
  final d = v ?? '';
  if (d.isEmpty) return 'Enter your mobile number';
  if (!RegExp(r'^[0-9]{10}$').hasMatch(d)) return 'Enter a 10 digit mobile number';
  if (!RegExp(r'^[6-9]').hasMatch(d)) return 'Mobile number must start with 6, 7, 8 or 9';
  if (RegExp(r'^(\d)\1{9}$').hasMatch(d)) return 'Enter a real mobile number';
  return null;
}

String? _checkAdminPassword(String? v, {String name = '', String email = ''}) {
  final p = v ?? '';
  if (p.isEmpty) return 'Create a password';
  if (p.length < 8) return 'Use at least 8 characters';
  if (p.length > 64) return 'Password can be at most 64 characters';
  if (RegExp(r'\s').hasMatch(p)) return 'Password cannot contain spaces';
  if (!(RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'[0-9]').hasMatch(p))) return 'Include letters and numbers';
  if (RegExp(r'^(.)\1+$').hasMatch(p)) return 'Password is too easy to guess';
  const common = ['password1', 'password123', 'admin123', 'admin1234', 'qwerty123', 'abcd1234', '12345678a', 'welcome123', 'phonehub123'];
  if (common.contains(p.toLowerCase())) return 'Password is too common. Choose another';
  final local = email.trim().split('@').first.toLowerCase();
  if (local.length >= 4 && p.toLowerCase().contains(local)) return 'Password should not contain your email name';
  return null;
}

/// Soft translucent circles (used on the gradient header / splash).
class _Bubbles extends StatelessWidget {
  const _Bubbles();

  Widget _dot(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(top: -70, right: -50, child: _dot(210, 0.07)),
            Positioned(top: 90, left: -60, child: _dot(130, 0.05)),
            Positioned(bottom: -50, right: 50, child: _dot(110, 0.06)),
          ],
        ),
      ),
    );
  }
}

/// Small frosted icon tile that "floats" on the gradient (retail feel).
class _FloatChip extends StatelessWidget {
  final IconData icon;
  final double s;
  final double size;
  final bool accent;
  const _FloatChip({required this.icon, required this.s, this.size = 38, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * s,
      height: size * s,
      decoration: BoxDecoration(
        color: accent ? AC.accent : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32 * s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: accent ? [BoxShadow(color: AC.accent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))] : null,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52 * s),
    );
  }
}

/// Small pill with icon + label shown under the header text.
class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final double s;
  const _Tag({required this.icon, required this.label, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * s, color: Colors.white),
          SizedBox(width: 5 * s),
          Text(label, style: TextStyle(fontSize: AppText.small * s, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// PhoneHub logo for the gradient header: white tile + wordmark.
class _Logo extends StatelessWidget {
  final double s;
  const _Logo({required this.s});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42 * s,
          height: 42 * s,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13 * s),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Icon(Icons.phone_iphone_rounded, color: AC.primary, size: 24 * s),
        ),
        SizedBox(width: 10 * s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
                children: const [
                  TextSpan(text: 'Phone'),
                  TextSpan(text: 'Hub', style: TextStyle(color: AC.accent)),
                ],
              ),
            ),
            Text('Second-hand phones', style: TextStyle(fontSize: AppText.small * s, color: Colors.white70)),
          ],
        ),
      ],
    );
  }
}

/// Gradient header with logo, headline and floating retail icons.
class _Hero extends StatelessWidget {
  final double s;
  final String eyebrow;
  final String title;
  final String subtitle;
  final double titleSize;
  final VoidCallback? onBack;
  final List<IconData> icons;
  final List<_Tag> tags;
  const _Hero({
    required this.s,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icons,
    this.titleSize = 26,
    this.onBack,
    this.tags = const [],
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final radius = BorderRadius.vertical(bottom: Radius.circular(36 * s));
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: adminGradient, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const _Bubbles(),
            Positioned(right: 22 * s, top: top + 62 * s, child: _FloatChip(icon: icons[0], s: s, size: 46)),
            Positioned(right: 80 * s, top: top + 104 * s, child: _FloatChip(icon: icons[1], s: s, size: 32)),
            Positioned(right: 34 * s, top: top + 124 * s, child: _FloatChip(icon: icons[2], s: s, size: 30, accent: true)),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24 * s, top + 14 * s, 24 * s, 66 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (onBack != null) ...[
                            IconButton(
                              onPressed: onBack,
                              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.16)),
                              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18 * s, color: Colors.white),
                            ),
                            SizedBox(width: 8 * s),
                          ],
                          _Logo(s: s),
                        ],
                      ),
                      SizedBox(height: 20 * s),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
                        decoration: BoxDecoration(color: AC.accent, borderRadius: BorderRadius.circular(20)),
                        child: Text(eyebrow, style: TextStyle(color: Colors.white, fontSize: AppText.caption * s, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      ),
                      SizedBox(height: 10 * s),
                      Padding(
                        padding: EdgeInsets.only(right: 96 * s),
                        child: Text(title, style: TextStyle(color: Colors.white, fontSize: titleSize * s, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
                      ),
                      SizedBox(height: 6 * s),
                      Padding(
                        padding: EdgeInsets.only(right: 70 * s),
                        child: Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: AppText.small * s, height: 1.4)),
                      ),
                      if (tags.isNotEmpty) ...[
                        SizedBox(height: 14 * s),
                        Wrap(spacing: 8 * s, runSpacing: 8 * s, children: tags),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White form card that overlaps the gradient header.
class _AuthCard extends StatelessWidget {
  final double s;
  final Widget child;
  const _AuthCard({required this.s, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20 * s, 24 * s, 20 * s, 20 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28 * s),
        border: Border.all(color: AC.border),
        boxShadow: [BoxShadow(color: AC.primary.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: child,
    );
  }
}

/// Page frame: gradient header on top, form card sliding over it.
class _AuthPage extends StatelessWidget {
  final double s;
  final Widget hero;
  final Widget card;
  final Widget? footer;
  const _AuthPage({required this.s, required this.hero, required this.card, this.footer});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              hero,
              Transform.translate(
                offset: Offset(0, -44 * s),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16 * s),
                      child: Column(children: [card, if (footer != null) footer!]),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- form building blocks --------------------------------------------------

InputDecoration _fieldDeco(double s, String hint, IconData icon, {Widget? suffix, Widget? extra}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14 * s),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: AppText.body * s, color: AC.muted.withValues(alpha: 0.7)),
    prefixIcon: Padding(
      padding: EdgeInsets.only(left: 14 * s, right: 10 * s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20 * s, color: AC.primary),
          if (extra != null) ...[SizedBox(width: 8 * s), extra],
        ],
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: AC.bg,
    contentPadding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 16 * s),
    counterText: '',
    border: border(AC.border),
    enabledBorder: border(AC.border),
    focusedBorder: border(AC.primary, 1.6),
    errorBorder: border(AC.danger),
    focusedErrorBorder: border(AC.danger, 1.6),
    errorStyle: TextStyle(fontSize: AppText.small * s),
  );
}

Widget _labeled(double s, String label, Widget field) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: EdgeInsets.only(left: 2 * s, bottom: 6 * s),
      child: Text(label, style: TextStyle(fontSize: AppText.small * s, fontWeight: FontWeight.w700, color: AC.text)),
    ),
    field,
  ],
);

Widget _cardTitle(double s, String title, String sub) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(title, style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w800, color: AC.text, letterSpacing: -0.3)),
    SizedBox(height: 4 * s),
    Text(sub, style: TextStyle(fontSize: AppText.small * s, color: AC.muted, height: 1.4)),
  ],
);

Widget _sectionTitle(double s, IconData icon, String text) => Row(
  children: [
    Container(
      padding: EdgeInsets.all(6 * s),
      decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9 * s)),
      child: Icon(icon, size: 15 * s, color: AC.primary),
    ),
    SizedBox(width: 8 * s),
    Text(text, style: TextStyle(fontSize: AppText.body * s, fontWeight: FontWeight.w800, color: AC.text)),
  ],
);

Widget _errorBox(double s, String text) => Container(
  width: double.infinity,
  margin: EdgeInsets.only(bottom: 12 * s),
  padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
  decoration: BoxDecoration(
    color: AC.danger.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12 * s),
    border: Border.all(color: AC.danger.withValues(alpha: 0.25)),
  ),
  child: Row(
    children: [
      Icon(Icons.error_outline_rounded, color: AC.danger, size: 18 * s),
      SizedBox(width: 8 * s),
      Expanded(child: Text(text, style: TextStyle(color: AC.danger, fontWeight: FontWeight.w600, fontSize: AppText.small * s))),
    ],
  ),
);

Widget _infoBox(double s, IconData icon, String text, {Color? color}) {
  final c = color ?? AC.primary;
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(12 * s),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14 * s),
      border: Border.all(color: c.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18 * s, color: c),
        SizedBox(width: 10 * s),
        Expanded(child: Text(text, style: TextStyle(fontSize: AppText.small * s, color: AC.text, height: 1.4))),
      ],
    ),
  );
}

Widget _spinner(double s) => SizedBox(width: 20 * s, height: 20 * s, child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white));

/// Gradient pill button (matches the header).
class _PrimaryButton extends StatelessWidget {
  final double s;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  const _PrimaryButton({required this.s, required this.label, required this.onPressed, this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;
    final radius = BorderRadius.circular(16 * s);
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        width: double.infinity,
        height: 54 * s,
        decoration: BoxDecoration(
          gradient: adminGradient,
          borderRadius: radius,
          boxShadow: disabled ? null : [BoxShadow(color: AC.primary.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? _spinner(s)
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: Colors.white, fontSize: AppText.subtitle * s, fontWeight: FontWeight.w700)),
                  if (icon != null) ...[SizedBox(width: 8 * s), Icon(icon, color: Colors.white, size: 20 * s)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _outlineButton(double s, String text, IconData icon, VoidCallback? onPressed) => SizedBox(
  width: double.infinity,
  height: 46 * s,
  child: OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18 * s),
    label: Text(text),
    style: OutlinedButton.styleFrom(
      foregroundColor: AC.primary,
      minimumSize: Size(0, 46 * s),
      side: BorderSide(color: AC.primary.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * s)),
      textStyle: TextStyle(fontSize: AppText.body * s, fontWeight: FontWeight.w700),
    ),
  ),
);

// GOOGLE: "Continue with Google" button (white, outlined, shows a spinner while loading).
Widget _googleButton(double s, VoidCallback? onPressed, bool loading) => SizedBox(
  width: double.infinity,
  height: 50 * s,
  child: OutlinedButton(
    onPressed: loading ? null : onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AC.text,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AC.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * s)),
    ),
    child: loading
        ? SizedBox(width: 20 * s, height: 20 * s, child: const CircularProgressIndicator(strokeWidth: 2.4))
        : Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Replace with the official logo: Image.asset('assets/google_g.png', height: 20 * s)
        Text('G', style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w800, color: const Color(0xFF4285F4))),
        SizedBox(width: 10 * s),
        Text('Continue with Google', style: TextStyle(fontSize: AppText.body * s, fontWeight: FontWeight.w700)),
      ],
    ),
  ),
);

TextButton _linkButton(double s, String text, VoidCallback? onPressed) => TextButton(
  onPressed: onPressed,
  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 6 * s), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
  child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.small * s)),
);

Widget _dividerLabel(double s, String text) => Row(
  children: [
    const Expanded(child: Divider(color: AC.border)),
    Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      child: Text(text, style: TextStyle(fontSize: AppText.small * s, color: AC.muted)),
    ),
    const Expanded(child: Divider(color: AC.border)),
  ],
);

/// Small trust badges shown under the card.
class _TrustRow extends StatelessWidget {
  final double s;
  const _TrustRow({required this.s});

  Widget _item(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15 * s, color: AC.muted),
      SizedBox(width: 5 * s),
      Text(text, style: TextStyle(fontSize: AppText.small * s, color: AC.muted, fontWeight: FontWeight.w600)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 18 * s),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16 * s,
        runSpacing: 8 * s,
        children: [
          _item(Icons.lock_outline_rounded, 'Encrypted sign-in'),
          _item(Icons.verified_user_outlined, 'Admin only'),
          _item(Icons.bolt_rounded, 'Fast & reliable'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Splash
// ---------------------------------------------------------------------------

/// Splash: logo + tagline + live status, then goes to Login (or the dashboard
/// when the admin chose "Remember me" and is still signed in).
class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  String _status = 'Starting up…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _status = 'Checking your session…');
    bool signedIn = false;
    try {
      signedIn = await AdminAuthService.instance.restoreSession();
    } catch (_) {
      signedIn = false;
    }
    final wait = const Duration(milliseconds: 2000) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future.delayed(wait);
    if (!mounted) return;
    setState(() => _status = signedIn ? 'Opening your dashboard…' : 'Ready to sign in');
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => signedIn ? const AdminShell() : const AdminLoginScreen()),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    return _fit(
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: adminGradient),
            child: Stack(
              children: [
                const _Bubbles(),
                Align(alignment: const Alignment(-0.78, -0.50), child: _FloatChip(icon: Icons.shopping_bag_rounded, s: s, size: 44)),
                Align(alignment: const Alignment(0.80, -0.38), child: _FloatChip(icon: Icons.smartphone_rounded, s: s, size: 36)),
                Align(alignment: const Alignment(-0.62, 0.50), child: _FloatChip(icon: Icons.local_shipping_rounded, s: s, size: 34)),
                Align(alignment: const Alignment(0.70, 0.55), child: _FloatChip(icon: Icons.payments_rounded, s: s, size: 40, accent: true)),
                Center(
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.88, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 92 * s,
                            height: 92 * s,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28 * s),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 28, offset: const Offset(0, 12))],
                            ),
                            child: Icon(Icons.admin_panel_settings_rounded, size: 48 * s, color: AC.primary),
                          ),
                          SizedBox(height: 20 * s),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 28 * s, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
                              children: const [
                                TextSpan(text: 'Phone'),
                                TextSpan(text: 'Hub', style: TextStyle(color: AC.accent)),
                              ],
                            ),
                          ),
                          SizedBox(height: 8 * s),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
                            decoration: BoxDecoration(color: AC.accent, borderRadius: BorderRadius.circular(20)),
                            child: Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: AppText.small * s, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                          ),
                          SizedBox(height: 14 * s),
                          Text('Manage your store, anywhere', style: TextStyle(color: Colors.white70, fontSize: AppText.small * s)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 64 * s,
                  right: 64 * s,
                  bottom: MediaQuery.of(context).padding.bottom + 40 * s,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(_status, key: ValueKey(_status), style: TextStyle(color: Colors.white70, fontSize: AppText.small * s)),
                      ),
                      SizedBox(height: 12 * s),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 2200),
                        builder: (_, v, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
                        ),
                      ),
                      SizedBox(height: 14 * s),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 13 * s, color: Colors.white60),
                          SizedBox(width: 5 * s),
                          Text('Secure admin console', style: TextStyle(color: Colors.white60, fontSize: AppText.caption * s)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

/// Admin login (email + password, or Google).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with SingleTickerProviderStateMixin {
  static const int _maxFails = 5;
  static const int _lockSeconds = 30;

  final _svc = AdminAuthService.instance;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(text: _svc.rememberedEmail ?? '');
  final _pass = TextEditingController();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  Timer? _lockTimer;
  bool _hide = true, _loading = false, _remember = true, _checking = false;
  bool _googleLoading = false; // GOOGLE
  String? _error;
  int _fails = 0, _lockLeft = 0;

  @override
  void initState() {
    super.initState();
    _svc.refreshAdminExists().then((_) {
      if (mounted) setState(() {});
    });
  }

  String? get _errorText {
    if (_lockLeft > 0) return 'Too many failed attempts. Try again in ${_lockLeft}s.';
    if (_error == null) return null;
    final left = _maxFails - _fails;
    if (_fails >= 3 && left > 0) return '$_error ($left ${left == 1 ? 'attempt' : 'attempts'} left)';
    return _error;
  }

  void _startLock() {
    _fails = 0;
    setState(() => _lockLeft = _lockSeconds);
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _lockLeft--;
        if (_lockLeft <= 0) {
          _lockLeft = 0;
          _error = null;
          t.cancel();
        }
      });
    });
  }

  Future<void> _login() async {
    if (_lockLeft > 0 || _loading) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      _shake.forward(from: 0);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _svc.login(_email.text, _pass.text);
    if (!mounted) return;
    if (err == null) {
      await _svc.setRememberedEmail(_remember ? _email.text.trim() : null);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminShell()));
      return;
    }
    _shake.forward(from: 0);
    setState(() {
      _loading = false;
      _error = err;
      if (err != 'No internet connection') _fails++;
    });
    if (_fails >= _maxFails) _startLock();
  }

  // GOOGLE: sign in with a Google account (admin account only).
  Future<void> _googleLogin() async {
    if (_lockLeft > 0 || _loading || _googleLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    final err = await _svc.loginWithGoogle(remember: _remember);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminShell()));
      return;
    }
    if (err != 'cancelled') _shake.forward(from: 0);
    setState(() {
      _googleLoading = false;
      _error = err == 'cancelled' ? null : err; // closing the popup shows no error
    });
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRegisterScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _retryCheck() async {
    setState(() => _checking = true);
    await _svc.refreshAdminExists();
    if (mounted) setState(() => _checking = false);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _shake.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final locked = _lockLeft > 0;
    final errText = _errorText;

    final form = AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(s, 'Sign in', 'Use your admin email and password to continue.'),
            SizedBox(height: 18 * s),
            if (!_svc.adminKnown) ...[
              _infoBox(s, Icons.cloud_off_rounded, 'Could not check the store setup. Check your internet connection.', color: AC.accent),
              Align(alignment: Alignment.centerRight, child: _linkButton(s, _checking ? 'Checking…' : 'Retry', _checking ? null : _retryCheck)),
              SizedBox(height: 6 * s),
            ],
            _labeled(
              s,
              'Email address',
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(254),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (v) => _validEmail(v) ? null : 'Enter a valid email',
                decoration: _fieldDeco(s, 'admin@yourstore.com', Icons.email_outlined),
              ),
            ),
            SizedBox(height: 14 * s),
            _labeled(
              s,
              'Password',
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                decoration: _fieldDeco(
                  s,
                  'Enter your password',
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10 * s),
            Row(
              children: [
                SizedBox(
                  width: 24 * s,
                  height: 24 * s,
                  child: Checkbox(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                SizedBox(width: 8 * s),
                GestureDetector(
                  onTap: () => setState(() => _remember = !_remember),
                  child: Text('Remember me', style: TextStyle(fontSize: AppText.small * s, color: AC.text)),
                ),
                const Spacer(),
                if (!_svc.canRegister)
                  _linkButton(
                    s,
                    'Forgot password?',
                        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminForgotPasswordScreen(initialEmail: _email.text.trim()))),
                  ),
              ],
            ),
            SizedBox(height: 16 * s),
            if (errText != null) _errorBox(s, errText),
            _PrimaryButton(

              s: s,
              label: locked ? 'Locked · ${_lockLeft}s' : 'Login',
              icon: locked ? Icons.lock_clock_rounded : Icons.arrow_forward_rounded,
              loading: _loading,
              onPressed: locked ? null : _login,
            ),
            SizedBox(height: 20 * s),
            // GOOGLE: shown only when an admin exists and the form is not locked.
            if (!locked) ...[
              _dividerLabel(s, 'or'),
              SizedBox(height: 14 * s),
              _googleButton(s, _googleLogin, _googleLoading),
              SizedBox(height: 20 * s),
            ],
            if (_svc.canRegister) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14 * s),
                decoration: BoxDecoration(
                  color: AC.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16 * s),
                  border: Border.all(color: AC.accent.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rocket_launch_rounded, size: 18 * s, color: AC.accent),
                        SizedBox(width: 8 * s),
                        Text('First time here?', style: TextStyle(fontSize: AppText.body * s, fontWeight: FontWeight.w800, color: AC.text)),
                      ],
                    ),
                    SizedBox(height: 6 * s),
                    Text('No admin account exists yet. Create it now to start managing your store.', style: TextStyle(fontSize: AppText.small * s, color: AC.muted, height: 1.4)),
                    SizedBox(height: 12 * s),
                    _outlineButton(s, 'Create admin account', Icons.person_add_alt_1_rounded, _openRegister),
                  ],
                ),
              ),
            ] else
              _dividerLabel(s, 'Admin access only'),
          ],
        ),
      ),
    );

    return _fit(
      _AuthPage(
        s: s,
        hero: _Hero(
          s: s,
          eyebrow: 'ADMIN PANEL',
          title: '${_greeting()} 👋',
          subtitle: 'Welcome back! Sign in to manage your store.',
          icons: const [Icons.shopping_bag_rounded, Icons.smartphone_rounded, Icons.payments_rounded],
          tags: [
            _Tag(icon: Icons.receipt_long_rounded, label: 'Orders', s: s),
            _Tag(icon: Icons.inventory_2_rounded, label: 'Products', s: s),
            _Tag(icon: Icons.groups_rounded, label: 'Customers', s: s),
          ],
        ),
        card: AnimatedBuilder(
          animation: _shake,
          builder: (_, child) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 9 * s, 0),
            child: child,
          ),
          child: _AuthCard(s: s, child: form),
        ),
        footer: _TrustRow(s: s),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register (the one and only admin)
// ---------------------------------------------------------------------------

/// Admin registration. Only possible while no admin exists.
class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _svc = AdminAuthService.instance;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true, _hide2 = true, _loading = false, _agree = false, _termsError = false;
  String? _error;

  bool get _longEnough => _pass.text.length >= 8;
  bool get _hasLetter => RegExp(r'[A-Za-z]').hasMatch(_pass.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_pass.text);
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_pass.text);
  bool get _hasSpecial => RegExp(r'[^A-Za-z0-9]').hasMatch(_pass.text);

  int get _strength => [_longEnough, _hasUpper, _hasNumber, _hasSpecial].where((e) => e).length;

  Future<void> _register() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final valid = _form.currentState!.validate();
    if (!_agree) setState(() => _termsError = true);
    if (!valid || !_agree) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final err = await _svc.register(name: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '), email: _email.text.trim(), phone: _phone.text, password: _pass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    TextInput.finishAutofillContext();
    snack(context, 'Welcome, ${_name.text.trim()}!');
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminShell()), (r) => r.isFirst);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _req(double s, bool ok, String text) => Padding(
    padding: EdgeInsets.only(top: 4 * s),
    child: Row(
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 15 * s, color: ok ? AC.success : AC.muted),
        SizedBox(width: 6 * s),
        Text(text, style: TextStyle(fontSize: AppText.small * s, color: ok ? AC.text : AC.muted)),
      ],
    ),
  );

  Widget _strengthMeter(double s) {
    final labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [AC.border, AC.danger, AC.accent, AC.primary, AC.success];
    final v = _pass.text.isEmpty ? 0 : _strength;
    return Padding(
      padding: EdgeInsets.only(top: 10 * s, left: 2 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < 4; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(color: i < v ? colors[v] : AC.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              SizedBox(width: 10 * s),
              Text(_pass.text.isEmpty ? '' : labels[v], style: TextStyle(fontSize: AppText.small * s, color: AC.muted, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_pass.text.isNotEmpty) ...[
            SizedBox(height: 4 * s),
            _req(s, _longEnough, 'At least 8 characters'),
            _req(s, _hasLetter && _hasNumber, 'Letters and numbers'),
            _req(s, _hasUpper, 'An uppercase letter (stronger)'),
            _req(s, _hasSpecial, 'A special character like @ # ! (stronger)'),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    final form = AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(s, 'Set up your store', 'Create the one admin account that manages products, orders and customers.'),
            SizedBox(height: 18 * s),
            _sectionTitle(s, Icons.person_outline_rounded, 'Your details'),
            SizedBox(height: 12 * s),
            _labeled(
              s,
              'Full name',
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(50),
                  FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{M} .'\-]", unicode: true)),
                ],
                validator: _checkAdminName,
                decoration: _fieldDeco(s, 'Enter your full name', Icons.person_outline_rounded),
              ),
            ),
            SizedBox(height: 12 * s),
            _labeled(
              s,
              'Email address',
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(254),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (v) => _validEmail(v) ? null : 'Enter a valid email',
                decoration: _fieldDeco(s, 'admin@yourstore.com', Icons.email_outlined),
              ),
            ),
            SizedBox(height: 12 * s),
            _labeled(
              s,
              'Mobile number',
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                validator: _checkAdminMobile,
                decoration: _fieldDeco(
                  s,
                  '10 digit mobile number',
                  Icons.phone_outlined,
                  extra: Text('+91', style: TextStyle(fontSize: AppText.body * s, color: AC.text, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            SizedBox(height: 20 * s),
            _sectionTitle(s, Icons.shield_outlined, 'Secure your account'),
            SizedBox(height: 12 * s),
            _labeled(
              s,
              'Password',
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(64),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (v) => _checkAdminPassword(v, name: _name.text, email: _email.text),
                decoration: _fieldDeco(
                  s,
                  'Create a strong password',
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
            ),
            _strengthMeter(s),
            SizedBox(height: 12 * s),
            _labeled(
              s,
              'Confirm password',
              TextFormField(
                controller: _confirm,
                obscureText: _hide2,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _register(),
                style: TextStyle(fontSize: AppText.body * s, color: AC.text),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(64),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (v) => (v == null || v.isEmpty) ? 'Re-enter your password' : (v != _pass.text ? 'Passwords do not match' : null),
                decoration: _fieldDeco(
                  s,
                  'Re-enter your password',
                  Icons.lock_outline_rounded,
                  suffix: IconButton(
                    icon: Icon(_hide2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
                    onPressed: () => setState(() => _hide2 = !_hide2),
                  ),
                ),
              ),
            ),
            SizedBox(height: 14 * s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24 * s,
                  height: 24 * s,
                  child: Checkbox(
                    value: _agree,
                    onChanged: (v) => setState(() {
                      _agree = v ?? false;
                      if (_agree) _termsError = false;
                    }),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    side: BorderSide(color: _termsError ? AC.danger : AC.muted, width: 1.5),
                  ),
                ),
                SizedBox(width: 8 * s),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _agree = !_agree;
                      if (_agree) _termsError = false;
                    }),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: AppText.small * s, color: AC.muted, height: 1.4),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(text: 'Terms of Service', style: TextStyle(fontWeight: FontWeight.w700, color: AC.text)),
                          TextSpan(text: ' and '),
                          TextSpan(text: 'Privacy Policy', style: TextStyle(fontWeight: FontWeight.w700, color: AC.text)),
                          TextSpan(text: ' of PhoneHub.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_termsError)
              Padding(
                padding: EdgeInsets.only(top: 6 * s, left: 32 * s),
                child: Text('Please accept to continue', style: TextStyle(fontSize: AppText.small * s, color: AC.danger)),
              ),
            SizedBox(height: 18 * s),
            if (_error != null) _errorBox(s, _error!),
            _PrimaryButton(s: s, label: 'Create account', icon: Icons.arrow_forward_rounded, loading: _loading, onPressed: _register),
            SizedBox(height: 10 * s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account?', style: TextStyle(color: AC.muted, fontSize: AppText.small * s)),
                _linkButton(s, 'Login', () => Navigator.pop(context)),
              ],
            ),
          ],
        ),
      ),
    );

    return _fit(
      _AuthPage(
        s: s,
        hero: _Hero(
          s: s,
          eyebrow: 'ADMIN REGISTRATION',
          title: 'Create Admin Account',
          titleSize: 22,
          subtitle: 'Set up the one admin account that runs your store.',
          onBack: () => Navigator.pop(context),
          icons: const [Icons.storefront_rounded, Icons.person_add_alt_1_rounded, Icons.workspace_premium_rounded],
          tags: [_Tag(icon: Icons.lock_outline_rounded, label: 'One admin account only', s: s)],
        ),
        card: _AuthCard(s: s, child: form),
        footer: _TrustRow(s: s),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot password (OTP flow)
// ---------------------------------------------------------------------------

/// Forgot password with a 6-digit OTP instead of an emailed link.
///
/// Stages:
///   0 = enter email  -> sends OTP
///   1 = enter OTP    -> verifies OTP
///   2 = new password -> resets password
///   3 = done         -> back to login
///
/// REQUIRES these 3 methods on [AdminAuthService] (each returns null on
/// success, or an error message String on failure):
///   Future<String?> sendPasswordOtp(String email)
///   Future<String?> verifyPasswordOtp(String email, String otp)
///   Future<String?> resetPasswordWithOtp({required String email, required String otp, required String newPassword})
class AdminForgotPasswordScreen extends StatefulWidget {
  /// Optional: e-mail typed on the login screen, filled in automatically.
  final String? initialEmail;
  const AdminForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<AdminForgotPasswordScreen> createState() => _AdminForgotPasswordScreenState();
}

class _AdminForgotPasswordScreenState extends State<AdminForgotPasswordScreen> {
  static const int _cooldownSeconds = 60;
  static const int _otpLength = 6;

  // ===========================================================================
  // TEST MODE - FOR TESTING ONLY
  // While _testMode is true, the OTP is NOT emailed and NOT checked by the
  // server: the fixed code _testOtp is accepted right here in the app, and
  // no Cloud Function is called. The password is NOT really changed.
  // !!! SET _testMode = false BEFORE RELEASING THE APP !!!
  // ===========================================================================
  static const bool _testMode = true;
  static const String _testOtp = '123456';

  final _svc = AdminAuthService.instance;
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail ?? '');
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  Timer? _timer;
  bool _busy = false, _hide = true, _hide2 = true;
  int _stage = 0;
  int _cooldown = 0;
  String? _err;

  // The email the OTP was actually sent to (so editing the field later can't change it).
  String _sentTo = '';

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldown = 0;
          t.cancel();
        }
      });
    });
  }

  // Stage 0 -> 1 (also used for "Send again")
  Future<void> _sendOtp({bool resend = false}) async {
    if (_busy) return;
    if (resend && _cooldown > 0) return;
    FocusScope.of(context).unfocus();
    final email = (resend ? _sentTo : _email.text).trim();
    if (!_validEmail(email)) {
      setState(() => _err = 'Enter a valid email address');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    if (_testMode) await Future.delayed(const Duration(milliseconds: 500));
    final err = _testMode ? null : await _svc.sendPasswordOtp(email);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _err = err;
      });
      return;
    }
    _sentTo = email;
    _otp.clear();
    setState(() {
      _busy = false;
      _stage = 1;
    });
    _startCooldown();
    if (resend) snack(context, 'A new OTP has been sent');
  }

  // Stage 1 -> 2
  Future<void> _verifyOtp() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final code = _otp.text.trim();
    if (code.length != _otpLength || !RegExp(r'^[0-9]+$').hasMatch(code)) {
      setState(() => _err = 'Enter the $_otpLength digit OTP');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    if (_testMode) await Future.delayed(const Duration(milliseconds: 400));
    final err = _testMode ? (code == _testOtp ? null : 'Wrong OTP. Use $_testOtp for testing') : await _svc.verifyPasswordOtp(_sentTo, code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) {
        _stage = 2;
      } else {
        _err = err;
      }
    });
  }

  // Stage 2 -> 3
  Future<void> _resetPassword() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final p = _pass.text;
    // same password rules as admin registration (length, spaces, easy / common passwords, email name)
    final passErr = _checkAdminPassword(p, email: _sentTo);
    if (passErr != null) {
      setState(() => _err = passErr);
      return;
    }
    if (_confirm.text.isEmpty) {
      setState(() => _err = 'Re-enter your password');
      return;
    }
    if (p != _confirm.text) {
      setState(() => _err = 'Passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    if (_testMode) await Future.delayed(const Duration(milliseconds: 500));
    final err = _testMode ? null : await _svc.resetPasswordWithOtp(email: _sentTo, otp: _otp.text.trim(), newPassword: p);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) {
        _stage = 3;
      } else {
        _err = err;
      }
    });
  }

  // Back to the email step.
  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _stage = 0;
      _err = null;
      _cooldown = 0;
      _otp.clear();
      _pass.clear();
      _confirm.clear();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _otp.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Three small bars showing which step the admin is on.
  Widget _progress(double s) => Padding(
    padding: EdgeInsets.only(bottom: 16 * s),
    child: Row(
      children: [
        for (int i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(color: i <= _stage ? AC.primary : AC.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
      ],
    ),
  );

  Widget _visibilityBtn(double s, bool hidden, VoidCallback onTap) => IconButton(
    icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
    onPressed: onTap,
  );

  // ---- stage 0: email ----
  Widget _emailStage(double s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _progress(s),
      _cardTitle(s, 'Reset your password', 'Enter your admin email and we will send you a 6 digit OTP.'),
      SizedBox(height: 18 * s),
      _labeled(
        s,
        'Email address',
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(254)],
          onChanged: (_) {
            if (_err != null) setState(() => _err = null);
          },
          onSubmitted: (_) => _sendOtp(),
          style: TextStyle(fontSize: AppText.body * s, color: AC.text),
          decoration: _fieldDeco(s, 'Enter your admin email', Icons.email_outlined),
        ),
      ),
      SizedBox(height: 18 * s),
      if (_err != null) _errorBox(s, _err!),
      _PrimaryButton(s: s, label: 'Send OTP', icon: Icons.send_rounded, loading: _busy, onPressed: _sendOtp),
      SizedBox(height: 10 * s),
      Center(child: _linkButton(s, 'Back to login', () => Navigator.pop(context))),
    ],
  );

  // ---- stage 1: OTP ----
  Widget _otpStage(double s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _progress(s),
      _cardTitle(s, 'Enter OTP', 'We sent a $_otpLength digit code to $_sentTo. It is valid for a few minutes.'),
      SizedBox(height: 18 * s),
      _labeled(
        s,
        'One-time password',
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          maxLength: _otpLength,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (_err != null) setState(() => _err = null);
            if (v.length == _otpLength) _verifyOtp();
          },
          onSubmitted: (_) => _verifyOtp(),
          style: TextStyle(fontSize: 26 * s, color: AC.text, fontWeight: FontWeight.w800, letterSpacing: 12 * s),
          decoration: _fieldDeco(s, '••••••', Icons.pin_outlined).copyWith(
            prefixIcon: null,
            contentPadding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 18 * s),
          ),
        ),
      ),
      SizedBox(height: 12 * s),
      _infoBox(
        s,
        _testMode ? Icons.bug_report_rounded : Icons.info_outline_rounded,
        _testMode ? 'TEST MODE: no email is sent. Use the OTP $_testOtp.' : 'Not there? Check your spam folder, or send the OTP again.',
        color: _testMode ? AC.accent : null,
      ),
      SizedBox(height: 18 * s),
      if (_err != null) _errorBox(s, _err!),
      _PrimaryButton(s: s, label: 'Verify OTP', icon: Icons.verified_rounded, loading: _busy, onPressed: _verifyOtp),
      SizedBox(height: 10 * s),
      Center(
        child: _linkButton(
          s,
          _cooldown > 0 ? 'Resend OTP in ${_cooldown}s' : 'Resend OTP',
          (_cooldown > 0 || _busy) ? null : () => _sendOtp(resend: true),
        ),
      ),
      Center(child: _linkButton(s, 'Use a different email', _changeEmail)),
    ],
  );

  // ---- stage 2: new password ----
  Widget _passwordStage(double s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _progress(s),
      _cardTitle(s, 'Create new password', 'OTP verified. Choose a new password for your admin account.'),
      SizedBox(height: 18 * s),
      _labeled(
        s,
        'New password',
        TextField(
          controller: _pass,
          obscureText: _hide,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(64)],
          onChanged: (_) {
            if (_err != null) setState(() => _err = null);
          },
          style: TextStyle(fontSize: AppText.body * s, color: AC.text),
          decoration: _fieldDeco(s, 'At least 8 characters', Icons.lock_outline_rounded, suffix: _visibilityBtn(s, _hide, () => setState(() => _hide = !_hide))),
        ),
      ),
      SizedBox(height: 12 * s),
      _labeled(
        s,
        'Confirm password',
        TextField(
          controller: _confirm,
          obscureText: _hide2,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(64)],
          onSubmitted: (_) => _resetPassword(),
          onChanged: (_) {
            if (_err != null) setState(() => _err = null);
          },
          style: TextStyle(fontSize: AppText.body * s, color: AC.text),
          decoration: _fieldDeco(s, 'Re-enter your password', Icons.lock_outline_rounded, suffix: _visibilityBtn(s, _hide2, () => setState(() => _hide2 = !_hide2))),
        ),
      ),
      SizedBox(height: 18 * s),
      if (_err != null) _errorBox(s, _err!),
      _PrimaryButton(s: s, label: 'Reset password', icon: Icons.check_rounded, loading: _busy, onPressed: _resetPassword),
    ],
  );

  // ---- stage 3: success ----
  Widget _doneStage(double s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 64 * s,
          height: 64 * s,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AC.success.withValues(alpha: 0.12)),
          child: Icon(Icons.check_circle_rounded, color: AC.success, size: 34 * s),
        ),
      ),
      SizedBox(height: 14 * s),
      Center(child: Text('Password updated', style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w800, color: AC.text, letterSpacing: -0.3))),
      SizedBox(height: 6 * s),
      Center(
        child: Text(
          _testMode
              ? 'TEST MODE: no real password change was made. Login with your current password.'
              : 'Your password was changed successfully. Login with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: AppText.small * s, color: AC.muted, height: 1.4),
        ),
      ),
      SizedBox(height: 20 * s),
      _PrimaryButton(s: s, label: 'Back to login', icon: Icons.arrow_forward_rounded, onPressed: () => Navigator.pop(context)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    final Widget body;
    switch (_stage) {
      case 0:
        body = _emailStage(s);
        break;
      case 1:
        body = _otpStage(s);
        break;
      case 2:
        body = _passwordStage(s);
        break;
      default:
        body = _doneStage(s);
    }

    final titles = ['Forgot Password?', 'Enter the OTP', 'New Password', 'All done!'];
    final subtitles = [
      'No worries, we will help you get back in.',
      'We sent a code to your email.',
      'Choose a strong new password.',
      'Your password has been reset.',
    ];
    final eyebrows = ['RESET PASSWORD', 'VERIFY OTP', 'NEW PASSWORD', 'SUCCESS'];
    final icons = <List<IconData>>[
      [Icons.lock_reset_rounded, Icons.mail_outline_rounded, Icons.verified_user_rounded],
      [Icons.pin_outlined, Icons.mark_email_read_rounded, Icons.verified_user_rounded],
      [Icons.password_rounded, Icons.lock_outline_rounded, Icons.verified_user_rounded],
      [Icons.check_circle_outline_rounded, Icons.lock_open_rounded, Icons.verified_user_rounded],
    ];

    return _fit(
      _AuthPage(
        s: s,
        hero: _Hero(
          s: s,
          eyebrow: eyebrows[_stage],
          title: titles[_stage],
          titleSize: 24,
          subtitle: subtitles[_stage],
          // From OTP/password stages, back goes one step; otherwise leaves the screen.
          onBack: (_stage == 0 || _stage == 3) ? () => Navigator.pop(context) : _changeEmail,
          icons: icons[_stage],
        ),
        card: _AuthCard(s: s, child: body),
        footer: _TrustRow(s: s),
      ),
    );
  }
}