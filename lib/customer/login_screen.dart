import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/customer/forgot_password.dart';
import 'package:phonehub/customer/register_screen.dart';

import 'home_screen.dart';
import 'theme.dart';
import 'data.dart';

// PhoneHub Splash Screen color palette.
const Color _line = Color(0xFFDCE8FF);
const Color _fieldFill = Color(0xFFF4F8FF);
const Color _navy = Color(0xFF10265F);
const Color _blue = Color(0xFF2452B8);
const Color _cyan = Color(0xFF38D9FF);

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

  bool _obscurePassword = true;
  bool _rememberMe = true;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.10,
      end: 0.30,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
    _glowController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        _showMessage('Login could not be completed. Please try again.');
        return;
      }

      // Profile data is loaded from Firestore. Auth details are used as a
      // safe fallback if the profile document has not been created yet.
      String name = user.displayName ?? '';
      String phone = user.phoneNumber ?? '';
      String userEmail = user.email ?? email;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = snapshot.data();
        if (data != null) {
          name = (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : name;
          phone = (data['phone'] as String?) ?? phone;
          userEmail = (data['email'] as String?) ?? userEmail;
        }
      } on FirebaseException {
        // Do not fail Authentication just because a profile read is denied
        // or temporarily unavailable. Firestore Rules still need configuring.
      }

      profile.value = UserProfile(
        name: name.isEmpty ? (userEmail.split('@').first) : name,
        phone: phone,
        email: userEmail,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
          message = 'Invalid email or password.';
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
      if (mounted) _showMessage(message);
    } catch (_) {
      if (mounted) _showMessage('Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF7FADEE),
        body: Stack(
          children: [
            const _LoginBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeTransition(
                      opacity: _entranceAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.035),
                          end: Offset.zero,
                        ).animate(_entranceAnimation),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Back button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.82),
                                shape: const CircleBorder(
                                  side: BorderSide(color: _line),
                                ),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.maybePop(context),
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: _navy,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 27),

                            // Glowing PhoneHub icon
                            Center(
                              child: AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 94,
                                    height: 94,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.48,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _cyan.withValues(
                                            alpha: _glowAnimation.value,
                                          ),
                                          blurRadius: 30,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF3D5BB8)
                                              .withValues(alpha: 0.14),
                                          blurRadius: 22,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(26),
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
                                      child: const Icon(
                                        Icons.phone_iphone_rounded,
                                        color: _navy,
                                        size: 47,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Heading
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                    colors: [
                                      Color(0xFF17356F),
                                      Color(0xFF3D5BB8),
                                    ],
                                  ).createShader(bounds),
                              child: const Text(
                                'Welcome back',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.12,
                                ),
                              ),
                            ),

                            const SizedBox(height: 9),

                            Text(
                              'Sign in to your PhoneHub account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _navy.withValues(alpha: 0.76),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Cyan and blue decorative line
                            Center(
                              child: Container(
                                width: 64,
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [
                                      _cyan,
                                      Color(0xFF3675FF),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3675FF)
                                          .withValues(alpha: 0.22),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 27),

                            // Translucent login card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 14,
                                  sigmaY: 14,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.88,
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3D5BB8)
                                            .withValues(alpha: 0.13),
                                        blurRadius: 28,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Email address',
                                          style: TextStyle(
                                            color: _navy,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),

                                        const SizedBox(height: 9),

                                        _LoginInput(
                                          controller: _emailController,
                                          hint: 'you@example.com',
                                          icon: Icons.mail_outline_rounded,
                                          keyboardType:
                                          TextInputType.emailAddress,
                                          textInputAction:
                                          TextInputAction.next,
                                          validator: (value) {
                                            final email =
                                                value?.trim() ?? '';

                                            if (email.isEmpty) {
                                              return 'Please enter your email';
                                            }

                                            if (!RegExp(
                                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                            ).hasMatch(email)) {
                                              return 'Enter a valid email address';
                                            }

                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 20),

                                        const Text(
                                          'Password',
                                          style: TextStyle(
                                            color: _navy,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),

                                        const SizedBox(height: 9),

                                        _LoginInput(
                                          controller: _passwordController,
                                          hint: 'Enter your password',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          textInputAction:
                                          TextInputAction.done,
                                          onSubmitted: (_) =>
                                              _submitLogin(),
                                          suffix: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: AppColors.muted,
                                              size: 20,
                                            ),
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }

                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 10),

                                        // Remember me and forgot password
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _rememberMe =
                                                        value ?? false;
                                                  });
                                                },
                                                activeColor: _blue,
                                                checkColor: Colors.white,
                                                side: const BorderSide(
                                                  color: AppColors.muted,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(5),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 7),

                                            const Text(
                                              'Remember me',
                                              style: TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),

                                            const Spacer(),

                                            TextButton(
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => const ForgotPasswordScreen(),
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: _blue,
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: const Text(
                                                'Forgot password?',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 22),

                                        // Gradient sign-in button
                                        SizedBox(
                                          height: 54,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(17),
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
                                                  color: const Color(0xFF3675FF)
                                                      .withValues(alpha: 0.30),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: _submitLogin,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                Colors.transparent,
                                                foregroundColor: Colors.white,
                                                shadowColor:
                                                Colors.transparent,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(17),
                                                ),
                                              ),
                                              child: const Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Sign In',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                      FontWeight.w800,
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

                                        const SizedBox(height: 22),

                                        // Divider
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Divider(color: _line),
                                            ),
                                            Padding(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                'OR CONTINUE WITH',
                                                style: TextStyle(
                                                  color: AppColors.muted
                                                      .withValues(alpha: 0.9),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                            ),
                                            const Expanded(
                                              child: Divider(color: _line),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 17),

                                        // Google sign-in placeholder
                                        OutlinedButton.icon(
                                          onPressed: () => _showMessage(
                                            'Connect Google sign-in to enable this option.',
                                          ),
                                          icon: const Icon(
                                            Icons.g_mobiledata_rounded,
                                            size: 27,
                                          ),
                                          label: const Text(
                                            'Continue with Google',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _navy,
                                            backgroundColor:
                                            Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                            side: const BorderSide(
                                              color: _line,
                                            ),
                                            minimumSize:
                                            const Size.fromHeight(50),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Registration navigation
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: _navy.withValues(alpha: 0.78),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: _navy,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Create account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Security footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 15,
                                  color: _navy.withValues(alpha: 0.62),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Secure sign-in • PhoneHub',
                                  style: TextStyle(
                                    color: _navy.withValues(alpha: 0.62),
                                    fontSize: 11,
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
          ],
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _LoginInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        color: _navy,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: _blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: Icon(icon, color: _blue, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fieldFill.withValues(alpha: 0.94),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        errorMaxLines: 2,
        errorStyle: const TextStyle(fontSize: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _blue, width: 1.4),
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

/// Background copied from the PhoneHub splash screen design.
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Exact splash screen gradient.
        Positioned.fill(
          child: Container(
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
          ),
        ),

        // Top-right blue glow.
        Positioned(
          top: -size.height * 0.11,
          right: -size.width * 0.25,
          child: _BackgroundOrb(
            size: size.width * 0.92,
            color: const Color(0xFF1E9BFF).withValues(alpha: 0.18),
          ),
        ),

        // Left-side blue glow.
        Positioned(
          top: size.height * 0.17,
          left: -size.width * 0.42,
          child: _BackgroundOrb(
            size: size.width * 0.76,
            color: const Color(0xFF1688FF).withValues(alpha: 0.15),
          ),
        ),

        // Bottom blue glow.
        Positioned(
          bottom: -size.height * 0.10,
          left: -size.width * 0.18,
          child: _BackgroundOrb(
            size: size.width * 1.05,
            color: const Color(0xFF245DFF).withValues(alpha: 0.14),
          ),
        ),

        // Cyan decorative dots.
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

class _BackgroundOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackgroundOrb({
    required this.size,
    required this.color,
  });

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