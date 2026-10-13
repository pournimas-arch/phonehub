import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../customer/theme.dart';
import 'assigned_orders_screen.dart';

/// Screen 1 – Login (2h)
/// Illustration, +91 mobile number, Get OTP, Login with Email.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool useEmail = false;
  final _ctrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (!useEmail && v.length != 10) {
      setState(() => error = 'Enter a valid 10-digit mobile number');
      return;
    }
    if (useEmail && !v.contains('@')) {
      setState(() => error = 'Enter a valid email address');
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Illustration header
            Container(
              height: 330,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF134E4A)]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(44)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: -60, right: -40, child: CircleAvatar(radius: 120, backgroundColor: Colors.white.withValues(alpha: 0.08))),
                  Positioned(bottom: -50, left: -50, child: CircleAvatar(radius: 110, backgroundColor: Colors.white.withValues(alpha: 0.07))),
                  Positioned(top: 90, left: 40, child: _floatIcon(Icons.inventory_2_rounded)),
                  Positioned(top: 120, right: 44, child: _floatIcon(Icons.location_on_rounded)),
                  Positioned(bottom: 90, right: 70, child: _floatIcon(Icons.phone_iphone_rounded)),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(34),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 12))],
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, size: 62, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        const Text('PhoneHub Delivery', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('Deliver happiness. Earn more.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome back, Partner 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text)),
                  const SizedBox(height: 6),
                  Text(
                    useEmail ? 'Login with your registered email address' : 'Login with your registered mobile number',
                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: cardDeco(radius: 18),
                    child: Row(
                      children: [
                        if (!useEmail)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                            child: const Text('🇮🇳  +91', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                          ),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            key: ValueKey(useEmail),
                            keyboardType: useEmail ? TextInputType.emailAddress : TextInputType.phone,
                            inputFormatters: useEmail ? null : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            onChanged: (_) {
                              if (error != null) setState(() => error = null);
                            },
                            decoration: InputDecoration(
                              hintText: useEmail ? 'you@example.com' : 'Mobile number',
                              hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500),
                              prefixIcon: useEmail ? const Icon(Icons.mail_outline_rounded, color: AppColors.muted) : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton(onPressed: _submit, child: Text(useEmail ? 'Continue' : 'Get OTP')),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppColors.muted))),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        useEmail = !useEmail;
                        _ctrl.clear();
                        error = null;
                      }),
                      icon: Icon(useEmail ? Icons.phone_android_rounded : Icons.mail_outline_rounded, size: 20),
                      label: Text(useEmail ? 'Login with Mobile' : 'Login with Email', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatIcon(IconData i) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
    child: Icon(i, color: Colors.white, size: 22),
  );
}
