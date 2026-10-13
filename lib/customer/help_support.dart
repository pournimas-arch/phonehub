import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';

/// Help & Support – contact options and common questions.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _phone = '+91 98765 00000';
  String _email = 'support@phonehub.in';
  bool _loadingContact = true;

  @override
  void initState() {
    super.initState();
    _loadSupportContact();
  }

  Future<void> _loadSupportContact() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appConfig')
          .doc('support')
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        setState(() {
          _phone = (data['phone'] as String?)?.trim().isNotEmpty == true
              ? (data['phone'] as String).trim()
              : _phone;
          _email = (data['email'] as String?)?.trim().isNotEmpty == true
              ? (data['email'] as String).trim()
              : _email;
        });
      }
    } catch (_) {
      // Keep the existing fallback contact details if Firestore is unavailable.
    } finally {
      if (mounted) setState(() => _loadingContact = false);
    }
  }

  static const _faqs = [
    ('How do I track my order?', 'Open the Orders tab and tap your order to see live delivery status.'),
    ('What does the phone condition mean?', 'Like New phones have no visible marks, Good phones have light wear and Fair phones have visible wear but work perfectly.'),
    ('Can I return a phone?', 'Yes. You can request a return within 7 days of delivery if the phone is not as described.'),
    ('How do I use a coupon?', 'Enter the coupon code in your cart before you pay. Open Coupons & Offers to copy a code.'),
  ];

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Widget _contact(BuildContext context, IconData icon, Color color, String title, String value) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _copy(context, title, value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: cardDeco(),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(value, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              _contact(context, Icons.call_rounded, AppColors.success, 'Call', _loadingContact ? 'Loading…' : _phone),
              const SizedBox(width: 12),
              _contact(context, Icons.email_outlined, AppColors.primary, 'Email', _loadingContact ? 'Loading…' : _email),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Frequently asked questions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 12),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: cardDeco(),
            child: Column(
              children: [
                for (int i = 0; i < _faqs.length; i++) ...[
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      title: Text(_faqs[i].$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text)),
                      children: [Text(_faqs[i].$2, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4))],
                    ),
                  ),
                  if (i != _faqs.length - 1) const Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
