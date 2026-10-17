import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phonehub/customer/category.dart';
import 'package:phonehub/customer/checkout_ui.dart';
import 'package:phonehub/customer/notification.dart';
import 'package:phonehub/customer/saved_addresses.dart';
import 'package:phonehub/customer/wishlist.dart';
import 'package:phonehub/role_select_screen.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'product_list_screen.dart';
import 'my_cart.dart';
import 'edit_profile_screen.dart';
import 'shared_ui.dart';
import 'my_orders_screen.dart';
import 'order_tracking_screen.dart';
import 'profile_navigation.dart';
import 'package:phonehub/app_text.dart';

/// Holds the bottom navigation: Home, Categories, Cart, Orders, Profile
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeTab(),
          CategoriesScreen(),
          CartScreen(showBack: false),
          OrdersScreen(),
          ProfileTab(),
        ],
      ),
      // Modern rounded bottom bar with soft shadow
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B2A5C).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              indicatorColor: AppColors.primary.withValues(alpha: 0.12),
              iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(
                  size: 23,
                  color: st.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.muted)),
              labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(
                  fontSize: AppText.caption,
                  fontWeight: st.contains(WidgetState.selected)
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: st.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.muted)),
            ),
            child: NavigationBar(
              selectedIndex: index,
              height: 64,
              elevation: 0,
              onDestinationSelected: (i) {
                HapticFeedback.selectionClick();
                setState(() => index = i);
              },
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home'),
                const NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Categories'),
                NavigationDestination(
                  icon: ValueListenableBuilder<List<CartItem>>(
                    valueListenable: cart,
                    builder: (_, items, __) => Badge(
                      isLabelVisible: items.isNotEmpty,
                      backgroundColor: AppColors.accent,
                      label: Text(items.length > 9 ? '9+' : '${items.length}'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                  selectedIcon: const Icon(Icons.shopping_cart_rounded),
                  label: 'Cart',
                ),
                const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Orders'),
                const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entry point for the Home screen. It always shows the shell, so the
/// bottom navigation (Home, Categories, Cart, Orders, Profile) is visible.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const MainShell();
}

// ---------------------------------------------------------------------------
// HOME TAB
// ---------------------------------------------------------------------------

const _hCardBorder = Color(0xFFDCE8FF);

/// Section title with the blue bar and an optional pill action (same bar as Cart).
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;

  const _SectionTitle(this.title, {this.action, this.onTap});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2))),
          if (action != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _hCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action!,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _Banner {
  final String tag;
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;

  const _Banner(this.tag, this.title, this.subtitle, this.cta, this.icon);
}

/// Banners are managed by the admin (Firestore `banners`).
List<_Banner> get _banners => homeBanners
    .map((b) =>
        _Banner(b.tag, b.title, b.subtitle, b.cta, Icons.phone_android_rounded))
    .toList();

/// Home screen
/// Same look as the Cart / Orders screens: shared gradient background, glass cards,
/// section titles, tinted chips and gradient buttons come from checkout_ui.dart.
/// Text sizes use the smaller steps of the AppText scale, same as the Cart screen.
/// Header, search, offers carousel, quick actions, active order, cart reminder with
/// free-delivery progress, brands, trust strip, best deals, popular phones.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final PageController _pc = PageController(viewportFraction: 0.94);
  Timer? _timer;
  int _page = 0;
  bool _loadingProducts = true;
  String? _productsError;

  // How many phones to show on Home (the rest is under "View all").
  static const int _homePhoneLimit = 6;
  static const int _dealsLimit = 6;

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pc.hasClients) return;
      if (_banners.length < 2) return;
      final next = (_page + 1) % _banners.length;
      _pc.animateToPage(next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic);
    });
  }

  Future<void> _loadCustomerData() async {
    try {
      await initializeCustomerData();
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productsError = null;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productsError = e.code == 'permission-denied'
            ? 'Firebase access is blocked. Please check Firestore Rules.'
            : 'Could not load products. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productsError = 'Could not load products. Please try again.';
      });
    }
  }

  /// Retry from the error card.
  void _retry() {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    _loadCustomerData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  void _openList([String? brand]) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => brand == null
                ? const ProductListScreen()
                : ProductListScreen(brand: brand)),
      );

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    final popular = phones.take(_homePhoneLimit).toList();
    final deals = phones.where((p) => p.off > 0).toList()
      ..sort((a, b) => b.off.compareTo(a.off));
    final topDeals = deals.take(_dealsLimit).toList();
    // Brand row: Apple, Samsung, OnePlus, Xiaomi, Realme
    const homeBrands = ['Apple', 'Samsung', 'OnePlus', 'Xiaomi', 'Realme'];

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
              const SizedBox(height: 12),
              Expanded(
                // Pull down to refresh the phones list
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadCustomerData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                    children: [
                      _bannerCarousel(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            _quickActions(),
                            _activeOrderCard(),
                            _cartReminder(),
                            const SizedBox(height: 14),
                            _SectionTitle('Shop by Brand',
                                action: 'See all', onTap: () => _openList()),
                            const SizedBox(height: 12),
                            _brandRow(homeBrands),
                            const SizedBox(height: 12),
                            _trustStrip(),
                            if (!_loadingProducts &&
                                _productsError == null &&
                                topDeals.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _SectionTitle('Best Deals',
                                  action: 'View all', onTap: () => _openList()),
                              const SizedBox(height: 12),
                              _dealsRow(topDeals),
                            ],
                            const SizedBox(height: 14),
                            _SectionTitle('Popular Phones',
                                action: 'View all', onTap: () => _openList()),
                            const SizedBox(height: 12),
                            if (_loadingProducts ||
                                _productsError != null ||
                                popular.isEmpty)
                              _stateCard()
                            else ...[
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: popular.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        mainAxisExtent: 200),
                                itemBuilder: (c, i) => _scaledCard(popular[i]),
                              ),
                              // "Browse all" button at the end of the list
                              if (phones.length > _homePhoneLimit) ...[
                                const SizedBox(height: 14),
                                GradientButton(
                                  height: 48,
                                  onTap: () => _openList(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Browse all ${phones.length} phones',
                                          style: const TextStyle(
                                              fontSize: AppText.small)),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Phone card scaled down a little so two fit nicely per row (same trick as before).
  Widget _scaledCard(Phone p) => LayoutBuilder(
        builder: (context, box) {
          const scale = 0.85;
          return FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(
                width: box.maxWidth / scale,
                height: box.maxHeight / scale,
                child: PhoneCard(phone: p)),
          );
        },
      );

  // ---- Header: same layout as the Cart screen ----
  // Gradient avatar tile, greeting caption over "Hello, name", wishlist and notification tiles.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _push(const EditProfileScreen()),
              child: ValueListenableBuilder<UserProfile>(
                valueListenable: profile,
                builder: (_, u, __) => Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Text(u.initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<UserProfile>(
                    valueListenable: profile,
                    builder: (_, u, __) => Text(
                      'Hello, ${u.firstName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9),
                  ),
                ],
              ),
            ),
            // Wishlist icon with a properly positioned count badge.
            GestureDetector(
              onTap: () => _push(const WishlistScreen()),
              child: Container(
                width: 40,
                height: 40,
                decoration: glassDeco(radius: 12),
                alignment: Alignment.center,
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: wishlist,
                  builder: (_, set, __) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          set.isEmpty
                              ? Icons.favorite_border_rounded
                              : Icons.favorite_rounded,
                          color:
                              set.isEmpty ? AppColors.text : AppColors.danger,
                          size: 20,
                        ),
                      ),
                      if (set.isNotEmpty)
                        Positioned(
                          top: -5,
                          right: -7,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              set.length > 9 ? '9+' : '${set.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Notification icon with a properly positioned notification dot.
            GestureDetector(
              onTap: () => _push(const NotificationsScreen()),
              child: Container(
                width: 40,
                height: 40,
                decoration: glassDeco(radius: 12),
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 20,
                        color: AppColors.text,
                      ),
                    ),
                    Positioned(
                      top: -3,
                      right: -4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ---- Search: same input style as the coupon field in Cart, opens the full search ----
  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _push(const ProductListScreen(autofocus: true)),
        child: Container(
          height: 46,
          padding: const EdgeInsets.fromLTRB(14, 0, 5, 0),
          decoration: BoxDecoration(
              color: checkoutFieldFill,
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: AppColors.muted, size: 19),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Search phones, brands…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.muted, fontSize: AppText.small))),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: brandGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Icon(Icons.tune_rounded,
                    size: 17, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Auto-scrolling promo carousel with dots ----
  Widget _bannerCarousel() {
    final banners = _banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pc,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: brandGradient,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                          right: -30,
                          top: -30,
                          child: CircleAvatar(
                              radius: 70,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08))),
                      Positioned(
                          left: -40,
                          bottom: -50,
                          child: CircleAvatar(
                              radius: 55,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.05))),
                      Positioned(
                          right: 14,
                          bottom: 8,
                          child: Icon(b.icon,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.22))),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(b.tag,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: AppText.caption,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8)),
                            ),
                            const SizedBox(height: 8),
                            Text(b.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppText.subtitle,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3)),
                            const SizedBox(height: 2),
                            Text(b.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: AppText.caption)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => _openList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b.cta,
                                        style: const TextStyle(
                                            color: Color(0xFF14307A),
                                            fontWeight: FontWeight.w800,
                                            fontSize: AppText.caption)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 14, color: Color(0xFF14307A)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- Quick actions (one-tap shortcuts) ----
  Widget _quickActions() {
    Widget item(IconData icon, String label, Color color, VoidCallback onTap,
        {String? badge}) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: glassDeco(radius: 14),
                alignment: Alignment.center,
                child: Badge(
                  isLabelVisible: badge != null,
                  backgroundColor: AppColors.accent,
                  label: badge == null ? null : Text(badge),
                  child: Icon(icon, color: color, size: 21),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item(Icons.grid_view_rounded, 'Categories', AppColors.primary,
            () => _push(const CategoriesScreen())),
        item(Icons.receipt_long_rounded, 'My Orders', AppColors.success,
            () => _push(const OrdersScreen())),
        item(Icons.local_offer_rounded, 'Offers', AppColors.accent,
            () => openProfileItem(context, 'Coupons & Offers'),
            badge: coupons.isEmpty ? null : '${coupons.length}'),
        item(Icons.headset_mic_rounded, 'Support', AppColors.primary,
            () => openProfileItem(context, 'Help & Support')),
      ],
    );
  }

  // ---- Active order shortcut (shown only while an order is on its way) ----
  Widget _activeOrderCard() {
    return ValueListenableBuilder<List<Order>>(
      valueListenable: orders,
      builder: (_, list, __) {
        final ongoing = list.where((o) => o.isOngoing).toList();
        if (ongoing.isEmpty) return const SizedBox.shrink();
        final o = ongoing.first;
        final more = ongoing.length - 1;
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () => _push(OrderTrackingScreen(order: o)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: glassDeco(radius: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.local_shipping_rounded,
                        color: AppColors.accent, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            more > 0
                                ? 'Your order is on its way (+$more more)'
                                : 'Your order is on its way',
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(o.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.small,
                                color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(o.statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Track',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- "Continue shopping" reminder with free-delivery progress (only when the cart has items) ----
  Widget _cartReminder() {
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: cart,
      builder: (_, items, __) {
        if (items.isEmpty) return const SizedBox.shrink();
        final subtotal =
            items.fold<int>(0, (s, e) => s + e.phone.price * e.qty);
        final showProgress = deliveryChargeCfg > 0 && freeDeliveryAboveCfg > 0;
        final remaining = freeDeliveryAboveCfg - subtotal;
        final unlocked = remaining <= 0;
        final progress = showProgress
            ? (subtotal / freeDeliveryAboveCfg).clamp(0.0, 1.0).toDouble()
            : 0.0;
        final color = unlocked ? AppColors.success : AppColors.primary;

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GestureDetector(
            onTap: () => _push(const CartScreen(showBack: true)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: glassDeco(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.shopping_cart_rounded,
                            color: AppColors.accent, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Your cart is waiting',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppText.small,
                                    color: AppColors.text)),
                            const SizedBox(height: 2),
                            Text(
                                '${items.length} ${items.length == 1 ? 'item' : 'items'} - ${rupee(subtotal)}',
                                style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: AppText.caption,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            gradient: brandGradient,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Text('Checkout',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.caption)),
                      ),
                    ],
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 10),
                    Text(
                      unlocked
                          ? 'Yay! You have unlocked FREE delivery'
                          : 'Add ${rupee(remaining)} more to get FREE delivery',
                      style: TextStyle(
                          color: unlocked ? AppColors.success : AppColors.text,
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: checkoutFieldFill,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- Brand row ----
  Widget _brandRow(List<String> homeBrands) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: homeBrands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final b = homeBrands[i];
          final c = brandColors[b] ?? AppColors.primary;
          return GestureDetector(
            onTap: () => _openList(b),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: c.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: c.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(b[0],
                      style: TextStyle(
                          color: c,
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 6),
                Text(b,
                    style: const TextStyle(
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Trust strip (warranty / delivery / returns) ----
  Widget _trustStrip() {
    final items = [
      (Icons.verified_user_outlined, '6 Month', 'Warranty'),
      (Icons.local_shipping_outlined, 'Free', 'Delivery'),
      (Icons.published_with_changes_rounded, '7 Day', 'Returns'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: glassDeco(radius: 18),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        Icon(items[i].$1, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 7),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$2,
                          style: const TextStyle(
                              fontSize: AppText.caption,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      Text(items[i].$3,
                          style: const TextStyle(
                              fontSize: AppText.caption,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Container(width: 1, height: 26, color: const Color(0xFFE8EFFC)),
          ],
        ],
      ),
    );
  }

  // ---- Best deals: phones with the biggest discount, horizontal list ----
  Widget _dealsRow(List<Phone> deals) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: deals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            SizedBox(width: 160, height: 200, child: _scaledCard(deals[i])),
      ),
    );
  }

  // ---- Loading / error / empty card for the phones list ----
  Widget _stateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: glassDeco(radius: 18),
      child: Column(
        children: [
          if (_loadingProducts) ...[
            const SizedBox(height: 4),
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            const Text('Loading phones...',
                style:
                    TextStyle(color: AppColors.muted, fontSize: AppText.small)),
          ] else if (_productsError != null) ...[
            const Icon(Icons.cloud_off_rounded,
                size: 36, color: AppColors.danger),
            const SizedBox(height: 10),
            const Text('Could not load phones',
                style: TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text(_productsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: AppText.small)),
            const SizedBox(height: 14),
            SizedBox(
              width: 140,
              child: GradientButton(
                  height: 44,
                  onTap: _retry,
                  child: const Text('Retry',
                      style: TextStyle(fontSize: AppText.small))),
            ),
          ] else ...[
            const Icon(Icons.phone_android_rounded,
                size: 36, color: AppColors.primary),
            const SizedBox(height: 10),
            const Text('No phones available yet',
                style: TextStyle(
                    fontSize: AppText.subtitle,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Please check back later.',
                style:
                    TextStyle(color: AppColors.muted, fontSize: AppText.small)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROFILE TAB
// ---------------------------------------------------------------------------

const _pCardBorder = Color(0xFFDCE8FF);
const _pDivider = Color(0xFFE8EFFC);

/// Section title with the blue bar (same as the Cart screen).
class _SectionBar extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionBar(this.title, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: AppText.body,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2))),
          if (icon != null) Icon(icon, color: AppColors.accent, size: 18),
        ],
      );
}

/// Profile screen
/// Same look as the Cart / Orders screens: shared gradient background, glass cards,
/// section titles, tinted chips and the 42px action row. Text sizes use the smaller
/// steps of the AppText scale, same as the Cart screen.
/// Header, profile card with stats, profile completion, account, preferences,
/// about, invite friends, logout.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool pushOn = true;

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- Actions ----
  void _inviteFriends() {
    HapticFeedback.selectionClick();
    Clipboard.setData(const ClipboardData(
        text:
            'Check out PhoneHub - certified used phones with warranty, free delivery and 7 day returns.'));
    _snack('Invite message copied. Paste it in any chat to share.');
  }

  void _showAbout() {
    Widget tile(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppText.small,
                            color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(text,
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: AppText.caption,
                            height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('About PhoneHub',
                  style: TextStyle(
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('Version 1.0.0',
                  style: TextStyle(
                      color: AppColors.muted, fontSize: AppText.small)),
              const SizedBox(height: 16),
              tile(Icons.verified_user_outlined, '6 month warranty',
                  'Every phone is quality checked and comes with warranty.'),
              tile(Icons.local_shipping_outlined, 'Free delivery',
                  'Delivery is free above the minimum order value.'),
              tile(Icons.published_with_changes_rounded, '7 day returns',
                  'Return or replace a phone within 7 days of delivery.'),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppText.subtitle,
                color: AppColors.text)),
        content: const Text(
            'You will need to sign in again to see your orders and wishlist.',
            style: TextStyle(
                color: AppColors.muted, fontSize: AppText.small, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              cart.value = [];
              // Really sign the customer out of Firebase, otherwise the
              // account stays logged in after "Log out".
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              // Back to the first screen, where the user picks a role.
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                  (r) => false);
            },
            child: const Text('Log out',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  // ---- Build ----
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _profileCard(),
                    const SizedBox(height: 14),
                    _completionCard(),
                    _menuCard('My Account', Icons.person_outline_rounded, [
                      ValueListenableBuilder<List<Order>>(
                        valueListenable: orders,
                        builder: (_, list, __) => _row(
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.success,
                          title: 'My Orders',
                          subtitle: list.isEmpty
                              ? 'No orders yet'
                              : 'Track your ${list.length} ${list.length == 1 ? 'order' : 'orders'}',
                          onTap: () => _push(const OrdersScreen()),
                        ),
                      ),
                      ValueListenableBuilder<List<CartItem>>(
                        valueListenable: cart,
                        builder: (_, items, __) => _row(
                          icon: Icons.shopping_cart_outlined,
                          color: AppColors.accent,
                          title: 'My Cart',
                          subtitle: items.isEmpty
                              ? 'Your cart is empty'
                              : '${items.length} ${items.length == 1 ? 'item' : 'items'} ready to checkout',
                          onTap: () => _push(const CartScreen(showBack: true)),
                        ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: wishlist,
                        builder: (_, set, __) => _row(
                          icon: Icons.favorite_border_rounded,
                          color: AppColors.danger,
                          title: 'Wishlist',
                          subtitle: set.isEmpty
                              ? 'Save phones you love'
                              : '${set.length} saved ${set.length == 1 ? 'phone' : 'phones'}',
                          onTap: () => openProfileItem(context, 'Wishlist'),
                        ),
                      ),
                      ValueListenableBuilder<List<SavedAddress>>(
                        valueListenable: savedAddresses,
                        builder: (_, list, __) => _row(
                          icon: Icons.location_on_outlined,
                          color: AppColors.primary,
                          title: 'Saved Addresses',
                          subtitle: list.isEmpty
                              ? 'Add a delivery address'
                              : '${list.length} saved ${list.length == 1 ? 'address' : 'addresses'}',
                          onTap: () =>
                              openProfileItem(context, 'Saved Addresses'),
                        ),
                      ),
                      _row(
                        icon: Icons.local_offer_outlined,
                        color: AppColors.accent,
                        title: 'Coupons & Offers',
                        subtitle: 'Save more on every phone',
                        trailing: _badge(
                            '${coupons.length} ${coupons.length == 1 ? 'offer' : 'offers'}',
                            AppColors.accent),
                        onTap: () =>
                            openProfileItem(context, 'Coupons & Offers'),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _menuCard('Preferences', Icons.tune_rounded, [
                      _row(
                        icon: Icons.notifications_none_rounded,
                        color: AppColors.success,
                        title: 'Push notifications',
                        subtitle: pushOn
                            ? 'On - order updates and offers'
                            : 'Off - you may miss order updates',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: pushOn,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => pushOn = v);
                            },
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => pushOn = !pushOn);
                        },
                      ),
                      _row(
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.primary,
                        title: 'Notifications',
                        subtitle: 'See your latest updates',
                        onTap: () => _push(const NotificationsScreen()),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _menuCard('More', Icons.info_outline_rounded, [
                      _row(
                        icon: Icons.headset_mic_outlined,
                        color: AppColors.primary,
                        title: 'Help & Support',
                        subtitle: 'FAQs and contact us',
                        onTap: () => openProfileItem(context, 'Help & Support'),
                      ),
                      _row(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.muted,
                        title: 'About PhoneHub',
                        subtitle: 'Version 1.0.0',
                        onTap: _showAbout,
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Logout (same tinted danger style as the Cart "Remove" action)
                    GestureDetector(
                      onTap: _confirmLogout,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded,
                                color: AppColors.danger, size: 17),
                            SizedBox(width: 8),
                            Text('Log out',
                                style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppText.small)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Center(
                        child: Text('PhoneHub v1.0.0',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header: same layout as the Cart screen (glass icon tile, title, caption, right tile).
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: glassDeco(radius: 14),
              child: const Icon(Icons.person_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'My Profile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppText.subtitle,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.3),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'YOUR ACCOUNT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.muted,
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _push(const NotificationsScreen()),
              child: Container(
                width: 40,
                height: 40,
                decoration: glassDeco(radius: 12),
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 20,
                        color: AppColors.text,
                      ),
                    ),
                    Positioned(
                      top: -3,
                      right: -4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
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
      ),
    );
  }

  // ---- Profile card: avatar, name, chips, stats, action row ----
  Widget _profileCard() {
    return Container(
      decoration: glassDeco(radius: 18),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<UserProfile>(
                  valueListenable: profile,
                  builder: (_, u, __) => Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Text(u.initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppText.subtitle,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<UserProfile>(
                        valueListenable: profile,
                        builder: (_, u, __) => Text(u.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: AppText.body,
                                color: AppColors.text,
                                height: 1.2)),
                      ),
                      const SizedBox(height: 3),
                      ValueListenableBuilder<UserProfile>(
                        valueListenable: profile,
                        builder: (_, u, __) => Text(u.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(Icons.verified_rounded, 'Verified',
                              AppColors.success),
                          _chip(Icons.workspace_premium_rounded,
                              'Member since 2025', AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _pDivider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                ValueListenableBuilder<List<Order>>(
                  valueListenable: orders,
                  builder: (_, list, __) => _stat(
                      '${list.length}',
                      'Orders',
                      Icons.receipt_long_rounded,
                      () => _push(const OrdersScreen())),
                ),
                Container(width: 1, height: 34, color: _pDivider),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: wishlist,
                  builder: (_, set, __) => _stat(
                      '${set.length}',
                      'Wishlist',
                      Icons.favorite_rounded,
                      () => _push(const WishlistScreen())),
                ),
                Container(width: 1, height: 34, color: _pDivider),
                _stat('${coupons.length}', 'Coupons', Icons.local_offer_rounded,
                    () => openProfileItem(context, 'Coupons & Offers')),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _pDivider),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(
                    child: _action(
                        Icons.edit_outlined,
                        'Edit profile',
                        AppColors.primary,
                        () => _push(const EditProfileScreen()))),
                Container(width: 1, height: 22, color: _pDivider),
                Expanded(
                    child: _action(
                        Icons.location_on_outlined,
                        'Addresses',
                        AppColors.accent,
                        () => openProfileItem(context, 'Saved Addresses'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Complete your profile" progress card (same as the free-delivery progress in Cart).
  /// Hidden once everything is done.
  Widget _completionCard() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: profile,
      builder: (_, u, __) => ValueListenableBuilder<List<SavedAddress>>(
        valueListenable: savedAddresses,
        builder: (_, addrs, __) {
          final hasName = u.name.trim().isNotEmpty;
          final hasPhone = u.phone.trim().isNotEmpty;
          final hasAddress = addrs.isNotEmpty;
          final done =
              (hasName ? 1 : 0) + (hasPhone ? 1 : 0) + (hasAddress ? 1 : 0);
          if (done == 3) return const SizedBox.shrink();

          final missing = !hasName
              ? 'Add your name'
              : !hasPhone
                  ? 'Add your phone number'
                  : 'Add a delivery address';
          final c = AppColors.primary;

          return GestureDetector(
            onTap: () => hasAddress || !hasName || !hasPhone
                ? _push(const EditProfileScreen())
                : openProfileItem(context, 'Saved Addresses'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: glassDeco(radius: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.account_circle_outlined,
                            size: 16, color: c),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('Complete your profile - $missing',
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: AppText.small,
                                  fontWeight: FontWeight.w700))),
                      Text('$done/3',
                          style: TextStyle(
                              color: c,
                              fontSize: AppText.caption,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: done / 3,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEAF1FF),
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Menu card: section title + rows, same glass card as Cart ----
  Widget _menuCard(String title, IconData icon, List<Widget> rows) {
    return Container(
      decoration: glassDeco(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: _SectionBar(title, icon: icon),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 62,
                  endIndent: 12,
                  color: _pDivider),
            rows[i],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: AppText.small,
                          color: AppColors.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent, size: 16),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppText.subtitle,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  // Tinted chip (same style as the status chip on the Orders card).
  Widget _chip(IconData icon, String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 12),
            const SizedBox(width: 4),
            Text(text,
                style: TextStyle(
                    color: c,
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: AppText.caption,
                fontWeight: FontWeight.w800)),
      );

  Widget _action(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
