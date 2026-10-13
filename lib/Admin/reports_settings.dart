import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

// ============================================================================
// REPORTS
// ============================================================================

/// Reports: Sales | Products | Customers. Export copies a CSV to the clipboard.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  String _csv() {
    final b = StringBuffer('Order ID,Date,Customer,Items,Total,Payment,Status\n');
    for (final o in store.orders) {
      b.writeln('${o.id},${fmtDate(o.placedAt)},"${store.customerName(o.customerId)}",${o.itemCount},${o.total},${o.paymentMethod},${o.statusLabel}');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share_rounded),
              onSelected: (v) {
                Clipboard.setData(ClipboardData(text: _csv()));
                snack(context, '$v report copied as CSV. Paste it in Excel or Sheets.');
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'Excel', child: Text('Export to Excel')), PopupMenuItem(value: 'PDF', child: Text('Export to PDF'))],
            ),
          ],
          bottom: const TabBar(
            labelColor: AC.primary,
            indicatorColor: AC.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: [Tab(text: 'Sales'), Tab(text: 'Products'), Tab(text: 'Customers')],
          ),
        ),
        body: ListenableBuilder(listenable: store, builder: (context, _) => TabBarView(children: [_SalesReport(), _ProductReport(), _CustomerReport()])),
      ),
    );
  }
}

Widget _stat(String label, String value, Color color) => Expanded(
  child: Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(radius: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AC.muted, fontSize: 12)),
      ],
    ),
  ),
);

class _SalesReport extends StatelessWidget {
  const _SalesReport();

  @override
  Widget build(BuildContext context) {
    final valid = store.validOrders;
    final avg = valid.isEmpty ? 0 : store.totalRevenue ~/ valid.length;
    final cancelRate = store.orders.isEmpty ? 0 : (store.orders.where((o) => o.cancelled).length * 100 / store.orders.length).round();
    final byMethod = <String, int>{};
    for (final o in valid) {
      byMethod[o.paymentMethod] = (byMethod[o.paymentMethod] ?? 0) + o.total;
    }
    final total = byMethod.values.fold<int>(0, (a, b) => a + b);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(children: [_stat('Total revenue', inr(store.totalRevenue), AC.primary), const SizedBox(width: 10), _stat('Avg. order value', inr(avg), AC.accent)]),
        const SizedBox(height: 10),
        Row(children: [_stat('Delivered', '${store.orders.where((o) => o.isDelivered).length}', AC.success), const SizedBox(width: 10), _stat('Cancel rate', '$cancelRate%', AC.danger)]),
        const SectionTitle('Last 7 days'),
        Container(padding: const EdgeInsets.fromLTRB(14, 18, 14, 12), decoration: cardDeco(), child: MiniBarChart(labels: store.dayLabels(7), values: store.revenueByDay(7))),
        const SectionTitle('Revenue by payment method'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(),
          child: Column(
            children: [
              for (final e in (byMethod.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 118, child: Text(e.key, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: total == 0 ? 0 : e.value / total, minHeight: 9, backgroundColor: AC.bg, color: AC.primary))),
                      const SizedBox(width: 10),
                      Text(inr(e.value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductReport extends StatelessWidget {
  const _ProductReport();

  @override
  Widget build(BuildContext context) {
    final rev = <String, int>{};
    final units = <String, int>{};
    for (final o in store.validOrders) {
      for (final it in o.items) {
        rev[it.name] = (rev[it.name] ?? 0) + it.price * it.qty;
        units[it.name] = (units[it.name] ?? 0) + it.qty;
      }
    }
    final rows = rev.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final low = store.phones.where((p) => p.stock <= 3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(children: [_stat('Phones listed', '${store.phones.length}', AC.primary), const SizedBox(width: 10), _stat('Units sold', '${units.values.fold<int>(0, (a, b) => a + b)}', AC.success)]),
        const SectionTitle('Best sellers by revenue'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(),
          child: rows.isEmpty
              ? const Text('No sales yet', style: TextStyle(color: AC.muted))
              : Column(
            children: [
              for (int i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: i == 0 ? AC.accent : AC.bg, child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : AC.text))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(rows[i].key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(inr(rows[i].value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), Text('${units[rows[i].key]} sold', style: const TextStyle(color: AC.muted, fontSize: 11))]),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SectionTitle('Needs restocking'),
        if (low.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: cardDeco(), child: const Text('All phones are well stocked', style: TextStyle(color: AC.muted))),
        for (final p in low)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: cardDeco(radius: 14),
            child: Row(children: [Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))), StatusChip(p.stock == 0 ? 'Out of stock' : '${p.stock} left', color: p.stock == 0 ? AC.danger : AC.warning)]),
          ),
      ],
    );
  }
}

class _CustomerReport extends StatelessWidget {
  const _CustomerReport();

  @override
  Widget build(BuildContext context) {
    final withOrders = store.customers.where((c) => store.ordersOf(c.id).any((o) => !o.cancelled)).toList();
    final repeat = store.customers.where((c) => store.ordersOf(c.id).where((o) => !o.cancelled).length > 1).length;
    final spend = <String, int>{for (final c in store.customers) c.name: store.ordersOf(c.id).where((o) => !o.cancelled).fold<int>(0, (s, o) => s + o.total)};
    final top = spend.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    // customers joined per month, last 6 months
    final now = DateTime.now();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final labels = <String>[];
    final vals = <double>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      labels.add(m[d.month - 1]);
      vals.add(store.customers.where((c) => c.joined.year == d.year && c.joined.month == d.month).length.toDouble());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(children: [_stat('Customers', '${store.customers.length}', AC.primary), const SizedBox(width: 10), _stat('Have ordered', '${withOrders.length}', AC.success), const SizedBox(width: 10), _stat('Repeat buyers', '$repeat', AC.accent)]),
        const SectionTitle('New customers (last 6 months)'),
        Container(padding: const EdgeInsets.fromLTRB(14, 18, 14, 12), decoration: cardDeco(), child: MiniBarChart(labels: labels, values: vals, height: 110)),
        const SectionTitle('Top customers'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(),
          child: top.isEmpty
              ? const Text('No orders yet', style: TextStyle(color: AC.muted))
              : Column(
            children: [
              for (int i = 0; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: i == 0 ? AC.accent : AC.bg, child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : AC.text))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(top[i].key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                      Text(inr(top[i].value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ADMIN PROFILE
// ============================================================================

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: store.adminName);
  late final _email = TextEditingController(text: store.adminEmail);
  late final _phone = TextEditingController(text: store.adminPhone);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    store.adminName = _name.text.trim();
    store.adminEmail = _email.text.trim();
    store.adminPhone = _phone.text.trim();
    store.changed();
    snack(context, 'Profile updated');
  }

  Future<void> _changePassword() async {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: oldP, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
              const SizedBox(height: 12),
              TextField(controller: newP, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: AC.danger, fontSize: 12.5, fontWeight: FontWeight.w700))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (oldP.text != store.adminPassword) {
                  setS(() => err = 'Current password is wrong');
                } else if (newP.text.length < 6) {
                  setS(() => err = 'New password needs 6+ characters');
                } else {
                  store.adminPassword = newP.text;
                  Navigator.pop(ctx);
                  snack(context, 'Password changed');
                }
              },
              child: const Text('Change', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    oldP.dispose();
    newP.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Center(child: CircleAvatar(radius: 44, backgroundColor: AC.primary, child: Text(store.adminName.isEmpty ? 'A' : store.adminName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)))),
            const SizedBox(height: 8),
            const Center(child: StatusChip('Super Admin', color: AC.primary)),
            const SizedBox(height: 22),
            formField('Full name', _name),
            formField('Email', _email, type: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
            formField('Phone', _phone, type: TextInputType.phone),
            ElevatedButton(onPressed: _save, child: const Text('Save changes')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _changePassword, icon: const Icon(Icons.lock_reset_rounded), label: const Text('Change password')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SETTINGS (+ staff, policies)
// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final _delivery = TextEditingController(text: '${store.deliveryCharge}');
  late final _freeAbove = TextEditingController(text: '${store.freeDeliveryAbove}');
  late final _returnDays = TextEditingController(text: '${store.returnDays}');
  late final _sPhone = TextEditingController(text: store.supportPhone);
  late final _sEmail = TextEditingController(text: store.supportEmail);

  @override
  void dispose() {
    for (final c in [_delivery, _freeAbove, _returnDays, _sPhone, _sEmail]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _num(String? v) => (int.tryParse((v ?? '').trim()) == null) ? 'Enter a number' : null;

  void _save() {
    if (!_form.currentState!.validate()) return;
    store.deliveryCharge = int.parse(_delivery.text.trim());
    store.freeDeliveryAbove = int.parse(_freeAbove.text.trim());
    store.returnDays = int.parse(_returnDays.text.trim());
    store.supportPhone = _sPhone.text.trim();
    store.supportEmail = _sEmail.text.trim();
    store.changed();
    snack(context, 'Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            const SectionTitle('Delivery'),
            Row(
              children: [
                Expanded(child: formField('Delivery charge', _delivery, type: TextInputType.number, prefix: '₹ ', validator: _num)),
                const SizedBox(width: 12),
                Expanded(child: formField('Free above', _freeAbove, type: TextInputType.number, prefix: '₹ ', validator: _num)),
              ],
            ),
            formField('Return window (days)', _returnDays, type: TextInputType.number, validator: _num),
            const SectionTitle('Support contact (shown in customer app)'),
            formField('Support phone', _sPhone, type: TextInputType.phone),
            formField('Support email', _sEmail, type: TextInputType.emailAddress),
            ElevatedButton(onPressed: _save, child: const Text('Save settings')),
            const SectionTitle('More'),
            _link(context, Icons.groups_rounded, 'Staff & roles', 'Manage who can use this admin app', const StaffScreen()),
            _link(context, Icons.policy_rounded, 'Policies', 'Returns, warranty and privacy', const PoliciesScreen()),
            const SizedBox(height: 4),
            ListenableBuilder(
              listenable: store,
              builder: (context, _) => Container(
                decoration: cardDeco(radius: 16),
                child: SwitchListTile(
                  value: store.pushAlerts,
                  activeColor: AC.success,
                  onChanged: (v) {
                    store.pushAlerts = v;
                    store.changed();
                  },
                  title: const Text('Push alerts', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('New orders and low stock', style: TextStyle(fontSize: 12, color: AC.muted)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(BuildContext context, IconData icon, String title, String sub, Widget page) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: cardDeco(radius: 16),
    child: ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: IconBadge(icon, AC.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(color: AC.muted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AC.muted),
    ),
  );
}

const _roles = ['Super Admin', 'Order Manager', 'Inventory Manager', 'Support Agent'];

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _edit(BuildContext context, {Staff? staff}) async {
    final name = TextEditingController(text: staff?.name ?? '');
    final email = TextEditingController(text: staff?.email ?? '');
    String role = staff?.role ?? 'Order Manager';
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
              Text(staff == null ? 'Add staff member' : 'Edit staff member', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setS(() => role = v ?? role),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (name.text.trim().isEmpty || !email.text.contains('@')) return;
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
      if (staff == null) {
        store.staff.add(Staff(name.text.trim(), email.text.trim(), role));
      } else {
        staff
          ..name = name.text.trim()
          ..email = email.text.trim()
          ..role = role;
      }
      store.changed();
    }
  }

  String _access(String role) {
    switch (role) {
      case 'Super Admin':
        return 'Full access';
      case 'Order Manager':
        return 'Orders, delivery, payments';
      case 'Inventory Manager':
        return 'Products, brands, stock';
      default:
        return 'Support tickets, customers';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Staff & roles')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context), backgroundColor: AC.accent, foregroundColor: Colors.white, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add staff', style: TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          children: [
            for (final s in store.staff)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDeco(radius: 16),
                child: ListTile(
                  onTap: () => _edit(context, staff: s),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(backgroundColor: s.active ? AC.primary : AC.muted, child: Text(s.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${s.role} • ${_access(s.role)}\n${s.email}', style: const TextStyle(color: AC.muted, fontSize: 12, height: 1.4)),
                  isThreeLine: true,
                  trailing: s.role == 'Super Admin'
                      ? null
                      : Switch(value: s.active, activeColor: AC.success, onChanged: (v) {
                    s.active = v;
                    store.changed();
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  late final _returns = TextEditingController(text: store.returnsPolicy);
  late final _warranty = TextEditingController(text: store.warrantyPolicy);
  late final _privacy = TextEditingController(text: store.privacyPolicy);

  @override
  void dispose() {
    _returns.dispose();
    _warranty.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Widget _box(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(controller: c, maxLines: 5, decoration: InputDecoration(labelText: label, alignLabelWithHint: true)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policies')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('These texts are shown to customers in the app.', style: TextStyle(color: AC.muted, fontSize: 12.5))),
          _box('Returns policy', _returns),
          _box('Warranty policy', _warranty),
          _box('Privacy policy', _privacy),
          ElevatedButton(
            onPressed: () {
              store.returnsPolicy = _returns.text.trim();
              store.warrantyPolicy = _warranty.text.trim();
              store.privacyPolicy = _privacy.text.trim();
              store.changed();
              snack(context, 'Policies saved');
            },
            child: const Text('Save policies'),
          ),
        ],
      ),
    );
  }
}
