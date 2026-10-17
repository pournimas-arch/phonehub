import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/customer/checkout_ui.dart';
import 'package:phonehub/customer/data.dart';
import 'package:phonehub/customer/product_list_screen.dart';
import 'package:phonehub/customer/theme.dart';
import 'package:phonehub/app_text.dart';

// Same look as the Cart / Orders screens: shared gradient background, glass cards,
// header tile and gradient buttons come from checkout_ui.dart.
// Text sizes use the smaller steps of the AppText scale, same as the Cart screen.

const _cardBorder = Color(0xFFDCE8FF);

enum _Sort { name, mostPhones, lowestPrice }

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle(this.title, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: AppText.body, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      if (icon != null) Icon(icon, color: AppColors.accent, size: 18),
    ],
  );
}

/// Categories screen
/// Header, live brand search, sort chips, grid / list toggle, brand cards with
/// phone count and starting price, "View all" and search-all fallback, empty state.
class CategoriesScreen extends StatefulWidget {
  final bool showBack;
  const CategoriesScreen({super.key, this.showBack = false});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _search = TextEditingController();
  String query = '';
  bool gridView = true;
  _Sort sort = _Sort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---- Navigation ----
  void _open([String? brand]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => brand == null ? const ProductListScreen() : ProductListScreen(brand: brand)),
    );
  }

  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen(autofocus: true)));
  }

  // ---- Data helpers ----
  int _countFor(String brand) => phones.where((p) => p.brand == brand).length;

  /// Lowest selling price among the brand's phones (0 when the brand has none).
  int _minPriceFor(String brand) {
    int? min;
    for (final p in phones) {
      if (p.brand != brand) continue;
      if (min == null || p.price < min) min = p.price;
    }
    return min ?? 0;
  }

  List<String> _visibleBrands() {
    final q = query.trim().toLowerCase();
    final list = brands.where((b) => q.isEmpty || b.toLowerCase().contains(q)).toList();
    switch (sort) {
      case _Sort.name:
        list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        break;
      case _Sort.mostPhones:
        list.sort((a, b) => _countFor(b).compareTo(_countFor(a)));
        break;
      case _Sort.lowestPrice:
        list.sort((a, b) {
          final pa = _minPriceFor(a);
          final pb = _minPriceFor(b);
          // Brands without phones go last.
          if (pa == 0 && pb == 0) return 0;
          if (pa == 0) return 1;
          if (pb == 0) return -1;
          return pa.compareTo(pb);
        });
        break;
    }
    return list;
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    final list = _visibleBrands();
    final searching = query.trim().isNotEmpty;

    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              _searchField(),
              const SizedBox(height: 10),
              _sortRow(),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? _emptyState(searching)
                    : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      sliver: SliverToBoxAdapter(child: _allPhonesCard()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      sliver: SliverToBoxAdapter(child: _sectionHeader(list.length)),
                    ),
                    if (gridView)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                                (context, i) => _brandGridCard(list[i]),
                            childCount: list.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, i) => _brandListCard(list[i]),
                            childCount: list.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header: same layout as the Cart screen (glass icon tile, title, caption, count pill).
  Widget _header() {
    final count = brands.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (widget.showBack) ...[
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: glassDeco(radius: 14),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 44,
              height: 44,
              decoration: glassDeco(radius: 14),
              child: const Icon(Icons.grid_view_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Categories',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'FIND YOUR NEXT PHONE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w700, letterSpacing: 0.9),
                  ),
                ],
              ),
            ),
            if (count > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder),
                ),
                child: Text('$count ${count == 1 ? 'brand' : 'brands'}', style: const TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              // Opens the full phone search.
              GestureDetector(
                onTap: _openSearch,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: glassDeco(radius: 12),
                  child: const Icon(Icons.search_rounded, size: 19, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Filters the brand list as you type (same input style as the coupon field in Cart).
  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => query = v),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w700, color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Search brands',
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: checkoutFieldFill,
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.muted),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
            onPressed: () {
              _search.clear();
              setState(() => query = '');
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  // Sort chips (same tinted chip style as the coupon chips) + grid / list toggle.
  Widget _sortRow() {
    Widget chip(String label, _Sort value) {
      final on = sort == value;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => sort = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? AppColors.primary : AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: Text(label, style: TextStyle(color: on ? Colors.white : AppColors.accent, fontSize: AppText.caption, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ),
      );
    }

    Widget toggle(IconData icon, bool grid) {
      final on = gridView == grid;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => gridView = grid);
        },
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: on ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: on ? AppColors.primary : AppColors.muted),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip('A-Z', _Sort.name),
                  const SizedBox(width: 8),
                  chip('Most phones', _Sort.mostPhones),
                  const SizedBox(width: 8),
                  chip('Lowest price', _Sort.lowestPrice),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: glassDeco(radius: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                toggle(Icons.grid_view_rounded, true),
                toggle(Icons.view_list_rounded, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // "All phones" shortcut card (same icon tile + label pattern as the Cart address card).
  Widget _allPhonesCard() {
    final total = phones.length;
    return GestureDetector(
      onTap: () => _open(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: glassDeco(radius: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.smartphone_rounded, color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Browse everything', style: TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('All phones ($total)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.small, color: AppColors.text)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: const Text('View all', style: TextStyle(color: AppColors.primary, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(int shown) {
    return Row(
      children: [
        const Expanded(child: _SectionTitle('Shop by brand')),
        Text('$shown ${shown == 1 ? 'brand' : 'brands'}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ---- Empty state ----
  Widget _emptyState(bool searching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder, width: 1.5),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Icon(searching ? Icons.search_off_rounded : Icons.grid_view_rounded, size: 46, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(searching ? 'No matching brands' : 'No brands yet', style: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              searching ? 'Try a different brand name or search all phones' : 'Brands will show up here',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: AppText.small),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 180,
              child: GradientButton(
                height: 44,
                onTap: searching ? _openSearch : () => _open(),
                child: Text(searching ? 'Search all phones' : 'Browse phones', style: const TextStyle(fontSize: AppText.small)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Brand cards ----
  /// Small phone illustration inside a tinted circle (same drawing as before, scaled).
  Widget _brandArt(String brand, Color color, {double size = 78}) {
    final k = size / 104;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.07))),
          Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 48 * k,
              height: 78 * k,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13 * k),
                border: Border.all(color: color.withValues(alpha: 0.65), width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 12 * k, offset: Offset(0, 5 * k))],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 5 * k,
                    left: 5 * k,
                    child: Container(
                      width: 15 * k,
                      height: 22 * k,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5 * k)),
                      child: Icon(Icons.camera_alt_rounded, color: color, size: 11 * k),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 4 * k,
            bottom: 6 * k,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: Text(brand.isNotEmpty ? brand[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: AppText.caption, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandGridCard(String brand) {
    final color = brandColors[brand] ?? AppColors.primary;
    final count = _countFor(brand);
    final from = _minPriceFor(brand);

    return GestureDetector(
      onTap: () => _open(brand),
      child: Container(
        decoration: glassDeco(radius: 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned(
                top: -33,
                right: -31,
                child: Container(width: 105, height: 105, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.09))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Center(child: _brandArt(brand, color, size: 84))),
                    const SizedBox(height: 8),
                    Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: AppText.body, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            count == 0 ? 'Coming soon' : '$count ${count == 1 ? 'phone' : 'phones'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.arrow_outward_rounded, size: 15, color: color),
                        ),
                      ],
                    ),
                    if (from > 0) ...[
                      const SizedBox(height: 2),
                      Text('From ${rupee(from)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontSize: AppText.small, fontWeight: FontWeight.w900)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandListCard(String brand) {
    final color = brandColors[brand] ?? AppColors.primary;
    final count = _countFor(brand);
    final from = _minPriceFor(brand);

    return GestureDetector(
      onTap: () => _open(brand),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: glassDeco(radius: 18),
        child: Row(
          children: [
            _brandArt(brand, color, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: AppText.body, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(count == 0 ? 'Coming soon' : '$count ${count == 1 ? 'phone' : 'phones'}', style: const TextStyle(color: AppColors.muted, fontSize: AppText.caption, fontWeight: FontWeight.w600)),
                  if (from > 0) ...[
                    const SizedBox(height: 3),
                    Text('From ${rupee(from)}', style: const TextStyle(color: AppColors.primary, fontSize: AppText.small, fontWeight: FontWeight.w900)),
                  ],
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_outward_rounded, size: 17, color: color),
            ),
          ],
        ),
      ),
    );
  }
}