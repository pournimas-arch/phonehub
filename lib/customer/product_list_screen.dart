import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';

/// Screen 3 – Product List (3h)
/// Brand filter chips, search, sort & condition filter, 2-column grid with price, condition and wishlist heart.
class ProductListScreen extends StatefulWidget {
  final String? brand;
  final bool autofocus;
  const ProductListScreen({super.key, this.brand, this.autofocus = false});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late String selected = widget.brand ?? 'All';
  String query = '';
  _Sort sort = _Sort.relevance;
  String condition = 'Any';
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      await initializeCustomerData();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.code == 'permission-denied'
            ? 'Firebase access is blocked. Please check Firestore Rules.'
            : 'Could not load phones. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load phones. Please try again.';
      });
    }
  }

  int get _activeFilters => (sort != _Sort.relevance ? 1 : 0) + (condition != 'Any' ? 1 : 0);

  void _openFilter() {
    var tmpSort = sort;
    var tmpCond = condition;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget chip(String label, bool on, VoidCallback tap) => GestureDetector(
            onTap: () => setSheet(tap),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: on ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: on ? AppColors.primary : AppColors.border),
              ),
              child: Text(label, style: TextStyle(color: on ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sort & Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 16),
                const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _Sort.values) chip(s.label, tmpSort == s, () => tmpSort = s),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Condition', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in const ['Any', 'Like New', 'Good', 'Fair']) chip(c, tmpCond == c, () => tmpCond = c),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          tmpSort = _Sort.relevance;
                          tmpCond = 'Any';
                        }),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            sort = tmpSort;
                            condition = tmpCond;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = phones.where((p) {
      final okBrand = selected == 'All' || p.brand == selected;
      final okQuery = query.isEmpty || p.name.toLowerCase().contains(query.toLowerCase()) || p.brand.toLowerCase().contains(query.toLowerCase());
      final okCond = condition == 'Any' || p.condition == condition;
      return okBrand && okQuery && okCond;
    }).toList();
    switch (sort) {
      case _Sort.priceLow:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _Sort.priceHigh:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _Sort.rating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _Sort.discount:
        filtered.sort((a, b) => b.off.compareTo(a.off));
        break;
      case _Sort.relevance:
        break;
    }

    return Scaffold(
      appBar: AppBar(title: Text(selected == 'All' ? 'All Phones' : selected)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: cardDeco(radius: 16),
                    child: TextField(
                      autofocus: widget.autofocus,
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'Search phones…',
                        hintStyle: const TextStyle(color: AppColors.muted),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        suffixIcon: query.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => query = '')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _openFilter,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Badge(
                      isLabelVisible: _activeFilters > 0,
                      backgroundColor: AppColors.accent,
                      label: Text('$_activeFilters'),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: brands.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final label = i == 0 ? 'All' : brands[i - 1];
                final on = label == selected;
                return GestureDetector(
                  onTap: () => setState(() => selected = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: on ? AppColors.primary : AppColors.border),
                      boxShadow: on ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                    ),
                    child: Text(label, style: TextStyle(color: on ? Colors.white : AppColors.text, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${filtered.length} phones found', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.muted),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 8),
                    TextButton.icon(onPressed: () { setState(() { _loading = true; _loadError = null; }); _loadProducts(); }, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                  ],
                ),
              ),
            )
                : filtered.isEmpty
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: AppColors.muted),
                  SizedBox(height: 10),
                  Text('No phones found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, mainAxisExtent: 252),
              itemBuilder: (_, i) => PhoneCard(phone: filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Sort {
  relevance('Relevance'),
  priceLow('Price: Low to High'),
  priceHigh('Price: High to Low'),
  rating('Top Rated'),
  discount('Biggest Discount');

  final String label;
  const _Sort(this.label);
}