import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'widgets.dart';
import 'shared_ui.dart';

// ---------- Shared styling (same as Home screen) ----------

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF4F8FF), Color(0xFFBBD5FB), Color(0xFF7FADEE)],
);

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob(this.size, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _cardBorder = Color(0xFFDCE8FF);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(gradient: _bgGradient),
          child: Stack(
            children: [
              Positioned(top: -70, right: -80, child: _Blob(240, 0.35)),
              Positioned(top: 420, left: -120, child: _Blob(280, 0.20)),
              SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    // ---- Header ----
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5))],
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your account', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                              SizedBox(height: 1),
                              Text('My Profile', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ---- Gradient welcome card ----
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 22, offset: const Offset(0, 12))],
                      ),
                      child: Stack(
                        children: [
                          Positioned(right: -50, top: -60, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withValues(alpha: 0.08))),
                          Positioned(left: -40, bottom: -70, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05))),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                child: const CircleAvatar(radius: 30, backgroundColor: AppColors.primary, child: Icon(Icons.person_outline_rounded, size: 32, color: Colors.white)),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Welcome to PhoneHub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                                    SizedBox(height: 5),
                                    Text('Sign-in and account services can be connected here.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Account ----
                    _section('My account', const [
                      _ProfileRow(icon: Icons.person_outline_rounded, color: AppColors.primary, title: 'Personal details', subtitle: 'Name, email and phone'),
                      _ProfileRow(icon: Icons.location_on_outlined, color: AppColors.primary, title: 'Saved addresses', subtitle: 'Manage delivery addresses'),
                      _ProfileRow(icon: Icons.payment_outlined, color: AppColors.accent, title: 'Payment methods', subtitle: 'Manage payment options'),
                    ]),
                    const SizedBox(height: 22),

                    // ---- Preferences & support ----
                    _section('Preferences & support', const [
                      _ProfileRow(icon: Icons.notifications_none_rounded, color: AppColors.success, title: 'Notifications', subtitle: 'Order and offer updates'),
                      _ProfileRow(icon: Icons.headset_mic_outlined, color: AppColors.primary, title: 'Help & support', subtitle: 'FAQs and contact support'),
                      _ProfileRow(icon: Icons.policy_outlined, color: AppColors.muted, title: 'Policies', subtitle: 'Returns, warranty and privacy'),
                    ]),
                    const SizedBox(height: 18),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'Demo UI: connect authentication, address storage, payments and support APIs before production.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 0, 10),
          child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: _cardBorder)),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i != rows.length - 1) const Divider(height: 1, indent: 74, endIndent: 16, color: Color(0xFFE8EFFC)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _ProfileRow({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () {},
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: color, size: 21),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
    subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12))),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
  );
}