import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _navy = Color(0xFF10265F);
const Color _blue = Color(0xFF2452B8);

/// Forgot Password – enter email, get a reset link confirmation.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool sent = false;
  bool _sending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _email.text.trim(),
      );
      if (!mounted) return;
      setState(() => sent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (e.code) {
          'invalid-email' => 'Please enter a valid email address.',
          'user-not-found' => 'No account was found for this email address.',
          'network-request-failed' => 'Network error. Check your connection and try again.',
          'too-many-requests' => 'Too many attempts. Please wait and try again.',
          _ => 'Could not send the reset link. Please try again.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not send the reset link. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F8FF), Color(0xFFBBD5FB), Color(0xFF7FADEE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: _navy),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFDCE8FF)),
                      boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: sent ? _success() : _form(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _blue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.lock_reset_rounded, color: _blue, size: 30),
          ),
          const SizedBox(height: 18),
          const Text('Forgot password?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          Text('Enter your email and we will send you a link to reset your password.', style: TextStyle(color: _navy.withValues(alpha: 0.7), fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 22),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email address' : null,
            decoration: InputDecoration(
              hintText: 'Email address',
              prefixIcon: const Icon(Icons.email_outlined, color: _blue),
              filled: true,
              fillColor: const Color(0xFFF4F8FF),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send Reset Link'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0x1A16A34A), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF16A34A), size: 34),
        ),
        const SizedBox(height: 18),
        const Text('Check your email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        Text('We sent a reset link to ${_email.text.trim()}.', textAlign: TextAlign.center, style: TextStyle(color: _navy.withValues(alpha: 0.7), fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 22),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Sign In')),
      ],
    );
  }
}
