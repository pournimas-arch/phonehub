import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

// -----------------------------------------------------------------------------
// Text sizes used on this screen (all smaller than before).
// Change them here and the whole screen follows.
// -----------------------------------------------------------------------------
const double _fHeader = 18; // "Coupons & Offers" title
const double _fTitle = 12; // card titles / section titles
const double _fBody = 10.5; // normal text
const double _fSmall = 9.5; // hints, chips, labels
const double _fTiny = 8.5; // tiny captions

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

/// Whole days between today and [d] (negative = in the past).
int _dayDiff(DateTime d) {
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

String _expiryText(Coupon c) {
  final n = _dayDiff(c.expiry);
  if (c.expired) {
    if (n >= 0) return 'Expired today';
    return 'Expired ${-n} ${-n == 1 ? 'day' : 'days'} ago';
  }
  if (n <= 0) return 'Expires today';
  if (n == 1) return 'Expires tomorrow';
  if (n <= 30) return 'Expires in $n days';
  return 'Expires ${fmtDate(c.expiry)}';
}

bool _endingSoon(Coupon c) => c.active && !c.expired && _dayDiff(c.expiry) <= 7;

({String big, String small}) _headline(Coupon c) {
  if (c.flat > 0) return (big: inr(c.flat), small: 'FLAT OFF');
  if (c.percent > 0) return (big: '${c.percent}%', small: c.maxOff > 0 ? 'OFF UPTO ${inr(c.maxOff)}' : 'OFF');
  if (c.freeDelivery) return (big: 'FREE', small: 'DELIVERY');
  return (big: '--', small: 'NO RULE');
}

List<(IconData, String)> _ruleChips(Coupon c) {
  final list = <(IconData, String)>[];
  if (c.flat > 0 && c.percent > 0) {
    list.add((Icons.percent_rounded, '${c.percent}% off${c.maxOff > 0 ? ' (max ${inr(c.maxOff)})' : ''}'));
  }
  if (c.freeDelivery && (c.flat > 0 || c.percent > 0)) {
    list.add((Icons.local_shipping_outlined, 'Free delivery'));
  }
  if (c.minOrder > 0) list.add((Icons.shopping_bag_outlined, 'Min order ${inr(c.minOrder)}'));
  if (c.firstOrderOnly) list.add((Icons.person_add_alt_1_outlined, 'First order only'));
  return list;
}

// -----------------------------------------------------------------------------
// Firestore sync (so coupons & banners created here really reach the customer app)
// -----------------------------------------------------------------------------

class _CouponSync {
  static final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore.instance.collection('coupons');

  static Map<String, dynamic> _map(Coupon c) => {
    'code': c.code,
    'title': c.title,
    'note': c.note,
    'flat': c.flat,
    'percent': c.percent,
    'maxOff': c.maxOff,
    'minOrder': c.minOrder,
    'freeDelivery': c.freeDelivery,
    'firstOrderOnly': c.firstOrderOnly,
    'isActive': c.active,
    'active': c.active,
    'expiry': Timestamp.fromDate(c.expiry),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Finds the existing document(s) of a coupon (doc id == code, or a `code` field).
  static Future<List<DocumentReference<Map<String, dynamic>>>> _refs(String code) async {
    final refs = <String, DocumentReference<Map<String, dynamic>>>{};
    final byId = await _col.doc(code).get();
    if (byId.exists) refs[byId.id] = byId.reference;
    final byField = await _col.where('code', isEqualTo: code).get();
    for (final d in byField.docs) {
      refs[d.id] = d.reference;
    }
    return refs.values.toList();
  }

  /// Returns null on success, otherwise a readable error.
  static Future<String?> save(Coupon c, {String? oldCode}) async {
    try {
      final refs = await _refs(oldCode ?? c.code);
      final data = _map(c);
      if (refs.isEmpty) {
        await _col.doc(c.code).set(data);
      } else {
        for (final r in refs) {
          await r.set(data, SetOptions(merge: true));
        }
      }
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied' ? 'Permission denied. Check Firestore rules.' : (e.message ?? e.code);
    } catch (e) {
      return '$e';
    }
  }

  static Future<String?> delete(String code) async {
    try {
      for (final r in await _refs(code)) {
        await r.delete();
      }
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied' ? 'Permission denied. Check Firestore rules.' : (e.message ?? e.code);
    } catch (e) {
      return '$e';
    }
  }
}

class _BannerSync {
  static final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore.instance.collection('banners');
  static final Map<PromoBanner, String> _ids = {};
  static bool _loaded = false;

  /// Loads banners from Firestore once per app run (the admin store does not load them).
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final snap = await _col.get();
      final docs = snap.docs.toList()
        ..sort((a, b) => ((a.data()['order'] as num?) ?? 0).compareTo((b.data()['order'] as num?) ?? 0));
      if (docs.isEmpty) return;
      store.banners.clear();
      for (final d in docs) {
        final m = d.data();
        final col = m['color'];
        final b = PromoBanner(
          '${m['title'] ?? ''}',
          '${m['subtitle'] ?? ''}',
          col is num ? Color(col.toInt()) : AC.primary,
          active: (m['isActive'] ?? m['active'] ?? true) == true,
        );
        _ids[b] = d.id;
        store.banners.add(b);
      }
      store.changed();
    } catch (_) {
      _loaded = false; // try again next time
    }
  }

  static Future<String?> save(PromoBanner b) async {
    try {
      final isNew = !_ids.containsKey(b);
      final ref = isNew ? _col.doc() : _col.doc(_ids[b]);
      _ids[b] = ref.id;
      final data = <String, dynamic>{
        'title': b.title,
        'subtitle': b.subtitle,
        'color': b.color.toARGB32(),
        'isActive': b.active,
        'active': b.active,
        'order': store.banners.indexOf(b),
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNew) 'tag': 'OFFER',
        if (isNew) 'cta': 'Shop Now',
      };
      await ref.set(data, SetOptions(merge: true));
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied' ? 'Permission denied. Check Firestore rules.' : (e.message ?? e.code);
    } catch (e) {
      return '$e';
    }
  }

  static Future<String?> saveOrder() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (int i = 0; i < store.banners.length; i++) {
        final id = _ids[store.banners[i]];
        if (id != null) batch.set(_col.doc(id), {'order': i}, SetOptions(merge: true));
      }
      await batch.commit();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  static Future<String?> delete(PromoBanner b) async {
    try {
      final id = _ids.remove(b);
      if (id != null) await _col.doc(id).delete();
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return '$e';
    }
  }
}

// -----------------------------------------------------------------------------
// Main screen: Coupons & Offers
// -----------------------------------------------------------------------------

/// Coupons & Offers: coupons and promotional home banners.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final compactTextTheme = baseTheme.textTheme.apply(fontSizeDelta: -2);
    return Theme(
      data: baseTheme.copyWith(textTheme: compactTextTheme),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: false,
            leadingWidth: 48, // brings the title closer to the back arrow
            titleSpacing: 4, // small gap between back arrow and title
            title: const Text(
              'Coupons & Offers',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.muted.withValues(alpha: .15)))),
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  labelPadding: EdgeInsets.symmetric(horizontal: 44), // clear gap between the two tabs
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AC.primary,
                  unselectedLabelColor: AC.muted,
                  indicatorColor: AC.primary,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1),
                  tabs: [
                    Tab(height: 44, icon: Icon(Icons.sell_outlined, size: 16), text: 'Coupons'),
                    Tab(height: 44, icon: Icon(Icons.image_outlined, size: 16), text: 'Home banners'),
                  ],
                ),
              ),
            ),
          ),
          body: const TabBarView(
            children: [_CouponsTab(), BannersScreen(embedded: true)],
          ),
        ),
      ),
    );
  }
}

class _CouponsTab extends StatefulWidget {
  const _CouponsTab();

  @override
  State<_CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends State<_CouponsTab> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';
  String _sort = 'Newest first';

  static const _sorts = ['Newest first', 'Expiring soon', 'Highest discount', 'Code A-Z'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isActive(Coupon c) => c.active && !c.expired;

  int _score(Coupon c) => c.flat > 0 ? c.flat : (c.percent > 0 ? (c.maxOff > 0 ? c.maxOff : c.percent * 100) : 0);

  Future<void> _toggle(Coupon c, bool v) async {
    c.active = v;
    store.changed();
    final err = await _CouponSync.save(c);
    if (err != null && mounted) {
      c.active = !v;
      store.changed();
      snack(context, 'Could not update ${c.code}: $err');
    }
  }

  Future<void> _delete(Coupon c) async {
    final ok = await confirmDialog(context, 'Delete ${c.code}?', 'Customers will no longer be able to use this code.', yes: 'Delete', danger: true);
    if (!ok) return;
    store.coupons.remove(c);
    store.changed();
    final err = await _CouponSync.delete(c.code);
    if (!mounted) return;
    snack(context, err == null ? '${c.code} deleted' : 'Removed here, but server delete failed: $err');
  }

  Future<void> _duplicate(Coupon c) async {
    var code = '${c.code}-COPY';
    var i = 2;
    while (store.coupons.any((x) => x.code == code)) {
      code = '${c.code}-COPY$i';
      i++;
    }
    final copy = Coupon(
      code: code,
      title: c.title,
      note: c.note,
      flat: c.flat,
      percent: c.percent,
      maxOff: c.maxOff,
      minOrder: c.minOrder,
      freeDelivery: c.freeDelivery,
      firstOrderOnly: c.firstOrderOnly,
      active: false, // a copy starts switched off so it never goes live by accident
      expiry: c.expiry,
    );
    store.coupons.insert(0, copy);
    store.changed();
    final err = await _CouponSync.save(copy);
    if (!mounted) return;
    snack(context, err == null ? 'Duplicated as $code (switched off)' : 'Duplicated here, but sync failed: $err');
  }

  void _openForm([Coupon? c]) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CouponFormScreen(coupon: c)),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final all = store.coupons;

        final activeCount = all.where(_isActive).length;
        final inactiveCount = all.where((c) => !c.active && !c.expired).length;
        final expiredCount = all.where((c) => c.expired).length;
        final soonCount = all.where(_endingSoon).length;

        final list = all.where((c) {
          final matchesSearch = query.isEmpty || c.code.toLowerCase().contains(query) || c.title.toLowerCase().contains(query);
          final matchesFilter = _filter == 'All' ||
              (_filter == 'Active' && _isActive(c)) ||
              (_filter == 'Inactive' && !c.active && !c.expired) ||
              (_filter == 'Expired' && c.expired);
          return matchesSearch && matchesFilter;
        }).toList();

        switch (_sort) {
          case 'Expiring soon':
            list.sort((a, b) {
              if (a.expired != b.expired) return a.expired ? 1 : -1; // expired go last
              return a.expiry.compareTo(b.expiry);
            });
          case 'Highest discount':
            list.sort((a, b) => _score(b).compareTo(_score(a)));
          case 'Code A-Z':
            list.sort((a, b) => a.code.compareTo(b.code));
          default:
            break;
        }

        final counts = {'All': all.length, 'Active': activeCount, 'Inactive': inactiveCount, 'Expired': expiredCount};

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            backgroundColor: AC.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add coupon', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
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
                      hintText: 'Search by coupon code or title',
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

              // ---- stats ----
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    _stat(Icons.sell_rounded, AC.primary, '${all.length}', 'Total'),
                    const SizedBox(width: 8),
                    _stat(Icons.check_circle_rounded, AC.success, '$activeCount', 'Live'),
                    const SizedBox(width: 8),
                    _stat(Icons.schedule_rounded, AC.warning, '$soonCount', 'Ending soon'),
                    const SizedBox(width: 8),
                    _stat(Icons.event_busy_rounded, AC.muted, '$expiredCount', 'Expired'),
                  ],
                ),
              ),

              // ---- filter chips ----
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final f in ['All', 'Active', 'Inactive', 'Expired'])
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
                    const Text('Your coupons', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
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
                  icon: all.isEmpty ? Icons.sell_outlined : Icons.search_off_rounded,
                  title: all.isEmpty ? 'No coupons yet' : 'No matching coupons',
                  subtitle: all.isEmpty ? 'Create a discount coupon to boost sales' : 'Try another search or status filter',
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return _CouponCard(
                      coupon: c,
                      onTap: () => _openForm(c),
                      onEdit: () => _openForm(c),
                      onDuplicate: () => _duplicate(c),
                      onDelete: () => _delete(c),
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: c.code));
                        snack(context, '${c.code} copied');
                      },
                      onToggle: (v) => _toggle(c, v),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
// Ticket style coupon card
// -----------------------------------------------------------------------------

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final bool preview; // true = used in the form as a live preview (no actions)
  final VoidCallback? onTap, onEdit, onDuplicate, onDelete, onCopy;
  final ValueChanged<bool>? onToggle;

  const _CouponCard({
    required this.coupon,
    this.preview = false,
    this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.onCopy,
    this.onToggle,
  });

  static const double _leftW = 86;

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    final expired = c.expired;
    final live = c.active && !expired;
    final soon = _endingSoon(c);
    final head = _headline(c);
    final chips = _ruleChips(c);

    final Gradient leftGradient = expired
        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA3A9B8), Color(0xFF7B8194)])
        : (c.active
        ? adminGradient
        : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB9BECB), Color(0xFF9096A8)]));

    final statusText = expired ? 'Expired' : (c.active ? 'Active' : 'Inactive');
    final statusColor0 = expired ? AC.muted : (c.active ? AC.success : AC.warning);
    final expiryColor = expired ? AC.danger : (soon ? AC.warning : AC.muted);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(radius: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: preview ? null : onTap,
            child: Stack(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------- left: the discount ----------
                      Container(
                        width: _leftW,
                        decoration: BoxDecoration(gradient: leftGradient),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        child: Stack(
                          children: [
                            Positioned(right: -26, top: -26, child: _bubble(70, .08)),
                            Positioned(left: -22, bottom: -28, child: _bubble(64, .07)),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(c.freeDelivery && c.flat == 0 && c.percent == 0 ? Icons.local_shipping_rounded : Icons.local_offer_rounded, color: Colors.white70, size: 15),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(head.big, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -.3, height: 1.05)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(head.small, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: _fTiny, letterSpacing: .4, height: 1.2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ---------- dashed tear line ----------
                      SizedBox(width: 1, child: CustomPaint(painter: _DashedLinePainter(AC.muted.withValues(alpha: .35)))),
                      // ---------- right: the details ----------
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: GestureDetector(
                                        onTap: preview ? null : onCopy,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AC.primary.withValues(alpha: .07),
                                            borderRadius: BorderRadius.circular(7),
                                            border: Border.all(color: AC.primary.withValues(alpha: .35)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  c.code,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900, fontSize: _fBody, letterSpacing: .6),
                                                ),
                                              ),
                                              if (!preview) ...[
                                                const SizedBox(width: 5),
                                                const Icon(Icons.copy_rounded, size: 11, color: AC.primary),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor0.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 5, height: 5, decoration: BoxDecoration(color: statusColor0, shape: BoxShape.circle)),
                                        const SizedBox(width: 4),
                                        Text(statusText, style: TextStyle(color: statusColor0, fontSize: _fSmall, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                  if (!preview)
                                    PopupMenuButton<String>(
                                      tooltip: 'More',
                                      padding: EdgeInsets.zero,
                                      iconSize: 18,
                                      icon: const Icon(Icons.more_vert_rounded, color: AC.muted),
                                      constraints: const BoxConstraints(minWidth: 130),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      onSelected: (v) {
                                        if (v == 'edit') onEdit?.call();
                                        if (v == 'copy') onCopy?.call();
                                        if (v == 'dup') onDuplicate?.call();
                                        if (v == 'del') onDelete?.call();
                                      },
                                      itemBuilder: (_) => [
                                        _menu('edit', Icons.edit_outlined, 'Edit'),
                                        _menu('copy', Icons.copy_rounded, 'Copy code'),
                                        _menu('dup', Icons.content_copy_rounded, 'Duplicate'),
                                        _menu('del', Icons.delete_outline_rounded, 'Delete', color: AC.danger),
                                      ],
                                    )
                                  else
                                    const SizedBox(width: 8),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                c.title.isEmpty ? 'Coupon title' : c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle, color: c.title.isEmpty ? AC.muted : AC.text),
                              ),
                              if (chips.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: [for (final ch in chips) _ruleChip(ch.$1, ch.$2)],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Divider(height: 1, color: AC.muted.withValues(alpha: .14)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(expired ? Icons.event_busy_outlined : (soon ? Icons.schedule_rounded : Icons.event_outlined), size: 13, color: expiryColor),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      _expiryText(c),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: expiryColor, fontSize: _fSmall, fontWeight: soon || expired ? FontWeight.w800 : FontWeight.w500),
                                    ),
                                  ),
                                  if (!preview) ...[
                                    Text(live ? 'Enabled' : 'Disabled', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                                    Transform.scale(
                                      scale: .72,
                                      child: Switch(
                                        value: c.active,
                                        activeColor: AC.success,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: onToggle,
                                      ),
                                    ),
                                  ] else
                                    const SizedBox(height: 28),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ticket notches on the tear line
                Positioned(left: _leftW - 5, top: -6, child: _notch()),
                Positioned(left: _leftW - 5, bottom: -6, child: _notch()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notch() => Container(width: 11, height: 11, decoration: const BoxDecoration(color: AC.bg, shape: BoxShape.circle));

  Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );

  Widget _ruleChip(IconData icon, String text) => Container(
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

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    double y = 8;
    while (y < size.height - 8) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + 4), paint);
      y += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

// -----------------------------------------------------------------------------
// Add / edit coupon form
// -----------------------------------------------------------------------------

/// Add / edit coupon. Pass [coupon] to edit.
class CouponFormScreen extends StatefulWidget {
  final Coupon? coupon;
  const CouponFormScreen({super.key, this.coupon});

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.coupon?.code ?? '');
  late final _title = TextEditingController(text: widget.coupon?.title ?? '');
  late final _flat = TextEditingController(text: (widget.coupon?.flat ?? 0) == 0 ? '' : widget.coupon!.flat.toString());
  late final _percent = TextEditingController(text: (widget.coupon?.percent ?? 0) == 0 ? '' : widget.coupon!.percent.toString());
  late final _maxOff = TextEditingController(text: (widget.coupon?.maxOff ?? 0) == 0 ? '' : widget.coupon!.maxOff.toString());
  late final _minOrder = TextEditingController(text: (widget.coupon?.minOrder ?? 0) == 0 ? '' : widget.coupon!.minOrder.toString());
  late bool freeDelivery = widget.coupon?.freeDelivery ?? false;
  late bool firstOrder = widget.coupon?.firstOrderOnly ?? false;
  late bool active = widget.coupon?.active ?? true;
  late DateTime expiry = widget.coupon?.expiry ?? DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  bool get editing => widget.coupon != null;

  @override
  void dispose() {
    for (final c in [_code, _title, _flat, _percent, _maxOff, _minOrder]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  String? _optNum(String? v, {int max = 100000000}) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a valid number';
    if (n > max) return 'Too large';
    return null;
  }

  void _generateCode() {
    const words = ['SAVE', 'DEAL', 'MEGA', 'FEST', 'WOW', 'HUB'];
    final r = Random();
    final base = words[r.nextInt(words.length)];
    final amount = _n(_percent) > 0 ? _n(_percent) : (_n(_flat) > 0 ? _n(_flat) : (10 + r.nextInt(90)));
    var code = '$base$amount';
    var i = 1;
    while (store.coupons.any((c) => c != widget.coupon && c.code == code)) {
      code = '$base$amount${i++}';
    }
    setState(() => _code.text = code);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: expiry,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => expiry = d);
  }

  void _setExpiryIn(int days) {
    final n = DateTime.now().add(Duration(days: days));
    setState(() => expiry = DateTime(n.year, n.month, n.day, 23, 59));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    final code = _code.text.trim().toUpperCase();
    if (_n(_flat) == 0 && _n(_percent) == 0 && !freeDelivery) {
      snack(context, 'Set a flat amount, a percentage or free delivery');
      return;
    }
    if (store.coupons.any((c) => c != widget.coupon && c.code == code)) {
      snack(context, 'Coupon code $code already exists');
      return;
    }
    final note = [
      if (_n(_minOrder) > 0) 'On orders of ${inr(_n(_minOrder))} or more',
      if (firstOrder) 'first order only',
    ].join(', ');

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final Coupon saved;
    String? oldCode;
    if (editing) {
      oldCode = widget.coupon!.code;
      saved = widget.coupon!
        ..code = code
        ..title = _title.text.trim()
        ..note = note
        ..flat = _n(_flat)
        ..percent = _n(_percent)
        ..maxOff = _n(_maxOff)
        ..minOrder = _n(_minOrder)
        ..freeDelivery = freeDelivery
        ..firstOrderOnly = firstOrder
        ..active = active
        ..expiry = expiry;
    } else {
      saved = Coupon(
        code: code,
        title: _title.text.trim(),
        note: note,
        flat: _n(_flat),
        percent: _n(_percent),
        maxOff: _n(_maxOff),
        minOrder: _n(_minOrder),
        freeDelivery: freeDelivery,
        firstOrderOnly: firstOrder,
        active: active,
        expiry: expiry,
      );
      store.coupons.insert(0, saved);
    }
    store.changed();

    final err = await _CouponSync.save(saved, oldCode: oldCode);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(err == null ? (editing ? 'Coupon updated' : 'Coupon $code created') : 'Saved here, but could not sync: $err'),
      ));
    if (mounted) navigator.pop();
  }

  Coupon _previewCoupon() => Coupon(
    code: _code.text.trim().isEmpty ? 'YOURCODE' : _code.text.trim().toUpperCase(),
    title: _title.text.trim(),
    flat: _n(_flat),
    percent: _n(_percent),
    maxOff: _n(_maxOff),
    minOrder: _n(_minOrder),
    freeDelivery: freeDelivery,
    firstOrderOnly: firstOrder,
    active: active,
    expiry: expiry,
  );

  Widget _label(String t, {IconData? icon}) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: AC.primary), const SizedBox(width: 6)],
        Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
      ],
    ),
  );

  Widget _input(
      String label,
      TextEditingController c, {
        TextInputType? type,
        String? prefix,
        Widget? suffix,
        String? hint,
        List<TextInputFormatter>? formatters,
        TextCapitalization caps = TextCapitalization.none,
        String? Function(String?)? validator,
        bool required = false,
      }) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      textCapitalization: caps,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixIcon: suffix,
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

  Widget _switchTile(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
    decoration: cardDeco(radius: 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AC.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1)),
              Text(sub, style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
            ],
          ),
        ),
        Transform.scale(scale: .85, child: Switch(value: value, activeColor: AC.success, onChanged: onChanged)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final days = _dayDiff(expiry);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leadingWidth: 48,
        titleSpacing: 4,
        title: Text(editing ? 'Edit coupon' : 'Add coupon', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete coupon',
              icon: const Icon(Icons.delete_outline_rounded, color: AC.danger, size: 22),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final ok = await confirmDialog(context, 'Delete ${widget.coupon!.code}?', 'Customers will no longer be able to use this code.', yes: 'Delete', danger: true);
                if (ok) {
                  final code = widget.coupon!.code;
                  store.coupons.remove(widget.coupon);
                  store.changed();
                  await _CouponSync.delete(code);
                  if (mounted) navigator.pop();
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
          children: [
            // ---- live preview ----
            _label('Live preview', icon: Icons.visibility_outlined),
            _CouponCard(coupon: _previewCoupon(), preview: true),

            // ---- basics ----
            _label('Coupon details', icon: Icons.sell_outlined),
            _input(
              'Coupon code',
              _code,
              hint: 'e.g. DIWALI500',
              caps: TextCapitalization.characters,
              required: true,
              formatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_-]')),
                LengthLimitingTextInputFormatter(20),
              ],
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Required';
                if (t.length < 3) return 'At least 3 characters';
                return null;
              },
              suffix: TextButton(
                onPressed: _generateCode,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Generate', style: TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w800, color: AC.primary)),
              ),
            ),
            const SizedBox(height: 12),
            _input('Title shown to customers', _title, hint: 'e.g. Diwali Dhamaka', required: true, formatters: [LengthLimitingTextInputFormatter(40)]),

            // ---- discount ----
            _label('Discount', icon: Icons.percent_rounded),
            Row(
              children: [
                Expanded(child: _input('Flat discount', _flat, type: TextInputType.number, prefix: '₹ ', formatters: digits, validator: (v) => _optNum(v))),
                const SizedBox(width: 10),
                Expanded(child: _input('Percent off', _percent, type: TextInputType.number, formatters: digits, validator: (v) => _optNum(v, max: 100))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _input('Max discount', _maxOff, type: TextInputType.number, prefix: '₹ ', formatters: digits, validator: (v) => _optNum(v))),
                const SizedBox(width: 10),
                Expanded(child: _input('Minimum order', _minOrder, type: TextInputType.number, prefix: '₹ ', formatters: digits, validator: (v) => _optNum(v))),
              ],
            ),

            // ---- conditions ----
            _label('Conditions', icon: Icons.tune_rounded),
            _switchTile(Icons.local_shipping_outlined, 'Free delivery', 'No delivery charge with this coupon', freeDelivery, (v) => setState(() => freeDelivery = v)),
            _switchTile(Icons.person_add_alt_1_outlined, 'First order only', 'Only for a customer\'s first order', firstOrder, (v) => setState(() => firstOrder = v)),
            _switchTile(Icons.power_settings_new_rounded, 'Active', active ? 'Customers can use it now' : 'Hidden from customers', active, (v) => setState(() => active = v)),

            // ---- expiry ----
            _label('Expiry', icon: Icons.event_rounded),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDeco(radius: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded, size: 18, color: AC.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmtDate(expiry), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1.5, color: AC.primary)),
                              Text(
                                days < 0 ? 'Already expired' : (days == 0 ? 'Ends today' : 'Valid for $days more ${days == 1 ? 'day' : 'days'}'),
                                style: TextStyle(fontSize: _fSmall, color: days < 0 ? AC.danger : AC.muted),
                              ),
                            ],
                          ),
                        ),
                        const Text('Change', style: TextStyle(color: AC.primary, fontSize: _fSmall, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in const [(7, '7 days'), (15, '15 days'), (30, '30 days'), (90, '3 months'), (365, '1 year')])
                        InkWell(
                          onTap: () => _setExpiryIn(d.$1),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AC.primary.withValues(alpha: .07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AC.primary.withValues(alpha: .25)),
                            ),
                            child: Text('+ ${d.$2}', style: const TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w700, color: AC.primary)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), textStyle: const TextStyle(fontSize: _fBody + 2, fontWeight: FontWeight.w800)),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editing ? 'Save changes' : 'Create coupon'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Home banners
// -----------------------------------------------------------------------------

/// Home banners shown on the customer home screen.
class BannersScreen extends StatefulWidget {
  final bool embedded;
  const BannersScreen({super.key, this.embedded = false});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  static const _palette = <Color>[
    AC.primary,
    Color(0xFF2563EB),
    Color(0xFF0F766E),
    Color(0xFF16A34A),
    AC.accent,
    Color(0xFFDC2626),
    Color(0xFFBE185D),
    Color(0xFF7C3AED),
  ];

  @override
  void initState() {
    super.initState();
    _BannerSync.load();
  }

  Future<void> _edit({PromoBanner? banner}) async {
    // The editor is its own widget: it creates AND disposes its text controllers,
    // so they are never disposed while the closing sheet is still using them.
    final result = await showModalBottomSheet<({String title, String sub, Color color})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BannerEditor(banner: banner, palette: _palette),
    );
    if (result == null || !mounted) return;

    PromoBanner b;
    if (banner == null) {
      b = PromoBanner(result.title, result.sub, result.color);
      store.banners.add(b);
    } else {
      b = banner
        ..title = result.title
        ..subtitle = result.sub
        ..color = result.color;
    }
    store.changed();
    final err = await _BannerSync.save(b);
    if (err != null && mounted) snack(context, 'Saved here, but could not sync: $err');
  }

  Future<void> _toggle(PromoBanner b, bool v) async {
    b.active = v;
    store.changed();
    final err = await _BannerSync.save(b);
    if (err != null && mounted) {
      b.active = !v;
      store.changed();
      snack(context, 'Could not update banner: $err');
    }
  }

  Future<void> _move(PromoBanner b, int dir) async {
    final i = store.banners.indexOf(b);
    final j = i + dir;
    if (i < 0 || j < 0 || j >= store.banners.length) return;
    store.banners
      ..removeAt(i)
      ..insert(j, b);
    store.changed();
    await _BannerSync.saveOrder();
  }

  Future<void> _delete(PromoBanner b) async {
    final ok = await confirmDialog(context, 'Delete banner?', 'It will be removed from the customer home screen.', yes: 'Delete', danger: true);
    if (!ok) return;
    store.banners.remove(b);
    store.changed();
    final err = await _BannerSync.delete(b);
    if (err != null && mounted) snack(context, 'Removed here, but server delete failed: $err');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final banners = store.banners;
        final liveCount = banners.where((b) => b.active).length;

        final body = ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
          children: [
            if (banners.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 2),
                child: Row(
                  children: [
                    const Text('Home banners', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                    const SizedBox(width: 6),
                    Text('$liveCount of ${banners.length} showing', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                  ],
                ),
              ),
            if (banners.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyState(icon: Icons.image_outlined, title: 'No banners', subtitle: 'Add one to show on the customer home screen'),
              ),
            for (int i = 0; i < banners.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(8),
                decoration: cardDeco(radius: 20),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _edit(banner: banners[i]),
                      borderRadius: BorderRadius.circular(16),
                      child: _bannerPreview(banners[i].title, banners[i].subtitle, banners[i].color, dim: !banners[i].active),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 6),
                        Icon(banners[i].active ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 14, color: banners[i].active ? AC.success : AC.muted),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            banners[i].active ? 'Showing on home' : 'Hidden',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: banners[i].active ? AC.success : AC.muted, fontWeight: FontWeight.w700, fontSize: _fSmall),
                          ),
                        ),
                        _iconBtn(Icons.arrow_upward_rounded, i == 0 ? null : () => _move(banners[i], -1), 'Move up'),
                        _iconBtn(Icons.arrow_downward_rounded, i == banners.length - 1 ? null : () => _move(banners[i], 1), 'Move down'),
                        _iconBtn(Icons.edit_outlined, () => _edit(banner: banners[i]), 'Edit'),
                        SizedBox(
                          width: 42,
                          height: 30,
                          child: FittedBox(
                            child: Switch(value: banners[i].active, activeColor: AC.success, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (v) => _toggle(banners[i], v)),
                          ),
                        ),
                        _iconBtn(Icons.delete_outline_rounded, () => _delete(banners[i]), 'Delete', color: AC.danger),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );

        final fab = FloatingActionButton.extended(
          onPressed: () => _edit(),
          backgroundColor: AC.primary,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add banner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.embedded
              ? null
              : AppBar(
            centerTitle: false,
            leadingWidth: 48,
            titleSpacing: 4,
            title: const Text('Home banners', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
          ),
          floatingActionButton: fab,
          body: body,
        );
      },
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, String tip, {Color? color}) => IconButton(
    tooltip: tip,
    onPressed: onTap,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
    padding: EdgeInsets.zero,
    icon: Icon(icon, size: 18, color: onTap == null ? AC.muted.withValues(alpha: .4) : (color ?? AC.muted)),
  );
}

// -----------------------------------------------------------------------------
// Banner preview + editor sheet
// -----------------------------------------------------------------------------

Widget _circle(double s, double a) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));

Widget _bannerPreview(String title, String sub, Color color, {bool dim = false}) => Opacity(
  opacity: dim ? .45 : 1,
  child: Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, .28)!]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Stack(
      children: [
        Positioned(top: -30, right: -20, child: _circle(110, .09)),
        Positioned(bottom: -40, right: 60, child: _circle(90, .07)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(6)),
                child: const Text('OFFER', style: TextStyle(color: Colors.white, fontSize: _fTiny, fontWeight: FontWeight.w800, letterSpacing: .8)),
              ),
              const SizedBox(height: 8),
              Text(title.isEmpty ? 'Banner heading' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 3),
              Text(sub.isEmpty ? 'Sub text appears here' : sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: _fBody)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Text('Shop Now', style: TextStyle(color: color, fontSize: _fSmall, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

class _BannerEditor extends StatefulWidget {
  final PromoBanner? banner;
  final List<Color> palette;
  const _BannerEditor({required this.banner, required this.palette});

  @override
  State<_BannerEditor> createState() => _BannerEditorState();
}

class _BannerEditorState extends State<_BannerEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.banner?.title ?? '');
  late final TextEditingController _sub = TextEditingController(text: widget.banner?.subtitle ?? '');
  late Color _color = widget.banner?.color ?? AC.primary;

  @override
  void dispose() {
    _title.dispose();
    _sub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.banner == null ? 'Add banner' : 'Edit banner', style: const TextStyle(fontSize: _fHeader - 2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _bannerPreview(_title.text.trim(), _sub.text.trim(), _color),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: _fBody + 1),
            decoration: const InputDecoration(labelText: 'Heading', isDense: true, labelStyle: TextStyle(fontSize: _fBody)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sub,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: _fBody + 1),
            decoration: const InputDecoration(labelText: 'Sub text', isDense: true, labelStyle: TextStyle(fontSize: _fBody)),
          ),
          const SizedBox(height: 12),
          const Text('Banner colour', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final c in widget.palette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: c == _color ? AC.text : Colors.transparent, width: 2.5)),
                    child: c == _color ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), textStyle: const TextStyle(fontSize: _fBody + 2, fontWeight: FontWeight.w800)),
            onPressed: () {
              final t = _title.text.trim();
              if (t.isEmpty) {
                snack(context, 'Enter a heading for the banner');
                return;
              }
              Navigator.pop(context, (title: t, sub: _sub.text.trim(), color: _color));
            },
            child: const Text('Save banner'),
          ),
        ],
      ),
    );
  }
}