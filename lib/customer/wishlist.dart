import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import 'package:phonehub/app_text.dart';

import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'checkout_ui.dart';
import 'product_list_screen.dart';
import 'product_detail_screen.dart';

const _cardBorder = Color(0xFFDCE8FF);

/// Wishlist screen styled to match CartScreen.
///
/// Preserves Firebase authentication, customer data initialization,
/// wishlist ValueNotifier, product navigation and existing theme helpers.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _error = 'Please sign in to view your wishlist.';
        });
        return;
      }

      // Keep the existing customer data and Firestore initialization.
      await initializeCustomerData();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.code == 'permission-denied'
            ? 'Access denied. Please check your Firestore Rules.'
            : 'Could not load your wishlist. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load your wishlist. Please try again.';
      });
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
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER - matching the CartScreen header
  // ------------------------------------------------------------

  Widget _header() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: wishlist,
      builder: (context, ids, _) {
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
                        'My Wishlist',
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
                        'YOUR FAVOURITE PHONES',
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
                if (ids.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Text(
                      '${ids.length} ${ids.length == 1 ? 'item' : 'items'}',
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
      },
    );
  }

  // ------------------------------------------------------------
  // MAIN CONTENT
  // ------------------------------------------------------------

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_error != null) {
      return _errorState();
    }

    return ValueListenableBuilder<Set<String>>(
      valueListenable: wishlist,
      builder: (context, ids, _) {
        final saved = phones.where((p) => ids.contains(p.id)).toList();

        if (saved.isEmpty) {
          return _emptyState();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Saved Phones',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    '${saved.length} ${saved.length == 1 ? 'phone' : 'phones'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: saved.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 280,
                ),
                itemBuilder: (context, index) {
                  return _WishlistPhoneCard(phone: saved[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

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
                Icons.favorite_border_rounded,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your wishlist is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.subtitle,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Save the phones you love and find them here whenever you need them.',
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
                height: 46,
                onTap: _browsePhones,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_android_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Browse phones',
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

  // ------------------------------------------------------------
  // ERROR STATE
  // ------------------------------------------------------------

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
                border: Border.all(color: _cardBorder, width: 1.5),
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
              _error!,
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
                onTap: _loadWishlist,
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

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

  void _browsePhones() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductListScreen(),
      ),
    );
  }
}

// ============================================================
// WISHLIST PRODUCT CARD
// ============================================================

class _WishlistPhoneCard extends StatelessWidget {
  final Phone phone;

  const _WishlistPhoneCard({required this.phone});

  void _openProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(phone: phone),
      ),
    );
  }

  void _removeFromWishlist(BuildContext context) {
    // Capture the messenger before updating the wishlist.
    final messenger = ScaffoldMessenger.of(context);

    // Uses the existing wishlist operation from data.dart.
    toggleWish(phone.id);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${phone.name} removed from wishlist'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mrp = phone.mrp > phone.price ? phone.mrp : 0;
    final hasDiscount = mrp > phone.price;

    return Container(
      decoration: glassDeco(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image and wishlist action.
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () => _openProduct(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.white.withValues(alpha: 0.60),
                    padding: const EdgeInsets.all(10),
                    child: PhoneImage(
                      phone: phone,
                      height: 125,
                      iconSize: 42,
                    ),
                  ),
                  if (phone.off > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: Text(
                          '${phone.off}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _removeFromWishlist(context),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 18,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Product information.
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openProduct(context),
                    child: Text(
                      phone.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: AppText.small,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 2,
                    children: [
                      Text(
                        rupee(phone.price),
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: AppText.body,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (hasDiscount)
                        Text(
                          rupee(mrp),
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: AppText.caption,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: OutlinedButton(
                      onPressed: () => _openProduct(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor:
                        AppColors.primary.withValues(alpha: 0.04),
                        side: const BorderSide(color: _cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View details',
                              style: TextStyle(
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}