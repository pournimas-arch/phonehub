import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/common.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';
import 'package:phonehub/delivery%20partner/partner_service.dart';
import 'package:phonehub/delivery%20partner/delivery_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'confirm_delivery_screen.dart';
import 'navigation_screen.dart';

/// Order Details: product, progress, quick actions, customer + address, map preview,
/// items, bill and the main action
/// (Picked Up -> Delivered with the customer's OTP).
/// Everything is live: the order comes from Firestore (orders_data.dart) and the
/// status changes are written back so the customer and the admin see them at once.
class DeliveryDetailsScreen extends StatefulWidget {
  final DeliveryOrder order;
  const DeliveryDetailsScreen({super.key, required this.order});

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  static const List<String> _steps = ['Assigned', 'Picked Up', 'Delivered'];
  static const Color _cod = Color(0xFFB45309);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _whatsapp = Color(0xFF25D366);

  /// Support number the admin saved in Settings (appConfig/store.supportPhone). Empty until it loads / is set.
  String _supportPhone = '';

  /// Problems that count as a failed delivery attempt (saved on the order and told to the customer).
  static const Set<String> _attemptIssues = {
    'Customer not reachable',
    'Wrong / incomplete address',
    'Customer asked to reschedule',
  };

  /// Reasons for giving an order back before pickup.
  static const List<String> _giveBackReasons = [
    'Vehicle problem',
    'Too far to deliver in time',
    'Not feeling well',
    'Other reason',
  ];

  /// The live copy of this order (the orders listener replaces the objects on every change).
  DeliveryOrder get order {
    for (final o in orders.value) {
      if (o.id == widget.order.id) return o;
    }
    return widget.order;
  }

  bool _busy = false;
  bool _reportingIssue = false;
  bool _givingBack = false;

  @override
  void initState() {
    super.initState();
    _loadSupportPhone();
  }

  Future<void> _loadSupportPhone() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('appConfig/store').get();
      final phone = (doc.data()?['supportPhone'] ?? '').toString().trim();
      if (mounted) setState(() => _supportPhone = phone);
    } catch (_) {}
  }

  Future<void> _callSupport() async {
    if (_supportPhone.isEmpty) {
      _toast('Support number is not set yet. Please use Report problem.', icon: Icons.headset_mic_rounded);
      return;
    }
    await _dial(_supportPhone);
  }
  late final Future<double?> _distance = _loadDistance();

  /// Distance from the partner's last known position to the customer (null when unknown).
  Future<double?> _loadDistance() async {
    if (order.lat == null || order.lng == null) return null;
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      return Geolocator.distanceBetween(p.latitude, p.longitude, order.lat!, order.lng!) / 1000;
    } catch (_) {
      return null;
    }
  }

  String get _shortId {
    final id = '${order.id}';
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  // ---------------------------------------------------------------- Actions

  void _openMap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationScreen(order: order)));
  }

  Future<bool> _launch(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  String get _cleanPhone => order.phone.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _dial(String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) {
      _toast('Customer number is not available', icon: Icons.call_rounded);
      return;
    }
    final opened = await _launch(Uri(scheme: 'tel', path: number));
    if (!opened && mounted) _toast('Could not open the dialer', icon: Icons.call_rounded);
  }

  Future<void> _sms() async {
    if (_cleanPhone.isEmpty) return _toast('Customer number is not available', icon: Icons.sms_rounded);
    final msg = 'Hi ${order.customer}, I am your PhoneHub delivery partner. I am on my way with your order #$_shortId.';
    final ok = await _launch(Uri(scheme: 'sms', path: _cleanPhone, queryParameters: {'body': msg}));
    if (!ok && mounted) _toast('Could not open messages', icon: Icons.sms_rounded);
  }

  Future<void> _whatsApp() async {
    var n = _cleanPhone.replaceAll('+', '');
    if (n.isEmpty) return _toast('Customer number is not available', icon: Icons.chat_rounded);
    if (n.length == 10) n = '91$n';
    final msg = 'Hi ${order.customer}, I am your PhoneHub delivery partner. I am on my way with your order #$_shortId.';
    final ok = await _launch(Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('WhatsApp is not available', icon: Icons.chat_rounded);
  }

  Future<void> _openGoogleMaps() async {
    final Uri uri;
    if (order.lat != null && order.lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${order.lat},${order.lng}&travelmode=driving');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order.address)}');
    }
    final ok = await _launch(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Could not open Google Maps', icon: Icons.map_rounded);
  }

  void _toast(String message, {IconData? icon, Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(icon ?? Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      );
  }

  Future<void> _copy(String text, String message) async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast(message);
  }

  Future<void> _mainAction(String s) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    if (s == 'Assigned') {
      setState(() => _busy = true);
      final ok = await updateStatus(order, 'Picked Up');
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) {
        _toast('Marked as picked up', icon: Icons.inventory_rounded);
        _openMap();
      } else {
        _toast('Could not update. Please check your internet.', icon: Icons.error_outline_rounded, color: _danger);
      }
    } else if (s == 'Picked Up') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmDeliveryScreen(order: order)));
    }
  }

  void _showCallSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            CircleAvatar(radius: 28, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: const Icon(Icons.call_rounded, color: AppColors.primary, size: 24)),
            const SizedBox(height: 12),
            Text(order.customer, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(order.phone, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      _copy(order.phone, 'Number copied');
                    },
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy number'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      _dial(order.phone);
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44), backgroundColor: AppColors.success, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportIssue(String issue) async {
    if (_reportingIssue) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    if (user == null || email.isEmpty) {
      _toast('Please sign in again before reporting a delivery issue.', icon: Icons.error_outline_rounded, color: _danger);
      return;
    }

    setState(() => _reportingIssue = true);
    try {
      // A failed delivery attempt is saved on the order itself (counter + reason) and the customer is told.
      var attemptSaved = false;
      if (_attemptIssues.contains(issue)) {
        final error = await reportFailedAttempt(order, issue);
        if (error != null) {
          if (mounted) _toast(error, icon: Icons.error_outline_rounded, color: _danger);
          return;
        }
        attemptSaved = true;
      }
      final now = FieldValue.serverTimestamp();
      final messageTime = Timestamp.now();
      final partnerName = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : email.split('@').first;

      // This document shape matches the existing Admin Ticket model and the
      // Firestore Rules for partner-created tickets (partnerId=email,
      // customerId='', status='Open'). No customer data is exposed here.
      await FirebaseFirestore.instance.collection('tickets').add({
        'partnerId': email,
        'partnerName': partnerName,
        'customerId': '',
        'orderId': order.id,
        'subject': 'Delivery issue: $issue',
        'status': 'Open',
        'messages': [
          {
            'fromAdmin': false,
            'text': 'Order #${order.id}: $issue',
            'time': messageTime,
          },
        ],
        'createdAt': now,
        'updatedAt': now,
        'createdByUid': user.uid,
        'type': 'delivery',
      });

      if (mounted) {
        _toast(attemptSaved ? 'Attempt recorded and issue sent to PhoneHub support.' : 'Issue sent to PhoneHub support.', icon: Icons.flag_rounded);
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'Could not report this issue. Check partner access in Firestore Rules.'
          : 'Could not send the issue. Please try again.';
      _toast(message, icon: Icons.error_outline_rounded, color: _danger);
    } catch (_) {
      if (mounted) {
        _toast('Could not send the issue. Please try again.', icon: Icons.error_outline_rounded, color: _danger);
      }
    } finally {
      if (mounted) setState(() => _reportingIssue = false);
    }
  }

  void _showIssueSheet() {
    if (_reportingIssue) return;
    const issues = [
      (Icons.phone_missed_rounded, 'Customer not reachable'),
      (Icons.wrong_location_rounded, 'Wrong / incomplete address'),
      (Icons.do_not_disturb_on_rounded, 'Customer refused the order'),
      (Icons.schedule_rounded, 'Customer asked to reschedule'),
      (Icons.report_problem_rounded, 'Other problem'),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Report a problem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Tell us what went wrong with this delivery.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
            for (final i in issues)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(radius: 18, backgroundColor: _danger.withValues(alpha: 0.10), child: Icon(i.$1, size: 18, color: _danger)),
                title: Text(i.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                onTap: () {
                  Navigator.pop(sheet);
                  _reportIssue(i.$2);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Give the order back BEFORE pickup. The admin is told and assigns another partner.
  void _showGiveBackSheet() {
    if (_givingBack || order.status != 'Assigned') return;
    var selected = 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              const Text('Give back this order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('The admin will assign it to another partner.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 8),
              for (int i = 0; i < _giveBackReasons.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setSheet(() => selected = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(selected == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: selected == i ? _danger : AppColors.muted),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_giveBackReasons[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  _giveBack(_giveBackReasons[selected]);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: _danger, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Give back order'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _giveBack(String reason) async {
    final me = PartnerService.instance.current;
    if (me == null) {
      _toast('Please log in again.', icon: Icons.error_outline_rounded, color: _danger);
      return;
    }
    setState(() => _givingBack = true);
    final error = await rejectOrder(order, me.id, me.name, reason);
    if (!mounted) return;
    setState(() => _givingBack = false);
    if (error != null) {
      _toast(error, icon: Icons.error_outline_rounded, color: _danger);
      return;
    }
    _toast('Order given back. The admin will assign it to someone else.', icon: Icons.undo_rounded);
    Navigator.pop(context);
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DeliveryOrder>>(
      valueListenable: orders,
      builder: (context, _, __) {
        final s = order.status;
        return DPage(
          title: 'Order Details',
          back: true,
          bottom: _bottomBar(s),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _productCard(),
              const SizedBox(height: 12),
              _progress(s),
              const SizedBox(height: 12),
              _paymentBanner(),
              if (order.attempts > 0) ...[
                const SizedBox(height: 12),
                _attemptsBanner(),
              ],
              const SizedBox(height: 12),
              _quickActions(),
              const SizedBox(height: 12),
              _infoCard(),
              const SizedBox(height: 12),
              _addressCard(),
              const SizedBox(height: 12),
              _mapCard(),
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                _itemsCard(),
              ],
              const SizedBox(height: 12),
              _billCard(),
              const SizedBox(height: 12),
              _helpCard(),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- Sections

  Widget _productCard() {
    final extra = order.items.length - 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DThumb(size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.items.isEmpty ? 'Phone order' : order.items.first, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text)),
                if (extra > 0) Text('+$extra more item${extra == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(height: 6),
                Text(rupee(order.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppColors.text)),
                const SizedBox(height: 8),
                DPill(dLabel(order), dColor(order)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(String status) {
    var current = _steps.indexOf(status);
    if (current < 0) current = 0;
    const labels = ['Assigned', 'Out for Delivery', 'Delivered'];
    const icons = [Icons.assignment_turned_in_rounded, Icons.two_wheeler_rounded, Icons.home_rounded];

    Widget dot(int i) {
      final done = i <= current;
      final isNow = i == current && current < 2;
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: done ? AppColors.primary : AppColors.border,
          shape: BoxShape.circle,
          boxShadow: isNow ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 0, spreadRadius: 5)] : null,
        ),
        child: Icon(done && i < current ? Icons.check_rounded : icons[i], size: 17, color: done ? Colors.white : AppColors.muted),
      );
    }

    Widget line(bool on) => Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(4)),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: cardDeco(radius: 18),
      child: Column(
        children: [
          Row(children: [dot(0), line(current >= 1), dot(1), line(current >= 2), dot(2)]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 3; i++)
                Text(labels[i], style: TextStyle(fontSize: 10.5, fontWeight: i == current ? FontWeight.w800 : FontWeight.w600, color: i <= current ? AppColors.primary : AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  /// Shown after a failed delivery attempt was reported (count + last reason, from the order).
  Widget _attemptsBanner() {
    final reason = order.lastFailedReason.isEmpty ? 'Reason not given' : order.lastFailedReason;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _danger.withValues(alpha: 0.25))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: _danger.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.report_problem_rounded, color: _danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${order.attempts} failed ${order.attempts == 1 ? 'attempt' : 'attempts'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('Last reason: $reason', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBanner() {
    final cod = order.isCod;
    final pending = order.payPending;
    final color = (cod || pending) ? AppColors.accent : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(cod ? Icons.payments_rounded : (pending ? Icons.schedule_rounded : Icons.verified_rounded), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment status', style: TextStyle(color: AppColors.muted, fontSize: 10.5)),
                const SizedBox(height: 2),
                Text(
                  cod ? 'Cash on Delivery' : (pending ? 'Online – payment pending (do not collect)' : 'Paid online – nothing to collect'),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: (cod || pending) ? _cod : AppColors.success),
                ),
              ],
            ),
          ),
          if (cod)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Collect', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                Text(rupee(order.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _cod)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: cardDeco(radius: 14),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        _actionTile(Icons.call_rounded, 'Call', AppColors.success, order.phone.isEmpty ? () => _toast('Customer number is not available', icon: Icons.call_rounded) : _showCallSheet),
        const SizedBox(width: 10),
        _actionTile(Icons.chat_rounded, 'WhatsApp', _whatsapp, _whatsApp),
        const SizedBox(width: 10),
        _actionTile(Icons.sms_rounded, 'SMS', AppColors.primary, _sms),
        const SizedBox(width: 10),
        _actionTile(Icons.directions_rounded, 'Directions', _cod, _openGoogleMaps),
      ],
    );
  }

  Widget _infoRow(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 104, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12))),
        Expanded(child: value),
      ],
    ),
  );

  Widget _infoCard() {
    const valueStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: cardDeco(radius: 18),
      child: Column(
        children: [
          _infoRow(
            'Order ID',
            InkWell(
              onTap: () => _copy('${order.id}', 'Order ID copied'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text('#$_shortId', style: valueStyle)),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 13, color: AppColors.muted),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _infoRow('Customer', Row(children: [
            CircleAvatar(radius: 11, backgroundColor: AppColors.primary.withValues(alpha: 0.12), child: Text(order.customer.isEmpty ? '?' : order.customer[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary))),
            const SizedBox(width: 8),
            Expanded(child: Text(order.customer, style: valueStyle)),
          ])),
          const Divider(height: 1, color: AppColors.border),
          _infoRow(
            'Phone',
            Row(
              children: [
                Expanded(child: Text(order.phone.isEmpty ? '—' : order.phone, style: valueStyle)),
                if (order.phone.isNotEmpty) CircleIconButton(icon: Icons.call_rounded, color: AppColors.success, onTap: _showCallSheet),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _infoRow(
            'Delivery Slot',
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Expanded(child: Text('${order.dateLabel} • ${order.slot}', style: valueStyle)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _addressCard() {
    final hasAddress = order.address.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Delivery address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          Text(hasAddress ? order.address : '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.45, color: AppColors.text)),
          if (hasAddress) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(order.address, 'Address copied'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40), foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)), textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openMap,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40), backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.navigation_rounded, size: 15),
                    label: const Text('Navigate'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapCard() {
    return GestureDetector(
      onTap: _openMap,
      child: Container(
        height: 150,
        decoration: cardDeco(radius: 18),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: MapPlaceholder()),
            Positioned(
              left: 12,
              bottom: 12,
              child: FutureBuilder<double?>(
                future: _distance,
                builder: (context, snap) {
                  final km = snap.data;
                  String text;
                  if (km == null) {
                    text = 'Tap to navigate';
                  } else {
                    final dist = km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
                    final mins = (km / 25 * 60).ceil().clamp(1, 999); // ~25 km/h city average
                    text = '$dist • ~$mins min';
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
                child: const Icon(Icons.open_in_full_rounded, size: 16, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Order items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 6, color: AppColors.primary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false, Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: bold ? 12 : 11.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: valueColor ?? AppColors.text)),
      ],
    ),
  );

  Widget _billCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Bill summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          _billRow('Order value', rupee(order.amount)),
          _billRow('Payment mode', order.isCod ? 'Cash on Delivery' : (order.payPending ? 'Online (payment pending)' : 'Paid online')),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: AppColors.border)),
          _billRow('To collect', order.isCod ? rupee(order.amount) : rupee(0), bold: true, valueColor: order.isCod ? _cod : AppColors.success),
        ],
      ),
    );
  }

  Widget _helpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Need help?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showIssueSheet,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: _danger, side: BorderSide(color: _danger.withValues(alpha: 0.4)), textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.report_problem_rounded, size: 15),
                  label: const Text('Report problem'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _callSupport,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)), textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.headset_mic_rounded, size: 15),
                  label: const Text('Call support'),
                ),
              ),
            ],
          ),
          // Only before pickup: after pickup the order must be delivered or reported.
          if (order.status == 'Assigned') ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _givingBack ? null : _showGiveBackSheet,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: _danger, side: BorderSide(color: _danger.withValues(alpha: 0.4)), textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.undo_rounded, size: 15),
              label: Text(_givingBack ? 'Giving back...' : 'Give back this order'),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Bottom bar

  Widget _bottomBar(String s) {
    final delivered = s == 'Delivered';
    final label = s == 'Assigned' ? 'Mark as Picked Up' : (s == 'Picked Up' ? 'Mark as Delivered' : 'Delivered');
    final icon = s == 'Assigned' ? Icons.inventory_rounded : Icons.check_circle_rounded;
    // Same colour as the tracker (Assigned / Out for Delivery).
    const Color btn = AppColors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (order.isCod && !delivered) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _cod.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cod.withValues(alpha: 0.25))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Collect', style: TextStyle(color: AppColors.muted, fontSize: 10)),
                    Text(rupee(order.amount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _cod)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (delivered || _busy) ? null : [BoxShadow(color: btn.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: ElevatedButton.icon(
                  onPressed: (delivered || _busy) ? null : () => _mainAction(s),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    elevation: 0,
                    backgroundColor: btn,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: delivered ? AppColors.success.withValues(alpha: 0.15) : btn.withValues(alpha: 0.6),
                    disabledForegroundColor: delivered ? AppColors.success : Colors.white,
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon, size: 19),
                  label: Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}