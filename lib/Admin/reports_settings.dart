import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

// Text sizes (same as the Coupons & Offers screen)
const double _fHeader = 18;
const double _fTitle = 12;
const double _fBody = 10.5;
const double _fSmall = 9.5;

// -----------------------------------------------------------------------------
// Validation helpers (logic only, no UI)
// -----------------------------------------------------------------------------

final RegExp _vEmail = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
final RegExp _vNameChars = RegExp(r"^\p{L}[\p{L}\p{M} .'\-]*$", unicode: true);

String _vClean(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

String? _vName(String? v, {String label = 'name'}) {
  final s = _vClean(v ?? '');
  if (s.isEmpty) return 'Enter your $label';
  if (s.length < 2) return 'The $label is too short';
  if (s.length > 50) return 'The $label can be at most 50 characters';
  if (!_vNameChars.hasMatch(s)) return 'Use letters only (spaces, . \' - allowed)';
  if (RegExp(r'(.)\1{3,}').hasMatch(s)) return 'Enter a real $label';
  return null;
}

String? _vEmailCheck(String? v, {bool required = true}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return required ? 'Enter an email address' : null;
  if (s.length > 254) return 'Email is too long';
  if (RegExp(r'\s').hasMatch(s)) return 'Email cannot contain spaces';
  if (s.contains('..') || s.startsWith('.') || s.split('@').first.endsWith('.')) return 'Enter a valid email address';
  if (s.split('@').first.length > 64) return 'The part before @ is too long';
  if (!_vEmail.hasMatch(s)) return 'Enter a valid email address';
  return null;
}

/// Keeps only the digits and removes +91 / 91 / leading 0, so "+91 98765-43210" becomes "9876543210".
String _vMobileDigits(String v) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return d;
}

/// Indian mobile number (10 digits, starts with 6-9). Empty is allowed unless [required].
String? _vMobile(String? v, {bool required = false, bool allowTollFree = false}) {
  final raw = (v ?? '').trim();
  if (raw.isEmpty) return required ? 'Enter a mobile number' : null;
  if (RegExp(r'[^0-9+\-() ]').hasMatch(raw)) return 'Use digits only';
  final d = _vMobileDigits(raw);
  if (allowTollFree && RegExp(r'^1800\d{6,7}$').hasMatch(raw.replaceAll(RegExp(r'\D'), ''))) return null;
  if (d.length != 10) return 'Enter a 10-digit mobile number';
  if (!RegExp(r'^[6-9]').hasMatch(d)) return 'Mobile number must start with 6, 7, 8 or 9';
  if (RegExp(r'^(\d)\1{9}$').hasMatch(d)) return 'Enter a real mobile number';
  return null;
}

/// Strong-enough password for the admin account.
String? _vStrongPassword(String pass, {String? oldPass, String? email}) {
  if (pass.isEmpty) return 'Enter a new password';
  if (pass.length < 8) return 'New password needs at least 8 characters';
  if (pass.length > 64) return 'New password can be at most 64 characters';
  if (RegExp(r'\s').hasMatch(pass)) return 'Password cannot contain spaces';
  if (!RegExp(r'[A-Za-z]').hasMatch(pass) || !RegExp(r'\d').hasMatch(pass)) {
    return 'Use both letters and numbers';
  }
  if (RegExp(r'^(.)\1+$').hasMatch(pass)) return 'Password is too easy to guess';
  const common = ['password1', 'password123', 'admin123', 'admin1234', 'qwerty123', 'abcd1234', '12345678a', 'welcome123', 'phonehub123'];
  if (common.contains(pass.toLowerCase())) return 'Password is too common. Choose another';
  if (oldPass != null && pass == oldPass) return 'New password must be different from the current one';
  final local = (email ?? '').split('@').first.toLowerCase();
  if (local.length >= 4 && pass.toLowerCase().contains(local)) return 'Password should not contain your email name';
  return null;
}

/// Whole number inside [min, max] (digits only, no sign, no decimals).
String? _vIntRange(String? v, {required String label, required int min, required int max}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Enter $label';
  if (!RegExp(r'^\d+$').hasMatch(s)) return 'Use digits only';
  final n = int.tryParse(s);
  if (n == null) return 'Enter a valid number';
  if (n < min || n > max) return 'Must be between $min and $max';
  return null;
}

// -----------------------------------------------------------------------------
// Small shared helpers
// -----------------------------------------------------------------------------

AppBar _appBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
  centerTitle: false,
  leadingWidth: 48,
  titleSpacing: 4,
  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
  actions: actions,
  bottom: bottom,
);

/// Same compact text theme the Coupons screen uses.
Widget _compact(BuildContext context, Widget child) {
  final base = Theme.of(context);
  return Theme(data: base.copyWith(textTheme: base.textTheme.apply(fontSizeDelta: -2)), child: child);
}

InputDecoration _dec(String label, {String? prefix, String? hint, String? helper, String? error}) => InputDecoration(
  labelText: label,
  hintText: hint,
  helperText: helper,
  errorText: error,
  prefixText: prefix,
  isDense: true,
  labelStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
  hintStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
  helperStyle: const TextStyle(fontSize: _fSmall, color: AC.muted),
  errorStyle: const TextStyle(fontSize: _fSmall),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .22))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .22))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.3)),
);

Widget _field(String label, TextEditingController c, {TextInputType? type, String? prefix, String? helper, String? Function(String?)? validator, int maxLines = 1, bool obscure = false, List<TextInputFormatter>? formatters}) => TextFormField(
  controller: c,
  keyboardType: type,
  obscureText: obscure,
  maxLines: maxLines,
  validator: validator,
  inputFormatters: formatters,
  style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
  decoration: _dec(label, prefix: prefix, helper: helper),
);

Widget _label(String t, {IconData? icon}) => Padding(
  padding: const EdgeInsets.only(top: 10, bottom: 8),
  child: Row(
    children: [
      if (icon != null) ...[Icon(icon, size: 14, color: AC.primary), const SizedBox(width: 6)],
      Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
    ],
  ),
);

Widget _iconBox(IconData icon, Color color) => Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
  child: Icon(icon, size: 18, color: color),
);

Widget _pill(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
  child: Text(text, style: TextStyle(color: color, fontSize: _fSmall, fontWeight: FontWeight.w800)),
);

Widget _bigButton(String text, VoidCallback onTap, {IconData? icon, bool outlined = false}) {
  final style = (outlined ? OutlinedButton.styleFrom : ElevatedButton.styleFrom)(
    minimumSize: const Size.fromHeight(46),
    textStyle: const TextStyle(fontSize: _fBody + 2, fontWeight: FontWeight.w800),
  );
  final i = icon == null ? null : Icon(icon, size: 17);
  if (outlined) {
    return OutlinedButton.icon(onPressed: onTap, style: style, icon: i ?? const SizedBox.shrink(), label: Text(text));
  }
  return ElevatedButton.icon(onPressed: onTap, style: style, icon: i ?? const SizedBox.shrink(), label: Text(text));
}

Widget _stat(IconData icon, Color color, String value, String label) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: cardDeco(radius: 12),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 3, height: 1.05, color: AC.text))),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, maxLines: 1, style: const TextStyle(color: AC.muted, fontSize: _fSmall - 1))),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _statRow(List<Widget> stats) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      for (int i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        stats[i],
      ],
    ],
  ),
);

Widget _box({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 10),
  padding: padding,
  decoration: cardDeco(radius: 16),
  child: child,
);

Widget _rank(int i) => CircleAvatar(
  radius: 11,
  backgroundColor: i == 0 ? AC.accent : AC.bg,
  child: Text('${i + 1}', style: TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : AC.text)),
);

Widget _switchTile(IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) => Container(
  margin: const EdgeInsets.only(bottom: 10),
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

/// Tappable card (same look as _switchTile) that opens another screen.
Widget _linkTile(IconData icon, String title, String sub, VoidCallback onTap) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  decoration: cardDeco(radius: 12),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
              const Icon(Icons.chevron_right_rounded, color: AC.muted),
            ],
          ),
        ),
      ),
    ),
  ),
);

// =============================================================================
// REPORTS
// =============================================================================

/// Reports: Sales | Products | Customers. The share button copies a CSV of all orders.
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
    return _compact(
      context,
      DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: _appBar(
            'Reports',
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 21),
                tooltip: 'Copy orders as CSV',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _csv()));
                  snack(context, 'Orders copied as CSV. Paste it in Excel or Sheets.');
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.muted.withValues(alpha: .15)))),
                child: const TabBar(
                  labelPadding: EdgeInsets.zero, // 3 equal tabs
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AC.primary,
                  unselectedLabelColor: AC.muted,
                  indicatorColor: AC.primary,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1),
                  tabs: [
                    Tab(height: 44, icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Sales'),
                    Tab(height: 44, icon: Icon(Icons.smartphone_rounded, size: 16), text: 'Products'),
                    Tab(height: 44, icon: Icon(Icons.people_alt_outlined, size: 16), text: 'Customers'),
                  ],
                ),
              ),
            ),
          ),
          body: ListenableBuilder(listenable: store, builder: (context, _) => const TabBarView(children: [_SalesReport(), _ProductReport(), _CustomerReport()])),
        ),
      ),
    );
  }
}

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
    final methods = byMethod.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _statRow([
          _stat(Icons.currency_rupee_rounded, AC.primary, inr(store.totalRevenue), 'Total revenue'),
          _stat(Icons.receipt_long_outlined, AC.accent, inr(avg), 'Avg. order value'),
        ]),
        _statRow([
          _stat(Icons.shopping_bag_outlined, AC.primary, '${store.orders.length}', 'Orders'),
          _stat(Icons.check_circle_rounded, AC.success, '${store.orders.where((o) => o.isDelivered).length}', 'Delivered'),
          _stat(Icons.cancel_outlined, AC.danger, '$cancelRate%', 'Cancel rate'),
        ]),
        _label('Last 7 days', icon: Icons.show_chart_rounded),
        _box(padding: const EdgeInsets.fromLTRB(14, 18, 14, 12), child: MiniBarChart(labels: store.dayLabels(7), values: store.revenueByDay(7))),
        _label('Revenue by payment method', icon: Icons.pie_chart_outline_rounded),
        _box(
          child: methods.isEmpty
              ? const Text('No sales yet', style: TextStyle(color: AC.muted, fontSize: _fBody))
              : Column(
            children: [
              for (final e in methods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 110, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: _fBody, fontWeight: FontWeight.w600))),
                      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: total == 0 ? 0 : e.value / total, minHeight: 8, backgroundColor: AC.bg, color: AC.primary))),
                      const SizedBox(width: 10),
                      Text(inr(e.value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody)),
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
    final low = store.phones.where((p) => p.stock <= 3).toList()..sort((a, b) => a.stock.compareTo(b.stock));
    final outCount = store.phones.where((p) => p.stock == 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _statRow([
          _stat(Icons.smartphone_rounded, AC.primary, '${store.phones.length}', 'Phones listed'),
          _stat(Icons.shopping_cart_checkout_rounded, AC.success, '${units.values.fold<int>(0, (a, b) => a + b)}', 'Units sold'),
          _stat(Icons.production_quantity_limits_rounded, AC.danger, '$outCount', 'Out of stock'),
        ]),
        _label('Best sellers by revenue', icon: Icons.emoji_events_outlined),
        _box(
          child: rows.isEmpty
              ? const Text('No sales yet', style: TextStyle(color: AC.muted, fontSize: _fBody))
              : Column(
            children: [
              for (int i = 0; i < rows.take(10).length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _rank(i),
                      const SizedBox(width: 10),
                      Expanded(child: Text(rows[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1))),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(inr(rows[i].value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
                          Text('${units[rows[i].key]} sold', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _label('Needs restocking', icon: Icons.inventory_2_outlined),
        if (low.isEmpty) _box(child: const Text('All phones are well stocked', style: TextStyle(color: AC.muted, fontSize: _fBody))),
        for (final p in low)
          _box(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _iconBox(Icons.smartphone_rounded, p.stock == 0 ? AC.danger : AC.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle))),
                _pill(p.stock == 0 ? 'Out of stock' : '${p.stock} left', p.stock == 0 ? AC.danger : AC.warning),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _statRow([
          _stat(Icons.people_alt_outlined, AC.primary, '${store.customers.length}', 'Customers'),
          _stat(Icons.shopping_bag_outlined, AC.success, '${withOrders.length}', 'Have ordered'),
          _stat(Icons.repeat_rounded, AC.accent, '$repeat', 'Repeat buyers'),
        ]),
        _label('New customers (last 6 months)', icon: Icons.person_add_alt_1_outlined),
        _box(padding: const EdgeInsets.fromLTRB(14, 18, 14, 12), child: MiniBarChart(labels: labels, values: vals, height: 110)),
        _label('Top customers', icon: Icons.emoji_events_outlined),
        _box(
          child: top.isEmpty
              ? const Text('No orders yet', style: TextStyle(color: AC.muted, fontSize: _fBody))
              : Column(
            children: [
              for (int i = 0; i < top.take(10).length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _rank(i),
                      const SizedBox(width: 10),
                      Expanded(child: Text(top[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1))),
                      Text(inr(top[i].value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
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

// =============================================================================
// ADMIN PROFILE
// =============================================================================

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

  bool _savingProfile = false;

  Future<void> _save() async {
    if (_savingProfile) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;

    final name = _vClean(_name.text);
    final email = _email.text.trim().toLowerCase();
    final phoneRaw = _phone.text.trim();
    final phone = phoneRaw.isEmpty ? '' : _vMobileDigits(phoneRaw);

    if (name == store.adminName.trim() && email == store.adminEmail.trim().toLowerCase() && phone == store.adminPhone.trim()) {
      snack(context, 'No changes to save');
      return;
    }
    setState(() => _savingProfile = true);
    final msg = await store.updateAdminProfile(name: name, email: email, phone: phone);
    if (!mounted) return;
    setState(() => _savingProfile = false);
    if (msg == null) {
      _name.text = name;
      _email.text = email;
      _phone.text = phone;
    }
    snack(context, msg ?? 'Profile updated');
  }

  Future<void> _changePassword() async {
    final done = await showDialog<bool>(context: context, builder: (_) => const _PasswordDialog());
    if (done == true && mounted) snack(context, 'Password changed');
  }

  @override
  Widget build(BuildContext context) {
    return _compact(
      context,
      Scaffold(
        appBar: _appBar('My profile'),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
            children: [
              // ---- header card ----
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Text(store.adminName.isEmpty ? 'A' : store.adminName[0].toUpperCase(), style: const TextStyle(color: AC.primary, fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.adminName.isEmpty ? 'Admin' : store.adminName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: _fTitle + 2)),
                          const SizedBox(height: 2),
                          Text(store.adminEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: _fSmall)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Super Admin', style: TextStyle(color: Colors.white, fontSize: _fSmall, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _label('Your details', icon: Icons.person_outline_rounded),
              _field('Full name', _name,
                  validator: (v) => _vName(v, label: 'name'),
                  formatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.allow(RegExp(r"[\p{L}\p{M} .'\-]", unicode: true)),
                  ]),
              const SizedBox(height: 12),
              _field('Email', _email,
                  type: TextInputType.emailAddress,
                  validator: _vEmailCheck,
                  formatters: [
                    LengthLimitingTextInputFormatter(254),
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ]),
              const SizedBox(height: 12),
              _field('Phone', _phone,
                  type: TextInputType.phone,
                  validator: (v) => _vMobile(v),
                  formatters: [
                    LengthLimitingTextInputFormatter(16),
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
                  ]),
              const SizedBox(height: 20),
              _bigButton('Save changes', _save, icon: Icons.check_rounded),
              const SizedBox(height: 10),
              _bigButton('Change password', _changePassword, icon: Icons.lock_reset_rounded, outlined: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns (and disposes) its own text controllers.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty) {
      setState(() => _err = 'Enter your current password');
      return;
    }
    final weak = _vStrongPassword(_new.text, oldPass: _old.text, email: store.adminEmail);
    if (weak != null) {
      setState(() => _err = weak);
      return;
    }
    if (_confirm.text.isEmpty) {
      setState(() => _err = 'Confirm your new password');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _err = 'Passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final e = await store.changeAdminPassword(_old.text, _new.text);
    if (!mounted) return;
    if (e != null) {
      setState(() {
        _busy = false;
        _err = e;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle + 2)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Current password', _old, obscure: true, formatters: [LengthLimitingTextInputFormatter(64)]),
            const SizedBox(height: 12),
            _field('New password', _new, obscure: true, formatters: [LengthLimitingTextInputFormatter(64), FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
            const SizedBox(height: 12),
            _field('Confirm new password', _confirm, obscure: true, formatters: [LengthLimitingTextInputFormatter(64), FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(alignment: Alignment.centerLeft, child: Text(_err!, style: const TextStyle(color: AC.danger, fontSize: _fSmall, fontWeight: FontWeight.w700))),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _busy ? null : _submit, child: const Text('Change')),
      ],
    );
  }
}

// =============================================================================
// SETTINGS
// =============================================================================

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
  late final _refundDays = TextEditingController(text: '${store.refundDays}');
  late final _pincodes = TextEditingController(text: store.serviceablePincodes);
  late final _sHours = TextEditingController(text: store.supportHours);
  late final _partnerEarn = TextEditingController(text: '${store.partnerEarning}');
  late final _sPhone = TextEditingController(text: store.supportPhone);
  late final _sEmail = TextEditingController(text: store.supportEmail);

  @override
  void dispose() {
    for (final c in [_delivery, _freeAbove, _returnDays, _refundDays, _pincodes, _sHours, _partnerEarn, _sPhone, _sEmail]) {
      c.dispose();
    }
    super.dispose();
  }

  // Limits keep the values sensible AND whole numbers: the Firestore rules compute the
  // refund window from returnDays, so a decimal / negative / huge value would break refunds.
  String? _deliveryCheck(String? v) => _vIntRange(v, label: 'the delivery charge', min: 0, max: 1000);
  String? _freeAboveCheck(String? v) => _vIntRange(v, label: 'the free delivery limit', min: 0, max: 1000000);
  String? _returnDaysCheck(String? v) => _vIntRange(v, label: 'the return window', min: 0, max: 30);
  String? _refundDaysCheck(String? v) => _vIntRange(v, label: 'the refund time', min: 0, max: 30);
  String? _earnCheck(String? v) => _vIntRange(v, label: 'the partner earning', min: 0, max: 1000);

  // Pincodes are 6 digits (not starting with 0), separated by commas or spaces, no repeats;
  // empty = every pincode is accepted.
  List<String> _pinList() => (_pincodes.text).split(RegExp(r'[,\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  String? _pins(String? v) {
    final parts = (v ?? '').split(RegExp(r'[,\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final seen = <String>{};
    for (final p in parts) {
      if (!RegExp(r'^[1-9]\d{5}$').hasMatch(p)) return '"$p" is not a valid 6-digit pincode';
      if (!seen.add(p)) return 'Pincode $p is entered twice';
    }
    if (parts.length > 500) return 'Add at most 500 pincodes';
    return null;
  }

  String? _supportPhoneCheck(String? v) => _vMobile(v, allowTollFree: true);
  String? _supportEmailCheck(String? v) => _vEmailCheck(v, required: false);

  String? _hoursCheck(String? v) {
    final s = _vClean(v ?? '');
    if (s.isEmpty) return null;
    if (s.length < 5) return 'Write the hours, for example: Mon-Sat, 10 AM to 7 PM';
    if (s.length > 60) return 'Support hours can be at most 60 characters';
    if (!RegExp(r'\d').hasMatch(s)) return 'Include the time, for example: 10 AM to 7 PM';
    return null;
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final charge = int.parse(_delivery.text.trim());
    final freeAbove = int.parse(_freeAbove.text.trim());

    // The customer app gives free delivery when the cart total is >= "Free above".
    // So "Free above = 0" would make EVERY order free even when a charge is set.
    if (charge > 0 && freeAbove == 0) {
      snack(context, 'Free above is 0, so delivery would be free on every order. Enter a higher limit, or set the delivery charge to 0.');
      return;
    }
    if (charge > 0 && freeAbove > 0 && freeAbove <= charge) {
      snack(context, 'Free delivery limit must be higher than the delivery charge');
      return;
    }

    final pins = _pinList();
    final pinText = pins.join(', ');
    final hours = _vClean(_sHours.text);
    final phone = _sPhone.text.trim();
    final email = _sEmail.text.trim().toLowerCase();
    final returnDays = int.parse(_returnDays.text.trim());
    final refundDays = int.parse(_refundDays.text.trim());
    final earn = int.parse(_partnerEarn.text.trim());

    if (charge == store.deliveryCharge &&
        freeAbove == store.freeDeliveryAbove &&
        returnDays == store.returnDays &&
        refundDays == store.refundDays &&
        pinText == store.serviceablePincodes.trim() &&
        hours == store.supportHours.trim() &&
        earn == store.partnerEarning &&
        phone == store.supportPhone.trim() &&
        email == store.supportEmail.trim()) {
      snack(context, 'No changes to save');
      return;
    }

    store.deliveryCharge = charge;
    store.freeDeliveryAbove = freeAbove;
    store.returnDays = returnDays;
    store.refundDays = refundDays;
    store.serviceablePincodes = pinText;
    store.supportHours = hours;
    store.partnerEarning = earn;
    store.supportPhone = phone;
    store.supportEmail = email;
    store.changed();
    _pincodes.text = pinText;
    _sHours.text = hours;
    _sEmail.text = email;
    snack(context, 'Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    return _compact(
      context,
      Scaffold(
        appBar: _appBar('Settings'),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
            children: [
              _label('Delivery', icon: Icons.local_shipping_outlined),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _field('Delivery charge', _delivery, type: TextInputType.number, prefix: '₹ ', validator: _deliveryCheck, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)])),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Free above', _freeAbove, type: TextInputType.number, prefix: '₹ ', validator: _freeAboveCheck, helper: 'Free delivery limit', formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)])),
                ],
              ),
              const SizedBox(height: 12),
              _field('Return window (days)', _returnDays, type: TextInputType.number, validator: _returnDaysCheck, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]),
              const SizedBox(height: 12),
              _field('Refund time (working days)', _refundDays, type: TextInputType.number, validator: _refundDaysCheck, helper: 'Shown to customers. Keep 0 to show no number', formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]),
              const SizedBox(height: 12),
              _field('Serviceable pincodes', _pincodes, type: TextInputType.text, validator: _pins, maxLines: 2, helper: 'Comma separated. Leave empty to deliver everywhere', formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9, \n]')), LengthLimitingTextInputFormatter(3600)]),
              const SizedBox(height: 12),
              _field('Delivery partner earning per order', _partnerEarn, type: TextInputType.number, prefix: '₹ ', validator: _earnCheck, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) => _switchTile(Icons.verified_user_outlined, 'Verify documents first', 'Only partners with verified Licence, Aadhaar and RC get orders', store.requireVerifiedPartners, (v) {
                  store.requireVerifiedPartners = v;
                  store.changed();
                }),
              ),

              _label('Support contact (shown in customer app)', icon: Icons.headset_mic_outlined),
              _field('Support phone', _sPhone, type: TextInputType.phone, validator: _supportPhoneCheck, formatters: [LengthLimitingTextInputFormatter(16), FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]'))]),
              const SizedBox(height: 12),
              _field('Support email', _sEmail, type: TextInputType.emailAddress, validator: _supportEmailCheck, formatters: [LengthLimitingTextInputFormatter(254), FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
              const SizedBox(height: 12),
              _field('Support hours', _sHours, helper: 'For example: Mon-Sat, 10 AM to 7 PM', validator: _hoursCheck, formatters: [LengthLimitingTextInputFormatter(60)]),
              const SizedBox(height: 18),
              _bigButton('Save settings', _save, icon: Icons.check_rounded),

              _label('More', icon: Icons.tune_rounded),
              ListenableBuilder(
                listenable: store,
                builder: (context, _) => _switchTile(Icons.notifications_active_outlined, 'Push alerts', 'New orders and low stock', store.pushAlerts, (v) {
                  store.pushAlerts = v;
                  store.changed();
                }),
              ),
              _label('Delivery partner app', icon: Icons.two_wheeler_rounded),
              _linkTile(Icons.card_giftcard_rounded, 'Partner rewards', 'Daily and weekly incentives shown in the delivery app', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerRewardsScreen()));
              }),
              _linkTile(Icons.gavel_rounded, 'Partner terms & privacy', 'Text shown to delivery partners', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerTermsScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STAFF (screen kept as-is, no longer linked from Settings)
// =============================================================================

const _roles = ['Super Admin', 'Order Manager', 'Inventory Manager', 'Support Agent'];

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

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _edit(BuildContext context, {Staff? staff}) async {
    final result = await showModalBottomSheet<({String name, String email, String role})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StaffEditor(staff: staff),
    );
    if (result == null) return;
    if (staff == null) {
      store.staff.add(Staff(result.name, result.email, result.role));
    } else {
      staff
        ..name = result.name
        ..email = result.email
        ..role = result.role;
    }
    store.changed();
  }

  Future<void> _delete(BuildContext context, Staff s) async {
    final ok = await confirmDialog(context, 'Remove ${s.name}?', 'They will no longer be able to use this admin app.', yes: 'Remove', danger: true);
    if (!ok) return;
    store.staff.remove(s);
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: _appBar('Staff & roles'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          backgroundColor: AC.primary,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('Add staff', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
        ),
        body: store.staff.isEmpty
            ? const EmptyState(icon: Icons.groups_outlined, title: 'No staff yet', subtitle: 'Add a staff member to share the work')
            : ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
          children: [
            for (final s in store.staff)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDeco(radius: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => _edit(context, staff: s),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: s.active ? AC.primary : AC.muted,
                                  child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: _fTitle + 2)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                                      Text(s.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _pill(s.role, s.role == 'Super Admin' ? AC.primary : AC.accent),
                                const SizedBox(width: 6),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Divider(height: 1, color: AC.muted.withValues(alpha: .14)),
                            Row(
                              children: [
                                const Icon(Icons.lock_open_rounded, size: 13, color: AC.muted),
                                const SizedBox(width: 5),
                                Expanded(child: Text(_access(s.role), style: const TextStyle(color: AC.muted, fontSize: _fSmall))),
                                if (s.role != 'Super Admin') ...[
                                  Text(s.active ? 'Active' : 'Off', style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                                  Transform.scale(
                                    scale: .72,
                                    child: Switch(
                                      value: s.active,
                                      activeColor: AC.success,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (v) {
                                        s.active = v;
                                        store.changed();
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AC.danger),
                                    onPressed: () => _delete(context, s),
                                  ),
                                ] else
                                  const SizedBox(height: 40),
                              ],
                            ),
                          ],
                        ),
                      ),
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

/// Owns (and disposes) its own text controllers.
class _StaffEditor extends StatefulWidget {
  final Staff? staff;
  const _StaffEditor({required this.staff});

  @override
  State<_StaffEditor> createState() => _StaffEditorState();
}

class _StaffEditorState extends State<_StaffEditor> {
  late final _name = TextEditingController(text: widget.staff?.name ?? '');
  late final _email = TextEditingController(text: widget.staff?.email ?? '');
  late String _role = widget.staff?.role ?? 'Order Manager';
  bool _tried = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _tried = true);
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || !email.contains('@')) return;
    Navigator.pop(context, (name: name, email: email, role: _role));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.staff == null ? 'Add staff member' : 'Edit staff member', style: const TextStyle(fontSize: _fHeader - 2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
            decoration: _dec('Full name', error: _tried && _name.text.trim().isEmpty ? 'Required' : null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
            decoration: _dec('Email', error: _tried && !_email.text.contains('@') ? 'Enter a valid email' : null),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _role,
            isExpanded: true,
            style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600, color: AC.text),
            decoration: _dec('Role', helper: _access(_role)),
            items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 16),
          _bigButton('Save', _save, icon: Icons.check_rounded),
        ],
      ),
    );
  }
}

// =============================================================================
// POLICIES (screen kept as-is, no longer linked from Settings)
// =============================================================================

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

  Widget _policyBox(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: 5,
      style: const TextStyle(fontSize: _fBody + 1),
      decoration: _dec(label).copyWith(alignLabelWithHint: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Policies'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('These texts are shown to customers in the app.', style: TextStyle(color: AC.muted, fontSize: _fSmall)),
          ),
          _policyBox('Returns policy', _returns),
          _policyBox('Warranty policy', _warranty),
          _policyBox('Privacy policy', _privacy),
          const SizedBox(height: 6),
          _bigButton('Save policies', () {
            store.returnsPolicy = _returns.text.trim();
            store.warrantyPolicy = _warranty.text.trim();
            store.privacyPolicy = _privacy.text.trim();
            store.changed();
            snack(context, 'Policies saved');
          }, icon: Icons.check_rounded),
        ],
      ),
    );
  }
}

// =============================================================================
// DELIVERY PARTNER REWARDS (saved to appConfig/partnerIncentives, shown live in the delivery app)
// =============================================================================

class _RuleRow {
  final TextEditingController target, title, reward;
  _RuleRow({int t = 0, String ti = '', String re = ''})
      : target = TextEditingController(text: t == 0 ? '' : '$t'),
        title = TextEditingController(text: ti),
        reward = TextEditingController(text: re);

  void dispose() {
    target.dispose();
    title.dispose();
    reward.dispose();
  }
}

class PartnerRewardsScreen extends StatefulWidget {
  const PartnerRewardsScreen({super.key});

  @override
  State<PartnerRewardsScreen> createState() => _PartnerRewardsScreenState();
}

class _PartnerRewardsScreenState extends State<PartnerRewardsScreen> {
  late final _dailyTarget = TextEditingController(text: store.partnerDailyTarget == 0 ? '' : '${store.partnerDailyTarget}');
  late final List<_RuleRow> _daily = store.partnerDailyIncentives.map((r) => _RuleRow(t: r.target, ti: r.title, re: r.reward)).toList();
  late final List<_RuleRow> _weekly = store.partnerWeeklyIncentives.map((r) => _RuleRow(t: r.target, ti: r.title, re: r.reward)).toList();
  bool _saving = false;
  // Removed rows are disposed with the screen (their text fields are still on screen for one frame).
  final List<_RuleRow> _removed = [];

  @override
  void dispose() {
    _dailyTarget.dispose();
    for (final r in [..._daily, ..._weekly, ..._removed]) {
      r.dispose();
    }
    super.dispose();
  }

  Widget _row(_RuleRow r, {required bool withTarget, required VoidCallback onRemove}) => _box(
    padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (withTarget) ...[
                    Expanded(flex: 3, child: _field('Deliveries', r.target, type: TextInputType.number)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(flex: 7, child: _field('What the partner has to do', r.title)),
                ],
              ),
              const SizedBox(height: 8),
              _field('Reward', r.reward, helper: 'For example: ₹150 bonus'),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AC.danger),
          onPressed: onRemove,
        ),
      ],
    ),
  );

  Future<void> _save() async {
    for (final r in _daily) {
      if (r.title.text.trim().isEmpty) continue;
      if ((int.tryParse(r.target.text.trim()) ?? 0) <= 0) {
        snack(context, 'Enter the number of deliveries for "${r.title.text.trim()}"');
        return;
      }
    }
    setState(() => _saving = true);
    store.partnerDailyTarget = int.tryParse(_dailyTarget.text.trim()) ?? 0;
    store.partnerDailyIncentives
      ..clear()
      ..addAll(_daily.where((r) => r.title.text.trim().isNotEmpty).map((r) => IncentiveRule(int.parse(r.target.text.trim()), r.title.text.trim(), r.reward.text.trim())));
    store.partnerWeeklyIncentives
      ..clear()
      ..addAll(_weekly.where((r) => r.title.text.trim().isNotEmpty).map((r) => IncentiveRule(0, r.title.text.trim(), r.reward.text.trim())));
    final err = await store.savePartnerConfig();
    if (!mounted) return;
    setState(() => _saving = false);
    snack(context, err ?? 'Rewards saved. Delivery partners see them now.');
  }

  @override
  Widget build(BuildContext context) {
    return _compact(
      context,
      Scaffold(
        appBar: _appBar('Partner rewards'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 4),
              child: Text('These rewards are shown in the Incentives screen of the delivery app. Leave a list empty to hide it.', style: TextStyle(color: AC.muted, fontSize: _fSmall)),
            ),
            _label('Daily target', icon: Icons.flag_outlined),
            _field('Deliveries per day', _dailyTarget, type: TextInputType.number, helper: 'The progress bar in the delivery app uses this number'),
            _label('Daily rewards', icon: Icons.today_outlined),
            for (var i = 0; i < _daily.length; i++)
              _row(_daily[i], withTarget: true, onRemove: () => setState(() => _removed.add(_daily.removeAt(i)))),
            _bigButton('Add daily reward', () => setState(() => _daily.add(_RuleRow())), icon: Icons.add_rounded, outlined: true),
            _label('Weekly rewards', icon: Icons.date_range_outlined),
            for (var i = 0; i < _weekly.length; i++)
              _row(_weekly[i], withTarget: false, onRemove: () => setState(() => _removed.add(_weekly.removeAt(i)))),
            _bigButton('Add weekly reward', () => setState(() => _weekly.add(_RuleRow())), icon: Icons.add_rounded, outlined: true),
            const SizedBox(height: 18),
            _bigButton(_saving ? 'Saving...' : 'Save rewards', _saving ? () {} : _save, icon: Icons.check_rounded),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DELIVERY PARTNER TERMS & PRIVACY (saved to appConfig/partnerTerms, shown live in the delivery app)
// =============================================================================

class PartnerTermsScreen extends StatefulWidget {
  const PartnerTermsScreen({super.key});

  @override
  State<PartnerTermsScreen> createState() => _PartnerTermsScreenState();
}

class _PartnerTermsScreenState extends State<PartnerTermsScreen> {
  late final _terms = TextEditingController(text: store.partnerTerms.join('\n'));
  late final _privacy = TextEditingController(text: store.partnerPrivacy.join('\n'));
  // One per line:  Question | Answer      and      Title | Text
  late final _faqs = TextEditingController(text: store.partnerFaqs.map((f) => '${f.q} | ${f.a}').join('\n'));
  late final _training = TextEditingController(text: store.partnerTraining.map((t) => '${t.title} | ${t.body}').join('\n'));
  bool _saving = false;

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    _faqs.dispose();
    _training.dispose();
    super.dispose();
  }

  List<String> _lines(String t) => t.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Widget _box2(String label, TextEditingController c, {String helper = 'One point per line'}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: 8,
      style: const TextStyle(fontSize: _fBody + 1),
      decoration: _dec(label, helper: helper).copyWith(alignLabelWithHint: true),
    ),
  );

  /// "Left | Right" lines -> pairs. Returns null (and the first bad line) when a line has no "|" or an empty left part.
  (List<(String, String)>?, String) _pairs(String t) {
    final out = <(String, String)>[];
    for (final line in _lines(t)) {
      final i = line.indexOf('|');
      final left = i < 0 ? '' : line.substring(0, i).trim();
      final right = i < 0 ? '' : line.substring(i + 1).trim();
      if (left.isEmpty || right.isEmpty) return (null, line);
      out.add((left, right));
    }
    return (out, '');
  }

  Future<void> _save() async {
    final faqs = _pairs(_faqs.text);
    if (faqs.$1 == null) {
      snack(context, 'FAQ line must look like: Question | Answer\n"${faqs.$2}"');
      return;
    }
    final tips = _pairs(_training.text);
    if (tips.$1 == null) {
      snack(context, 'Training tip line must look like: Title | Text\n"${tips.$2}"');
      return;
    }
    setState(() => _saving = true);
    store.partnerFaqs
      ..clear()
      ..addAll(faqs.$1!.map((p) => Faq(p.$1, p.$2)));
    store.partnerTraining
      ..clear()
      ..addAll(tips.$1!.map((p) => PartnerTip(p.$1, p.$2)));
    store.partnerTerms
      ..clear()
      ..addAll(_lines(_terms.text));
    store.partnerPrivacy
      ..clear()
      ..addAll(_lines(_privacy.text));
    final err = await store.savePartnerConfig();
    if (!mounted) return;
    setState(() => _saving = false);
    snack(context, err ?? 'Saved. Delivery partners see the new text now.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Partner terms & privacy'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('These texts are shown to delivery partners in their app (Terms, Help and Training screens).', style: TextStyle(color: AC.muted, fontSize: _fSmall)),
          ),
          _box2('Terms of service', _terms),
          _box2('Privacy policy', _privacy),
          _box2('Help FAQs for partners', _faqs, helper: 'One per line: Question | Answer'),
          _box2('Training & safety tips', _training, helper: 'One per line: Title | Text'),
          const SizedBox(height: 6),
          _bigButton(_saving ? 'Saving...' : 'Save text', _saving ? () {} : _save, icon: Icons.check_rounded),
        ],
      ),
    );
  }
}