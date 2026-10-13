import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'theme.dart';

const Color _line = Color(0xFFDCE8FF);
const Color _fieldFill = Color(0xFFF4F8FF);
const Color _navy = Color(0xFF10265F);
const Color _blue = Color(0xFF2452B8);
const Color _cyan = Color(0xFF38D9FF);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _showMessage(
        'Please accept the Terms & Conditions to continue.',
      );
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    UserCredential? credential;

    try {
      // Create a real Firebase Authentication account.
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Firebase did not return the newly created user.',
        );
      }

      // Save the customer's profile in Firestore using their Auth UID.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'fullName': name,
        'email': email,
        'phone': phone,
        'role': 'customer',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedTerms': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Account created successfully. Please sign in.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'email-already-in-use':
          _showMessage('An account with this email already exists. Please sign in.');
          break;
        case 'invalid-email':
          _showMessage('Please enter a valid email address.');
          break;
        case 'weak-password':
          _showMessage('Please choose a stronger password.');
          break;
        case 'network-request-failed':
          _showMessage('Network error. Check your internet connection and try again.');
          break;
        default:
          _showMessage(e.message ?? 'Could not create your account. Please try again.');
      }
    } on FirebaseException catch (e) {
      // Avoid leaving an Auth account without its required Firestore profile
      // when profile creation fails (for example, because rules deny the write).
      try {
        await credential?.user?.delete();
      } catch (_) {
        // The original Firestore error below is the useful error to display.
      }

      if (!mounted) return;
      if (e.code == 'permission-denied') {
        _showMessage(
          'Profile could not be saved. Update Firestore Rules to allow a customer to create their own users/{uid} document.',
        );
      } else {
        _showMessage('Could not save your profile: ${e.message ?? e.code}');
      }
    } catch (e) {
      try {
        await credential?.user?.delete();
      } catch (_) {}
      if (!mounted) return;
      _showMessage('Registration failed. Please try again.');
    }
  }

  Widget _eye(bool obscured, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        obscured
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        color: AppColors.muted,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF7FADEE),
        body: Stack(
          children: [
            const _RegisterBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
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

                            const SizedBox(height: 22),

                            // Animated glowing registration icon
                            Center(
                              child: AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 88,
                                    height: 88,
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
                                      child: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                        color: _navy,
                                        size: 39,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 19),

                            // Page title
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                    colors: [
                                      Color(0xFF17356F),
                                      Color(0xFF3D5BB8),
                                    ],
                                  ).createShader(bounds),
                              child: const Text(
                                'Create account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.12,
                                ),
                              ),
                            ),

                            const SizedBox(height: 9),

                            Text(
                              'Join PhoneHub for better phone deals',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _navy.withValues(alpha: 0.76),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Cyan-blue accent line
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

                            const SizedBox(height: 25),

                            // Translucent registration card
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
                                        const _FieldLabel('Full name'),
                                        const SizedBox(height: 8),

                                        _RegisterInput(
                                          controller: _nameController,
                                          hint: 'Enter your full name',
                                          icon: Icons.person_outline_rounded,
                                          textInputAction:
                                          TextInputAction.next,
                                          validator: (value) {
                                            if ((value ?? '').trim().length <
                                                2) {
                                              return 'Please enter your full name';
                                            }
                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 17),

                                        const _FieldLabel('Email address'),
                                        const SizedBox(height: 8),

                                        _RegisterInput(
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

                                        const SizedBox(height: 17),

                                        const _FieldLabel('Phone number'),
                                        const SizedBox(height: 8),

                                        _RegisterInput(
                                          controller: _phoneController,
                                          hint: 'Enter your phone number',
                                          icon: Icons.phone_outlined,
                                          keyboardType: TextInputType.phone,
                                          textInputAction:
                                          TextInputAction.next,
                                          validator: (value) {
                                            final phone = (value ?? '')
                                                .replaceAll(
                                              RegExp(r'[\s()+-]'),
                                              '',
                                            );

                                            if (phone.isEmpty) {
                                              return 'Please enter your phone number';
                                            }

                                            if (!RegExp(r'^\d{10,13}$')
                                                .hasMatch(phone)) {
                                              return 'Enter a valid phone number';
                                            }

                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 17),

                                        const _FieldLabel('Password'),
                                        const SizedBox(height: 8),

                                        _RegisterInput(
                                          controller: _passwordController,
                                          hint: 'Create a password',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          textInputAction:
                                          TextInputAction.next,
                                          suffix: _eye(
                                            _obscurePassword,
                                                () {
                                              setState(() {
                                                _obscurePassword =
                                                !_obscurePassword;
                                              });
                                            },
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 17),

                                        const _FieldLabel(
                                          'Confirm password',
                                        ),
                                        const SizedBox(height: 8),

                                        _RegisterInput(
                                          controller:
                                          _confirmPasswordController,
                                          hint: 'Re-enter your password',
                                          icon: Icons.lock_reset_rounded,
                                          obscureText:
                                          _obscureConfirmPassword,
                                          textInputAction:
                                          TextInputAction.done,
                                          onSubmitted: (_) =>
                                              _submitRegistration(),
                                          suffix: _eye(
                                            _obscureConfirmPassword,
                                                () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                              });
                                            },
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').isEmpty) {
                                              return 'Please confirm your password';
                                            }

                                            if (value !=
                                                _passwordController.text) {
                                              return 'Passwords do not match';
                                            }

                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Terms and conditions
                                        Row(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Checkbox(
                                                value: _acceptTerms,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _acceptTerms =
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
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  top: 3,
                                                ),
                                                child: Text(
                                                  'I agree to the Terms & Conditions and Privacy Policy.',
                                                  style: TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 12,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 22),

                                        // Gradient create account button
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
                                              onPressed:
                                              _submitRegistration,
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
                                                    'Create Account',
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
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Navigate to login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: _navy.withValues(alpha: 0.78),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: _navy,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'Sign in',
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
                                  'Secure registration • PhoneHub',
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

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return const _FieldLabelText();
  }
}

class _FieldLabelText extends StatelessWidget {
  const _FieldLabelText();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _RegisterInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  const _RegisterInput({
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
          borderSide: const BorderSide(
            color: _blue,
            width: 1.4,
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

/// PhoneHub splash-screen background with the exact same gradient,
/// ambient blue glow circles, and cyan dot patterns.
class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

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
                  Color(0xFFF4F8FF),
                  Color(0xFFBBD5FB),
                  Color(0xFF7FADEE),
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
            color: const Color(0xFF1E9BFF).withValues(alpha: 0.18),
          ),
        ),

        Positioned(
          top: size.height * 0.17,
          left: -size.width * 0.42,
          child: _BackgroundOrb(
            size: size.width * 0.76,
            color: const Color(0xFF1688FF).withValues(alpha: 0.15),
          ),
        ),

        Positioned(
          bottom: -size.height * 0.10,
          left: -size.width * 0.18,
          child: _BackgroundOrb(
            size: size.width * 1.05,
            color: const Color(0xFF245DFF).withValues(alpha: 0.14),
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