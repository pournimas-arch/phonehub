import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/common.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';
import 'delivery_details_screen.dart';
import 'partner_service.dart';

/// Partner account menu + all its sub screens.
/// Same UI language as Delivery Details: teal gradient header, 18px cards,
/// staggered reveal animation, floating teal toast, bottom action bar.
///
/// Screens in this file:
///  PartnerMenuScreen, MyDocumentsScreen, VehicleDetailsScreen,
///  BankAccountScreen, DeliveryHistoryScreen, IncentivesScreen,
///  TrainingSafetyScreen, HelpSupportScreen, TermsPrivacyScreen

// ================================================================ Shared

const Color _teal = Color(0xFF0F766E);
const Color _tealLight = Color(0xFF14B8A6);
const Color _amber = Color(0xFFB45309);

/// Reads a text field of the partner's saved record (partners/{email}).
String _s(Map<String, dynamic> d, String k) => (d[k] ?? '').toString().trim();
String _orDash(String v) => v.isEmpty ? '—' : v;

/// Live copy of an admin-edited document (appConfig/{name}). Errors are treated as "nothing saved".
Stream<Map<String, dynamic>> _cfg(String name) => FirebaseFirestore.instance
    .doc('appConfig/$name')
    .snapshots()
    .map((s) => s.data() ?? <String, dynamic>{})
    .handleError((_) {});

List<String> _strs(dynamic v) =>
    v is List ? v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList() : <String>[];

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => e.map((k, val) => MapEntry('$k', val))).toList()
    : <Map<String, dynamic>>[];

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Small spinner card shown only while the first copy of the admin's text is loading.
Widget _loadingCard() => _card(
  child: const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  ),
);

/// Shown when the admin has not saved this text yet (nothing is made up in the app).
Widget _notSetCard(String text) => _card(
  child: Text(
    text,
    style: const TextStyle(color: AppColors.muted, height: 1.45, fontSize: 12),
  ),
);

/// "Not uploaded" | "Pending" | "Verified" | "Rejected" for a document key (licence / aadhaar / rc).
String _docStatusOf(Map<String, Map<String, dynamic>> docs, String key) {
  final d = docs[key];
  if (d == null) return 'Not uploaded';
  final st = _s(d, 'status');
  return st.isEmpty ? 'Pending' : st;
}

Color _docStatusColor(String s) {
  if (s == 'Verified') return AppColors.success;
  if (s == 'Pending') return _amber;
  return AppColors.danger;
}

/// Fade and slide a section in, slightly later for each index.
Widget _reveal(int index, Widget child) {
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: Duration(milliseconds: 350 + index * 90),
    curve: Curves.easeOutCubic,
    builder: (context, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - t)),
        child: c,
      ),
    ),
    child: child,
  );
}

void _toast(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(icon ?? Icons.check_circle_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
}

Future<void> _copy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _toast(context, message);
}

/// Standard page: AppBar + ListView of revealed sections + optional bottom bar.
Widget _scaffold({
  required String title,
  required List<Widget> sections,
  Widget? bottom,
}) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          _reveal(i, sections[i]),
          if (i < sections.length - 1) const SizedBox(height: 12),
        ],
      ],
    ),
    bottomNavigationBar: bottom,
  );
}

Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(radius: 18),
    child: child,
  );
}

/// Teal gradient header card (same as Delivery Details header).
Widget _header({
  required String caption,
  required String title,
  String? subtitle,
  required IconData icon,
  Widget? footer,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_teal, _tealLight],
      ),
      boxShadow: [
        BoxShadow(
          color: _teal.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 11,
                  ),
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer,
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ],
    ),
  );
}

Widget _sectionTitle(IconData icon, String title,
    {Color color = AppColors.primary}) {
  return Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.text,
        ),
      ),
    ],
  );
}

Widget _iconBox(IconData icon, Color color, {double size = 20}) {
  return Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: size),
  );
}

Widget _chip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

Widget _infoRow(String label, String value,
    {bool bold = false, Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: bold ? 12 : 11.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _quickAction({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: color.withValues(alpha: 0.09),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _outlineButton(String label, IconData icon, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(40),
        foregroundColor: _teal,
        side: const BorderSide(color: _teal, width: 1.2),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    ),
  );
}

/// White bottom bar with the main teal action button.
Widget _bottomBar(String label, IconData icon, VoidCallback? onPressed) {
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    ),
  );
}

/// Expandable row without the default divider lines.
Widget _expandTile(
    BuildContext context, {
      Widget? leading,
      required String title,
      String? subtitle,
      required List<Widget> children,
    }) {
  return Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 6),
      shape: const Border(),
      collapsedShape: const Border(),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.text,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
      ),
      children: children,
    ),
  );
}

// ------------------------------------------------------------- Edit sheet

void _openEditSheet(
    BuildContext context, {
      required String title,
      required List<String> labels,
      required List<String> values,
      required ValueChanged<List<String>> onSave,
      String button = 'Save',
    }) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EditSheet(
      title: title,
      labels: labels,
      values: values,
      button: button,
      onSave: onSave,
    ),
  );
}

class _EditSheet extends StatefulWidget {
  final String title;
  final List<String> labels;
  final List<String> values;
  final String button;
  final ValueChanged<List<String>> onSave;

  const _EditSheet({
    required this.title,
    required this.labels,
    required this.values,
    required this.button,
    required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final List<TextEditingController> _controllers = [
    for (final v in widget.values) TextEditingController(text: v),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.2),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < _controllers.length; i++) ...[
              TextField(
                controller: _controllers[i],
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  labelText: widget.labels[i],
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  enabledBorder: _border(AppColors.border),
                  focusedBorder: _border(_teal),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () {
                final result = [for (final c in _controllers) c.text.trim()];
                Navigator.pop(context);
                widget.onSave(result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(widget.button),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================== Menu

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle; // null = live vehicle number
  final WidgetBuilder builder;
  const _MenuItem(this.icon, this.title, this.subtitle, this.builder);
}

class PartnerMenuScreen extends StatelessWidget {
  const PartnerMenuScreen({super.key});

  static final List<_MenuItem> _items = [
    _MenuItem(Icons.badge_rounded, 'My Documents', 'Licence, Aadhaar, RC',
            (_) => const MyDocumentsScreen()),
    _MenuItem(Icons.two_wheeler_rounded, 'Vehicle Details', null,
            (_) => const VehicleDetailsScreen()),
    _MenuItem(Icons.account_balance_rounded, 'Bank Account',
        'Payout & settlements', (_) => const BankAccountScreen()),
    _MenuItem(Icons.history_rounded, 'Delivery History', 'Past orders & trips',
            (_) => const DeliveryHistoryScreen()),
    _MenuItem(Icons.card_giftcard_rounded, 'Incentives & Rewards',
        'Daily & weekly bonuses', (_) => const IncentivesScreen()),
    _MenuItem(Icons.school_rounded, 'Training & Safety',
        'Tips to deliver better', (_) => const TrainingSafetyScreen()),
    _MenuItem(Icons.headset_mic_rounded, 'Help & Support',
        '24x7 partner support', (_) => const HelpSupportScreen()),
    _MenuItem(Icons.description_rounded, 'Terms & Privacy', null,
            (_) => const TermsPrivacyScreen()),
  ];

  Widget _row(BuildContext context, _MenuItem item) {
    Widget subtitle(String text) => Text(
      text,
      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    );

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: item.builder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: _teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.text,
                    ),
                  ),
                  if (item.title == 'Vehicle Details')
                    ValueListenableBuilder<Map<String, dynamic>>(
                      valueListenable: PartnerService.instance.data,
                      builder: (context, d, child) {
                        final n = _s(d, 'vehicleNo');
                        final old = _s(d, 'vehicle');
                        return subtitle(n.isNotEmpty ? n : (old.isNotEmpty ? old : 'Add vehicle details'));
                      },
                    )
                  else if (item.subtitle != null)
                    subtitle(item.subtitle!),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = PartnerService.instance.current;
    return _scaffold(
      title: 'Account',
      sections: [
        _header(
          caption: 'Welcome back',
          title: (me == null || me.name.isEmpty) ? 'Delivery Partner' : me.name,
          subtitle: (me == null || me.phone.isEmpty) ? null : me.phone,
          icon: Icons.person_rounded,
        ),
        Container(
          decoration: cardDeco(radius: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    _row(context, _items[i]),
                    if (i < _items.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 66),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================== Documents

class _Doc {
  final String key; // licence / aadhaar / rc  (saved as partners/{email}/docs/{key})
  final String name;
  final String hint;
  final IconData icon;
  const _Doc(this.key, this.name, this.hint, this.icon);
}

class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  static const List<_Doc> _docs = [
    _Doc('licence', 'Driving Licence', 'Valid driving licence', Icons.badge_rounded),
    _Doc('aadhaar', 'Aadhaar Card', 'Identity proof', Icons.fingerprint_rounded),
    _Doc('rc', 'RC Book', 'Vehicle registration certificate', Icons.directions_car_rounded),
  ];

  String _busy = ''; // key of the document being uploaded

  /// Camera / gallery -> small JPEG -> saved for the admin to verify.
  Future<void> _pick(_Doc d) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: _teal),
              title: const Text('Take a photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _teal),
              title: const Text('Choose from gallery', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _busy = d.key);
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 60);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final uri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (uri.length > 650000) {
        if (mounted) _toast(context, 'Photo is too large. Please take a smaller photo.', icon: Icons.error_outline_rounded);
        return;
      }
      final err = await PartnerService.instance.uploadDocument(d.key, uri);
      if (mounted) {
        _toast(context, err ?? '${d.name} sent for verification',
            icon: err == null ? Icons.upload_file_rounded : Icons.error_outline_rounded);
      }
    } catch (_) {
      if (mounted) _toast(context, 'Could not read the photo. Please try again.', icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  Widget _docCard(_Doc d, Map<String, Map<String, dynamic>> saved) {
    final status = _docStatusOf(saved, d.key);
    final color = _docStatusColor(status);
    final reason = status == 'Rejected' ? _s(saved[d.key] ?? const <String, dynamic>{}, 'reason') : '';
    final busy = _busy == d.key;
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(d.icon, _teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      reason.isEmpty ? d.hint : 'Rejected: $reason',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _chip(status, color),
            ],
          ),
          const SizedBox(height: 12),
          _outlineButton(
            busy ? 'Uploading…' : (status == 'Not uploaded' ? 'Upload' : 'Replace document'),
            Icons.upload_file_rounded,
            busy ? () {} : () => _pick(d),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Map<String, dynamic>>>(
      valueListenable: PartnerService.instance.docs,
      builder: (context, saved, child) {
        final verified = _docs.where((d) => _docStatusOf(saved, d.key) == 'Verified').length;

        return _scaffold(
          title: 'My Documents',
          sections: [
            _header(
              caption: 'Verification',
              title: '$verified of ${_docs.length} verified',
              subtitle: 'Keep documents valid to keep receiving orders',
              icon: Icons.verified_user_rounded,
            ),
            for (final d in _docs) _docCard(d, saved),
            _card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.muted, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Documents are verified by the admin. '
                          'Make sure photos are clear and all corners are visible.',
                      style: TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================== Vehicle

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  void _edit(Map<String, dynamic> d) {
    _openEditSheet(
      context,
      title: 'Edit vehicle details',
      labels: const ['Vehicle number', 'Vehicle model', 'Vehicle type (e.g. Bike)', 'Fuel type (e.g. Petrol)'],
      values: [_s(d, 'vehicleNo'), _s(d, 'vehicleModel'), _s(d, 'vehicleType'), _s(d, 'fuelType')],
      onSave: (v) async {
        final err = await PartnerService.instance.saveFields({
          'vehicleNo': v[0].toUpperCase(),
          'vehicleModel': v[1],
          'vehicleType': v[2],
          'fuelType': v[3],
        });
        if (!mounted) return;
        _toast(context, err ?? 'Vehicle details updated', icon: err == null ? null : Icons.error_outline_rounded);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: PartnerService.instance.data,
      builder: (context, d, child) {
        final number = _s(d, 'vehicleNo');
        final model = _s(d, 'vehicleModel');
        return _scaffold(
          title: 'Vehicle Details',
          bottom: _bottomBar('Edit vehicle details', Icons.edit_rounded, () => _edit(d)),
          sections: [
            _header(
              caption: 'Registered vehicle',
              title: number.isEmpty ? 'Add vehicle number' : number,
              subtitle: model.isEmpty ? 'Tap edit to add your vehicle details' : model,
              icon: Icons.two_wheeler_rounded,
            ),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.two_wheeler_rounded, 'Vehicle info'),
                  const SizedBox(height: 10),
                  _infoRow('Vehicle type', _orDash(_s(d, 'vehicleType'))),
                  _infoRow('Vehicle number', _orDash(number)),
                  _infoRow('Model', _orDash(model)),
                  _infoRow('Fuel type', _orDash(_s(d, 'fuelType'))),
                ],
              ),
            ),
            ValueListenableBuilder<Map<String, Map<String, dynamic>>>(
              valueListenable: PartnerService.instance.docs,
              builder: (context, saved, child) {
                final licence = _docStatusOf(saved, 'licence');
                final aadhaar = _docStatusOf(saved, 'aadhaar');
                final rc = _docStatusOf(saved, 'rc');
                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.shield_rounded, 'Compliance',
                          color: AppColors.success),
                      const SizedBox(height: 10),
                      _infoRow('Driving licence', licence, valueColor: _docStatusColor(licence)),
                      _infoRow('Aadhaar card', aadhaar, valueColor: _docStatusColor(aadhaar)),
                      _infoRow('RC verification', rc, valueColor: _docStatusColor(rc)),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ================================================================== Bank

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  String _masked(String account) {
    if (account.length <= 4) return account;
    return '•••• ${account.substring(account.length - 4)}';
  }

  void _edit(Map<String, dynamic> d) {
    _openEditSheet(
      context,
      title: 'Update bank details',
      labels: const [
        'Account holder name',
        'Bank name',
        'Account number',
        'IFSC code',
      ],
      values: [_s(d, 'bankHolder'), _s(d, 'bankName'), _s(d, 'bankAccount'), _s(d, 'bankIfsc')],
      onSave: (v) async {
        final account = v[2].replaceAll(' ', '');
        final ifsc = v[3].replaceAll(' ', '').toUpperCase();
        if (account.isNotEmpty && !RegExp(r'^[0-9]{9,18}$').hasMatch(account)) {
          _toast(context, 'Enter a valid account number (9–18 digits)', icon: Icons.error_outline_rounded);
          return;
        }
        if (ifsc.isNotEmpty && !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
          _toast(context, 'Enter a valid IFSC code (e.g. SBIN0001234)', icon: Icons.error_outline_rounded);
          return;
        }
        final err = await PartnerService.instance.saveFields({
          'bankHolder': v[0],
          'bankName': v[1],
          'bankAccount': account,
          'bankIfsc': ifsc,
        });
        if (!mounted) return;
        _toast(context, err ?? 'Bank details updated', icon: err == null ? null : Icons.error_outline_rounded);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: PartnerService.instance.data,
      builder: (context, d, child) {
        final account = _s(d, 'bankAccount');
        return ValueListenableBuilder<List<DeliveryOrder>>(
          valueListenable: orders,
          builder: (context, all, child) {
            final done = all.where((o) => o.status == 'Delivered').toList();
            final earned = done.fold<int>(0, (sum, o) => sum + o.earning);
            return _scaffold(
              title: 'Bank Account',
              bottom: _bottomBar(
                  'Update bank details', Icons.account_balance_rounded, () => _edit(d)),
              sections: [
                _header(
                  caption: 'Total earnings',
                  title: rupee(earned),
                  subtitle: account.isEmpty ? 'Add your bank details to receive payouts' : 'Payouts go to ${_masked(account)}',
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.account_balance_rounded, 'Bank details'),
                      const SizedBox(height: 10),
                      _infoRow('Account holder', _orDash(_s(d, 'bankHolder'))),
                      _infoRow('Bank', _orDash(_s(d, 'bankName'))),
                      _infoRow('Account number', account.isEmpty ? '—' : _masked(account)),
                      _infoRow('IFSC', _orDash(_s(d, 'bankIfsc'))),
                    ],
                  ),
                ),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.receipt_long_rounded, 'Earnings summary'),
                      const SizedBox(height: 10),
                      _infoRow('Orders delivered', '${done.length}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      _infoRow('Total earnings', rupee(earned),
                          bold: true, valueColor: _teal),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ================================================================ History

class DeliveryHistoryScreen extends StatelessWidget {
  const DeliveryHistoryScreen({super.key});

  Widget _tripCard(BuildContext context, DeliveryOrder o) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeliveryDetailsScreen(order: o)),
        ),
        child: _card(
          child: Row(
            children: [
              _iconBox(Icons.check_circle_rounded, AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${o.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      o.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${o.dateLabel} • ${o.slot}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupee(o.amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _chip(o.isCod ? 'COD' : 'Paid',
                      o.isCod ? _amber : AppColors.success),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DeliveryOrder>>(
      valueListenable: orders,
      builder: (context, orderList, child) {
        final done = orderList.where((o) => o.status == 'Delivered').toList();
        final cod = done.where((o) => o.isCod).length;

        return _scaffold(
          title: 'Delivery History',
          sections: [
            _header(
              caption: 'Completed trips',
              title: '${done.length} deliveries',
              subtitle: '$cod cash on delivery • ${done.length - cod} paid online',
              icon: Icons.history_rounded,
            ),
            if (done.isEmpty)
              _card(
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded,
                            color: AppColors.muted, size: 30),
                        SizedBox(height: 8),
                        Text(
                          'No completed deliveries yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Delivered orders will show up here',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              for (final o in done) _tripCard(context, o),
          ],
        );
      },
    );
  }
}

// ============================================================= Incentives

class IncentivesScreen extends StatelessWidget {
  const IncentivesScreen({super.key});

  Widget _dailyTile(int done, int target, String title, String reward) {
    final reached = done >= target;
    final color = reached ? AppColors.success : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              reached ? Icons.check_rounded : Icons.lock_outline_rounded,
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.text,
              ),
            ),
          ),
          if (reward.isNotEmpty) _chip(reward, reached ? AppColors.success : _amber),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Daily target, daily and weekly rewards = what the admin saved in Settings (appConfig/partnerIncentives).
    return StreamBuilder<Map<String, dynamic>>(
      stream: _cfg('partnerIncentives'),
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data ?? const <String, dynamic>{};
        final loading = !cfgSnap.hasData && cfgSnap.connectionState == ConnectionState.waiting;
        final t = cfg['dailyTarget'];
        final daily = _maps(cfg['daily'])
            .map((m) => (
        target: m['target'] is num ? (m['target'] as num).toInt() : 0,
        title: '${m['title'] ?? ''}'.trim(),
        reward: '${m['reward'] ?? ''}'.trim(),
        ))
            .where((r) => r.title.isNotEmpty)
            .toList()
          ..sort((a, b) => a.target.compareTo(b.target));
        final weekly = _maps(cfg['weekly'])
            .map((m) => (title: '${m['title'] ?? ''}'.trim(), reward: '${m['reward'] ?? ''}'.trim()))
            .where((r) => r.title.isNotEmpty)
            .toList();

        // Goal = the admin's daily target; if none is set, the biggest daily reward slab.
        var goal = t is num ? t.toInt() : 0;
        if (goal <= 0 && daily.isNotEmpty) goal = daily.last.target;

        return ValueListenableBuilder<List<DeliveryOrder>>(
          valueListenable: orders,
          builder: (context, orderList, child) {
            final now = DateTime.now();
            // Today's progress = orders this partner actually delivered today.
            final done = orderList
                .where((o) => o.status == 'Delivered' && o.deliveredAt != null && _isSameDay(o.deliveredAt!, now))
                .length;
            final progress = goal > 0 ? (done / goal).clamp(0.0, 1.0) : 0.0;
            final left = goal > 0 ? (goal - done).clamp(0, goal) : 0;

            return _scaffold(
              title: 'Incentives & Rewards',
              sections: [
                _header(
                  caption: "Today's bonus progress",
                  title: goal > 0 ? '$done / $goal deliveries' : '$done deliveries today',
                  subtitle: goal <= 0
                      ? 'No daily target has been set yet'
                      : left == 0
                      ? 'Target reached. Great work!'
                      : '$left more to unlock the top daily bonus',
                  icon: Icons.card_giftcard_rounded,
                  footer: goal > 0
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : null,
                ),
                if (loading) _loadingCard(),
                if (!loading && daily.isEmpty && weekly.isEmpty)
                  _notSetCard('No bonuses have been published yet. They will appear here as soon as the admin adds them.'),
                if (daily.isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.today_rounded, 'Daily bonuses'),
                        const SizedBox(height: 8),
                        for (final r in daily) _dailyTile(done, r.target, r.title, r.reward),
                      ],
                    ),
                  ),
                if (weekly.isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(Icons.date_range_rounded, 'Weekly bonuses'),
                        const SizedBox(height: 8),
                        for (final w in weekly)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                const Icon(Icons.stars_rounded, size: 16, color: _teal),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    w.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                                if (w.reward.isNotEmpty) _chip(w.reward, _amber),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================== Training

class _Tip {
  final IconData icon;
  final String title;
  final String body;
  const _Tip(this.icon, this.title, this.body);
}

class TrainingSafetyScreen extends StatefulWidget {
  const TrainingSafetyScreen({super.key});

  @override
  State<TrainingSafetyScreen> createState() => _TrainingSafetyScreenState();
}

class _TrainingSafetyScreenState extends State<TrainingSafetyScreen> {
  // Icons only; the tip titles and texts are written by the admin (appConfig/partnerTerms.training).
  static const List<IconData> _icons = [
    Icons.sports_motorsports_rounded,
    Icons.inventory_2_rounded,
    Icons.verified_rounded,
    Icons.payments_rounded,
    Icons.nightlight_round,
    Icons.sentiment_satisfied_alt_rounded,
  ];

  // Tips the partner marked as done (saved on this phone, per partner, by tip title).
  final Set<String> _done = {};

  String get _prefKey => 'training_done_${PartnerService.instance.current?.id ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  Future<void> _loadDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefKey) ?? const <String>[];
      if (!mounted) return;
      setState(() => _done.addAll(saved));
    } catch (_) {
      // progress simply starts empty
    }
  }

  Future<void> _toggle(String title) async {
    setState(() {
      if (!_done.add(title)) _done.remove(title);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefKey, _done.toList());
    } catch (_) {
      // keep the in-memory state
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _cfg('partnerTerms'),
      builder: (context, snap) {
        final loading = !snap.hasData && snap.connectionState == ConnectionState.waiting;
        final raw = _maps(snap.data?['training']);
        final tips = <_Tip>[
          for (int i = 0; i < raw.length; i++)
            if ('${raw[i]['title'] ?? ''}'.trim().isNotEmpty)
              _Tip(_icons[i % _icons.length], '${raw[i]['title']}'.trim(), '${raw[i]['body'] ?? ''}'.trim()),
        ];
        final doneCount = tips.where((t) => _done.contains(t.title)).length;

        return _scaffold(
          title: 'Training & Safety',
          sections: [
            _header(
              caption: 'Your progress',
              title: '$doneCount of ${tips.length} completed',
              subtitle: tips.isEmpty ? 'No training tips published yet' : 'Read each tip and mark it as done',
              icon: Icons.school_rounded,
              footer: tips.isEmpty
                  ? null
                  : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: doneCount / tips.length,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            if (loading) _loadingCard(),
            if (!loading && tips.isEmpty)
              _notSetCard('The admin has not added any training or safety tips yet.'),
            for (final tip in tips)
              _card(
                child: _expandTile(
                  context,
                  leading: _iconBox(
                    _done.contains(tip.title) ? Icons.check_rounded : tip.icon,
                    _done.contains(tip.title) ? AppColors.success : _teal,
                  ),
                  title: tip.title,
                  subtitle: _done.contains(tip.title) ? 'Completed' : 'Tap to read',
                  children: [
                    Text(
                      tip.body,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _outlineButton(
                      _done.contains(tip.title) ? 'Mark as not done' : 'Mark as done',
                      _done.contains(tip.title) ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                          () => _toggle(tip.title),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ================================================================== Help

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // Support contact = what the admin saved in Settings (appConfig/store). Nothing is made up here.
  String _phone = '';
  String _email = '';
  String _hours = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  /// Uses the support phone / email the admin saved in Settings.
  Future<void> _loadContacts() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('appConfig/store').get();
      final m = doc.data() ?? <String, dynamic>{};
      final ph = _s(m, 'supportPhone');
      final em = _s(m, 'supportEmail');
      final hr = _s(m, 'supportHours');
      if (!mounted) return;
      setState(() {
        _phone = ph;
        _email = em;
        _hours = hr;
      });
    } catch (_) {
      // contacts stay empty until the admin saves them
    }
  }

  void _notSet(String what) =>
      _toast(context, 'The admin has not added the support $what yet', icon: Icons.info_outline_rounded);

  Future<void> _call() async {
    if (_phone.isEmpty) {
      _notSet('number');
      return;
    }
    final number = _phone.replaceAll(RegExp(r'[^0-9+]'), '');
    var ok = false;
    try {
      ok = number.isNotEmpty && await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      _toast(context, 'Could not open the dialer. Number: $_phone', icon: Icons.error_outline_rounded);
    }
  }

  /// Saves the issue as a support ticket (tickets/{id}) so it shows up in the Admin's Support screen.
  /// Returns null when it worked, otherwise a message to show.
  Future<String?> _sendTicket(String orderId, String text) async {
    final p = PartnerService.instance.current;
    if (p == null) return 'Please log in again';
    try {
      final now = Timestamp.now();
      final message = text.length > 500 ? text.substring(0, 500) : text;
      await FirebaseFirestore.instance.collection('tickets').add({
        'partnerId': p.id,
        'partnerName': p.name,
        'partnerPhone': p.phone,
        'customerId': '',
        'source': 'partner',
        'category': 'Delivery partner',
        'orderId': orderId,
        'subject': orderId.isEmpty ? 'Delivery partner: ${p.name}' : 'Delivery partner: order $orderId',
        'status': 'Open',
        'created': now,
        'messages': [
          {'fromAdmin': false, 'text': message, 'time': now},
        ],
      });
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'Not allowed. Please contact the admin.'
          : 'Could not send. Please check your internet and try again.';
    } catch (_) {
      return 'Could not send. Please check your internet and try again.';
    }
  }

  void _report() {
    _openEditSheet(
      context,
      title: 'Report an issue',
      labels: const ['Order ID (optional)', 'Describe your issue'],
      values: const ['', ''],
      button: 'Submit',
      onSave: (v) async {
        if (v[1].isEmpty) {
          if (mounted) _toast(context, 'Please describe your issue', icon: Icons.error_outline_rounded);
          return;
        }
        final err = await _sendTicket(v[0], v[1]);
        if (!mounted) return;
        _toast(
          context,
          err ?? 'Issue submitted. Support will contact you.',
          icon: err == null ? Icons.support_agent_rounded : Icons.error_outline_rounded,
        );
      },
    );
  }

  Color _ticketColor(String status) {
    switch (status) {
      case 'Resolved':
        return AppColors.success;
      case 'In Progress':
        return _amber;
      default:
        return AppColors.info;
    }
  }

  /// The partner's own tickets with the status and the latest reply from support.
  Widget _myTickets() {
    final me = PartnerService.instance.current;
    if (me == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('tickets').where('partnerId', isEqualTo: me.id).snapshots(),
      builder: (context, snap) {
        DateTime when(Map<String, dynamic> m) {
          final c = m['created'];
          return c is Timestamp ? c.toDate() : DateTime(2000);
        }

        final docs = [...?snap.data?.docs]..sort((a, b) => when(b.data()).compareTo(when(a.data())));
        if (docs.isEmpty) return const SizedBox.shrink();
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(Icons.confirmation_number_outlined, 'My requests'),
              const SizedBox(height: 8),
              for (int i = 0; i < docs.length && i < 5; i++) ...[
                Builder(builder: (_) {
                  final m = docs[i].data();
                  final status = _s(m, 'status').isEmpty ? 'Open' : _s(m, 'status');
                  String reply = '';
                  final msgs = m['messages'];
                  if (msgs is List) {
                    for (final e in msgs) {
                      if (e is Map && e['fromAdmin'] == true) reply = (e['text'] ?? '').toString().trim();
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _s(m, 'subject').isEmpty ? 'Support request' : _s(m, 'subject'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.text),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _chip(status, _ticketColor(status)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reply.isEmpty ? 'Waiting for a reply from support' : 'Support: $reply',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.4),
                      ),
                    ],
                  );
                }),
                if (i < docs.length - 1 && i < 4) const Divider(height: 16, color: AppColors.border),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      title: 'Help & Support',
      bottom: _bottomBar('Report an issue', Icons.report_problem_rounded, _report),
      sections: [
        _header(
          caption: 'Partner support',
          title: _phone.isEmpty ? 'Contact support' : _phone,
          subtitle: _hours.isNotEmpty
              ? _hours
              : (_email.isNotEmpty ? _email : 'Use Report an issue below'),
          icon: Icons.headset_mic_rounded,
        ),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.call_rounded,
                label: 'Call',
                color: AppColors.success,
                onTap: _call,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickAction(
                icon: Icons.copy_rounded,
                label: 'Copy number',
                color: AppColors.primary,
                onTap: () => _phone.isEmpty ? _notSet('number') : _copy(context, _phone, 'Number copied'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickAction(
                icon: Icons.email_rounded,
                label: 'Copy email',
                color: _teal,
                onTap: () => _email.isEmpty ? _notSet('email') : _copy(context, _email, 'Email copied'),
              ),
            ),
          ],
        ),
        _myTickets(),
        // Common questions = written by the admin (appConfig/partnerTerms.faqs). Hidden until there are some.
        StreamBuilder<Map<String, dynamic>>(
          stream: _cfg('partnerTerms'),
          builder: (context, snap) {
            final faqs = _maps(snap.data?['faqs'])
                .map((m) => (q: '${m['q'] ?? ''}'.trim(), a: '${m['a'] ?? ''}'.trim()))
                .where((f) => f.q.isNotEmpty)
                .toList();
            if (faqs.isEmpty) return const SizedBox.shrink();
            return _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.help_outline_rounded, 'Common questions'),
                  const SizedBox(height: 4),
                  for (int i = 0; i < faqs.length; i++) ...[
                    _expandTile(
                      context,
                      title: faqs[i].q,
                      children: [
                        Text(
                          faqs[i].a,
                          style: const TextStyle(
                            color: AppColors.muted,
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (i < faqs.length - 1) const Divider(height: 1, color: AppColors.border),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ================================================================= Terms

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  Widget _clauses(IconData icon, String title, List<String> items) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(icon, title),
          const SizedBox(height: 10),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Terms and privacy text = what the admin saved in Settings (appConfig/partnerTerms).
    return StreamBuilder<Map<String, dynamic>>(
      stream: _cfg('partnerTerms'),
      builder: (context, snap) {
        final loading = !snap.hasData && snap.connectionState == ConnectionState.waiting;
        final terms = _strs(snap.data?['terms']);
        final privacy = _strs(snap.data?['privacy']);
        return _scaffold(
          title: 'Terms & Privacy',
          sections: [
            _header(
              caption: 'Legal',
              title: 'Terms & Privacy',
              subtitle: 'Please read how we work together',
              icon: Icons.description_rounded,
            ),
            if (loading) _loadingCard(),
            if (!loading && terms.isEmpty && privacy.isEmpty)
              _notSetCard('The terms and privacy policy have not been published yet.'),
            if (terms.isNotEmpty) _clauses(Icons.gavel_rounded, 'Terms of service', terms),
            if (privacy.isNotEmpty) _clauses(Icons.lock_rounded, 'Privacy policy', privacy),
          ],
        );
      },
    );
  }
}