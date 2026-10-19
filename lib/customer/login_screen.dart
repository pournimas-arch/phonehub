import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/customer/forgot_password.dart';
import 'package:phonehub/customer/register_screen.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/push_service.dart';

import 'home_screen.dart';
import 'theme.dart';
import 'data.dart';

// -----------------------------------------------------------------------------
// PhoneHub palette — original colors preserved.
// -----------------------------------------------------------------------------

const Color _line = Color(0xFFDCE8FF);
const Color _fieldFill = Color(0xFFF4F8FF);
const Color _navy = Color(0xFF10265F);
const Color _blue = Color(0xFF2452B8);
const Color _cyan = Color(0xFF38D9FF);
const Color _deepNavy = Color(0xFF071538);

// -----------------------------------------------------------------------------
// Login validation + brute-force protection
// -----------------------------------------------------------------------------
const int _maxEmailLength = 100;
const int _maxPasswordLength = 128;

/// After this many wrong passwords in a row the form is paused for a short time.
const int _maxFailedAttempts = 5;

// Kept at file level so the counter survives leaving and re-opening this screen
// (for example after logout) during the same app session.
int _failedLogins = 0;
int _lockLevel = 0;
DateTime? _lockedUntil;

final RegExp _loginEmailFormat =
RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

String? _validateLoginEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Please enter your email address';
  if (s.length > _maxEmailLength) {
    return 'Email must be $_maxEmailLength characters or fewer';
  }
  if (s.contains('..') || !_loginEmailFormat.hasMatch(s)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? _validateLoginPassword(String? v) {
  final p = v ?? '';
  if (p.isEmpty) return 'Please enter your password';
  if (p.length < 6) return 'Password must be at least 6 characters';
  if (p.length > _maxPasswordLength) {
    return 'Password must be $_maxPasswordLength characters or fewer';
  }
  return null;
}

/// Seconds left before the next login try is allowed (0 = not locked).
int _lockSecondsLeft() {
  final until = _lockedUntil;
  if (until == null) return 0;
  final left = until.difference(DateTime.now()).inSeconds + 1;
  if (left <= 0) {
    _lockedUntil = null;
    return 0;
  }
  return left;
}

String _waitText(int seconds) {
  if (seconds < 60) return '$seconds seconds';
  final m = (seconds / 60).ceil();
  return m == 1 ? '1 minute' : '$m minutes';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.12,
      end: 0.32,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _glowController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _navy,
          elevation: 8,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Firebase Authentication
  // ---------------------------------------------------------------------------

  Future<void> _submitLogin() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Too many wrong passwords -> wait before trying again.
    final wait = _lockSecondsLeft();
    if (wait > 0) {
      _showMessage(
        'Too many failed attempts. Please try again in ${_waitText(wait)}, '
            'or use Forgot password.',
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        _showMessage(
          'Login could not be completed. Please try again.',
        );
        return;
      }

      // Correct password -> clear the failed-attempt counter.
      _failedLogins = 0;
      _lockLevel = 0;
      _lockedUntil = null;

      // Use Firebase Authentication as a fallback if the Firestore
      // profile is unavailable or has not been created yet.
      String name = user.displayName ?? '';
      String phone = user.phoneNumber ?? '';
      String userEmail = user.email ?? email;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = snapshot.data();

        // No customer profile: this login may belong to a delivery partner or
        // an admin. They must use their own app, not the customer app.
        if (!snapshot.exists) {
          final mail = (user.email ?? email).trim().toLowerCase();
          String? wrongApp;
          try {
            final partner = await FirebaseFirestore.instance
                .collection('partners')
                .doc(mail)
                .get();
            if (partner.exists) {
              wrongApp = 'This is a delivery partner account. '
                  'Please sign in from the Delivery Partner app.';
            } else {
              final admin = await FirebaseFirestore.instance
                  .collection('admins')
                  .doc(user.uid)
                  .get();
              if (admin.exists) {
                wrongApp = 'This is an admin account. '
                    'Please sign in from the Admin app.';
              }
            }
          } on FirebaseException {
            // If these checks are not allowed, continue as a normal customer.
          }
          if (wrongApp != null) {
            await FirebaseAuth.instance.signOut();
            _showMessage(wrongApp);
            return;
          }
        }

        if (userData != null && userData['blocked'] == true) {
          await FirebaseAuth.instance.signOut();

          _showMessage(
            'Your account has been blocked. Please contact support.',
          );
          return;
        }

        if (userData != null) {
          final profileName = userData['name'];
          final profilePhone = userData['phone'];
          final profileEmail = userData['email'];

          if (profileName is String &&
              profileName.trim().isNotEmpty) {
            name = profileName.trim();
          }

          if (profilePhone is String) {
            phone = profilePhone;
          }

          if (profileEmail is String &&
              profileEmail.trim().isNotEmpty) {
            userEmail = profileEmail.trim();
          }
        }
      } on FirebaseException {
        // Preserve the existing authentication fallback.
        // Configure Firestore security rules appropriately.
      }

      // Push notifications: save this phone's token on users/{uid}.fcmToken.
      unawaited(PushService.instance.register('users/${user.uid}'));

      profile.value = UserProfile(
        name: name.isNotEmpty
            ? name
            : userEmail.split('@').first,
        phone: phone,
        email: userEmail,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      var message = 'Unable to sign in. Please try again.';

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          _failedLogins++;
          if (_failedLogins >= _maxFailedAttempts) {
            // 30 s, then 60 s, 120 s ... up to 5 minutes.
            final int seconds = (30 * (1 << _lockLevel)).clamp(30, 300).toInt();
            _lockLevel = _lockLevel < 4 ? _lockLevel + 1 : _lockLevel;
            _failedLogins = 0;
            _lockedUntil = DateTime.now().add(Duration(seconds: seconds));
            message = 'Too many failed attempts. '
                'Please try again in ${_waitText(seconds)}, or use Forgot password.';
          } else {
            final left = _maxFailedAttempts - _failedLogins;
            message = left <= 2
                ? 'Invalid email or password. $left ${left == 1 ? 'attempt' : 'attempts'} left.'
                : 'Invalid email or password.';
          }
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
      }

      _showMessage(message);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openForgotPassword() {
    if (_isLoading) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  void _openRegistration() {
    if (_isLoading) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFD0E1F9),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const Positioned.fill(
              child: _LoginBackground(),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxHeight / 740)
                      .clamp(0.82, 1.0)
                      .toDouble();

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      22,
                      10 * scale,
                      22,
                      20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 30,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 440,
                          ),
                          child: FadeTransition(
                            opacity: _entranceAnimation,
                            child: SlideTransition(
                              position: reduceMotion
                                  ? const AlwaysStoppedAnimation(
                                Offset.zero,
                              )
                                  : Tween<Offset>(
                                begin: const Offset(0, 0.035),
                                end: Offset.zero,
                              ).animate(_entranceAnimation),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  _buildBackButton(),
                                  SizedBox(height: 15 * scale),

                                  _buildLogo(
                                    screenWidth: screenSize.width,
                                    reduceMotion: reduceMotion,
                                  ),

                                  SizedBox(height: 18 * scale),

                                  _buildHeading(),

                                  SizedBox(height: 20 * scale),

                                  _buildLoginCard(scale),

                                  SizedBox(height: 15 * scale),

                                  _buildRegistration(),

                                  const SizedBox(height: 13),

                                  _buildSecurityFooter(),
                                ],
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

  // ---------------------------------------------------------------------------
  // Back navigation
  // ---------------------------------------------------------------------------

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.78),
        elevation: 2,
        shadowColor: _blue.withValues(alpha: 0.10),
        shape: const CircleBorder(
          side: BorderSide(color: _line),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _isLoading
              ? null
              : () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              Icons.arrow_back_rounded,
              color: _navy,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Animated PhoneHub logo
  // ---------------------------------------------------------------------------

  Widget _buildLogo({
    required double screenWidth,
    required bool reduceMotion,
  }) {
    final logoSize = (screenWidth * 0.19)
        .clamp(70.0, 84.0)
        .toDouble();

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: logoSize + 18,
                height: logoSize + 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(
                        alpha: reduceMotion
                            ? 0.18
                            : _glowAnimation.value,
                      ),
                      blurRadius: 32,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),

              Container(
                width: logoSize + 12,
                height: logoSize + 12,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.42),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Color(0xFFE5EEFF),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.phone_iphone_rounded,
                      color: _navy,
                      size: logoSize * 0.51,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                right: -1,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        _cyan,
                        Color(0xFF3675FF),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Welcome heading
  // ---------------------------------------------------------------------------

  Widget _buildHeading() {
    return Column(
      children: [
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
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.12,
            ),
          ),
        ),

        const SizedBox(height: 9),

        const Text(
          'Sign in to your PhoneHub account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF354A70),
            fontSize: AppText.small,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
          ),
        ),

        const SizedBox(height: 15),

        Container(
          width: 58,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [
                _cyan,
                Color(0xFF3675FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: 0.18),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Login card
  // ---------------------------------------------------------------------------

  Widget _buildLoginCard(double scale) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.12),
            blurRadius: 35,
            offset: const Offset(0, 17),
          ),
          BoxShadow(
            color: _navy.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 14,
            sigmaY: 14,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              19,
              20 * scale,
              19,
              19 * scale,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.97),
                  Colors.white.withValues(alpha: 0.86),
                ],
              ),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.96),
                width: 1.3,
              ),
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SectionLabel(
                    title: 'Email address',
                  ),

                  const SizedBox(height: 8),

                  _LoginInput(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hint: 'you@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    onSubmitted: (_) {
                      _passwordFocus.requestFocus();
                    },
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxEmailLength),
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: _validateLoginEmail,
                  ),

                  SizedBox(height: 17 * scale),

                  const _SectionLabel(
                    title: 'Password',
                  ),

                  const SizedBox(height: 8),

                  _LoginInput(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [
                      AutofillHints.password,
                    ],
                    onSubmitted: (_) => _submitLogin(),
                    suffix: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _blue,
                        size: 20,
                      ),
                    ),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxPasswordLength),
                    ],
                    validator: _validateLoginPassword,
                  ),

                  SizedBox(height: 10 * scale),

                  _buildRememberAndForgot(),

                  SizedBox(height: 17 * scale),

                  _buildSignInButton(),

                  SizedBox(height: 19 * scale),

                  _buildDivider(),

                  SizedBox(height: 16 * scale),

                  _buildGooglePlaceholder(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Remember me and forgot password
  // ---------------------------------------------------------------------------

  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: _isLoading
                ? null
                : (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            activeColor: _blue,
            checkColor: Colors.white,
            side: const BorderSide(
              color: Color(0xFF9AAAC4),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),

        const SizedBox(width: 7),

        Flexible(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            child: const Text(
              'Remember me',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: AppText.small,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        const SizedBox(width: 3),

        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: AppText.small,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sign-in button with progress state
  // ---------------------------------------------------------------------------

  Widget _buildSignInButton() {
    return SizedBox(
      height: 53,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2452B8),
              Color(0xFF3675FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.26),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isLoading
                ? const Row(
              key: ValueKey('loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 11),
                Text(
                  'Signing in...',
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
                : const Row(
              key: ValueKey('idle'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.25,
                  ),
                ),
                SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Divider
  // ---------------------------------------------------------------------------

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: _line,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.9),
              fontSize: AppText.caption,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const Expanded(
          child: Divider(
            color: _line,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Google sign-in placeholder
  // ---------------------------------------------------------------------------

  Widget _buildGooglePlaceholder() {
    return OutlinedButton(
      onPressed: _isLoading
          ? null
          : () {
        _showMessage(
          'Google sign-in is not configured yet.',
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: _navy,
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        side: const BorderSide(
          color: _line,
          width: 1.2,
        ),
        minimumSize: const Size.fromHeight(49),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _blue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: AppText.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Registration link
  // ---------------------------------------------------------------------------

  Widget _buildRegistration() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 1,
      children: [
        Text(
          "Don't have an account?",
          style: TextStyle(
            color: _navy.withValues(alpha: 0.80),
            fontSize: AppText.small,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: _openRegistration,
          style: TextButton.styleFrom(
            foregroundColor: _blue,
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 5,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Create account',
            style: TextStyle(
              color: _navy,
              fontSize: AppText.small,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Security footer
  // ---------------------------------------------------------------------------

  Widget _buildSecurityFooter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.80),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: _navy.withValues(alpha: 0.72),
              size: 15,
            ),
            const SizedBox(width: 7),
            Text(
              'Secure sign-in • PhoneHub',
              style: TextStyle(
                color: _navy.withValues(alpha: 0.76),
                fontSize: AppText.caption,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small section label
// -----------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _navy,
        fontSize: AppText.small,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reusable login input
// -----------------------------------------------------------------------------

class _LoginInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const _LoginInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onSubmitted,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      inputFormatters: inputFormatters,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      enabled: true,
      autocorrect: false,
      enableSuggestions: !obscureText,
      style: const TextStyle(
        color: _navy,
        fontSize: AppText.body,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: _blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: AppText.body,
          fontWeight: FontWeight.w400,
        ),

        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: _blue,
              size: 17,
            ),
          ),
        ),

        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 44,
        ),

        suffixIcon: suffix,

        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),

        filled: true,
        fillColor: _fieldFill.withValues(alpha: 0.96),
        isDense: true,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 15,
        ),

        errorMaxLines: 2,

        errorStyle: const TextStyle(
          color: Color(0xFFD83C48),
          fontSize: AppText.caption,
          height: 1.2,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: _line,
            width: 1.1,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: _blue,
            width: 1.5,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE5484D),
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFFE5484D),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Login background — original PhoneHub gradient and blue palette preserved.
// -----------------------------------------------------------------------------

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: Container(
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
          ),
        ),

        Positioned(
          top: -size.height * 0.11,
          right: -size.width * 0.25,
          child: _BackgroundOrb(
            size: size.width * 0.92,
            color: const Color(0xFF1E9BFF)
                .withValues(alpha: 0.18),
          ),
        ),

        Positioned(
          top: size.height * 0.17,
          left: -size.width * 0.42,
          child: _BackgroundOrb(
            size: size.width * 0.76,
            color: const Color(0xFF1688FF)
                .withValues(alpha: 0.15),
          ),
        ),

        Positioned(
          bottom: -size.height * 0.10,
          left: -size.width * 0.18,
          child: _BackgroundOrb(
            size: size.width * 1.05,
            color: const Color(0xFF245DFF)
                .withValues(alpha: 0.14),
          ),
        ),

        Positioned(
          top: size.height * 0.17,
          right: 28,
          child: const _DotPattern(),
        ),

        Positioned(
          bottom: size.height * 0.25,
          left: 24,
          child: const _DotPattern(),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Background glow
// -----------------------------------------------------------------------------

class _BackgroundOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackgroundOrb({
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
// Decorative dots
// -----------------------------------------------------------------------------

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
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
      ),
    );
  }
}