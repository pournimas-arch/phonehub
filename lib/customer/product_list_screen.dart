import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:phonehub/customer/shared_ui.dart';
import 'package:phonehub/app_text.dart';

import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'checkout_ui.dart';

const _productListBorder = Color(0xFFDCE8FF);

/// Product List screen styled to match Wishlist / Cart screens.
/// Keeps existing product data, search, brand selection, sorting, condition
/// filters, PhoneCard behaviour and customer Firebase initialization.
class ProductListScreen extends StatefulWidget {
  final String? brand;
  final bool autofocus;

  const ProductListScreen({
    super.key,
    this.brand,
    this.autofocus = false,
  });

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

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brand != widget.brand && widget.brand != null) {
      selected = widget.brand!;
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

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

  int get _activeFilters =>
      (sort != _Sort.relevance ? 1 : 0) + (condition != 'Any' ? 1 : 0);

  bool get _hasFilters =>
      selected != 'All' ||
          query.trim().isNotEmpty ||
          sort != _Sort.relevance ||
          condition != 'Any';

  void _openFilter() {
    var tmpSort = sort;
    var tmpCond = condition;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget chip(String label, bool on, VoidCallback tap) {
            return GestureDetector(
              onTap: tap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: on ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: AppText.small,
                  ),
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Sort & Filter',
                      style: TextStyle(
                        fontSize: AppText.subtitle,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Sort by',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppText.small,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final s in _Sort.values)
                          chip(s.label, tmpSort == s, () {
                            setSheet(() => tmpSort = s);
                          }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Condition',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppText.small,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final c in const ['Any', 'Like New', 'Good', 'Fair'])
                          chip(c, tmpCond == c, () {
                            setSheet(() => tmpCond = c);
                          }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: checkoutLine),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              textStyle: const TextStyle(
                                fontSize: AppText.small,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () => setSheet(() {
                              tmpSort = _Sort.relevance;
                              tmpCond = 'Any';
                            }),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientButton(
                            height: 42,
                            onTap: () {
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
              ),
            ),
          );
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      selected = 'All';
      query = '';
      sort = _Sort.relevance;
      condition = 'Any';
    });
  }

  List<Phone> _filteredPhones() {
    final normalizedQuery = query.trim().toLowerCase();
    final result = phones.where((p) {
      final okBrand = selected == 'All' || p.brand == selected;
      final okQuery = normalizedQuery.isEmpty ||
          p.name.toLowerCase().contains(normalizedQuery) ||
          p.brand.toLowerCase().contains(normalizedQuery);
      final okCond = condition == 'Any' || p.condition == condition;
      return okBrand && okQuery && okCond;
    }).toList();

    switch (sort) {
      case _Sort.priceLow:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _Sort.priceHigh:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _Sort.rating:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _Sort.discount:
        result.sort((a, b) => b.off.compareTo(a.off));
        break;
      case _Sort.relevance:
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPhones();

    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: glassDeco(radius: 16),
                        child: TextField(
                          autofocus: widget.autofocus,
                          onChanged: (value) => setState(() => query = value),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: AppText.small,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search phones…',
                            hintStyle: const TextStyle(
                              color: AppColors.muted,
                              fontSize: AppText.small,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.muted,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 17,
                              ),
                              onPressed: () =>
                                  setState(() => query = ''),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    GestureDetector(
                      onTap: _openFilter,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: brandGradient,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color:
                              AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 9,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Badge(
                            isLabelVisible: _activeFilters > 0,
                            backgroundColor: AppColors.accent,
                            label: Text(
                              '$_activeFilters',
                              style:
                              const TextStyle(fontSize: AppText.caption),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: brands.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final label = i == 0 ? 'All' : brands[i - 1];
                    final on = label == selected;
                    return GestureDetector(
                      onTap: () => setState(() => selected = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: on ? AppColors.primary : checkoutLine,
                          ),
                          boxShadow: on
                              ? [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.15),
                              blurRadius: 7,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: on ? Colors.white : AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: AppText.small,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 13, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filtered.length} ${filtered.length == 1 ? 'phone' : 'phones'} found',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: AppText.small,
                        ),
                      ),
                    ),
                    if (_hasFilters)
                      GestureDetector(
                        onTap: _clearFilters,
                        child: const Text(
                          'Clear all',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: AppText.small,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                )
                    : _loadError != null
                    ? _errorState()
                    : filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadProducts,
                  child: GridView.builder(
                    padding:
                    const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: filtered.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      mainAxisExtent: 280,
                    ),
                    itemBuilder: (_, i) =>
                        PhoneCard(phone: filtered[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: glassDeco(radius: 14),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    selected == 'All' ? 'All Phones' : selected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'FIND YOUR NEXT PHONE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _productListBorder),
              ),
              child: Text(
                '${phones.length} ${phones.length == 1 ? 'phone' : 'phones'}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppText.caption,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _productListBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppText.body,
                color: AppColors.text,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 150,
              child: GradientButton(
                height: 44,
                onTap: _loadProducts,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Retry',
                      style: TextStyle(fontSize: AppText.small),
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

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _productListBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No phones found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.subtitle,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another search or clear the filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: AppText.small,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 190,
              child: GradientButton(
                height: 44,
                onTap: _clearFilters,
                child: const Text(
                  'Clear filters',
                  style: TextStyle(fontSize: AppText.small),
                ),
              ),
            ),
          ],
        ),
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
