import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

/// Delivery partners list.
class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Delivery Partners'),
          actions: [IconButton(icon: const Icon(Icons.map_rounded), tooltip: 'Live tracking', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveTrackingScreen())))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerFormScreen())),
          backgroundColor: AC.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add partner', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          children: [
            for (final p in store.partners)
              Builder(builder: (context) {
                final mine = store.orders.where((o) => o.partnerId == p.id).toList();
                final live = mine.where((o) => o.isOngoing).length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: cardDeco(radius: 16),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerDetailScreen(partnerId: p.id))),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(radius: 24, backgroundColor: p.active ? AC.primary : AC.muted, child: Text(p.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${p.vehicle}\n★ ${p.rating} • ${mine.length} orders • $live active', style: const TextStyle(color: AC.muted, fontSize: 12, height: 1.4)),
                    isThreeLine: true,
                    trailing: StatusChip(p.active ? 'Active' : 'Inactive'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Add / edit delivery partner.
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
  bool get editing => widget.partner != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
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
      store.partners.add(Partner(id: 'd${store.partners.length + 1}${DateTime.now().millisecond}', name: _name.text.trim(), phone: _phone.text.trim(), vehicle: _vehicle.text.trim(), rating: 5.0));
    }
    store.changed();
    snack(context, editing ? 'Partner updated' : 'Partner added');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit partner' : 'Add partner')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            formField('Full name', _name),
            formField('Phone number', _phone, type: TextInputType.phone, validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Enter a valid phone number' : null),
            formField('Vehicle (e.g. Bike • MH 12 AB 1234)', _vehicle),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _save, child: Text(editing ? 'Save changes' : 'Add partner')),
          ],
        ),
      ),
    );
  }
}

/// Partner profile with assigned orders.
class PartnerDetailScreen extends StatelessWidget {
  final String partnerId;
  const PartnerDetailScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.partnerById(partnerId);
        if (p == null) return const Scaffold(body: EmptyState(icon: Icons.error_outline, title: 'Partner not found'));
        final mine = store.orders.where((o) => o.partnerId == p.id).toList();
        final delivered = mine.where((o) => o.isDelivered).length;
        final live = mine.where((o) => o.isOngoing).length;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Delivery partner'),
            actions: [IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerFormScreen(partner: p))))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Text(p.name[0], style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900, fontSize: 24))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                              Text(p.phone, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                              Text(p.vehicle, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _hero('★ ${p.rating}', 'Rating'),
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
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: p.phone));
                        snack(context, 'Number copied');
                      },
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveTrackingScreen())), icon: const Icon(Icons.map_rounded, size: 18), label: const Text('Track live'))),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: cardDeco(),
                child: SwitchListTile(
                  value: p.active,
                  activeColor: AC.success,
                  onChanged: (v) {
                    p.active = v;
                    store.changed();
                  },
                  title: const Text('Available for deliveries', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Inactive partners cannot be assigned to orders', style: TextStyle(fontSize: 12, color: AC.muted)),
                ),
              ),
              SectionTitle('Assigned orders (${mine.length})'),
              if (mine.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: cardDeco(), child: const Text('No orders assigned yet', style: TextStyle(color: AC.muted))),
              for (final o in mine) OrderTile(order: o),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
      ],
    ),
  );
}

/// Live tracking: every "Out for Delivery" order moves from the store to the customer.
/// (Simulated with an animation. Replace with real GPS from your backend.)
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final live = store.orders.where((o) => !o.cancelled && o.stage == 3).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Live tracking')),
          body: Column(
            children: [
              Container(
                height: 300,
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                decoration: cardDeco(radius: 24),
                clipBehavior: Clip.antiAlias,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: _MapPainter(live.map((o) => o.id).toList(), live.map((o) => store.partnerById(o.partnerId)?.name ?? '?').toList(), _c.value),
                  ),
                ),
              ),
              Expanded(
                child: live.isEmpty
                    ? const EmptyState(icon: Icons.two_wheeler_rounded, title: 'No deliveries on the road', subtitle: 'Orders marked "Out for Delivery" appear here')
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    for (int i = 0; i < live.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: cardDeco(radius: 16),
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: live[i].id))),
                          leading: const IconBadge(Icons.two_wheeler_rounded, AC.accent),
                          title: Text('#${live[i].id} • ${store.partnerById(live[i].partnerId)?.name ?? 'Unassigned'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: Text('To ${store.customerName(live[i].customerId)} • ETA ${8 + i * 6} mins', style: const TextStyle(color: AC.muted, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right_rounded),
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
  final List<String> ids, names;
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
      canvas.drawLine(Offset(0, size.height * i / 5), Offset(size.width, size.height * i / 5), i == 2 ? road : thin);
      canvas.drawLine(Offset(size.width * i / 5, 0), Offset(size.width * i / 5, size.height), i == 3 ? road : thin);
    }
    final park = Paint()..color = const Color(0xFFCFE8D5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.62, size.height * 0.08, size.width * 0.28, size.height * 0.22), const Radius.circular(14)), park);

    final hub = Offset(size.width * 0.15, size.height * 0.5);
    _pin(canvas, hub, AC.primary, Icons.store_rounded);

    for (int i = 0; i < ids.length; i++) {
      final r = math.Random(ids[i].hashCode);
      final dest = Offset(size.width * (0.5 + r.nextDouble() * 0.42), size.height * (0.12 + r.nextDouble() * 0.76));
      final corner = Offset(dest.dx, hub.dy);
      final prog = (t + i * 0.27) % 1.0;
      // route: hub -> corner -> dest
      final route = Paint()
        ..color = AC.accent.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawPath(Path()..moveTo(hub.dx, hub.dy)..lineTo(corner.dx, corner.dy)..lineTo(dest.dx, dest.dy), route);
      _pin(canvas, dest, AC.success, Icons.home_rounded);
      final l1 = (corner - hub).distance, l2 = (dest - corner).distance;
      final d = prog * (l1 + l2);
      final pos = d <= l1 ? Offset.lerp(hub, corner, l1 == 0 ? 0 : d / l1)! : Offset.lerp(corner, dest, l2 == 0 ? 0 : (d - l1) / l2)!;
      canvas.drawCircle(pos, 15, Paint()..color = AC.accent);
      canvas.drawCircle(pos, 15, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
      final tp = TextPainter(text: TextSpan(text: names[i].split(' ').first, style: const TextStyle(color: AC.text, fontSize: 10.5, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, pos + Offset(-tp.width / 2, 18));
      final ic = TextPainter(text: TextSpan(text: String.fromCharCode(Icons.two_wheeler_rounded.codePoint), style: TextStyle(fontFamily: Icons.two_wheeler_rounded.fontFamily, fontSize: 17, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      ic.paint(canvas, pos - Offset(ic.width / 2, ic.height / 2));
    }
  }

  void _pin(Canvas canvas, Offset p, Color c, IconData icon) {
    canvas.drawCircle(p, 14, Paint()..color = c);
    final ic = TextPainter(text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, fontSize: 16, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
    ic.paint(canvas, p - Offset(ic.width / 2, ic.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
