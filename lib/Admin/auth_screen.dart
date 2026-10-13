import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';
import 'admin_shell.dart';
import 'admin_auth_service.dart';

// ---------------------------------------------------------------------------
// Shared helpers (colors come only from AC.* and adminGradient)
// ---------------------------------------------------------------------------

const Color _pageBg = Color(0xFFF7F8FD);

/// Scale factor so sizes follow the screen width without getting too big/small.
double _scale(BuildContext context) => (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.2).toDouble();

/// Keeps system font scaling in a sensible range.
Widget _fit(Widget child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.1, child: child);

/// Soft translucent circles (used on the splash gradient).
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

/// Light page background with soft waves at the top-right and bottom.
class _WavesPainter extends CustomPainter {
  final Color color;
  const _WavesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final top = Path()
      ..moveTo(w * 0.30, 0)
      ..quadraticBezierTo(w * 0.55, h * 0.11, w, h * 0.07)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(top, Paint()..color = color.withValues(alpha: 0.07));

    final bottomBack = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.40, h * 0.80, w, h * 0.92)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(bottomBack, Paint()..color = color.withValues(alpha: 0.06));

    final bottomFront = Path()
      ..moveTo(0, h * 0.94)
      ..quadraticBezierTo(w * 0.55, h * 0.88, w, h * 0.96)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(bottomFront, Paint()..color = color.withValues(alpha: 0.08));
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => old.color != color;
}

class _WaveBackground extends StatelessWidget {
  const _WaveBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _WavesPainter(AC.primary))),
    );
  }
}

/// PhoneHub logo: icon tile + wordmark.
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
            color: AC.primary,
            borderRadius: BorderRadius.circular(13 * s),
            boxShadow: [BoxShadow(color: AC.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 24 * s),
        ),
        SizedBox(width: 10 * s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AC.text),
                children: const [
                  TextSpan(text: 'Phone'),
                  TextSpan(text: 'Hub', style: TextStyle(color: AC.primary)),
                ],
              ),
            ),
            Text('Second-hand phones', style: TextStyle(fontSize: 11 * s, color: AC.muted)),
          ],
        ),
      ],
    );
  }
}

/// Login illustration: a laptop showing a store dashboard with parcels.
class _LoginIllustration extends StatelessWidget {
  final double s;
  const _LoginIllustration({required this.s});

  Widget _bar(double h) => Container(
    width: 8 * s,
    height: h * s,
    decoration: BoxDecoration(color: AC.primary, borderRadius: BorderRadius.circular(3 * s)),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142 * s,
      height: 128 * s,
      child: Stack(
        children: [
          Positioned(
            right: 2 * s,
            top: 0,
            child: Container(
              width: 112 * s,
              height: 112 * s,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AC.primary.withValues(alpha: 0.10)),
            ),
          ),
          // Laptop
          Positioned(
            left: 4 * s,
            top: 24 * s,
            child: Column(
              children: [
                Container(
                  width: 104 * s,
                  height: 66 * s,
                  padding: EdgeInsets.all(7 * s),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8 * s),
                    border: Border.all(color: AC.primary, width: 2.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 30 * s,
                        height: 38 * s,
                        decoration: BoxDecoration(color: AC.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6 * s)),
                        child: Icon(Icons.storefront_rounded, size: 18 * s, color: AC.accent),
                      ),
                      SizedBox(width: 8 * s),
                      _bar(14),
                      SizedBox(width: 4 * s),
                      _bar(24),
                      SizedBox(width: 4 * s),
                      _bar(34),
                    ],
                  ),
                ),
                Container(
                  width: 124 * s,
                  height: 7 * s,
                  decoration: BoxDecoration(color: AC.primary, borderRadius: BorderRadius.vertical(bottom: Radius.circular(8 * s))),
                ),
              ],
            ),
          ),
          // Parcel
          Positioned(
            right: 0,
            bottom: 6 * s,
            child: Container(
              width: 38 * s,
              height: 34 * s,
              decoration: BoxDecoration(
                color: AC.accent,
                borderRadius: BorderRadius.circular(8 * s),
                boxShadow: [BoxShadow(color: AC.accent.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20 * s),
            ),
          ),
          // Small phone
          Positioned(
            left: 0,
            bottom: 10 * s,
            child: Container(
              width: 24 * s,
              height: 30 * s,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7 * s),
                border: Border.all(color: AC.primary, width: 2),
              ),
              child: Icon(Icons.smartphone_rounded, size: 14 * s, color: AC.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Register illustration: admin avatar with crown and gear.
class _RegisterIllustration extends StatelessWidget {
  final double s;
  const _RegisterIllustration({required this.s});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104 * s,
      height: 104 * s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 96 * s, height: 96 * s, decoration: BoxDecoration(shape: BoxShape.circle, color: AC.primary.withValues(alpha: 0.10))),
          Positioned(
            left: 4 * s,
            bottom: 8 * s,
            child: Container(width: 24 * s, height: 24 * s, decoration: BoxDecoration(shape: BoxShape.circle, color: AC.accent.withValues(alpha: 0.25))),
          ),
          Container(
            width: 64 * s,
            height: 64 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AC.primary,
              boxShadow: [BoxShadow(color: AC.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Icon(Icons.person_rounded, color: Colors.white, size: 38 * s),
          ),
          Positioned(top: 2 * s, right: 10 * s, child: Icon(Icons.workspace_premium_rounded, color: AC.accent, size: 24 * s)),
          Positioned(
            right: 4 * s,
            bottom: 12 * s,
            child: Container(
              padding: EdgeInsets.all(4 * s),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)]),
              child: Icon(Icons.settings_rounded, color: AC.primary, size: 16 * s),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined field: icon tile on the left, small label on top, value below.
InputDecoration _fieldDeco(double s, String label, IconData icon, {String? hint, Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16 * s),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: TextStyle(fontSize: 13 * s, color: AC.text, fontWeight: FontWeight.w500),
    hintStyle: TextStyle(fontSize: 13.5 * s, color: AC.muted.withValues(alpha: 0.65)),
    prefixIcon: Padding(
      padding: EdgeInsets.fromLTRB(10 * s, 0, 4 * s, 0),
      child: Container(
        width: 38 * s,
        height: 38 * s,
        decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(11 * s)),
        child: Icon(icon, size: 19 * s, color: AC.muted),
      ),
    ),
    prefixIconConstraints: BoxConstraints(minWidth: 54 * s, minHeight: 38 * s),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 17 * s),
    counterText: '',
    enabledBorder: border(AC.border),
    focusedBorder: border(AC.primary, 1.6),
    errorBorder: border(AC.danger),
    focusedErrorBorder: border(AC.danger, 1.6),
    border: border(AC.border),
    errorStyle: TextStyle(fontSize: 11.5 * s),
  );
}

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
      Expanded(child: Text(text, style: TextStyle(color: AC.danger, fontWeight: FontWeight.w600, fontSize: 12.5 * s))),
    ],
  ),
);

/// Pill button.
Widget _bigButton(double s, {required VoidCallback? onPressed, required Widget child}) => SizedBox(
  width: double.infinity,
  height: 52 * s,
  child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30 * s)),
      textStyle: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w700),
    ),
    child: child,
  ),
);

Widget _arrowLabel(double s, String text) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [Text(text), SizedBox(width: 8 * s), Icon(Icons.arrow_forward_rounded, size: 18 * s)],
);

Widget _spinner(double s) => SizedBox(width: 20 * s, height: 20 * s, child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white));

TextButton _linkButton(double s, String text, VoidCallback onPressed) => TextButton(
  onPressed: onPressed,
  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 6 * s), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
  child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5 * s)),
);

// ---------------------------------------------------------------------------
// Splash
// ---------------------------------------------------------------------------

/// Splash: logo + tagline, then goes to Login.
class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2200), () async {
      final signedIn = await AdminAuthService.instance.restoreSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => signedIn ? const AdminShell() : const AdminLoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    return _fit(
      Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: adminGradient),
          child: Stack(
            children: [
              const _Bubbles(),
              Center(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.88, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84 * s,
                          height: 84 * s,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26 * s),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 28, offset: const Offset(0, 12))],
                          ),
                          child: Icon(Icons.admin_panel_settings_rounded, size: 44 * s, color: AC.primary),
                        ),
                        SizedBox(height: 20 * s),
                        Text('PhoneHub', style: TextStyle(color: Colors.white, fontSize: 26 * s, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        SizedBox(height: 8 * s),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 4 * s),
                          decoration: BoxDecoration(color: AC.accent, borderRadius: BorderRadius.circular(20)),
                          child: Text('Admin', style: TextStyle(color: Colors.white, fontSize: 11.5 * s, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                        ),
                        SizedBox(height: 14 * s),
                        Text('Manage your store, anywhere', style: TextStyle(color: Colors.white70, fontSize: 12.5 * s)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 64 * s,
                right: 64 * s,
                bottom: MediaQuery.of(context).padding.bottom + 40 * s,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 2000),
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

/// Admin login (email + password).
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _svc = AdminAuthService.instance;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(text: _svc.rememberedEmail ?? '');
  final _pass = TextEditingController();
  bool _hide = true, _loading = false, _remember = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _svc.refreshAdminExists().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await _svc.login(_email.text, _pass.text);
    if (!mounted) return;
    if (err == null) {
      await _svc.setRememberedEmail(_remember ? _email.text.trim() : null);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminShell()));
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRegisterScreen()));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    return _fit(
      Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            const _WaveBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(24 * s, 24 * s, 24 * s, 16 * s),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Logo(s: s),
                          SizedBox(height: 22 * s),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Admin Panel', style: TextStyle(fontSize: 14 * s, color: AC.text)),
                                    SizedBox(height: 4 * s),
                                    Text('Welcome Back!', style: TextStyle(fontSize: 26 * s, fontWeight: FontWeight.w800, color: AC.text, letterSpacing: -0.5)),
                                    SizedBox(height: 8 * s),
                                    Text('Sign in to your admin account to manage your store.', style: TextStyle(fontSize: 12.5 * s, color: AC.muted, height: 1.4)),
                                  ],
                                ),
                              ),
                              _LoginIllustration(s: s),
                            ],
                          ),
                          SizedBox(height: 24 * s),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                            decoration: _fieldDeco(s, 'Email Address', Icons.email_outlined, hint: 'Enter your email'),
                          ),
                          SizedBox(height: 14 * s),
                          TextFormField(
                            controller: _pass,
                            obscureText: _hide,
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                            decoration: _fieldDeco(
                              s,
                              'Password',
                              Icons.lock_outline_rounded,
                              hint: 'Enter your password',
                              suffix: IconButton(
                                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
                                onPressed: () => setState(() => _hide = !_hide),
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
                                child: Text('Remember me', style: TextStyle(fontSize: 12.5 * s, color: AC.text)),
                              ),
                              const Spacer(),
                              if (!_svc.canRegister)
                                _linkButton(s, 'Forgot Password?', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminForgotPasswordScreen()))),
                            ],
                          ),
                          SizedBox(height: 16 * s),
                          if (_error != null) _errorBox(s, _error!),
                          _bigButton(s, onPressed: _loading ? null : _login, child: _loading ? _spinner(s) : _arrowLabel(s, 'Login')),
                          SizedBox(height: 22 * s),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AC.border)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12 * s),
                                child: Text('Admin Access Only', style: TextStyle(fontSize: 12 * s, color: AC.muted)),
                              ),
                              const Expanded(child: Divider(color: AC.border)),
                            ],
                          ),
                          if (_svc.canRegister) ...[
                            SizedBox(height: 10 * s),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('New admin?', style: TextStyle(color: AC.muted, fontSize: 12.5 * s)),
                                _linkButton(s, 'Create account', _openRegister),
                              ],
                            ),
                          ],
                          SizedBox(height: 28 * s),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined, size: 15 * s, color: AC.muted),
                                SizedBox(width: 6 * s),
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(fontSize: 11.5 * s, color: AC.muted),
                                    children: const [
                                      TextSpan(text: 'Secure · Fast · '),
                                      TextSpan(text: 'Reliable', style: TextStyle(fontWeight: FontWeight.w700, color: AC.text)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
  bool _hide = true, _hide2 = true, _loading = false;
  String? _error;

  int get _strength {
    final p = _pass.text;
    int n = 0;
    if (p.length >= 8) n++;
    if (RegExp(r'[A-Z]').hasMatch(p)) n++;
    if (RegExp(r'[0-9]').hasMatch(p)) n++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) n++;
    return n;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final err = await _svc.register(name: _name.text, email: _email.text, phone: _phone.text, password: _pass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
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

  Widget _strengthMeter(double s) {
    final labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [AC.border, AC.danger, AC.accent, AC.primary, AC.primary];
    final v = _pass.text.isEmpty ? 0 : _strength;
    return Padding(
      padding: EdgeInsets.only(top: 8 * s, left: 4 * s),
      child: Row(
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
          Text(_pass.text.isEmpty ? '' : labels[v], style: TextStyle(fontSize: 11 * s, color: AC.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    return _fit(
      Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            const _WaveBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(24 * s, 8 * s, 24 * s, 16 * s),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20 * s, color: AC.primary),
                          ),
                          SizedBox(height: 10 * s),
                          _Logo(s: s),
                          SizedBox(height: 14 * s),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Admin Registration', style: TextStyle(fontSize: 14 * s, color: AC.text)),
                                    SizedBox(height: 4 * s),
                                    Text('Create Admin Account', style: TextStyle(fontSize: 22 * s, fontWeight: FontWeight.w800, color: AC.text, letterSpacing: -0.4)),
                                    SizedBox(height: 8 * s),
                                    Text('Set up your account to manage products, orders, users and more.', style: TextStyle(fontSize: 12.5 * s, color: AC.muted, height: 1.4)),
                                  ],
                                ),
                              ),
                              _RegisterIllustration(s: s),
                            ],
                          ),
                          SizedBox(height: 20 * s),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
                            decoration: _fieldDeco(s, 'Full Name', Icons.person_outline_rounded, hint: 'Enter your full name'),
                          ),
                          SizedBox(height: 12 * s),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Enter a valid email' : null,
                            decoration: _fieldDeco(s, 'Email Address', Icons.email_outlined, hint: 'Enter your email'),
                          ),
                          SizedBox(height: 12 * s),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => (v == null || !RegExp(r'^[0-9]{10}$').hasMatch(v)) ? 'Enter a 10 digit mobile number' : null,
                            decoration: _fieldDeco(s, 'Phone Number', Icons.phone_outlined, hint: 'Enter your mobile number'),
                          ),
                          SizedBox(height: 12 * s),
                          TextFormField(
                            controller: _pass,
                            obscureText: _hide,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                            decoration: _fieldDeco(
                              s,
                              'Password',
                              Icons.lock_outline_rounded,
                              hint: 'Create a strong password',
                              suffix: IconButton(
                                icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
                                onPressed: () => setState(() => _hide = !_hide),
                              ),
                            ),
                          ),
                          _strengthMeter(s),
                          SizedBox(height: 12 * s),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _hide2,
                            style: TextStyle(fontSize: 14 * s, color: AC.text),
                            validator: (v) => v != _pass.text ? 'Passwords do not match' : null,
                            decoration: _fieldDeco(
                              s,
                              'Confirm Password',
                              Icons.lock_outline_rounded,
                              hint: 'Re-enter your password',
                              suffix: IconButton(
                                icon: Icon(_hide2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20 * s, color: AC.muted),
                                onPressed: () => setState(() => _hide2 = !_hide2),
                              ),
                            ),
                          ),
                          SizedBox(height: 18 * s),
                          if (_error != null) _errorBox(s, _error!),
                          _bigButton(s, onPressed: _loading ? null : _register, child: _loading ? _spinner(s) : _arrowLabel(s, 'Register')),
                          SizedBox(height: 10 * s),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account?', style: TextStyle(color: AC.muted, fontSize: 12.5 * s)),
                              _linkButton(s, 'Login', () => Navigator.pop(context)),
                            ],
                          ),
                          SizedBox(height: 8 * s),
                        ],
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// Forgot password
// ---------------------------------------------------------------------------

/// Forgot password: Firebase emails a reset link to the admin.
class AdminForgotPasswordScreen extends StatefulWidget {
  const AdminForgotPasswordScreen({super.key});

  @override
  State<AdminForgotPasswordScreen> createState() => _AdminForgotPasswordScreenState();
}

class _AdminForgotPasswordScreenState extends State<AdminForgotPasswordScreen> {
  final _svc = AdminAuthService.instance;
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _err;

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _err = 'Enter a valid email address');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final err = await _svc.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _err = err;
      _sent = err == null;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);

    return _fit(
      Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            const _WaveBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(24 * s, 8 * s, 24 * s, 24 * s),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20 * s, color: AC.primary),
                        ),
                      ),
                      SizedBox(height: 10 * s),
                      Align(alignment: Alignment.centerLeft, child: _Logo(s: s)),
                      SizedBox(height: 28 * s),
                      Text('Reset Password', style: TextStyle(fontSize: 14 * s, color: AC.text)),
                      SizedBox(height: 4 * s),
                      Text(_sent ? 'Check your inbox' : 'Forgot Password?', style: TextStyle(fontSize: 24 * s, fontWeight: FontWeight.w800, color: AC.text, letterSpacing: -0.4)),
                      SizedBox(height: 8 * s),
                      Text(
                        _sent
                            ? 'We sent a password reset link to ${_email.text.trim()}. Open it, choose a new password, then login.'
                            : 'Enter your admin email and we will send you a link to reset your password.',
                        style: TextStyle(color: AC.muted, fontSize: 12.5 * s, height: 1.4),
                      ),
                      SizedBox(height: 22 * s),
                      if (!_sent) ...[
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(fontSize: 14 * s, color: AC.text),
                          decoration: _fieldDeco(s, 'Email Address', Icons.email_outlined, hint: 'Enter your admin email'),
                        ),
                        SizedBox(height: 18 * s),
                        if (_err != null) _errorBox(s, _err!),
                        _bigButton(s, onPressed: _busy ? null : _send, child: _busy ? _spinner(s) : _arrowLabel(s, 'Send reset link')),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.all(16 * s),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16 * s), border: Border.all(color: AC.border)),
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_read_outlined, color: AC.primary, size: 28 * s),
                              SizedBox(width: 12 * s),
                              Expanded(child: Text('Not there? Check your spam folder or send the link again.', style: TextStyle(fontSize: 12.5 * s, color: AC.muted, height: 1.4))),
                            ],
                          ),
                        ),
                        SizedBox(height: 18 * s),
                        _bigButton(s, onPressed: () => Navigator.pop(context), child: _arrowLabel(s, 'Back to login')),
                        SizedBox(height: 8 * s),
                        Center(child: _linkButton(s, 'Send again', () => setState(() => _sent = false))),
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