import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

/// Drawn phone thumbnail using the phone's two colours (no image files needed).
class PhoneThumb extends StatelessWidget {
  // dynamic on purpose: accepts a Phone even if admin_data.dart is imported under two paths.
  final dynamic phone;
  final double size;
  const PhoneThumb(this.phone, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final List cols = phone.colors as List;
    final Color c1 = cols.isNotEmpty ? cols.first as Color : AC.primary;
    final Color c2 = cols.length > 1 ? cols[1] as Color : c1;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.smartphone_rounded, color: Colors.white.withValues(alpha: 0.9), size: size * 0.55),
    );
  }
}

/// Phones list: search, brand chips, stock filter, enable/disable, add.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String brand = 'All';
  String stock = 'All stock';
  String condition = 'All conditions';
  String query = '';

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = store.phones.where((p) {
          if (brand != 'All' && p.brand != brand) return false;
          if (stock != 'All stock' && p.stockLabel != stock) return false;
          if (condition != 'All conditions' && p.condition != condition) return false;
          if (q.isNotEmpty && !('${p.name} ${p.brand}'.toLowerCase().contains(q))) return false;
          return true;
        }).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Products'),
            actions: [
              PopupMenuButton<String>(
                icon: Badge(isLabelVisible: condition != 'All conditions', smallSize: 8, child: const Icon(Icons.filter_list_rounded)),
                onSelected: (v) => setState(() => condition = v),
                itemBuilder: (_) => [for (final c in ['All conditions', ...conditions]) PopupMenuItem(value: c, child: Text(c, style: TextStyle(fontWeight: c == condition ? FontWeight.w800 : FontWeight.w500)))],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _push(const PhoneFormScreen()),
            backgroundColor: AC.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add phone', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), child: SearchBox(hint: 'Search phones or brands', onChanged: (v) => setState(() => query = v))),
              Padding(padding: const EdgeInsets.only(left: 16), child: ChipTabs(items: ['All', ...store.brands.map((b) => b.name)], selected: brand, onSelect: (v) => setState(() => brand = v))),
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.only(left: 16), child: ChipTabs(items: const ['All stock', 'In stock', 'Low stock', 'Out of stock'], selected: stock, onSelect: (v) => setState(() => stock = v))),
              const SizedBox(height: 10),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.smartphone_outlined, title: 'No phones found', subtitle: 'Change the filters or add a new phone')
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _tile(list[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(Phone p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(radius: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _push(ProductDetailScreen(phone: p)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Opacity(opacity: p.active ? 1 : 0.4, child: PhoneThumb(p)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text('${p.brand} • ${p.storage} • ${p.condition}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(inr(p.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(inr(p.mrp), style: const TextStyle(color: AC.muted, fontSize: 11.5, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                        StatusChip('${p.stock} left', color: statusColor(p.stockLabel)),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(value: p.active, activeColor: AC.success, onChanged: (v) {
                p.active = v;
                store.changed();
                snack(context, v ? '${p.name} is visible to customers' : '${p.name} is hidden from customers');
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone detail: specs, stock, visibility, edit and delete.
class ProductDetailScreen extends StatelessWidget {
  final Phone phone;
  const ProductDetailScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = phone;
        final sold = store.validOrders.fold<int>(0, (s, o) => s + o.items.where((i) => i.phoneId == p.id).fold<int>(0, (a, i) => a + i.qty));
        return Scaffold(
          appBar: AppBar(
            title: const Text('Phone details'),
            actions: [
              IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhoneFormScreen(phone: p)))),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.colors.first, p.colors.length > 1 ? p.colors[1] : p.colors.first]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    Center(child: Icon(Icons.smartphone_rounded, size: 110, color: Colors.white.withValues(alpha: 0.9))),
                    Positioned(top: 14, right: 14, child: StatusChip(p.active ? 'Active' : 'Inactive')),
                    Positioned(left: 16, bottom: 14, child: Text('${p.off}% OFF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(inr(p.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AC.primary)),
                  const SizedBox(width: 8),
                  Text(inr(p.mrp), style: const TextStyle(color: AC.muted, decoration: TextDecoration.lineThrough)),
                  const Spacer(),
                  const Icon(Icons.star_rounded, color: AC.warning, size: 18),
                  Text(' ${p.rating}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              SectionTitle('Specifications'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Column(
                  children: [
                    KV('Brand', p.brand),
                    KV('Storage', p.storage),
                    KV('Condition', p.condition),
                    KV('Battery health', '${p.battery}%'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Text('Colours', style: TextStyle(color: AC.muted, fontSize: 13)),
                          const Spacer(),
                          for (final c in p.colors) Container(width: 20, height: 20, margin: const EdgeInsets.only(left: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AC.border))),
                        ],
                      ),
                    ),
                    KV('Units sold', '$sold'),
                  ],
                ),
              ),
              SectionTitle('Stock'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.stock} units', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          StatusChip(p.stockLabel),
                        ],
                      ),
                    ),
                    _roundBtn(Icons.remove_rounded, () => store.setStock(p, p.stock - 1)),
                    const SizedBox(width: 10),
                    _roundBtn(Icons.add_rounded, () => store.setStock(p, p.stock + 1)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: cardDeco(),
                child: SwitchListTile(
                  value: p.active,
                  activeColor: AC.success,
                  onChanged: (v) {
                    p.active = v;
                    store.changed();
                  },
                  title: const Text('Visible to customers', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Turn off to hide this phone in the customer app', style: TextStyle(fontSize: 12, color: AC.muted)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhoneFormScreen(phone: p))), child: const Text('Edit phone')),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AC.danger, side: const BorderSide(color: AC.danger, width: 1.4)),
                onPressed: () async {
                  final ok = await confirmDialog(context, 'Delete ${p.name}?', 'This removes the phone from your catalogue. Past orders are not affected.', yes: 'Delete', danger: true);
                  if (ok) {
                    store.deletePhone(p);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete phone'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AC.primary)),
  );
}

/// Add / edit phone. Pass [phone] to edit.
class PhoneFormScreen extends StatefulWidget {
  final Phone? phone;
  const PhoneFormScreen({super.key, this.phone});

  @override
  State<PhoneFormScreen> createState() => _PhoneFormScreenState();
}

class _PhoneFormScreenState extends State<PhoneFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.phone?.name ?? '');
  late final _price = TextEditingController(text: widget.phone?.price.toString() ?? '');
  late final _mrp = TextEditingController(text: widget.phone?.mrp.toString() ?? '');
  late final _battery = TextEditingController(text: widget.phone?.battery.toString() ?? '');
  late final _stock = TextEditingController(text: widget.phone?.stock.toString() ?? '1');
  late String brand = widget.phone?.brand ?? store.brands.first.name;
  late String storage = widget.phone?.storage ?? '128 GB';
  late String condition = widget.phone?.condition ?? 'Good';
  late Color c1 = widget.phone?.colors.first ?? swatches[0];
  late Color c2 = (widget.phone != null && widget.phone!.colors.length > 1) ? widget.phone!.colors[1] : swatches[10];
  int photos = 0;

  bool get editing => widget.phone != null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _mrp.dispose();
    _battery.dispose();
    _stock.dispose();
    super.dispose();
  }

  String? _num(String? v, {int min = 0, int? max}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < min) return 'Minimum $min';
    if (max != null && n > max) return 'Maximum $max';
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final price = int.parse(_price.text.trim());
    final mrp = int.parse(_mrp.text.trim());
    if (mrp < price) {
      snack(context, 'MRP cannot be lower than the selling price');
      return;
    }
    final battery = int.parse(_battery.text.trim());
    final stockN = int.parse(_stock.text.trim());
    if (editing) {
      final p = widget.phone!;
      p
        ..name = _name.text.trim()
        ..brand = brand
        ..storage = storage
        ..condition = condition
        ..price = price
        ..mrp = mrp
        ..battery = battery
        ..stock = stockN
        ..colors = [c1, c2];
      store.changed();
      snack(context, '${p.name} updated');
    } else {
      store.addPhone(Phone(id: store.nextPhoneId(), name: _name.text.trim(), brand: brand, storage: storage, condition: condition, price: price, mrp: mrp, battery: battery, rating: 4.0, colors: [c1, c2], stock: stockN));
      snack(context, '${_name.text.trim()} added');
    }
    Navigator.pop(context);
  }

  Widget _drop(String label, String value, List<String> items, ValueChanged<String> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
      onChanged: (v) => onChanged(v ?? value),
    ),
  );

  Widget _swatchPicker(String title, Color current, ValueChanged<Color> onPick) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in swatches)
            GestureDetector(
              onTap: () => onPick(s),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: s, shape: BoxShape.circle, border: Border.all(color: s == current ? AC.accent : Colors.transparent, width: 3)),
                child: s == current ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
              ),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit phone' : 'Add phone')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            // Photos (placeholder: connect image_picker + storage later)
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() => photos++);
                      snack(context, 'Photo picker is a placeholder. Add image_picker to upload real photos.');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 92,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.border)),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_rounded, color: AC.primary), SizedBox(height: 6), Text('Add photo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))]),
                    ),
                  ),
                  for (int i = 0; i < photos; i++)
                    Container(
                      width: 92,
                      margin: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [c1, c2]), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.image_rounded, color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            formField('Phone name', _name),
            _drop('Brand', brand, store.brands.map((b) => b.name).toList(), (v) => setState(() => brand = v)),
            Row(
              children: [
                Expanded(child: _drop('Storage', storage, storages, (v) => setState(() => storage = v))),
                const SizedBox(width: 12),
                Expanded(child: _drop('Condition', condition, conditions, (v) => setState(() => condition = v))),
              ],
            ),
            Row(
              children: [
                Expanded(child: formField('Selling price', _price, type: TextInputType.number, prefix: '₹ ', validator: (v) => _num(v, min: 1))),
                const SizedBox(width: 12),
                Expanded(child: formField('MRP', _mrp, type: TextInputType.number, prefix: '₹ ', validator: (v) => _num(v, min: 1))),
              ],
            ),
            Row(
              children: [
                Expanded(child: formField('Battery health %', _battery, type: TextInputType.number, validator: (v) => _num(v, min: 1, max: 100))),
                const SizedBox(width: 12),
                Expanded(child: formField('Stock (units)', _stock, type: TextInputType.number, validator: (v) => _num(v, min: 0))),
              ],
            ),
            _swatchPicker('Main colour', c1, (c) => setState(() => c1 = c)),
            const SizedBox(height: 14),
            _swatchPicker('Second colour', c2, (c) => setState(() => c2 = c)),
            const SizedBox(height: 26),
            ElevatedButton(onPressed: _save, child: Text(editing ? 'Save changes' : 'Add phone')),
          ],
        ),
      ),
    );
  }
}

/// Inventory: see stock of every phone and change it quickly.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = [...store.phones]..sort((a, b) => a.stock.compareTo(b.stock));
        final list = all.where((p) => filter == 'All' || (filter == 'Low stock' && p.stock > 0 && p.stock <= 3) || (filter == 'Out of stock' && p.stock == 0)).toList();
        final units = store.phones.fold<int>(0, (s, p) => s + p.stock);
        final value = store.phones.fold<int>(0, (s, p) => s + p.stock * p.price);
        return Scaffold(
          appBar: AppBar(title: const Text('Inventory')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(
                children: [
                  _sum('Units in stock', '$units', AC.primary),
                  const SizedBox(width: 10),
                  _sum('Stock value', inr(value), AC.success),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _sum('Low stock', '${store.phones.where((p) => p.stock > 0 && p.stock <= 3).length}', AC.warning),
                  const SizedBox(width: 10),
                  _sum('Out of stock', '${store.phones.where((p) => p.stock == 0).length}', AC.danger),
                ],
              ),
              const SizedBox(height: 14),
              ChipTabs(items: const ['All', 'Low stock', 'Out of stock'], selected: filter, onSelect: (v) => setState(() => filter = v)),
              const SizedBox(height: 12),
              if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.inventory_2_outlined, title: 'Nothing here', subtitle: 'All phones are well stocked')),
              for (final p in list)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: cardDeco(radius: 16),
                  child: Row(
                    children: [
                      PhoneThumb(p, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            Text('${p.storage} • ${p.condition}', style: const TextStyle(color: AC.muted, fontSize: 12)),
                            const SizedBox(height: 4),
                            StatusChip(p.stockLabel),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.remove_circle_outline_rounded), color: AC.primary, onPressed: () => store.setStock(p, p.stock - 1)),
                      SizedBox(width: 26, child: Text('${p.stock}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      IconButton(icon: const Icon(Icons.add_circle_rounded), color: AC.primary, onPressed: () => store.setStock(p, p.stock + 1)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sum(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AC.muted, fontSize: 12)),
        ],
      ),
    ),
  );
}