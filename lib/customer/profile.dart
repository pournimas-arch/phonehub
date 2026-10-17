import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'data.dart';
import 'edit_profile_screen.dart';
import 'help_support.dart';
import 'notification.dart';
import 'saved_addresses.dart';
import 'theme.dart';

// Same background gradient as the Home screen.
const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFFCFDFF), // top: nearly white
    Color(0xFFE9F1FE), // middle
    Color(0xFFD0E1F9), // bottom
  ],
);

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob(this.size, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _cardBorder = Color(0xFFDCE8FF);

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showPaymentInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Payment methods'),
        content: const Text(
          'Payment options are shown during checkout. No card or UPI details are stored on this profile screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Policies written by the admin in Settings (appConfig/store: returnsPolicy, warrantyPolicy,
  /// privacyPolicy, returnDays, refundDays). Live: an edit by the admin shows here at once.
  void _showPolicies(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('PhoneHub policies'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder(
            stream: FirebaseFirestore.instance.collection('appConfig').doc('store').snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('Could not load the policies. Please check your connection and try again.');
              }
              if (!snap.hasData) {
                return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
              }
              final c = snap.data!.data() ?? <String, dynamic>{};
              String text(String key) => (c[key] is String) ? (c[key] as String).trim() : '';
              final rd = c['returnDays'];
              final fd = c['refundDays'];
              final sections = <(String, String)>[
                if (rd is num && rd > 0)
                  ('Return window', 'You can request a return within ${rd.toInt()} days of delivery.'
                      '${fd is num && fd > 0 ? ' Refunds are processed within ${fd.toInt()} working days.' : ''}'),
                if (text('returnsPolicy').isNotEmpty) ('Returns', text('returnsPolicy')),
                if (text('warrantyPolicy').isNotEmpty) ('Warranty', text('warrantyPolicy')),
                if (text('privacyPolicy').isNotEmpty) ('Privacy', text('privacyPolicy')),
              ];
              if (sections.isEmpty) {
                return const Text('PhoneHub has not published its policies yet. Please contact support from the Help & support screen.');
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in sections) ...[
                      Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body)),
                      const SizedBox(height: 4),
                      Text(s.$2, style: const TextStyle(fontSize: AppText.small, height: 1.4)),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
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
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3D5BB8).withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_rounded, size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Profile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppText.title,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'YOUR ACCOUNT',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: AppText.caption,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(right: -50, top: -60, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withValues(alpha: 0.08))),
                          Positioned(left: -40, bottom: -70, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05))),
                          ValueListenableBuilder<UserProfile>(
                            valueListenable: profile,
                            builder: (context, userProfile, _) {
                              final displayName = userProfile.name.trim().isNotEmpty
                                  ? userProfile.name.trim()
                                  : (authUser?.displayName?.trim().isNotEmpty == true
                                  ? authUser!.displayName!.trim()
                                  : 'Welcome to PhoneHub');
                              final displayEmail = userProfile.email.trim().isNotEmpty
                                  ? userProfile.email.trim()
                                  : (authUser?.email ?? 'Manage your PhoneHub account');
                              final initial = displayName == 'Welcome to PhoneHub'
                                  ? 'P'
                                  : displayName.characters.first.toUpperCase();
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                    child: CircleAvatar(
                                      radius: 30,
                                      backgroundColor: AppColors.primary,
                                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: AppText.title)),
                                        const SizedBox(height: 5),
                                        Text(displayEmail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: AppText.small, height: 1.35)),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _open(context, const EditProfileScreen()),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 3),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              Text('Edit profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: AppText.small)),
                                              SizedBox(width: 5),
                                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                                            ]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _section('My account', [
                      _ProfileRow(
                        icon: Icons.person_outline_rounded,
                        color: AppColors.primary,
                        title: 'Personal details',
                        subtitle: 'Name, email and phone',
                        onTap: () => _open(context, const EditProfileScreen()),
                      ),
                      _ProfileRow(
                        icon: Icons.location_on_outlined,
                        color: AppColors.primary,
                        title: 'Saved addresses',
                        subtitle: 'Manage delivery addresses',
                        onTap: () => _open(context, const SavedAddressesScreen()),
                      ),
                      _ProfileRow(
                        icon: Icons.payment_outlined,
                        color: AppColors.accent,
                        title: 'Payment methods',
                        subtitle: 'Payment options at checkout',
                        onTap: () => _showPaymentInfo(context),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    _section('Preferences & support', [
                      _ProfileRow(
                        icon: Icons.notifications_none_rounded,
                        color: AppColors.success,
                        title: 'Notifications',
                        subtitle: 'Order and offer updates',
                        onTap: () => _open(context, const NotificationsScreen()),
                      ),
                      _ProfileRow(
                        icon: Icons.headset_mic_outlined,
                        color: AppColors.primary,
                        title: 'Help & support',
                        subtitle: 'FAQs and contact support',
                        onTap: () => _open(context, const HelpSupportScreen()),
                      ),
                      _ProfileRow(
                        icon: Icons.policy_outlined,
                        color: AppColors.muted,
                        title: 'Policies',
                        subtitle: 'Returns, warranty and privacy',
                        onTap: () => _showPolicies(context),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    if (authUser == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Sign in to save your details and see your orders.',
                          style: TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.4),
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
          child: Text(title, style: const TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w800, color: AppColors.muted)),
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
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: color, size: 21),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.body, color: AppColors.text)),
    subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small))),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
  );
}