import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/main_shell.dart';
import 'package:phonehub/delivery%20partner/partner_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isActivating = false;
  bool busy = false;
  bool hidePassword = true;
  bool sendingReset = false;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String? error;
  String? emailError;
  String? passwordError;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (error != null || emailError != null || passwordError != null) {
      setState(() {
        error = null;
        emailError = null;
        passwordError = null;
      });
    }
  }

  bool _validateInputs() {
    final email = _email.text.trim();
    final password = _pass.text;

    String? newEmailError;
    String? newPasswordError;

    if (email.isEmpty) {
      newEmailError = 'Please enter your email address';
    } else if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email)) {
      newEmailError = 'Please enter a valid email address';
    }

    if (password.isEmpty) {
      newPasswordError = isActivating
          ? 'Please create a password'
          : 'Please enter your password';
    } else if (password.length < 6) {
      newPasswordError = 'Password must contain at least 6 characters';
    }

    setState(() {
      emailError = newEmailError;
      passwordError = newPasswordError;
      error = null;
    });

    if (newEmailError != null) {
      _emailFocus.requestFocus();
      return false;
    }

    if (newPasswordError != null) {
      _passwordFocus.requestFocus();
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (busy || !_validateInputs()) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final email = _email.text.trim();
      final password = _pass.text;

      final result = isActivating
          ? await PartnerService.instance.activate(
        email,
        password,
      )
          : await PartnerService.instance.login(
        email,
        password,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          busy = false;
          error = result;
        });
        return;
      }

      // Replace the login route after successful authentication.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const MainShell(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        busy = false;
        error = 'Something went wrong. Please try again.';
      });

      debugPrint('Partner authentication error: $e');
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final email = _email.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        emailError = 'Enter a valid email address first';
        error = null;
      });
      _emailFocus.requestFocus();
      return;
    }

    if (sendingReset || busy) return;

    setState(() {
      sendingReset = true;
      error = null;
    });

    try {
      final result = await PartnerService.instance.sendPasswordReset(email);

      if (!mounted) return;

      setState(() => sendingReset = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: result == null
                ? const Color(0xFF087F69)
                : const Color(0xFFB42318),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Row(
              children: [
                Icon(
                  result == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result ?? 'Password reset link sent to $email',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;

      setState(() => sendingReset = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send the reset link. Please try again.',
            style: TextStyle(fontSize: 12.5),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      debugPrint('Password reset error: $e');
    }
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();

    setState(() {
      isActivating = !isActivating;
      error = null;
      emailError = null;
      passwordError = null;
      _pass.clear();
    });
  }

  InputDecoration _dec({
    required String hint,
    required IconData icon,
    Widget? suffix,
    String? fieldError,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      errorText: fieldError,
      errorStyle: const TextStyle(fontSize: 11),
      hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _email,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      style: const TextStyle(fontSize: 13),
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      onChanged: (_) {
        if (emailError != null || error != null) _clearErrors();
      },
      onSubmitted: (_) => _passwordFocus.requestFocus(),
      decoration: _dec(hint: 'Email address', icon: Icons.mail_outline_rounded, fieldError: emailError),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _pass,
      focusNode: _passwordFocus,
      obscureText: hidePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      style: const TextStyle(fontSize: 13),
      onChanged: (_) {
        if (passwordError != null || error != null) _clearErrors();
      },
      onSubmitted: (_) => _submit(),
      decoration: _dec(
        hint: isActivating ? 'Create a password' : 'Password',
        icon: Icons.lock_outline_rounded,
        fieldError: passwordError,
        suffix: IconButton(
          tooltip: hidePassword ? 'Show password' : 'Hide password',
          icon: Icon(hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.muted),
          onPressed: () => setState(() => hidePassword = !hidePassword),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF0B5E57), AppColors.primary, Color(0xFF14B8A6)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: busy
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isActivating ? 'Activate & Login' : 'Login',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFDDF3EE),
              Color(0xFFF7FAF9),
              Color(0xFFE4F1EE),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Soft decorative shapes keep the background subtle.
            Positioned(
              top: -75,
              right: -55,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -90,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.06),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    keyboardOpen ? 6 : 14,
                    18,
                    14,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0B5E57),
                                    AppColors.primary,
                                    Color(0xFF14B8A6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.phone_android_rounded,
                                color: Colors.white,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PhoneHub',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 26,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'DELIVERY PARTNER',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Main login card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(23),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withValues(
                                  alpha: 0.09,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isActivating
                                          ? Icons.person_add_alt_1_rounded
                                          : Icons.lock_open_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isActivating
                                          ? 'ACCOUNT ACTIVATION'
                                          : 'PARTNER ACCESS',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 11),
                              Text(
                                isActivating
                                    ? 'Activate your account'
                                    : 'Welcome back',
                                style: const TextStyle(
                                  fontSize: 23,
                                  height: 1.12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.7,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                isActivating
                                    ? 'Use the email registered by your admin to get started.'
                                    : 'Sign in to manage your deliveries and account.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                'Email address',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildEmailField(),
                              const SizedBox(height: 12),
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildPasswordField(),
                              if (!isActivating)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: (sendingReset || busy)
                                        ? null
                                        : _forgotPassword,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 5,
                                      ),
                                      foregroundColor: AppColors.primary,
                                    ),
                                    child: Text(
                                      sendingReset
                                          ? 'Sending reset link...'
                                          : 'Forgot password?',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 6),
                              if (error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.07,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.danger,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error!,
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 12,
                                            height: 1.4,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              _buildButton(),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.border.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: AppColors.muted.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.border.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment:
                                  WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      isActivating
                                          ? 'Already activated? '
                                          : 'New delivery partner? ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: busy ? null : _toggleMode,
                                      child: Text(
                                        isActivating
                                            ? 'Login here'
                                            : 'Activate account',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Your account and information stay protected',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                ),
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
          ],
        ),
      ),
    );
  }
}
