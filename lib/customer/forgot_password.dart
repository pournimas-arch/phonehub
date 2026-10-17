import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/customer/theme.dart';

import 'login_screen.dart';

const Color _navy = Color(0xFF10265F);
const Color _blue = Color(0xFF2452B8);
const Color _cyan = Color(0xFF38D9FF);
const Color _line = Color(0xFFDCE8FF);
const Color _fieldFill = Color(0xFFF4F8FF);
const Color _errorRed = Color(0xFFE5484D);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _sent = false;
  bool _sending = false;
  String? _errorMessage;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _glowAnimation = Tween<double>(
      begin: 0.10,
      end: 0.28,
    ).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _glowController.repeat(reverse: true);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
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
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFF9E2935) : _navy,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
  }

  Future<void> _sendResetEmail() async {
    if (_sending) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      setState(() {
        _sent = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'user-not-found':
        // Show the same confirmation as a successful request so the
        // screen does not disclose whether an email has an account.
          setState(() {
            _sent = true;
          });
          break;

        case 'invalid-email':
          setState(() {
            _errorMessage = 'Please enter a valid email address.';
          });
          break;

        case 'network-request-failed':
          setState(() {
            _errorMessage =
            'Network error. Check your internet connection and try again.';
          });
          break;

        case 'too-many-requests':
          setState(() {
            _errorMessage =
            'Too many attempts. Please wait a little before trying again.';
          });
          break;

        case 'operation-not-allowed':
          setState(() {
            _errorMessage =
            'Password reset is not enabled. Please contact support.';
          });
          break;

        default:
          setState(() {
            _errorMessage =
            'Could not process your request. Please try again.';
          });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        'Something went wrong. Please check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _editEmail() {
    if (_sending) return;

    setState(() {
      _sent = false;
      _errorMessage = null;
    });

    _entranceController.forward(from: 0);
  }

  void _goToSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
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
            const _ForgotPasswordBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 34,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 440,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBackButton(),
                              const SizedBox(height: 28),
                              _buildBrandIcon(),
                              const SizedBox(height: 19),
                              _buildHeading(),
                              const SizedBox(height: 26),
                              FadeTransition(
                                opacity: _entranceAnimation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.035),
                                    end: Offset.zero,
                                  ).animate(_entranceAnimation),
                                  child: _buildCard(),
                                ),
                              ),
                              const SizedBox(height: 19),
                              _buildSecurityFooter(),
                            ],
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

  Widget _buildBrandIcon() {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
                padding: const EdgeInsets.all(6),
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
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF3D5BB8)
                          .withValues(alpha: 0.17),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
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
                  child: Icon(
                    _sent
                        ? Icons.mark_email_read_rounded
                        : Icons.lock_reset_rounded,
                    color: _navy,
                    size: 40,
                  ),
                ),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 25,
                  height: 25,
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
                  child: Icon(
                    _sent
                        ? Icons.check_rounded
                        : Icons.shield_outlined,
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

  Widget _buildHeading() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFF17356F),
              Color(0xFF3D5BB8),
            ],
          ).createShader(bounds),
          child: Text(
            _sent ? 'Check your email' : 'Forgot password?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _sent
              ? 'Your next step to getting back into PhoneHub'
              : 'No worries. Let’s help you get back into your account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy.withValues(alpha: 0.76),
            fontSize: AppText.small,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 56,
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
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
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
            padding: const EdgeInsets.all(24),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _sent ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('resetForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionIcon(
            icon: Icons.mark_email_unread_outlined,
          ),
          const SizedBox(height: 19),
          const Text(
            'Reset your password',
            style: TextStyle(
              color: _navy,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the email address linked to your PhoneHub account. '
                'We’ll send instructions to reset your password.',
            style: TextStyle(
              color: _navy.withValues(alpha: 0.73),
              fontSize: AppText.body,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 23),
          const _FieldLabel('Email address'),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            onFieldSubmitted: (_) => _sendResetEmail(),
            style: const TextStyle(
              color: _navy,
              fontSize: AppText.body,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: _blue,
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Please enter your email address';
              }

              if (!RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              ).hasMatch(email)) {
                return 'Enter a valid email address';
              }

              return null;
            },
            decoration: InputDecoration(
              hintText: 'you@example.com',
              hintStyle: const TextStyle(
                color: AppColors.muted,
                fontSize: AppText.body,
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
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: _blue,
                    size: 17,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 49,
                minHeight: 46,
              ),
              filled: true,
              fillColor: _fieldFill.withValues(alpha: 0.96),
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
                borderSide: const BorderSide(color: _line),
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
                borderSide: const BorderSide(color: _errorRed),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: _errorRed,
                  width: 1.4,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 13),
            _buildErrorMessage(_errorMessage!),
          ],
          const SizedBox(height: 22),
          _buildPrimaryButton(
            label: 'Send Reset Link',
            loadingLabel: 'Sending reset link...',
            icon: Icons.arrow_forward_rounded,
            isLoading: _sending,
            onPressed: _sendResetEmail,
          ),
          const SizedBox(height: 17),
          Center(
            child: TextButton.icon(
              onPressed: _sending ? null : _goToSignIn,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 17,
              ),
              label: const Text('Back to Sign In'),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: AppText.small,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('resetSuccess'),
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF16A34A).withValues(alpha: 0.10),
            border: Border.all(
              color: const Color(0xFF16A34A).withValues(alpha: 0.20),
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Color(0xFF16A34A),
            size: 37,
          ),
        ),
        const SizedBox(height: 21),
        const Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'If an account is associated with this email, '
              'you’ll receive a password reset link shortly.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _navy.withValues(alpha: 0.74),
            fontSize: AppText.body,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.email_outlined,
                color: _blue,
                size: 21,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reset email requested for',
                      style: TextStyle(
                        color: _navy,
                        fontSize: AppText.small,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      _emailController.text.trim(),
                      style: const TextStyle(
                        color: _blue,
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        _buildHelpfulTips(),
        const SizedBox(height: 22),
        _buildPrimaryButton(
          label: 'Back to Sign In',
          icon: Icons.login_rounded,
          onPressed: _goToSignIn,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _sending ? null : _sendResetEmail,
            icon: _sending
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _blue,
              ),
            )
                : const Icon(
              Icons.refresh_rounded,
              size: 19,
            ),
            label: Text(
              _sending ? 'Sending...' : 'Resend reset link',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: _line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppText.small,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        TextButton(
          onPressed: _sending ? null : _editEmail,
          style: TextButton.styleFrom(
            foregroundColor: _navy,
          ),
          child: const Text(
            'Use a different email address',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppText.small,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionIcon({required IconData icon}) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _blue.withValues(alpha: 0.08),
        ),
      ),
      child: Icon(
        icon,
        color: _blue,
        size: 29,
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _errorRed.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _errorRed,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _errorRed,
                fontSize: AppText.small,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpfulTips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: _blue,
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Can’t find the email?',
                style: TextStyle(
                  color: _navy,
                  fontSize: AppText.small,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _tip('Check your spam or junk folder.'),
          const SizedBox(height: 7),
          _tip('Make sure you entered the correct email.'),
          const SizedBox(height: 7),
          _tip('The reset link may take a few minutes to arrive.'),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            Icons.circle,
            color: _blue,
            size: 5,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _navy.withValues(alpha: 0.74),
              fontSize: AppText.small,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    String loadingLabel = 'Please wait...',
    bool isLoading = false,
    IconData? icon,
  }) {
    return SizedBox(
      height: 52,
      width: double.infinity,
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
              color: const Color(0xFF3675FF).withValues(alpha: 0.30),
              blurRadius: 17,
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
                Colors.white.withValues(alpha: 0.17),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
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
              child: isLoading
                  ? Row(
                key: const ValueKey('buttonLoading'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loadingLabel,
                    style: const TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
                  : Row(
                key: const ValueKey('buttonReady'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 9),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 8,
        ),
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
              'Secure account recovery • PhoneHub',
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

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 2,
        bottom: 7,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _navy,
          fontSize: AppText.small,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// PhoneHub's original background gradient and blue ambient glow effects.
class _ForgotPasswordBackground extends StatelessWidget {
  const _ForgotPasswordBackground();

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