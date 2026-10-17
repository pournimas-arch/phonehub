import 'package:flutter/material.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/Admin/phone_extras.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/Admin/phone_shared_widgets.dart';
import 'package:phonehub/Admin/product_detail_screen.dart';
import 'package:phonehub/Admin/phone_form_screen.dart';

// ===========================================================================
// Products list
// ===========================================================================

/// Phones list: summary, stock tabs with counts, search, filter & sort sheet.
class ProductsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ProductsScreen({super.key, this.onBack});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}
class _ProductsScreenState extends State<ProductsScreen> {
  static const tabs = ['All', 'In stock', 'Low stock', 'Out of stock'];
  static const visibilities = ['All', 'Active', 'Hidden'];
  static const sorts = ['Default', 'Price: low to high', 'Price: high to low', 'Name A-Z', 'Stock: low to high'];

  String tab = 'All';
  String brand = 'All';
  String condition = 'All conditions';
  String visibility = 'All';
  String sort = 'Default';
  String query = '';

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  bool _matchTab(Phone p, String t) => t == 'All' || p.stockLabel == t;

  int _count(String t) => store.phones.where((p) => _matchTab(p, t)).length;

  bool get _filtersOn => brand != 'All' || condition != 'All conditions' || visibility != 'All' || sort != 'Default';
  int get _filterCount =>
      (brand != 'All' ? 1 : 0) + (condition != 'All conditions' ? 1 : 0) + (visibility != 'All' ? 1 : 0) + (sort != 'Default' ? 1 : 0);

  void _resetFilters() => setState(() {
    brand = 'All';
    condition = 'All conditions';
    visibility = 'All';
    sort = 'Default';
  });

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          void pick(VoidCallback f) {
            setState(f);
            setM(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Filter & sort', style: TextStyle(fontSize: (AppText.title - 2), fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(onPressed: () => pick(_resetFilters), child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800))),
                    ],
                  ),
                  phoneFilterGroup('Brand', ['All', ...store.brands.map((b) => b.name)], brand, (v) => pick(() => brand = v)),
                  phoneFilterGroup('Condition', ['All conditions', ...conditions], condition, (v) => pick(() => condition = v)),
                  phoneFilterGroup('Visibility', visibilities, visibility, (v) => pick(() => visibility = v)),
                  phoneFilterGroup('Sort by', sorts, sort, (v) => pick(() => sort = v)),
                  const SizedBox(height: 18),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Show phones')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary() {
    final all = store.phones;
    final units = all.fold<int>(0, (s, p) => s + p.stock);
    final value = all.fold<int>(0, (s, p) => s + p.stock * p.price);
    return phoneSummaryCard([
      phoneStat(Icons.smartphone_rounded, 'Phones', '${all.length}'),
      phoneStatDivider(),
      phoneStat(Icons.inventory_2_rounded, 'Units', '$units'),
      phoneStatDivider(),
      phoneStat(Icons.account_balance_wallet_rounded, 'Stock value', inr(value)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = query.trim().toLowerCase();
        final list = store.phones.where((p) {
          if (!_matchTab(p, tab)) return false;
          if (brand != 'All' && p.brand != brand) return false;
          if (condition != 'All conditions' && p.condition != condition) return false;
          if (visibility == 'Active' && !p.active) return false;
          if (visibility == 'Hidden' && p.active) return false;
          if (q.isNotEmpty && !('${p.name} ${p.brand} ${p.storage}'.toLowerCase().contains(q))) return false;
          return true;
        }).toList();

        switch (sort) {
          case 'Price: low to high':
            list.sort((a, b) => a.price.compareTo(b.price));
            break;
          case 'Price: high to low':
            list.sort((a, b) => b.price.compareTo(a.price));
            break;
          case 'Name A-Z':
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            break;
          case 'Stock: low to high':
            list.sort((a, b) => a.stock.compareTo(b.stock));
            break;
        }

        final listValue = list.fold<int>(0, (s, p) => s + p.stock * p.price);

        return Scaffold(
          appBar: phoneAppBar(
            context,
            'Products',
            actions: [
              Badge(
                isLabelVisible: _filtersOn,
                label: Text('$_filterCount'),
                alignment: const Alignment(0.5, -0.5),
                child: IconButton(icon: const Icon(Icons.tune_rounded), tooltip: 'Filter & sort', onPressed: _openFilters),
              ),
              const SizedBox(width: 6),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _push(const PhoneFormScreen()),
            backgroundColor: AC.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add phone', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              _summary(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SearchBox(hint: 'Search phones, brands or storage', onChanged: (v) => setState(() => query = v)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ChipTabs(
                  items: [for (final t in tabs) '$t ${_count(t)}'],
                  selected: '$tab ${_count(tab)}',
                  onSelect: (v) => setState(() => tab = tabs.firstWhere((t) => v.startsWith('$t '), orElse: () => 'All')),
                ),
              ),
              if (_filtersOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (brand != 'All') phoneActiveChip(brand, () => setState(() => brand = 'All')),
                      if (condition != 'All conditions') phoneActiveChip(condition, () => setState(() => condition = 'All conditions')),
                      if (visibility != 'All') phoneActiveChip(visibility, () => setState(() => visibility = 'All')),
                      if (sort != 'Default') phoneActiveChip(sort, () => setState(() => sort = 'Default')),
                      ActionChip(
                        label: const Text('Clear all', style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w800, color: AC.danger)),
                        backgroundColor: AC.danger.withValues(alpha: 0.08),
                        side: BorderSide.none,
                        onPressed: _resetFilters,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    Text('${list.length} ${list.length == 1 ? 'phone' : 'phones'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1))),
                    const Spacer(),
                    if (list.isNotEmpty) Text('Stock worth ${inr(listValue)}', style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyState(icon: Icons.smartphone_outlined, title: 'No phones found', subtitle: 'Try another tab, search or filter'),
                )
              else
                for (final p in list) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _tile(p)),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(Phone p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(radius: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _push(ProductDetailScreen(phone: p)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Opacity(opacity: p.active ? 1 : 0.4, child: PhoneThumb(p, size: 52)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${p.brand} • ${p.storage} • ${p.condition}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(inr(p.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(inr(p.mrp), style: const TextStyle(color: AC.muted, fontSize: 10, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 6),
                        phonePill('${p.off}% OFF', AC.success),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  phonePill('${p.stock} left', statusColor(p.stockLabel)),
                  const SizedBox(height: 2),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: p.active,
                      activeColor: AC.success,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        p.active = v;
                        store.changed();
                        snack(context, v ? '${p.name} is visible to customers' : '${p.name} is hidden from customers');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}