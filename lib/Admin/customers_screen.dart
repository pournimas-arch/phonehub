import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/Admin/orders_screen.dart';
import 'package:phonehub/Admin/products_screen.dart';
import 'admin_theme.dart';
import 'admin_data.dart';


/// Customer list with search and filter.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String query = '';
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = store.customers.where((c) {
          if (filter == 'Active' && c.blocked) return false;
          if (filter == 'Blocked' && !c.blocked) return false;
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q) || c.phone.contains(q);
        }).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Customers')),
          body: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), child: SearchBox(hint: 'Search name, email or phone', onChanged: (v) => setState(() => query = v))),
              Padding(padding: const EdgeInsets.only(left: 16), child: ChipTabs(items: const ['All', 'Active', 'Blocked'], selected: filter, onSelect: (v) => setState(() => filter = v))),
              const SizedBox(height: 10),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.people_outline_rounded, title: 'No customers found')
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final orders = store.ordersOf(c.id);
                    final spent = orders.where((o) => !o.cancelled).fold<int>(0, (s, o) => s + o.total);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: cardDeco(radius: 16),
                      child: ListTile(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id))),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: CircleAvatar(radius: 24, backgroundColor: c.blocked ? AC.muted : AC.primary, child: Text(c.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
                        title: Row(children: [Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))), if (c.blocked) ...[const SizedBox(width: 8), const StatusChip('Blocked')]]),
                        subtitle: Text('${c.email}\n${orders.length} orders • ${inr(spent)}', style: const TextStyle(color: AC.muted, fontSize: 12, height: 1.4)),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded, color: AC.muted),
                      ),
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
}

/// Customer detail: profile, addresses, wishlist, order history, block / unblock.
class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.customerById(customerId);
        if (c == null) return const Scaffold(body: EmptyState(icon: Icons.error_outline, title: 'Customer not found'));
        final orders = store.ordersOf(c.id);
        final spent = orders.where((o) => !o.cancelled).fold<int>(0, (s, o) => s + o.total);
        final wish = c.wishlist.map(store.phoneById).whereType<Phone>().toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Customer')),
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
                        CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Text(c.initial, style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900, fontSize: 24))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                              Text(c.email, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                              Text(c.phone, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _hero('${orders.length}', 'Orders'),
                        _hero(inr(spent), 'Spent'),
                        _hero(fmtDate(c.joined), 'Joined'),
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
                        Clipboard.setData(ClipboardData(text: c.phone));
                        snack(context, 'Number copied');
                      },
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.email));
                        snack(context, 'Email copied');
                      },
                      icon: const Icon(Icons.email_rounded, size: 18),
                      label: const Text('Email'),
                    ),
                  ),
                ],
              ),
              SectionTitle('Saved addresses'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: c.addresses.isEmpty
                    ? const Text('No saved addresses', style: TextStyle(color: AC.muted))
                    : Column(
                  children: [
                    for (final a in c.addresses)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.location_on_rounded, color: AC.primary, size: 20), const SizedBox(width: 10), Expanded(child: Text(a, style: const TextStyle(fontSize: 13, height: 1.35)))]),
                      ),
                  ],
                ),
              ),
              SectionTitle('Wishlist (${wish.length})'),
              if (wish.isEmpty)
                Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: cardDeco(), child: const Text('Nothing saved', style: TextStyle(color: AC.muted)))
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wish.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => Container(
                      width: 190,
                      padding: const EdgeInsets.all(10),
                      decoration: cardDeco(radius: 16),
                      child: Row(
                        children: [
                          PhoneThumb(wish[i], size: 44),
                          const SizedBox(width: 10),
                          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(wish[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)), Text(inr(wish[i].price), style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w800, fontSize: 12.5))])),
                        ],
                      ),
                    ),
                  ),
                ),
              SectionTitle('Order history'),
              if (orders.isEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: cardDeco(), child: const Text('No orders yet', style: TextStyle(color: AC.muted))),
              for (final o in orders) OrderTile(order: o),
              const SizedBox(height: 14),
              Container(
                decoration: cardDeco(),
                child: SwitchListTile(
                  value: c.blocked,
                  activeColor: AC.danger,
                  onChanged: (v) async {
                    final ok = await confirmDialog(context, v ? 'Block ${c.name}?' : 'Unblock ${c.name}?', v ? 'They will not be able to place new orders until you unblock them.' : 'They can place orders again.', yes: v ? 'Block' : 'Unblock', danger: v);
                    if (ok) {
                      c.blocked = v;
                      store.changed();
                    }
                  },
                  title: const Text('Block customer', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Stops new orders from this account', style: TextStyle(fontSize: 12, color: AC.muted)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(String v, String l) => Expanded(
    child: Column(
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
        const SizedBox(height: 2),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
      ],
    ),
  );
}

/// Brands: add, edit, enable / disable, delete.
class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  Future<void> _edit(BuildContext context, {Brand? brand}) async {
    final name = TextEditingController(text: brand?.name ?? '');
    Color color = brand?.color ?? swatches[0];
    final saved = await showModalBottomSheet<bool>(
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
              Text(brand == null ? 'Add brand' : 'Edit brand', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Brand name')),
              const SizedBox(height: 14),
              const Text('Brand colour (also used as logo colour)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in swatches)
                    GestureDetector(
                      onTap: () => setS(() => color = s),
                      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: s, shape: BoxShape.circle, border: Border.all(color: s == color ? AC.accent : Colors.transparent, width: 3))),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  final n = name.text.trim();
                  if (n.isEmpty) return;
                  final dup = store.brands.any((b) => b != brand && b.name.toLowerCase() == n.toLowerCase());
                  if (dup) {
                    snack(ctx, 'This brand already exists');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) {
      final n = name.text.trim();
      if (brand == null) {
        store.brands.add(Brand(n, color));
      } else {
        final old = brand.name;
        brand
          ..name = n
          ..color = color;
        for (final p in store.phones.where((p) => p.brand == old)) {
          p.brand = n;
        }
      }
      store.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Brands')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context), backgroundColor: AC.accent, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Add brand', style: TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          children: [
            for (final b in store.brands)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDeco(radius: 16),
                child: ListTile(
                  onTap: () => _edit(context, brand: b),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(b.name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${store.phoneCountOfBrand(b.name)} phones', style: const TextStyle(color: AC.muted, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(value: b.active, activeColor: AC.success, onChanged: (v) {
                        b.active = v;
                        store.changed();
                      }),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AC.danger),
                        onPressed: () async {
                          if (store.phoneCountOfBrand(b.name) > 0) {
                            snack(context, 'Remove or move the ${store.phoneCountOfBrand(b.name)} ${b.name} phones first');
                            return;
                          }
                          final ok = await confirmDialog(context, 'Delete ${b.name}?', 'This brand will be removed from the customer app.', yes: 'Delete', danger: true);
                          if (ok) {
                            store.brands.remove(b);
                            store.changed();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
