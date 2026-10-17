import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phonehub/Admin/order_details.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'package:phonehub/app_text.dart';

import 'admin_theme.dart';
import 'admin_data.dart';

// -----------------------------------------------------------------------------
// Delivery partners screens
// Same UI style as the Coupons & Offers screen.
// -----------------------------------------------------------------------------

const double _fHeader = 18; // screen title
const double _fTitle = 12; // card titles / section titles
const double _fBody = 10.5; // normal text
const double _fSmall = 9.5; // hints, chips, labels
const double _fTiny = 8.5; // tiny captions

// -----------------------------------------------------------------------------
// Small shared widgets (same look as the coupons screen)
// -----------------------------------------------------------------------------

AppBar _appBar(String title, {List<Widget>? actions}) => AppBar(
  centerTitle: false,
  leadingWidth: 48,
  titleSpacing: 4,
  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
  actions: actions,
);

Widget _sectionLabel(String t, {IconData? icon}) => Padding(
  padding: const EdgeInsets.only(top: 6, bottom: 8),
  child: Row(
    children: [
      if (icon != null) ...[Icon(icon, size: 14, color: AC.primary), const SizedBox(width: 6)],
      Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
    ],
  ),
);

Widget _infoChip(IconData icon, String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  decoration: BoxDecoration(color: AC.bg, borderRadius: BorderRadius.circular(6)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: AC.muted),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: _fSmall - .5, color: AC.text, fontWeight: FontWeight.w600)),
    ],
  ),
);

/// Small coloured label (Online, cash held, gave back ...), same size as _infoChip.
Widget _flagChip(IconData icon, Color color, String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: _fSmall - .5, color: color, fontWeight: FontWeight.w700)),
    ],
  ),
);

/// Opens the dialer; if that is not possible the number is copied instead.
Future<void> _dialPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) {
    snack(context, 'No phone number saved');
    return;
  }
  try {
    if (await launchUrl(Uri(scheme: 'tel', path: number))) return;
  } catch (_) {}
  if (!context.mounted) return;
  Clipboard.setData(ClipboardData(text: number));
  snack(context, 'Number copied. Open your dialer to call.');
}

Widget _statusPill(bool active) {
  final color = active ? AC.success : AC.warning;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(active ? 'Active' : 'Inactive', style: TextStyle(color: color, fontSize: _fSmall, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AC.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AC.primary : AC.muted.withValues(alpha: .25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: _fBody, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: .22) : AC.muted.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(fontSize: _fTiny, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Main screen: Delivery Partners
// -----------------------------------------------------------------------------

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';
  String _sort = 'Default';

  static const _sorts = ['Default', 'Top rated', 'Most orders', 'Name A-Z'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _orderCount(Partner p) => store.orders.where((o) => o.partnerId == p.id && !o.cancelled).length;
  int _liveCount(Partner p) => store.orders.where((o) => o.partnerId == p.id && o.isOngoing).length;
  int _cashHeld(Partner p) => store.partnerCashPending(p.id);
  int _gaveBackCount(Partner p) => store.orders.where((o) => o.rejectedByPartner(p.id)).length;

  void _openForm([Partner? p]) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PartnerFormScreen(partner: p)),
  );

  void _openDetail(Partner p) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PartnerDetailScreen(partnerId: p.id)),
  );

  void _toggle(Partner p, bool v) {
    p.active = v;
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final compactTextTheme = baseTheme.textTheme.apply(fontSizeDelta: -2);

    return Theme(
      data: baseTheme.copyWith(textTheme: compactTextTheme),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final query = _search.text.trim().toLowerCase();
          final all = store.partners;

          final activeCount = all.where((p) => p.active).length;
          final inactiveCount = all.where((p) => !p.active).length;
          final onlineCount = all.where((p) => p.active && p.online).length;
          final cashDueCount = all.where((p) => _cashHeld(p) > 0).length;
          final onRoadCount = all.where((p) => _liveCount(p) > 0).length;

          final list = all.where((p) {
            final matchesSearch = query.isEmpty ||
                p.name.toLowerCase().contains(query) ||
                p.phone.toLowerCase().contains(query) ||
                p.email.toLowerCase().contains(query) ||
                p.vehicle.toLowerCase().contains(query);
            final matchesFilter = _filter == 'All' ||
                (_filter == 'Active' && p.active) ||
                (_filter == 'Online' && p.active && p.online) ||
                (_filter == 'Cash due' && _cashHeld(p) > 0) ||
                (_filter == 'Inactive' && !p.active);
            return matchesSearch && matchesFilter;
          }).toList();

          switch (_sort) {
            case 'Top rated':
              list.sort((a, b) => b.rating.compareTo(a.rating));
            case 'Most orders':
              list.sort((a, b) => _orderCount(b).compareTo(_orderCount(a)));
            case 'Name A-Z':
              list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            default:
              break;
          }

          final counts = {'All': all.length, 'Active': activeCount, 'Online': onlineCount, 'Cash due': cashDueCount, 'Inactive': inactiveCount};

          return Scaffold(
            appBar: _appBar(
              'Delivery Partners',
              actions: [
                IconButton(
                  icon: const Icon(Icons.map_rounded, size: 22),
                  tooltip: 'Live tracking',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AC.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Add partner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
            ),
            body: Column(
              children: [
                // ---- search ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: _fBody + 1),
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone, email or vehicle',
                        hintStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                          tooltip: 'Clear search',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .18))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .18))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.2)),
                      ),
                    ),
                  ),
                ),
                // ---- filter chips ----
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final f in ['All', 'Active', 'Online', 'Cash due', 'Inactive'])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: _FilterPill(label: f, count: counts[f] ?? 0, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                        ),
                    ],
                  ),
                ),

                // ---- count + sort ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Text('Your partners', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                      const SizedBox(width: 6),
                      Text('${list.length} shown', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'Sort',
                        initialValue: _sort,
                        onSelected: (v) => setState(() => _sort = v),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (_) => [
                          for (final s in _sorts)
                            PopupMenuItem(value: s, height: 38, child: Text(s, style: TextStyle(fontSize: _fBody + 1, fontWeight: s == _sort ? FontWeight.w800 : FontWeight.w500))),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 15, color: AC.primary),
                              const SizedBox(width: 4),
                              Text(_sort, style: const TextStyle(color: AC.primary, fontSize: _fSmall, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- list ----
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(
                    icon: all.isEmpty ? Icons.people_alt_outlined : Icons.search_off_rounded,
                    title: all.isEmpty ? 'No delivery partners yet' : 'No matching partners',
                    subtitle: all.isEmpty ? 'Add a partner to manage delivery assignments' : 'Try another search or status filter',
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _partnerCard(list[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: cardDeco(radius: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 2, height: 1.05, color: AC.text)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fTiny)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _partnerCard(Partner p) {
    final orders = _orderCount(p);
    final live = _liveCount(p);
    final cash = _cashHeld(p);
    final gaveBack = _gaveBackCount(p);
    final unpaid = store.partnerUnpaidEarning(p.id);
    final docsBlocked = p.active && !store.partnerCanTakeOrders(p);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(radius: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _openDetail(p),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: p.active ? AC.primary : AC.muted,
                        child: Text(
                          p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: _fTitle + 2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle, color: AC.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.vehicle.isEmpty ? 'No vehicle added' : p.vehicle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AC.muted, fontSize: _fSmall),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _statusPill(p.active),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.more_vert_rounded, color: AC.muted),
                        constraints: const BoxConstraints(minWidth: 130),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (v) {
                          if (v == 'edit') _openForm(p);
                          if (v == 'call') _dialPhone(context, p.phone);
                          if (v == 'copy') {
                            Clipboard.setData(ClipboardData(text: p.phone));
                            snack(context, 'Number copied');
                          }
                        },
                        itemBuilder: (_) => [
                          _menu('edit', Icons.edit_outlined, 'Edit'),
                          _menu('call', Icons.call_rounded, 'Call'),
                          _menu('copy', Icons.copy_rounded, 'Copy number'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (p.active) _flagChip(Icons.circle, p.online ? AC.success : AC.muted, p.online ? 'Online' : 'Offline'),
                      _infoChip(Icons.star_rounded, p.rating > 0 ? '${p.rating}' : 'New'),
                      _infoChip(Icons.inventory_2_outlined, '$orders orders'),
                      _infoChip(Icons.two_wheeler_rounded, '$live active'),
                      if (cash > 0) _flagChip(Icons.payments_rounded, AC.warning, '${inr(cash)} cash held'),
                      if (unpaid > 0) _flagChip(Icons.account_balance_wallet_rounded, AC.info, '${inr(unpaid)} to pay'),
                      if (docsBlocked) _flagChip(Icons.verified_user_rounded, AC.warning, 'Docs not verified'),
                      if (gaveBack > 0) _flagChip(Icons.undo_rounded, AC.danger, '$gaveBack gave back'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: AC.muted.withValues(alpha: .14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.call_outlined, size: 13, color: AC.muted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          p.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AC.muted, fontSize: _fSmall),
                        ),
                      ),
                      Text(p.active ? 'Available' : 'Unavailable', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                      Transform.scale(
                        scale: .72,
                        child: Switch(
                          value: p.active,
                          activeColor: AC.success,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => _toggle(p, v),
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
    );
  }

  PopupMenuItem<String> _menu(String v, IconData icon, String label, {Color? color}) => PopupMenuItem(
    value: v,
    height: 38,
    child: Row(
      children: [
        Icon(icon, size: 16, color: color ?? AC.text),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600, color: color ?? AC.text)),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Add / edit delivery partner
// -----------------------------------------------------------------------------

class PartnerFormScreen extends StatefulWidget {
  final Partner? partner;

  const PartnerFormScreen({super.key, this.partner});

  @override
  State<PartnerFormScreen> createState() => _PartnerFormScreenState();
}

class _PartnerFormScreenState extends State<PartnerFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.partner?.name ?? '');
  late final _phone = TextEditingController(text: widget.partner?.phone ?? '+91 ');
  late final _vehicle = TextEditingController(text: widget.partner?.vehicle ?? '');
  final _email = TextEditingController();

  bool get editing => widget.partner != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    if (editing) {
      widget.partner!
        ..name = _name.text.trim()
        ..phone = _phone.text.trim()
        ..vehicle = _vehicle.text.trim();
    } else {
      final email = _email.text.trim().toLowerCase();
      if (store.partners.any((p) => p.id == email)) {
        snack(context, 'A partner with this email already exists');
        return;
      }
      store.partners.add(
        Partner(
          id: email,
          email: email,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          vehicle: _vehicle.text.trim(),
          // A new partner has no rating yet; it becomes the average of the stars customers give.
          rating: 0,
        ),
      );
    }

    store.changed();
    snack(context, editing ? 'Partner updated' : 'Partner added');
    Navigator.pop(context);
  }

  Widget _input(
      String label,
      TextEditingController c, {
        TextInputType? type,
        String? hint,
        TextCapitalization caps = TextCapitalization.none,
        String? Function(String?)? validator,
        bool required = false,
      }) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      textCapitalization: caps,
      style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
        hintStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
        errorStyle: const TextStyle(fontSize: _fSmall),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .22))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .22))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(editing ? 'Edit partner' : 'Add partner'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
          children: [
            _sectionLabel('Partner details', icon: Icons.person_outline_rounded),
            _input('Full name', _name, caps: TextCapitalization.words, required: true),
            const SizedBox(height: 12),
            _input(
              'Phone number',
              _phone,
              type: TextInputType.phone,
              validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Enter a valid phone number' : null,
            ),
            const SizedBox(height: 12),
            _input('Vehicle (e.g. Bike • MH 12 AB 1234)', _vehicle),

            _sectionLabel('Login', icon: Icons.mail_outline_rounded),
            if (!editing)
              _input(
                'Email (the partner logs in with this)',
                _email,
                type: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@') || v.contains(' ')) ? 'Enter a valid email' : null,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: cardDeco(radius: 12),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 18, color: AC.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Login email: ${widget.partner!.email}',
                        style: const TextStyle(color: AC.muted, fontSize: _fSmall),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                textStyle: const TextStyle(fontSize: _fBody + 2, fontWeight: FontWeight.w800),
              ),
              child: Text(editing ? 'Save changes' : 'Add partner'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Partner profile with assigned orders
// -----------------------------------------------------------------------------

class PartnerDetailScreen extends StatelessWidget {
  final String partnerId;

  const PartnerDetailScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.partnerById(partnerId);
        if (p == null) {
          return Scaffold(
            appBar: _appBar('Delivery partner'),
            body: const EmptyState(icon: Icons.error_outline, title: 'Partner not found'),
          );
        }

        final mine = store.orders.where((o) => o.partnerId == p.id).toList()
          ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
        final delivered = mine.where((o) => o.isDelivered).length;
        final live = mine.where((o) => o.isOngoing).length;
        // Cash, failed attempts and orders the partner gave back (all from the delivery partner app).
        final cashOrders = store.cashPendingOrders(p.id);
        final cashHeld = store.partnerCashPending(p.id);
        final cashHandedOver = mine.where((o) => o.isCod && o.cashSettled && !o.cancelled).fold<int>(0, (s, o) => s + o.cashDue);
        final failedAttempts = mine.fold<int>(0, (s, o) => s + o.deliveryAttempts);
        final gaveBack = store.orders.where((o) => o.rejectedByPartner(p.id)).toList()
          ..sort((a, b) => (b.rejectedAt ?? b.placedAt).compareTo(a.rejectedAt ?? a.placedAt));

        // Earnings the admin still has to pay, what was paid before, and return pickups given to this partner.
        final unpaid = store.partnerUnpaidEarning(p.id);
        final unpaidOrders = store.unpaidEarningOrders(p.id);
        final paidTotal = store.partnerPaidTotal(p.id);
        final payoutList = store.payoutsOf(p.id);
        final returnPickups = store.orders.where((o) => o.returnPartnerId.toLowerCase() == p.id.toLowerCase()).toList()
          ..sort((a, b) => (b.returnPickedAt ?? b.placedAt).compareTo(a.returnPickedAt ?? a.placedAt));

        return Scaffold(
          appBar: _appBar(
            'Delivery partner',
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 22),
                tooltip: 'Edit partner',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PartnerFormScreen(partner: p)),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: Colors.white,
                          child: Text(
                            p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                            style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: _fTitle + 1)),
                              const SizedBox(height: 3),
                              Text(p.phone, style: const TextStyle(color: Colors.white70, fontSize: _fSmall)),
                              Text(p.vehicle, style: const TextStyle(color: Colors.white70, fontSize: _fSmall)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _statusPill(p.active),
                            if (p.active) ...[
                              const SizedBox(height: 5),
                              _flagChip(Icons.circle, p.online ? AC.success : AC.muted, p.online ? 'Online' : 'Offline'),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _hero(p.rating > 0 ? '★ ${p.rating}' : '★ —', 'Rating'),
                        _hero('$delivered', 'Delivered'),
                        _hero('$live', 'Active'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: () => _dialPhone(context, p.phone),
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Call', style: TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Track live', style: TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: cardDeco(radius: 12),
                child: Row(
                  children: [
                    const Icon(Icons.power_settings_new_rounded, size: 18, color: AC.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available for deliveries', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1)),
                          Text('Inactive partners cannot be assigned to orders', style: TextStyle(color: AC.muted, fontSize: _fSmall)),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: .85,
                      child: Switch(
                        value: p.active,
                        activeColor: AC.success,
                        onChanged: (v) {
                          p.active = v;
                          store.changed();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionLabel('Cash & delivery record', icon: Icons.payments_outlined),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: cardDeco(radius: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _record(inr(cashHeld), 'Cash held', cashHeld > 0 ? AC.warning : AC.text),
                        _record(inr(cashHandedOver), 'Handed over', AC.success),
                        _record('$failedAttempts', 'Failed tries', failedAttempts > 0 ? AC.warning : AC.text),
                        _record('${gaveBack.length}', 'Gave back', gaveBack.isNotEmpty ? AC.danger : AC.text),
                      ],
                    ),
                    if (cashHeld > 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40), backgroundColor: AC.success, textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                          onPressed: () => _settleAll(context, p, cashOrders, cashHeld),
                          child: Text('Mark ${inr(cashHeld)} received'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!store.partnerCanTakeOrders(p)) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _flagChip(Icons.verified_user_rounded, AC.warning, 'Verify ${p.docsNotVerified.map(_PartnerVerification._titleOf).join(', ')} to give orders'),
                ),
              ],
              const SizedBox(height: 10),
              _sectionLabel('Earnings & payouts', icon: Icons.account_balance_wallet_outlined),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: cardDeco(radius: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _record(inr(unpaid), 'To pay', unpaid > 0 ? AC.warning : AC.text),
                        _record(inr(paidTotal), 'Paid out', AC.success),
                        _record('${unpaidOrders.length}', 'Unpaid orders', AC.text),
                        _record('${store.partnerActiveOrders(p.id)}', 'Carrying now', AC.text),
                      ],
                    ),
                    if (unpaid > 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40), backgroundColor: AC.success, textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                          onPressed: () => _payEarnings(context, p, unpaid, unpaidOrders.length),
                          child: Text('Pay ${inr(unpaid)} to ${p.name}'),
                        ),
                      ),
                    ],
                    if (store.partnerEarning == 0 && payoutList.isEmpty && unpaidOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('Set the earning per delivered order in Settings so deliveries earn money.', style: TextStyle(fontSize: _fSmall, color: AC.muted)),
                      ),
                    if (payoutList.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Payout history', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
                      const SizedBox(height: 4),
                      for (final x in payoutList.take(6))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: AC.success),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('${fmtDate(x.date)} • ${x.orderCount} order(s)${x.note.isEmpty ? '' : ' • ${x.note}'}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: _fSmall, color: AC.muted)),
                              ),
                              Text(inr(x.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _PartnerVerification(partnerId: p.id),
              const SizedBox(height: 10),
              _sectionLabel('Assigned orders (${mine.length})', icon: Icons.inventory_2_outlined),
              if (mine.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: cardDeco(radius: 12),
                  child: const Text('No orders assigned yet', style: TextStyle(fontSize: _fBody, color: AC.muted)),
                ),
              for (final o in mine) OrderTile(order: o),
              if (returnPickups.isNotEmpty) ...[
                const SizedBox(height: 10),
                _sectionLabel('Return pickups (${returnPickups.length})', icon: Icons.assignment_return_outlined),
                for (final o in returnPickups) OrderTile(order: o),
              ],
              if (gaveBack.isNotEmpty) ...[
                const SizedBox(height: 10),
                _sectionLabel('Gave back (${gaveBack.length})', icon: Icons.undo_rounded),
                for (final o in gaveBack) OrderTile(order: o),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _record(String value, String label, Color color) => Expanded(
    child: Column(
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 1, color: color))),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
      ],
    ),
  );

  /// The admin received all the COD cash this partner was holding.
  Future<void> _settleAll(BuildContext context, Partner p, List<AdminOrder> orders, int total) async {
    final ok = await confirmDialog(
      context,
      'Cash received?',
      'Confirm that you received ${inr(total)} from ${p.name} for ${orders.length} delivered order(s).',
      yes: 'Yes, received',
    );
    if (!ok || !context.mounted) return;
    final saved = await store.settleCash(orders);
    if (context.mounted) snack(context, saved ? '${inr(total)} marked as received' : 'Could not save. Please check your internet and try again.');
  }

  /// The admin pays the partner everything he earned so far (one payout record, his delivered orders become "paid").
  Future<void> _payEarnings(BuildContext context, Partner p, int total, int count) async {
    final ok = await confirmDialog(
      context,
      'Pay earnings?',
      'Confirm that you paid ${inr(total)} to ${p.name} for $count delivered order(s).',
      yes: 'Yes, paid',
    );
    if (!ok || !context.mounted) return;
    final saved = await store.payPartner(p.id);
    if (context.mounted) snack(context, saved ? '${inr(total)} paid to ${p.name}' : 'Could not save. Please check your internet and try again.');
  }

  Widget _hero(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: _fTitle + 2)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: _fSmall)),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Partner verification: documents (Licence / Aadhaar / RC) + vehicle & bank details.
// Reads what the partner app saved in partners/{email}/docs/* and partners/{email}.
// The admin verifies or rejects a document; the partner sees the new status live.
// -----------------------------------------------------------------------------

class _PartnerVerification extends StatelessWidget {
  final String partnerId;

  const _PartnerVerification({required this.partnerId});

  // key (same keys as the partner app) -> title
  static const List<List<String>> _docs = [
    ['licence', 'Driving Licence'],
    ['aadhaar', 'Aadhaar Card'],
    ['rc', 'RC Book'],
  ];

  static String _titleOf(String key) {
    for (final d in _docs) {
      if (d[0] == key) return d[1];
    }
    return key;
  }

  static Color _color(String status) {
    switch (status) {
      case 'Verified':
        return AC.success;
      case 'Rejected':
        return AC.danger;
      case 'Not uploaded':
        return AC.muted;
      default:
        return AC.warning;
    }
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(color: color, fontSize: _fSmall, fontWeight: FontWeight.w800)),
  );

  Uint8List? _bytes(dynamic image) {
    try {
      final s = (image ?? '').toString();
      if (s.isEmpty) return null;
      final i = s.indexOf(',');
      return base64Decode(i >= 0 ? s.substring(i + 1) : s);
    } catch (_) {
      return null;
    }
  }

  void _view(BuildContext context, String title, Map<String, dynamic> d) {
    final bytes = _bytes(d['image']);
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle + 1))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(dialog).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (bytes == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Photo could not be opened', style: TextStyle(fontSize: _fBody, color: AC.muted)),
                )
              else
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, String key, String status, {String reason = ''}) async {
    try {
      await fs.FirebaseFirestore.instance.doc('partners/$partnerId/docs/$key').update({
        'status': status,
        'reason': reason,
        'reviewedAt': fs.FieldValue.serverTimestamp(),
      });
      // Tell the delivery partner (Notifications screen of the delivery app).
      final title = _titleOf(key);
      unawaited(store.notifyPartner(
        partnerId,
        status == 'Verified' ? '$title verified' : '$title rejected',
        status == 'Verified'
            ? 'Your $title was checked and verified by the admin.'
            : 'Your $title was rejected${reason.isEmpty ? '' : ': $reason'}. Please upload a clear photo again.',
        type: 'document',
      ));
      if (context.mounted) snack(context, status == 'Verified' ? 'Document verified' : 'Document rejected');
    } catch (_) {
      if (context.mounted) snack(context, 'Could not update the document. Please try again.');
    }
  }

  Future<void> _reject(BuildContext context, String key, String title) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: 'Reject $title'),
    );
    if (reason == null || !context.mounted) return;
    await _setStatus(context, key, 'Rejected', reason: reason);
  }

  Widget _docTile(BuildContext context, String key, String title, Map<String, dynamic>? d) {
    final status = d == null ? 'Not uploaded' : ((d['status'] ?? '').toString().isEmpty ? 'Pending' : d['status'].toString());
    final color = _color(status);
    final reason = status == 'Rejected' ? (d?['reason'] ?? '').toString() : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1))),
              _chip(status, color),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reason: $reason', style: const TextStyle(fontSize: _fSmall, color: AC.muted)),
          ],
          if (d == null) ...[
            const SizedBox(height: 4),
            const Text('Partner has not uploaded this document yet', style: TextStyle(fontSize: _fSmall, color: AC.muted)),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
                    onPressed: () => _view(context, title, d),
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text('View', style: TextStyle(fontSize: _fBody, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
                    onPressed: status == 'Verified' ? null : () => _setStatus(context, key, 'Verified'),
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text('Verify', style: TextStyle(fontSize: _fBody, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36), foregroundColor: AC.danger),
                    onPressed: status == 'Rejected' ? null : () => _reject(context, key, title),
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Reject', style: TextStyle(fontSize: _fBody, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, dynamic value) {
    final v = (value ?? '').toString().trim();
    return InkWell(
      onTap: v.isEmpty
          ? null
          : () {
        Clipboard.setData(ClipboardData(text: v));
        snack(context, '$label copied');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: _fBody, color: AC.muted))),
            Expanded(
              flex: 5,
              child: Text(
                v.isEmpty ? '—' : v,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: _fBody, fontWeight: FontWeight.w700, color: AC.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = fs.FirebaseFirestore.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Documents', icon: Icons.verified_user_outlined),
        StreamBuilder<fs.QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('partners/$partnerId/docs').snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(radius: 12),
                child: const Text('Could not load documents', style: TextStyle(fontSize: _fBody, color: AC.muted)),
              );
            }
            final saved = <String, Map<String, dynamic>>{
              for (final d in snap.data?.docs ?? <fs.QueryDocumentSnapshot<Map<String, dynamic>>>[]) d.id: d.data(),
            };
            return Column(
              children: [
                for (final d in _docs) _docTile(context, d[0], d[1], saved[d[0]]),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        _sectionLabel('Vehicle & bank details', icon: Icons.account_balance_outlined),
        StreamBuilder<fs.DocumentSnapshot<Map<String, dynamic>>>(
          stream: db.doc('partners/$partnerId').snapshots(),
          builder: (context, snap) {
            final m = snap.data?.data() ?? <String, dynamic>{};
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: cardDeco(radius: 12),
              child: Column(
                children: [
                  _row(context, 'Vehicle number', m['vehicleNo']),
                  _row(context, 'Vehicle model', m['vehicleModel']),
                  _row(context, 'Vehicle type', m['vehicleType']),
                  _row(context, 'Fuel type', m['fuelType']),
                  const Divider(height: 14),
                  _row(context, 'Account holder', m['bankHolder']),
                  _row(context, 'Bank name', m['bankName']),
                  _row(context, 'Account number', m['bankAccount']),
                  _row(context, 'IFSC code', m['bankIfsc']),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Asks the admin for the reason when a document is rejected (shown to the partner).
class _ReasonDialog extends StatefulWidget {
  final String title;

  const _ReasonDialog({required this.title});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle + 2)),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 120,
        decoration: const InputDecoration(hintText: 'Reason (e.g. photo is blurry)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: AC.muted)),
        ),
        TextButton(
          onPressed: () {
            final r = _c.text.trim();
            if (r.isEmpty) return;
            Navigator.of(context).pop(r);
          },
          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800, color: AC.danger)),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Live tracking: every "Out for Delivery" order moves from the store to the customer.
// Simulated with an animation. Replace with real GPS from your backend.
// -----------------------------------------------------------------------------

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

/// A GPS point read from Firestore (partner position or customer's delivery point).
class _LivePoint {
  final double lat, lng;
  final DateTime? at;
  const _LivePoint(this.lat, this.lng, [this.at]);
  gm.LatLng get ll => gm.LatLng(lat, lng);
}

_LivePoint? _livePoint(dynamic lat, dynamic lng, [dynamic at]) {
  if (lat is! num || lng is! num) return null;
  return _LivePoint(lat.toDouble(), lng.toDouble(), at is fs.Timestamp ? at.toDate() : null);
}

double _kmBetween(_LivePoint a, _LivePoint b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h.toDouble()));
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  // Real positions, saved by the delivery partner app (see orders_data.dart there).
  StreamSubscription<fs.QuerySnapshot<Map<String, dynamic>>>? _partnerSub;
  StreamSubscription<fs.QuerySnapshot<Map<String, dynamic>>>? _orderSub;
  final Map<String, _LivePoint> _partnerPos = {}; // partner email -> position
  final Map<String, _LivePoint> _dest = {}; // order id -> customer's delivery point
  final Map<String, _LivePoint> _orderPartnerPos = {}; // order id -> partner position saved on the order
  gm.GoogleMapController? _map;
  String _fitKey = '';

  @override
  void initState() {
    super.initState();
    final db = fs.FirebaseFirestore.instance;
    _partnerSub = db.collection('partners').snapshots().listen((snap) {
      _partnerPos.clear();
      for (final d in snap.docs) {
        final m = d.data();
        final p = _livePoint(m['lat'], m['lng'], m['locationAt']);
        if (p != null) _partnerPos[d.id.toLowerCase()] = p;
      }
      if (mounted) setState(() {});
    }, onError: (Object e) => debugPrint('PhoneHub live tracking partners: $e'));
    _orderSub = db.collection('orders').where('status', isEqualTo: 'Out for Delivery').snapshots().listen((snap) {
      _dest.clear();
      _orderPartnerPos.clear();
      for (final d in snap.docs) {
        final m = d.data();
        final dest = _livePoint(m['addressLat'], m['addressLng']);
        if (dest != null) _dest[d.id] = dest;
        final pp = _livePoint(m['partnerLat'], m['partnerLng'], m['partnerLocationAt']);
        if (pp != null) _orderPartnerPos[d.id] = pp;
      }
      if (mounted) setState(() {});
    }, onError: (Object e) => debugPrint('PhoneHub live tracking orders: $e'));
  }

  @override
  void dispose() {
    _partnerSub?.cancel();
    _orderSub?.cancel();
    _map?.dispose();
    _c.dispose();
    super.dispose();
  }

  _LivePoint? _partnerPoint(AdminOrder o) {
    final id = (o.partnerId ?? '').toLowerCase();
    return _partnerPos[id] ?? _orderPartnerPos[o.id];
  }

  String _ago(DateTime? t) {
    if (t == null) return 'Live';
    final m = DateTime.now().difference(t).inMinutes;
    return m < 1 ? 'Updated just now' : 'Updated $m min ago';
  }

  String _etaText(AdminOrder o) {
    final p = _partnerPoint(o), d = _dest[o.id];
    if (p == null || d == null) return p == null ? 'waiting for partner location' : 'ETA not available';
    final mins = math.max(1, (_kmBetween(p, d) / 25 * 60).ceil());
    return 'ETA $mins mins';
  }

  /// Frames all deliveries on the map (only when the set of deliveries changes).
  void _fit(List<gm.LatLng> pts, String key) {
    if (key == _fitKey || pts.isEmpty) return;
    _fitKey = key;
    final map = _map;
    if (map == null) return;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (pts.length == 1) {
        map.animateCamera(gm.CameraUpdate.newLatLngZoom(pts.first, 14)).catchError((Object _) {});
        return;
      }
      final lats = pts.map((e) => e.latitude), lngs = pts.map((e) => e.longitude);
      final b = gm.LatLngBounds(
        southwest: gm.LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
        northeast: gm.LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
      );
      map.animateCamera(gm.CameraUpdate.newLatLngBounds(b, 60)).catchError((Object _) {});
    });
  }

  Widget _liveMap(List<AdminOrder> live) {
    final markers = <gm.Marker>{};
    final lines = <gm.Polyline>{};
    final pts = <gm.LatLng>[];
    for (final o in live) {
      final p = _partnerPoint(o), d = _dest[o.id];
      final name = store.partnerById(o.partnerId)?.name ?? 'Partner';
      if (p != null) {
        pts.add(p.ll);
        markers.add(gm.Marker(
          markerId: gm.MarkerId('p_${o.id}'),
          position: p.ll,
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
          infoWindow: gm.InfoWindow(title: '$name • #${o.id}', snippet: _ago(p.at)),
        ));
      }
      if (d != null) {
        pts.add(d.ll);
        markers.add(gm.Marker(
          markerId: gm.MarkerId('d_${o.id}'),
          position: d.ll,
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
          infoWindow: gm.InfoWindow(title: store.customerName(o.customerId), snippet: 'Order #${o.id}'),
        ));
      }
      if (p != null && d != null) {
        lines.add(gm.Polyline(
          polylineId: gm.PolylineId('l_${o.id}'),
          points: [p.ll, d.ll],
          color: AC.accent,
          width: 3,
          patterns: [gm.PatternItem.dash(16), gm.PatternItem.gap(8)],
        ));
      }
    }
    if (pts.isEmpty) return const SizedBox.shrink();
    final key = (live.map((e) => e.id).toList()..sort()).join(',');
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit(pts, key));
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: pts.first, zoom: 13),
      onMapCreated: (c) {
        _map = c;
        _fit(pts, key);
      },
      markers: markers,
      polylines: lines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final live = store.orders.where((o) => !o.cancelled && o.stage == 3).toList();
        // Real map when at least one live position is known; otherwise the old picture.
        final hasReal = live.any((o) => _partnerPoint(o) != null || _dest[o.id] != null);

        return Scaffold(
          appBar: _appBar('Live tracking'),
          body: Column(
            children: [
              Container(
                height: 260,
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: cardDeco(radius: 16),
                clipBehavior: Clip.antiAlias,
                child: hasReal
                    ? _liveMap(live)
                    : AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: _MapPainter(
                      live.map((o) => o.id).toList(),
                      live.map((o) => store.partnerById(o.partnerId)?.name ?? '?').toList(),
                      _c.value,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    const Text('On the road', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                    const SizedBox(width: 6),
                    Text('${live.length} deliveries', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                  ],
                ),
              ),
              Expanded(
                child: live.isEmpty
                    ? const EmptyState(
                  icon: Icons.two_wheeler_rounded,
                  title: 'No deliveries on the road',
                  subtitle: 'Orders marked "Out for Delivery" appear here',
                )
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  children: [
                    for (int i = 0; i < live.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: cardDeco(radius: 16),
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: live[i].id)),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: const IconBadge(Icons.two_wheeler_rounded, AC.accent),
                          title: Text(
                            '#${live[i].id} • ${store.partnerById(live[i].partnerId)?.name ?? 'Unassigned'}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              'To ${store.customerName(live[i].customerId)} • ${_etaText(live[i])}',
                              style: const TextStyle(color: AC.muted, fontSize: _fSmall),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AC.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<String> ids;
  final List<String> names;
  final double t;

  _MapPainter(this.ids, this.names, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9EEF7));

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9;
    final thin = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;

    for (int i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 5),
        Offset(size.width, size.height * i / 5),
        i == 2 ? road : thin,
      );
      canvas.drawLine(
        Offset(size.width * i / 5, 0),
        Offset(size.width * i / 5, size.height),
        i == 3 ? road : thin,
      );
    }

    final park = Paint()..color = const Color(0xFFCFE8D5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.08, size.width * 0.28, size.height * 0.22),
        const Radius.circular(14),
      ),
      park,
    );

    final hub = Offset(size.width * 0.15, size.height * 0.5);
    _pin(canvas, hub, AC.primary, Icons.store_rounded);

    for (int i = 0; i < ids.length; i++) {
      final r = math.Random(ids[i].hashCode);
      final dest = Offset(
        size.width * (0.5 + r.nextDouble() * 0.42),
        size.height * (0.12 + r.nextDouble() * 0.76),
      );
      final corner = Offset(dest.dx, hub.dy);
      final prog = (t + i * 0.27) % 1.0;

      final route = Paint()
        ..color = AC.accent.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      canvas.drawPath(
        Path()
          ..moveTo(hub.dx, hub.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(dest.dx, dest.dy),
        route,
      );

      _pin(canvas, dest, AC.success, Icons.home_rounded);
      final l1 = (corner - hub).distance;
      final l2 = (dest - corner).distance;
      final d = prog * (l1 + l2);
      final pos = d <= l1
          ? Offset.lerp(hub, corner, l1 == 0 ? 0 : d / l1)!
          : Offset.lerp(corner, dest, l2 == 0 ? 0 : (d - l1) / l2)!;

      canvas.drawCircle(pos, 15, Paint()..color = AC.accent);
      canvas.drawCircle(
        pos,
        15,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: names[i].split(' ').first,
          style: const TextStyle(color: AC.text, fontSize: _fTiny, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      tp.paint(canvas, pos + Offset(-tp.width / 2, 18));

      final icon = Icons.two_wheeler_rounded;
      final ic = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontFamily: icon.fontFamily, fontSize: _fTitle, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ic.paint(canvas, pos - Offset(ic.width / 2, ic.height / 2));
    }
  }

  void _pin(Canvas canvas, Offset p, Color color, IconData icon) {
    canvas.drawCircle(p, 14, Paint()..color = color);
    final ic = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontFamily: icon.fontFamily, fontSize: _fTitle, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ic.paint(canvas, p - Offset(ic.width / 2, ic.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}