import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'theme.dart';
import 'package:phonehub/app_text.dart';

const Color _line = Color(0xFFDCE8FF);
const Color _fieldFill = Color(0xFFF4F8FF);
const Color _navy = Color(0xFF10265F);
const Color _blue = Color(0xFF2452B8);
const Color _cyan = Color(0xFF38D9FF);
const Color _errorRed = Color(0xFFE5484D);

// ---------------------------------------------------------------------------
// Registration validation
// ---------------------------------------------------------------------------
const int _maxName = 50;
const int _maxEmail = 100;
const int _minPassword = 8;
const int _maxPassword = 64;

final RegExp _nameChars = RegExp(r"^\p{L}[\p{L}\p{M} .'-]*$", unicode: true);
final RegExp _emailFormat =
RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

/// Common typing mistakes in the email domain -> what the person most likely meant.
const Map<String, String> _emailTypos = {
  'gmial.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gmail.con': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gmail.in': 'gmail.com',
  'yahooo.com': 'yahoo.com',
  'yaho.com': 'yahoo.com',
  'yahoo.con': 'yahoo.com',
  'hotmial.com': 'hotmail.com',
  'hotmail.con': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outlook.con': 'outlook.com',
};

/// Passwords that are far too easy to guess.
const Set<String> _commonPasswords = {
  'password', 'password1', 'password123', 'password@123', 'passw0rd',
  '12345678', '123456789', '1234567890', '11111111', '00000000',
  'qwerty123', 'qwertyuiop', 'abc12345', 'abcd1234', 'iloveyou',
  'admin123', 'welcome1', 'welcome123', 'letmein1', 'phonehub123', 'phonehub1',
};

/// Trims and collapses repeated spaces ("Ravi   Kumar " -> "Ravi Kumar").
String _cleanName(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Keeps the digits only and removes a +91 / 91 / 0 prefix -> the 10-digit mobile number.
String _phoneDigits(String v) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) {
    d = d.substring(2);
  } else if (d.length == 11 && d.startsWith('0')) {
    d = d.substring(1);
  }
  return d;
}

String? _validateRegisterName(String? v) {
  final s = _cleanName(v ?? '');
  if (s.isEmpty) return 'Please enter your full name';
  if (s.length < 2) return 'Name must contain at least 2 characters';
  if (s.length > _maxName) return 'Name must be $_maxName characters or fewer';
  if (!_nameChars.hasMatch(s)) return 'Use letters only (no numbers or symbols)';
  return null;
}

String? _validateRegisterEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Please enter your email';
  if (s.length > _maxEmail) return 'Email must be $_maxEmail characters or fewer';
  if (s.contains('..') || !_emailFormat.hasMatch(s)) {
    return 'Enter a valid email address';
  }
  final domain = s.split('@').last.toLowerCase();
  final fix = _emailTypos[domain];
  if (fix != null) return 'Did you mean $fix?';
  return null;
}

String? _validateRegisterPhone(String? v) {
  final raw = (v ?? '').trim();
  if (raw.isEmpty) return 'Please enter your phone number';
  if (RegExp(r'[^0-9+\-() ]').hasMatch(raw)) {
    return 'Phone number can only contain digits';
  }
  final d = _phoneDigits(raw);
  if (d.length != 10) return 'Enter a 10-digit mobile number';
  if (!RegExp(r'^[6-9]').hasMatch(d)) {
    return 'Mobile number must start with 6, 7, 8 or 9';
  }
  if (RegExp(r'^(\d)\1{9}$').hasMatch(d)) return 'Enter a real mobile number';
  return null;
}

String? _validateRegisterPassword(String? v, {required String name, required String email}) {
  final p = v ?? '';
  if (p.isEmpty) return 'Please create a password';
  if (p.length < _minPassword) {
    return 'Password must be at least $_minPassword characters';
  }
  if (p.length > _maxPassword) {
    return 'Password must be $_maxPassword characters or fewer';
  }
  if (RegExp(r'\s').hasMatch(p)) return 'Password cannot contain spaces';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) {
    return 'Use at least one letter and one number';
  }
  final lower = p.toLowerCase();
  if (_commonPasswords.contains(lower) || RegExp(r'^(.)\1+$').hasMatch(p)) {
    return 'This password is too common. Choose a stronger one';
  }
  final local = email.trim().toLowerCase().split('@').first;
  if (local.length >= 4 && lower.contains(local)) {
    return 'Password should not contain your email name';
  }
  final first = _cleanName(name).toLowerCase().split(' ').first;
  if (first.length >= 4 && lower.contains(first)) {
    return 'Password should not contain your name';
  }
  return null;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isSubmitting = false;

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

    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();

    _glowController.dispose();
    _entranceController.dispose();

    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFF9E2935) : _navy,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  Future<void> _submitRegistration() async {
    if (_isSubmitting) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      _showMessage(
        'Please accept the Terms & Conditions to continue.',
        isError: true,
      );
      return;
    }

    final name = _cleanName(_nameController.text);
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneDigits(_phoneController.text);
    final password = _passwordController.text;

    setState(() => _isSubmitting = true);

    UserCredential? credential;

    try {
      // Create the Firebase Authentication account.
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

      // Save the customer's profile using the Firebase Auth UID.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
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
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'email-already-in-use':
          _showMessage(
            'An account with this email already exists. Please sign in.',
            isError: true,
          );
          break;

        case 'invalid-email':
          _showMessage(
            'Please enter a valid email address.',
            isError: true,
          );
          break;

        case 'weak-password':
          _showMessage(
            'Please choose a stronger password.',
            isError: true,
          );
          break;

        case 'network-request-failed':
          _showMessage(
            'Network error. Check your internet connection and try again.',
            isError: true,
          );
          break;

        case 'too-many-requests':
          _showMessage(
            'Too many attempts. Please wait and try again.',
            isError: true,
          );
          break;

        case 'operation-not-allowed':
          _showMessage(
            'Email sign-up is not available right now. Please contact PhoneHub support.',
            isError: true,
          );
          break;

        default:
          _showMessage(
            'Could not create your account. Please try again.',
            isError: true,
          );
      }
    } on FirebaseException catch (e) {
      // If the profile write fails, try to remove the newly created Auth
      // account so the user is not left with a partially created account.
      try {
        await credential?.user?.delete();
      } catch (_) {
        // Keep the original Firestore error as the useful error.
      }

      if (!mounted) return;

      if (e.code == 'permission-denied') {
        _showMessage(
          'Your profile could not be saved. Please check your Firestore Rules.',
          isError: true,
        );
      } else if (e.code == 'unavailable') {
        _showMessage(
          'The service is temporarily unavailable. Please try again.',
          isError: true,
        );
      } else {
        _showMessage(
          'Could not save your profile. Please try again.',
          isError: true,
        );
      }
    } catch (_) {
      try {
        await credential?.user?.delete();
      } catch (_) {
        // Cleanup is best-effort.
      }

      if (!mounted) return;

      _showMessage(
        'Registration failed. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  Widget _eye(bool obscured, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      tooltip: obscured ? 'Show password' : 'Hide password',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 44,
        minHeight: 44,
      ),
      icon: Icon(
        obscured
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        color: AppColors.muted,
        size: 19,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFD0E1F9),
        body: Stack(
          children: [
            const _RegisterBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale =
                  (constraints.maxHeight / 760).clamp(0.82, 1.0).toDouble();

                  Widget gap(double height) {
                    return SizedBox(height: height * scale);
                  }

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      22,
                      10 * scale,
                      22,
                      20 * scale,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 30 * scale,
                      ),
                      child: Center(
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
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildBackButton(),

                                  gap(12),

                                  _buildBrandIcon(scale),

                                  gap(13),

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
                                        fontSize: 27,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                        height: 1.12,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 7),

                                  Text(
                                    'Join PhoneHub for better phone deals',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _navy.withValues(alpha: 0.76),
                                      fontSize: AppText.small,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  gap(12),

                                  _buildAccentLine(),

                                  gap(20),

                                  _buildRegistrationCard(scale),

                                  gap(14),

                                  _buildSignInLink(),

                                  gap(10),

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

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.84),
        elevation: 2,
        shadowColor: const Color(0xFF3D5BB8).withValues(alpha: 0.20),
        shape: const CircleBorder(
          side: BorderSide(color: _line),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.maybePop(context),
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

  Widget _buildBrandIcon(double scale) {
    final iconSize = 72 * scale;

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.48),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cyan.withValues(
                        alpha: _glowAnimation.value,
                      ),
                      blurRadius: 27,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF3D5BB8).withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(23),
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
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: _navy,
                    size: 34 * scale,
                  ),
                ),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                        color: const Color(0xFF3675FF)
                            .withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
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

  Widget _buildAccentLine() {
    return Center(
      child: Container(
        width: 58,
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
              color: const Color(0xFF3675FF).withValues(alpha: 0.22),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationCard(double scale) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D5BB8).withValues(alpha: 0.20),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              19,
              21 * scale,
              19,
              20 * scale,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  Colors.white.withValues(alpha: 0.87),
                ],
              ),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.96),
                width: 1.2,
              ),
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel('Full name'),
                  _RegisterInput(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    onSubmitted: (_) => _emailFocus.requestFocus(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxName),
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[\p{L}\p{M} .'\-]", unicode: true),
                      ),
                    ],
                    validator: _validateRegisterName,
                  ),

                  SizedBox(height: 15 * scale),

                  const _FieldLabel('Email address'),
                  _RegisterInput(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hint: 'you@example.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _phoneFocus.requestFocus(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxEmail),
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: _validateRegisterEmail,
                  ),

                  SizedBox(height: 15 * scale),

                  const _FieldLabel('Phone number'),
                  _RegisterInput(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    hint: 'Enter your phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(16),
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9+\-() ]'),
                      ),
                    ],
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: _validateRegisterPhone,
                  ),

                  SizedBox(height: 15 * scale),

                  const _FieldLabel('Password'),
                  _RegisterInput(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hint: 'Create a password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxPassword),
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    // Re-check "Confirm password" when the password changes.
                    onChanged: (_) {
                      if (_confirmPasswordController.text.isNotEmpty) {
                        _confirmFieldKey.currentState?.validate();
                      }
                    },
                    suffix: _eye(
                      _obscurePassword,
                      _togglePasswordVisibility,
                    ),
                    validator: (value) => _validateRegisterPassword(
                      value,
                      name: _nameController.text,
                      email: _emailController.text,
                    ),
                  ),

                  SizedBox(height: 15 * scale),

                  const _FieldLabel('Confirm password'),
                  _RegisterInput(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    hint: 'Re-enter your password',
                    icon: Icons.lock_reset_rounded,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _submitRegistration(),
                    fieldKey: _confirmFieldKey,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxPassword),
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    suffix: _eye(
                      _obscureConfirmPassword,
                      _toggleConfirmPasswordVisibility,
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Please confirm your password';
                      }

                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }

                      return null;
                    },
                  ),

                  SizedBox(height: 16 * scale),

                  _buildTermsCheckbox(),

                  SizedBox(height: 18 * scale),

                  _buildSubmitButton(),

                  const SizedBox(height: 14),

                  _buildFormHint(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => _acceptTerms = !_acceptTerms);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) {
                    setState(() => _acceptTerms = value ?? false);
                  },
                  activeColor: _blue,
                  checkColor: Colors.white,
                  side: const BorderSide(color: AppColors.muted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'I agree to the Terms & Conditions and Privacy Policy.',
                    style: TextStyle(
                      color: _navy.withValues(alpha: 0.78),
                      fontSize: AppText.small,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
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
              color: const Color(0xFF3675FF).withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isSubmitting
                  ? const Row(
                key: ValueKey('loading'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 11),
                  Text(
                    'Creating account...',
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
                    'Create Account',
                    style: TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 9),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 15,
          color: _navy.withValues(alpha: 0.65),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Your information is handled securely.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _navy.withValues(alpha: 0.70),
              fontSize: AppText.caption,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Already have an account?',
            style: TextStyle(
              color: _navy.withValues(alpha: 0.80),
              fontSize: AppText.small,
            ),
          ),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              ),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: _navy,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign in',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: AppText.small,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityFooter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: _navy.withValues(alpha: 0.72),
            ),
            const SizedBox(width: 7),
            Text(
              'Secure registration • PhoneHub',
              style: TextStyle(
                color: _navy.withValues(alpha: 0.72),
                fontSize: AppText.caption,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visible field labels above each input.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: _navy,
          fontSize: AppText.small,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _RegisterInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  const _RegisterInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.fieldKey,
    this.autofillHints,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
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
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: _blue,
              size: 17,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 49,
          minHeight: 46,
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
          fontSize: AppText.caption,
          height: 1.25,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: _line,
            width: 1,
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
            color: _errorRed,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: _errorRed,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Background retains the original three-color gradient and blue glow effects.
class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
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