import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'checkout_ui.dart';
import 'package:phonehub/app_text.dart';

// ---------------------------------------------------------------------------
// Support request validation (logic only, no UI)
// ---------------------------------------------------------------------------
const int _kSubjectMin = 5;
const int _kSubjectMax = 80;
const int _kMessageMin = 15;
const int _kMessageMax = 500;
const int _kMaxOpenTickets = 5; // open / in-progress requests one customer can have
const int _kTicketGapSeconds = 30; // minimum gap between two new requests

// Kept at file level so closing and re-opening the sheet does not reset the gap.
DateTime? _lastTicketAt;

String _cleanSubject(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Trims, turns every run of spaces into one, and keeps at most one blank line.
String _cleanMessage(String v) => v
    .trim()
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n');

/// Rejects keyboard-smash, symbols only and repeated characters.
String? _checkReadable(String s, String what) {
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(s).length;
  if (letters == 0) return 'The $what must contain letters';
  if (RegExp(r'(.)\1{5,}').hasMatch(s)) return 'Please write a real $what';
  final visible = s.replaceAll(RegExp(r'\s'), '').length;
  if (visible > 0 && letters / visible < 0.4) {
    return 'The $what has too many symbols or numbers';
  }
  return null;
}

String? _validateTicketSubject(String? v) {
  final s = _cleanSubject(v ?? '');
  if (s.isEmpty) return 'Enter a subject';
  if (s.length < _kSubjectMin) return 'Subject must be at least $_kSubjectMin characters';
  if (s.length > _kSubjectMax) return 'Subject can be at most $_kSubjectMax characters';
  return _checkReadable(s, 'subject');
}

String? _validateTicketMessage(String? v) {
  final s = _cleanMessage(v ?? '');
  if (s.isEmpty) return 'Please describe your issue';
  if (s.length < _kMessageMin) return 'Please add a few more details (at least $_kMessageMin characters)';
  if (s.length > _kMessageMax) return 'Message can be at most $_kMessageMax characters';
  if (s.split(RegExp(r'\s+')).length < 3) return 'Please write at least 3 words';
  return _checkReadable(s, 'message');
}

class _Faq {
  final String q, a;
  const _Faq(this.q, this.a);
}

String _fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String _fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return AppColors.primary;
    case 'resolved':
    case 'closed':
      return AppColors.success;
    default:
      return AppColors.accent;
  }
}

Widget _statusChip(String status) {
  final c = _statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(status, style: TextStyle(color: c, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
  );
}

/// Help & Support – contact options, FAQs and the customer's support requests.
/// UI style matches the Saved Addresses screen.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _phone = '';
  String _email = '';
  String _hours = '';
  bool _loading = true;
  bool _loadFailed = false;
  List<_Faq> _faqs = [];

  final _faqSearch = TextEditingController();
  String _faqQuery = '';
  String? _copiedLabel;
  bool _showAllTickets = false;

  // Live listeners: when the admin changes Settings or FAQs the screen updates by itself.
  Map<String, dynamic>? _storeCfg; // appConfig/store (supportPhone, supportEmail, supportHours)
  Map<String, dynamic>? _supportCfg; // appConfig/support (older documents, used only as a fallback)
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _storeSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _supportSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _faqSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _storeSub?.cancel();
    _supportSub?.cancel();
    _faqSub?.cancel();
    _faqSearch.dispose();
    super.dispose();
  }

  /// Support contact = what the admin saved in Settings (appConfig/store: supportPhone /
  /// supportEmail / supportHours). The older appConfig/support document is only a fallback.
  void _applyConfig() {
    String clean(dynamic v) => (v is String) ? v.trim() : '';
    String pick(String key, String legacyKey) {
      final v = clean(_storeCfg?[key]);
      return v.isNotEmpty ? v : clean(_supportCfg?[legacyKey]);
    }

    _phone = pick('supportPhone', 'phone');
    _email = pick('supportEmail', 'email');
    _hours = pick('supportHours', 'hours');
  }

  /// FAQs written by the admin; hidden ones (isActive == false) are not shown to customers.
  List<_Faq> _parseFaqs(QuerySnapshot<Map<String, dynamic>> snap) {
    final docs = snap.docs.where((d) => d.data()['isActive'] != false).toList()
      ..sort((a, b) {
        final oa = a.data()['order'];
        final ob = b.data()['order'];
        return (oa is num ? oa : 0).compareTo(ob is num ? ob : 0);
      });
    return [
      for (final d in docs)
        if ((d.data()['q'] ?? d.data()['question'] ?? '').toString().trim().isNotEmpty)
          _Faq(
            (d.data()['q'] ?? d.data()['question']).toString(),
            (d.data()['a'] ?? d.data()['answer'] ?? '').toString(),
          ),
    ];
  }

  /// Starts the live listeners once (after the first load succeeded or failed).
  void _listen() {
    final db = FirebaseFirestore.instance;
    _storeSub ??= db.collection('appConfig').doc('store').snapshots().listen((doc) {
      if (!mounted) return;
      setState(() {
        _storeCfg = doc.data();
        _applyConfig();
      });
    }, onError: (Object _) {});
    _supportSub ??= db.collection('appConfig').doc('support').snapshots().listen((doc) {
      if (!mounted) return;
      setState(() {
        _supportCfg = doc.data();
        _applyConfig();
      });
    }, onError: (Object _) {});
    _faqSub ??= db.collection('faqs').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() => _faqs = _parseFaqs(snap));
    }, onError: (Object _) {});
  }

  /// Loads support contact details and FAQs (written by the admin).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    bool failed = false;
    final db = FirebaseFirestore.instance;
    try {
      _storeCfg = (await db.collection('appConfig').doc('store').get()).data();
    } catch (_) {
      failed = true;
    }
    try {
      _supportCfg = (await db.collection('appConfig').doc('support').get()).data();
    } catch (_) {
      // older optional document: not an error for the customer
    }
    _applyConfig();
    try {
      _faqs = _parseFaqs(await db.collection('faqs').get());
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadFailed = failed;
    });
    _listen();
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copiedLabel = label);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedLabel == label) setState(() => _copiedLabel = null);
    });
  }

  Future<void> _raiseTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to contact support')));
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const _NewTicketSheet(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent. We will reply here soon.')));
    }
  }

  void _openTicket(String ticketId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => _TicketChatSheet(ticketId: ticketId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 14),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      if (_loadFailed) ...[_errorBanner(), const SizedBox(height: 12)],
                      Row(
                        children: [
                          _contactCard(Icons.call_rounded, AppColors.success, 'Call', _phone),
                          const SizedBox(width: 12),
                          _contactCard(Icons.email_outlined, AppColors.primary, 'Email', _email),
                        ],
                      ),
                      if (_hours.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: glassDeco(radius: 18),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Support hours: $_hours',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.body, color: AppColors.text)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _sectionTitle('My support requests'),
                      const SizedBox(height: 12),
                      _ticketsSection(),
                      const SizedBox(height: 22),
                      _sectionTitle('Frequently asked questions'),
                      const SizedBox(height: 12),
                      _faqSearchBar(),
                      const SizedBox(height: 12),
                      _faqSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: checkoutBottomBarDeco(),
          child: SafeArea(
            top: false,
            child: GradientButton(
              onTap: _raiseTicket,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.headset_mic_rounded), SizedBox(width: 6), Text('Raise a support request')],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Header styled to match the PhoneHub Wishlist screen.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: glassDeco(radius: 14),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Help & Support',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'WE ARE HERE TO HELP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
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

  Widget _sectionTitle(String t) =>
      Text(t, style: const TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800, color: AppColors.text));

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Some information could not be loaded.',
                style: TextStyle(color: AppColors.danger, fontSize: AppText.small, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: _load,
            child: const Text('Retry', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: AppText.small)),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(IconData icon, Color color, String title, String value) {
    final available = value.isNotEmpty;
    final copied = _copiedLabel == title;
    return Expanded(
      child: GestureDetector(
        onTap: available ? () => _copy(title, value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: glassDeco(
            radius: 22,
            borderColor: copied ? AppColors.success : null,
            borderWidth: copied ? 1.6 : 1,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(
                _loading ? 'Loading…' : (available ? value : 'Not available'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.3),
              ),
              if (available && !_loading) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 12, color: copied ? AppColors.success : AppColors.primary),
                    const SizedBox(width: 4),
                    Text(copied ? 'Copied' : 'Tap to copy',
                        style: TextStyle(
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w800,
                            color: copied ? AppColors.success : AppColors.primary)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tickets

  Widget _ticketsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _infoCard(Icons.lock_outline_rounded, 'Sign in to see your support requests');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('tickets').where('customerId', isEqualTo: user.uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _infoCard(Icons.error_outline_rounded, 'Could not load your requests');
        }
        if (!snap.hasData) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ta = a.data()['created'];
            final tb = b.data()['created'];
            final da = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final db = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return db.compareTo(da);
          });
        if (docs.isEmpty) {
          return _infoCard(Icons.inbox_outlined, 'No requests yet. Tap "Raise a support request" if you need help.');
        }
        final shown = _showAllTickets ? docs : docs.take(3).toList();
        return Column(
          children: [
            for (final d in shown) ...[
              _ticketCard(d.id, d.data()),
              const SizedBox(height: 12),
            ],
            if (docs.length > 3)
              GestureDetector(
                onTap: () => setState(() => _showAllTickets = !_showAllTickets),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _showAllTickets ? 'Show less' : 'View all ${docs.length} requests',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: AppText.body),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _infoCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDeco(radius: 22),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.35))),
        ],
      ),
    );
  }

  Widget _ticketCard(String id, Map<String, dynamic> data) {
    final subject = (data['subject'] ?? 'Support request').toString();
    final status = (data['status'] ?? 'Open').toString();
    final created = data['created'];
    final msgs = (data['messages'] is List) ? data['messages'] as List : const [];
    String last = '';
    bool lastFromAdmin = false;
    if (msgs.isNotEmpty && msgs.last is Map) {
      final m = msgs.last as Map;
      last = (m['text'] ?? '').toString();
      lastFromAdmin = m['fromAdmin'] == true;
    }
    return GestureDetector(
      onTap: () => _openTicket(id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: glassDeco(radius: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text)),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(status),
                    ],
                  ),
                  if (last.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('${lastFromAdmin ? 'Support: ' : 'You: '}$last',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.35)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '#$id${created is Timestamp ? '  •  ${_fmtDate(created.toDate())}' : ''}',
                    style: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- FAQs

  Widget _faqSearchBar() {
    return TextField(
      controller: _faqSearch,
      onChanged: (v) => setState(() => _faqQuery = v),
      decoration: InputDecoration(
        hintText: 'Search questions',
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        suffixIcon: _faqQuery.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
          onPressed: () {
            _faqSearch.clear();
            setState(() => _faqQuery = '');
          },
        ),
        filled: true,
        fillColor: checkoutFieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _faqSection() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    final q = _faqQuery.trim().toLowerCase();
    final list = q.isEmpty
        ? _faqs
        : _faqs.where((f) => f.q.toLowerCase().contains(q) || f.a.toLowerCase().contains(q)).toList();

    if (_faqs.isEmpty) {
      return _infoCard(Icons.help_outline_rounded, 'No questions available right now.');
    }
    if (list.isEmpty) {
      return _infoCard(Icons.search_off_rounded, 'No questions match your search. Try raising a support request.');
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: glassDeco(radius: 22),
      child: Column(
        children: [
          for (int i = 0; i < list.length; i++) ...[
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: AppColors.primary,
                collapsedIconColor: AppColors.muted,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(list[i].q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.body, color: AppColors.text)),
                children: [Text(list[i].a, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.4))],
              ),
            ),
            if (i != list.length - 1) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

// ======================================================== new request sheet

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  static const _categories = ['Order', 'Payment', 'Delivery', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'Order';
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted),
    filled: true,
    fillColor: checkoutFieldFill,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );

  void _warn(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    // A second tap while the first request is still running would create a duplicate ticket.
    if (_sending) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_categories.contains(_category)) {
      _warn('Please choose a category');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _warn('Please sign in to contact support');
      return;
    }

    // Minimum gap between two new requests.
    final last = _lastTicketAt;
    if (last != null) {
      final wait = _kTicketGapSeconds - DateTime.now().difference(last).inSeconds;
      if (wait > 0) {
        _warn('Please wait $wait seconds before sending another request.');
        return;
      }
    }

    final subject = _cleanSubject(_subject.text);
    final message = _cleanMessage(_message.text);

    setState(() => _sending = true);
    try {
      // Own tickets only (the Firestore rules allow this query). Used to stop duplicates
      // and to limit how many requests can be open at the same time.
      final mine = await FirebaseFirestore.instance
          .collection('tickets')
          .where('customerId', isEqualTo: user.uid)
          .get();
      var openCount = 0;
      for (final d in mine.docs) {
        final data = d.data();
        final status = (data['status'] ?? 'Open').toString().toLowerCase();
        if (status == 'closed' || status == 'resolved') continue;
        openCount++;
        final sameSubject = (data['subject'] ?? '').toString().trim().toLowerCase() == subject.toLowerCase();
        if (sameSubject) {
          if (!mounted) return;
          setState(() => _sending = false);
          _warn('You already have an open request with this subject. Please reply to it instead.');
          return;
        }
      }
      if (openCount >= _kMaxOpenTickets) {
        if (!mounted) return;
        setState(() => _sending = false);
        _warn('You already have $openCount open requests. Please wait for a reply or close one first.');
        return;
      }

      final now = Timestamp.now();
      final ticketRef = FirebaseFirestore.instance.collection('tickets').doc();
      await ticketRef.set({
        'customerId': user.uid,
        'subject': subject,
        'category': _category,
        'status': 'Open',
        'created': now,
        'updatedAt': FieldValue.serverTimestamp(),
        'messages': [
          {'fromAdmin': false, 'text': message, 'time': now},
        ],
      });
      _lastTicketAt = DateTime.now();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CheckoutSectionTitle('Contact support'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _categories)
                    GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: _category == c ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _category == c ? AppColors.primary : const Color(0xFFDCE8FF)),
                          boxShadow: _category == c
                              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: Text(c,
                            style: TextStyle(
                                color: _category == c ? Colors.white : AppColors.text,
                                fontWeight: FontWeight.w700,
                                fontSize: AppText.body)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subject,
                maxLength: 80,
                decoration: _deco('Subject').copyWith(counterText: ''),
                validator: _validateTicketSubject,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                maxLines: 4,
                maxLength: 500,
                decoration: _deco('Describe your issue'),
                validator: _validateTicketMessage,
              ),
              const SizedBox(height: 12),
              GradientButton(
                onTap: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ ticket chat

class _TicketChatSheet extends StatefulWidget {
  final String ticketId;
  const _TicketChatSheet({required this.ticketId});

  @override
  State<_TicketChatSheet> createState() => _TicketChatSheetState();
}

class _TicketChatSheetState extends State<_TicketChatSheet> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _cleanMessage(_reply.text);
    if (text.isEmpty || _sending) return;
    // A reply may be only an order number, so only keyboard-smash is rejected here.
    if (RegExp(r'(.)\1{9,}').hasMatch(text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a real reply')));
      return;
    }
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply must be 500 characters or fewer.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to reply.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final ticketRef = FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId);

      // Read and update in one transaction so a reply cannot overwrite a
      // concurrent admin reply, and do not allow replies to closed tickets.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(ticketRef);
        if (!snapshot.exists) {
          throw StateError('This support request no longer exists.');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        if ((data['customerId'] ?? '').toString() != user.uid) {
          throw StateError('You do not have permission to reply to this request.');
        }
        if ((data['status'] ?? 'Open').toString().toLowerCase() == 'closed') {
          throw StateError('This request is closed. Raise a new request if you still need help.');
        }

        final messages = data['messages'] is List
            ? List<dynamic>.from(data['messages'] as List)
            : <dynamic>[];
        messages.add({
          'fromAdmin': false,
          'text': text,
          'time': Timestamp.now(),
        });
        // A customer reply on a "Resolved" request opens it again so the admin sees it.
        final reopen = (data['status'] ?? 'Open').toString().toLowerCase() == 'resolved';
        transaction.update(ticketRef, {
          'messages': messages,
          if (reopen) 'status': 'Open',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _reply.clear();
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message
            : 'Could not send. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(Map m) {
    final fromAdmin = m['fromAdmin'] == true;
    final time = m['time'];
    return Align(
      alignment: fromAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: fromAdmin ? checkoutFieldFill : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromAdmin ? 4 : 16),
            bottomRight: Radius.circular(fromAdmin ? 16 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fromAdmin ? 'Support' : 'You',
              style: TextStyle(
                  fontSize: AppText.caption,
                  fontWeight: FontWeight.w800,
                  color: fromAdmin ? AppColors.primary : Colors.white70),
            ),
            const SizedBox(height: 2),
            Text((m['text'] ?? '').toString(),
                style: TextStyle(fontSize: AppText.body, height: 1.35, color: fromAdmin ? AppColors.text : Colors.white)),
            if (time is Timestamp) ...[
              const SizedBox(height: 4),
              Text(_fmtTime(time.toDate()),
                  style: TextStyle(fontSize: AppText.caption, color: fromAdmin ? AppColors.muted : Colors.white70)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('tickets').doc(widget.ticketId).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('Could not load this request.'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!.data();
            if (data == null) {
              return const Center(child: Text('This request no longer exists.'));
            }
            final subject = (data['subject'] ?? 'Support request').toString();
            final status = (data['status'] ?? 'Open').toString();
            final msgs = (data['messages'] is List) ? (data['messages'] as List).whereType<Map>().toList() : <Map>[];
            final closed = status.toLowerCase() == 'closed';

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
            });

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.title, color: AppColors.text)),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('#${widget.ticketId}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.small)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    children: [for (final m in msgs) _bubble(m)],
                  ),
                ),
                const SizedBox(height: 8),
                if (closed)
                  const Text('This request is closed. Raise a new request if you still need help.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: AppText.small))
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText: 'Type a reply',
                            hintStyle: const TextStyle(color: AppColors.muted),
                            filled: true,
                            fillColor: checkoutFieldFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendReply,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: _sending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}