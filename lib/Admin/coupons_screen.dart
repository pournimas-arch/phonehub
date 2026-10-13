import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

/// Coupons & Offers: two tabs - Coupons and Home banners.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coupons & Offers'),
          bottom: const TabBar(
            labelColor: AC.primary,
            indicatorColor: AC.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: 'Coupons'), Tab(text: 'Home banners')],
          ),
        ),
        body: const TabBarView(children: [_CouponsTab(), BannersScreen(embedded: true)]),
      ),
    );
  }
}

class _CouponsTab extends StatelessWidget {
  const _CouponsTab();

  String _rule(Coupon c) {
    final parts = <String>[];
    if (c.flat > 0) parts.add('Flat ${inr(c.flat)} off');
    if (c.percent > 0) parts.add('${c.percent}% off${c.maxOff > 0 ? ' (max ${inr(c.maxOff)})' : ''}');
    if (c.freeDelivery) parts.add('Free delivery');
    if (c.minOrder > 0) parts.add('Min order ${inr(c.minOrder)}');
    if (c.firstOrderOnly) parts.add('First order only');
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CouponFormScreen())),
          backgroundColor: AC.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add coupon', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: store.coupons.isEmpty
            ? const EmptyState(icon: Icons.sell_outlined, title: 'No coupons yet', subtitle: 'Create one to boost sales')
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            for (final c in store.coupons)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: cardDeco(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CouponFormScreen(coupon: c))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: AC.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.accent, style: BorderStyle.solid)),
                              child: Text(c.code, style: const TextStyle(color: AC.accent, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.copy_rounded, size: 18, color: AC.muted),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: c.code));
                                snack(context, '${c.code} copied');
                              },
                            ),
                            const Spacer(),
                            StatusChip(c.expired ? 'Expired' : (c.active ? 'Active' : 'Inactive'), color: c.expired ? AC.muted : null),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 4),
                        Text(_rule(c), style: const TextStyle(color: AC.muted, fontSize: 12.5, height: 1.4)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 15, color: AC.muted),
                            const SizedBox(width: 5),
                            Text('Expires ${fmtDate(c.expiry)}', style: const TextStyle(color: AC.muted, fontSize: 12)),
                            const Spacer(),
                            Switch(
                              value: c.active,
                              activeColor: AC.success,
                              onChanged: (v) {
                                c.active = v;
                                store.changed();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
  late DateTime expiry = widget.coupon?.expiry ?? DateTime.now().add(const Duration(days: 30));

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

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: expiry, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => expiry = d);
  }

  void _save() {
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
    if (editing) {
      widget.coupon!
        ..code = code
        ..title = _title.text.trim()
        ..note = note
        ..flat = _n(_flat)
        ..percent = _n(_percent)
        ..maxOff = _n(_maxOff)
        ..minOrder = _n(_minOrder)
        ..freeDelivery = freeDelivery
        ..firstOrderOnly = firstOrder
        ..expiry = expiry;
    } else {
      store.coupons.insert(0, Coupon(code: code, title: _title.text.trim(), note: note, flat: _n(_flat), percent: _n(_percent), maxOff: _n(_maxOff), minOrder: _n(_minOrder), freeDelivery: freeDelivery, firstOrderOnly: firstOrder, expiry: expiry));
    }
    store.changed();
    snack(context, editing ? 'Coupon updated' : 'Coupon $code created');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit coupon' : 'Add coupon'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AC.danger),
              onPressed: () async {
                final ok = await confirmDialog(context, 'Delete ${widget.coupon!.code}?', 'Customers will no longer be able to use this code.', yes: 'Delete', danger: true);
                if (ok) {
                  store.coupons.remove(widget.coupon);
                  store.changed();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            formField('Coupon code (e.g. DIWALI500)', _code),
            formField('Title shown to customers', _title),
            Row(
              children: [
                Expanded(child: formField('Flat discount', _flat, type: TextInputType.number, prefix: '₹ ', validator: (v) => _optNum(v))),
                const SizedBox(width: 12),
                Expanded(child: formField('Percent off', _percent, type: TextInputType.number, validator: (v) => _optNum(v, max: 100))),
              ],
            ),
            Row(
              children: [
                Expanded(child: formField('Max discount', _maxOff, type: TextInputType.number, prefix: '₹ ', validator: (v) => _optNum(v))),
                const SizedBox(width: 12),
                Expanded(child: formField('Minimum order', _minOrder, type: TextInputType.number, prefix: '₹ ', validator: (v) => _optNum(v))),
              ],
            ),
            Container(decoration: cardDeco(radius: 14), child: SwitchListTile(value: freeDelivery, activeColor: AC.success, onChanged: (v) => setState(() => freeDelivery = v), title: const Text('Free delivery', style: TextStyle(fontWeight: FontWeight.w700)))),
            const SizedBox(height: 10),
            Container(decoration: cardDeco(radius: 14), child: SwitchListTile(value: firstOrder, activeColor: AC.success, onChanged: (v) => setState(() => firstOrder = v), title: const Text('First order only', style: TextStyle(fontWeight: FontWeight.w700)))),
            const SizedBox(height: 10),
            Container(
              decoration: cardDeco(radius: 14),
              child: ListTile(
                onTap: _pickDate,
                leading: const Icon(Icons.event_rounded, color: AC.primary),
                title: const Text('Expiry date', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(fmtDate(expiry), style: const TextStyle(fontWeight: FontWeight.w800, color: AC.primary)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _save, child: Text(editing ? 'Save changes' : 'Create coupon')),
          ],
        ),
      ),
    );
  }
}

/// Home banners shown on the customer home screen.
class BannersScreen extends StatelessWidget {
  final bool embedded;
  const BannersScreen({super.key, this.embedded = false});

  Future<void> _edit(BuildContext context, {PromoBanner? banner}) async {
    final title = TextEditingController(text: banner?.title ?? '');
    final sub = TextEditingController(text: banner?.subtitle ?? '');
    Color color = banner?.color ?? AC.primary;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(banner == null ? 'Add banner' : 'Edit banner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Heading')),
              const SizedBox(height: 12),
              TextField(controller: sub, decoration: const InputDecoration(labelText: 'Sub text')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in [AC.primary, AC.accent, const Color(0xFF0F766E), const Color(0xFFBE185D), const Color(0xFF7C3AED)])
                    GestureDetector(onTap: () => setS(() => color = c), child: Container(width: 34, height: 34, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: c == color ? Colors.black : Colors.transparent, width: 2.5)))),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      if (banner == null) {
        store.banners.add(PromoBanner(title.text.trim(), sub.text.trim(), color));
      } else {
        banner
          ..title = title.text.trim()
          ..subtitle = sub.text.trim()
          ..color = color;
      }
      store.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final body = ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            if (store.banners.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: EmptyState(icon: Icons.image_outlined, title: 'No banners', subtitle: 'Add one to show on the customer home screen')),
            for (final b in store.banners)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _edit(context, banner: b),
                      borderRadius: BorderRadius.circular(20),
                      child: Opacity(
                        opacity: b.active ? 1 : 0.4,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [b.color, b.color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(b.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 6),
                        Text(b.active ? 'Showing on home' : 'Hidden', style: TextStyle(color: b.active ? AC.success : AC.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        const Spacer(),
                        Switch(value: b.active, activeColor: AC.success, onChanged: (v) {
                          b.active = v;
                          store.changed();
                        }),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AC.danger),
                          onPressed: () async {
                            final ok = await confirmDialog(context, 'Delete banner?', 'It will be removed from the customer home screen.', yes: 'Delete', danger: true);
                            if (ok) {
                              store.banners.remove(b);
                              store.changed();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
        final fab = FloatingActionButton.extended(onPressed: () => _edit(context), backgroundColor: AC.accent, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Add banner', style: TextStyle(fontWeight: FontWeight.w800)));
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: embedded ? null : AppBar(title: const Text('Home banners')),
          floatingActionButton: fab,
          body: body,
        );
      },
    );
  }
}
