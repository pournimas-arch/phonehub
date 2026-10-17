import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'theme.dart';
import 'data.dart';
import 'checkout_ui.dart';
import 'package:phonehub/app_text.dart';

const Color _cardBorder = Color(0xFFDCE8FF);

/// Coupons & Offers screen styled to match WishlistScreen.
///
/// Preserves Firestore coupon loading, local fallback offers, search, filters,
/// copy-to-clipboard, expandable terms, retry handling, and the existing Coupon
/// model used by the cart. No other screen or file needs to be changed.
class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  static const List<String> _filters = [
    'All',
    'Flat off',
    'Percent off',
    'Free delivery',
    'First order',
  ];

  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  String _filter = 'All';
  String? _copiedCode;
  String? _expandedCode;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    return FirebaseFirestore.instance
        .collection('coupons')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  void _refresh() {
    setState(() => _stream = _buildStream());
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  bool _isCurrentlyValid(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    // Support the expiry field names used by older and newer coupon documents.
    final expiry = _dateValue(
      data['expiresAt'] ?? data['expiryDate'] ?? data['validUntil'] ?? data['endDate'],
    );
    // Coupons without an expiry date remain valid until disabled by an admin.
    return expiry == null || !expiry.isBefore(DateTime.now());
  }

  Coupon _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Coupon(
      code: (data['code'] ?? doc.id).toString().trim().toUpperCase(),
      title: (data['title'] ?? data['name'] ?? 'Special offer').toString(),
      note: (data['note'] ?? data['description'] ?? '').toString(),
      flat: _asInt(data['flat'] ?? data['flatDiscount']),
      percent: _asInt(data['percent'] ?? data['discountPercent']),
      maxOff: _asInt(data['maxOff'] ?? data['maxDiscount']),
      minOrder: _asInt(data['minOrder'] ?? data['minimumOrder']),
      freeDelivery: data['freeDelivery'] == true,
      firstOrderOnly: data['firstOrderOnly'] == true,
    );
  }

  bool _matches(Coupon coupon) {
    final query = _query.trim().toLowerCase();

    if (query.isNotEmpty) {
      final searchable =
      '${coupon.code} ${coupon.title} ${coupon.note}'.toLowerCase();
      if (!searchable.contains(query)) return false;
    }

    switch (_filter) {
      case 'Flat off':
        return coupon.flat > 0;
      case 'Percent off':
        return coupon.percent > 0;
      case 'Free delivery':
        return coupon.freeDelivery;
      case 'First order':
        return coupon.firstOrderOnly;
      default:
        return true;
    }
  }

  String _discountLabel(Coupon coupon) {
    if (coupon.percent > 0) return '${coupon.percent}%\nOFF';
    if (coupon.flat > 0) return '₹${coupon.flat}\nOFF';
    if (coupon.freeDelivery) return 'FREE\nDELIVERY';
    return 'SPECIAL\nOFFER';
  }

  Future<void> _copy(Coupon coupon) async {
    try {
      await Clipboard.setData(ClipboardData(text: coupon.code));
      if (!mounted) return;

      setState(() => _copiedCode = coupon.code);

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('${coupon.code} copied. Paste it in your cart.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && _copiedCode == coupon.code) {
          setState(() => _copiedCode = null);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy the coupon code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.5,
                        ),
                      );
                    }

                    // Continue showing the app's existing offers when Firestore
                    // is empty or unavailable.
                    final bool failed = snapshot.hasError;
                    final firestoreDocs = snapshot.hasData
                        ? snapshot.data!.docs.where(_isCurrentlyValid).toList()
                        : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final List<Coupon> all = firestoreDocs.isNotEmpty
                        ? firestoreDocs.map(_fromDoc).toList()
                        : coupons;
                    final visible = all.where(_matches).toList();

                    return Column(
                      children: [
                        _searchBar(),
                        const SizedBox(height: 12),
                        _filterChips(),
                        const SizedBox(height: 8),
                        if (failed) _offlineBanner(),
                        Expanded(
                          child: visible.isEmpty
                              ? _emptyState()
                              : ListView(
                            padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 10,
                                  left: 2,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius:
                                        BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Available Offers',
                                        style: TextStyle(
                                          color: AppColors.text,
                                          fontSize: AppText.body,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${visible.length} ${visible.length == 1 ? 'offer' : 'offers'}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: AppText.caption,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final coupon in visible) ...[
                                _card(coupon),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header follows the same compact glass-button and typography style as
  // WishlistScreen. Only this screen's UI is changed.
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Coupons & Offers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'EXCLUSIVE DEALS FOR YOU',
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
              width: 42,
              height: 42,
              decoration: glassDeco(radius: 14),
              child: const Icon(
                Icons.local_offer_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: glassDeco(radius: 14),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (value) => setState(() => _query = value),
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: AppText.body,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search coupon code or offer',
            hintStyle: const TextStyle(
              color: AppColors.muted,
              fontSize: AppText.small,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 21,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.muted,
                size: 20,
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.72),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _filter == filter;

          return GestureDetector(
            onTap: () => setState(() => _filter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? AppColors.primary : _cardBorder,
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: AppText.small,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _offlineBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Could not load latest offers. Showing saved offers.',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: AppText.small,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _refresh,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Retry',
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
                border: Border.all(color: _cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No coupons found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.subtitle,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different search or filter to discover available offers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: AppText.small,
                height: 1.5,
              ),
            ),
            if (_query.isNotEmpty || _filter != 'All') ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: GradientButton(
                  height: 44,
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _filter = 'All';
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_off_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Clear filters',
                        style: TextStyle(fontSize: AppText.small),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.success,
              fontSize: AppText.caption,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _terms(Coupon coupon) {
    final terms = <String>[];

    if (coupon.minOrder > 0) {
      terms.add('Valid on orders of ₹${coupon.minOrder} or more.');
    }
    if (coupon.percent > 0) {
      terms.add(
        coupon.maxOff > 0
            ? 'Get ${coupon.percent}% off, up to ₹${coupon.maxOff}.'
            : 'Get ${coupon.percent}% off on your order.',
      );
    }
    if (coupon.flat > 0) {
      terms.add('Flat ₹${coupon.flat} off on your order.');
    }
    if (coupon.freeDelivery) {
      terms.add('Delivery charges are waived.');
    }
    if (coupon.firstOrderOnly) {
      terms.add('Valid on your first order only.');
    }
    terms.add('Paste the code in your cart before payment.');
    terms.add('Only one coupon can be used per order.');

    return terms;
  }

  Widget _card(Coupon coupon) {
    final copied = _copiedCode == coupon.code;
    final expanded = _expandedCode == coupon.code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _expandedCode = expanded ? null : coupon.code;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: glassDeco(
            radius: 18,
            borderColor: copied ? AppColors.success : null,
            borderWidth: copied ? 1.6 : 1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _discountLabel(coupon),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: AppText.small,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppText.body,
                            color: AppColors.text,
                          ),
                        ),
                        if (coupon.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            coupon.note,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: AppText.small,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (coupon.minOrder > 0)
                              _tag(
                                Icons.shopping_bag_outlined,
                                'Min ₹${coupon.minOrder}',
                              ),
                            if (coupon.percent > 0 && coupon.maxOff > 0)
                              _tag(
                                Icons.savings_outlined,
                                'Up to ₹${coupon.maxOff}',
                              ),
                            if (coupon.freeDelivery)
                              _tag(
                                Icons.local_shipping_rounded,
                                'Free delivery',
                              ),
                            if (coupon.firstOrderOnly)
                              _tag(Icons.star_rounded, 'First order'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Text(
                        coupon.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppText.body,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: copied ? AppColors.success : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _copy(coupon),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              copied ? 'Copied' : 'Copy',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.small,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    expanded ? 'Hide details' : 'View details',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.small,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (copied)
                    const Text(
                      'Ready to use',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: _cardBorder),
                const SizedBox(height: 10),
                for (final term in _terms(coupon))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 8),
                          child: Icon(
                            Icons.circle,
                            size: 5,
                            color: AppColors.muted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            term,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: AppText.small,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
