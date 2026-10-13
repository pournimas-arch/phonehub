import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:phonehub/customer/category.dart';
import 'package:phonehub/customer/notification.dart';
import 'package:phonehub/customer/saved_addresses.dart';
import 'package:phonehub/customer/wishlist.dart';
import 'widgets.dart';
import 'theme.dart';
import 'data.dart';
import 'splash_screen.dart';
import 'product_list_screen.dart';
import 'my_cart.dart';
import 'edit_profile_screen.dart';
import 'shared_ui.dart';
import 'my_orders_screen.dart';
import 'profile_navigation.dart';


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
              iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(size: 23, color: st.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
              labelTextStyle: WidgetStateProperty.resolveWith((st) => TextStyle(fontSize: 9.5, fontWeight: st.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600, color: st.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
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
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Categories'),
                NavigationDestination(
                  icon: ValueListenableBuilder<List<CartItem>>(
                    valueListenable: cart,
                    builder: (_, items, __) => Badge(
                      isLabelVisible: items.isNotEmpty,
                      backgroundColor: AppColors.accent,
                      label: Text('${items.length}'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                  selectedIcon: const Icon(Icons.shopping_cart_rounded),
                  label: 'Cart',
                ),
                const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
                const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
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

// ---------- Shared styling helpers (match Splash / Login look) ----------

BoxDecoration _glass({double radius = 18}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: const Color(0xFFDCE8FF)),
  boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))],
);

const _bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF4F8FF), Color(0xFFBBD5FB), Color(0xFF7FADEE)],
);

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob(this.size, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;
  const _SectionTitle(this.title, this.action, this.onTap);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action, style: const TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
            ],
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// HOME TAB
// ---------------------------------------------------------------------------

class _Banner {
  final String tag;
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  const _Banner(this.tag, this.title, this.subtitle, this.cta, this.icon);
}

const _banners = [
  _Banner('LIMITED OFFER', 'Up to 40% OFF', 'on certified pre-owned phones', 'Shop Now', Icons.phone_android_rounded),
  _Banner('NEW ARRIVALS', 'Latest 5G Phones', 'fresh stock from top brands', 'Explore', Icons.bolt_rounded),
  _Banner('EXCHANGE BONUS', 'Extra ₹5,000 back', 'when you trade in your old phone', 'Trade in', Icons.currency_exchange_rounded),
];

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

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_page + 1) % _banners.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
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

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 👋';
    if (h < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  void _openList([String? brand]) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => brand == null ? const ProductListScreen() : ProductListScreen(brand: brand)),
  );

  @override
  Widget build(BuildContext context) {
    final popular = phones.toList();
    // Brand row exactly as per task: Apple, Samsung, OnePlus, Xiaomi, Realme
    const homeBrands = ['Apple', 'Samsung', 'OnePlus', 'Xiaomi', 'Realme'];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          decoration: const BoxDecoration(gradient: _bgGradient),
          child: Stack(
            children: [
              Positioned(top: -70, right: -80, child: _Blob(240, 0.35)),
              Positioned(top: 420, left: -120, child: _Blob(280, 0.20)),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _header(),
                          const SizedBox(height: 18),
                          _searchBar(),
                        ]),
                      ),
                    ),
                    SliverToBoxAdapter(child: const SizedBox(height: 18)),
                    SliverToBoxAdapter(child: _bannerCarousel()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 18),
                          _SectionTitle('Shop by Brand', 'See all', () => _openList()),
                          const SizedBox(height: 14),
                          _brandRow(homeBrands),
                          const SizedBox(height: 12),
                          _trustStrip(),
                          const SizedBox(height: 22),
                          _SectionTitle('Popular Phones', 'View all', () => _openList()),
                          const SizedBox(height: 14),
                        ]),
                      ),
                    ),
                    if (_loadingProducts || _productsError != null || popular.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: _glass(radius: 18),
                            child: Column(
                              children: [
                                if (_loadingProducts) ...[
                                  const SizedBox(height: 8),
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  const Text('Loading phones...', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                                ] else if (_productsError != null) ...[
                                  const Icon(Icons.cloud_off_rounded, size: 30, color: AppColors.muted),
                                  const SizedBox(height: 8),
                                  Text(_productsError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 10),
                                  TextButton.icon(onPressed: _loadCustomerData, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                                ] else ...[
                                  const Icon(Icons.phone_android_rounded, size: 30, color: AppColors.muted),
                                  const SizedBox(height: 8),
                                  const Text('No phones available yet.', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  const Text('Please check back later.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                                (c, i) => LayoutBuilder(
                              builder: (context, box) {
                                const scale = 0.85;
                                return FittedBox(
                                  fit: BoxFit.contain,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: box.maxWidth / scale,
                                    height: box.maxHeight / scale,
                                    child: PhoneCard(phone: popular[i]),
                                  ),
                                );
                              },
                            ),
                            childCount: popular.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 200),
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

  // ---- Header: avatar, greeting, wishlist + notification buttons ----
  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          alignment: Alignment.center,
          child: ValueListenableBuilder<UserProfile>(valueListenable: profile, builder: (_, u, __) => Text(u.initial, style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
              const SizedBox(height: 1),
              ValueListenableBuilder<UserProfile>(valueListenable: profile, builder: (_, u, __) => Text('Hello, ${u.firstName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3))),
            ],
          ),
        ),
        Container(
          decoration: _glass(radius: 14),
          child: IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
            icon: const Icon(Icons.favorite_border_rounded, color: AppColors.text, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: _glass(radius: 14),
          child: IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: const Badge(smallSize: 9, backgroundColor: AppColors.accent, child: Icon(Icons.notifications_none_rounded, color: AppColors.text, size: 22)),
          ),
        ),
      ],
    );
  }

  // ---- Search bar ----
  Widget _searchBar() {
    return Tap(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen(autofocus: true))),
      child: Container(
        height: 50,
        padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
        decoration: _glass(radius: 18),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Expanded(child: Text('Search phones, brands…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted, fontSize: 12))),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: brandGradient,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.tune_rounded, size: 19, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Auto-scrolling promo carousel with dots ----
  Widget _bannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 186,
          child: PageView.builder(
            controller: _pc,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = _banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: brandGradient,
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Stack(
                    children: [
                      Positioned(right: -30, top: -30, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withValues(alpha: 0.08))),
                      Positioned(left: -40, bottom: -50, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05))),
                      Positioned(right: 16, bottom: 8, child: Icon(b.icon, size: 96, color: Colors.white.withValues(alpha: 0.22))),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                              child: Text(b.tag, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                            ),
                            const SizedBox(height: 9),
                            Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 19.5, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                            const SizedBox(height: 2),
                            Text(b.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                            const SizedBox(height: 12),
                            Tap(
                              onTap: () => _openList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b.cta, style: const TextStyle(color: Color(0xFF14307A), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF14307A)),
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
            for (int i = 0; i < _banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- Brand row ----
  Widget _brandRow(List<String> homeBrands) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: homeBrands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final b = homeBrands[i];
          final c = brandColors[b] ?? AppColors.primary;
          return Tap(
            onTap: () => _openList(b),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [BoxShadow(color: c.withValues(alpha: 0.20), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: Text(b[0], style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                Text(b, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text)),
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
      decoration: _glass(radius: 18),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                    child: Icon(items[i].$1, size: 17, color: AppColors.primary),
                  ),
                  const SizedBox(width: 7),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$2, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.text)),
                      Text(items[i].$3, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            if (i != items.length - 1) Container(width: 1, height: 26, color: const Color(0xFFDCE8FF)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROFILE TAB
// ---------------------------------------------------------------------------

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool pushOn = true;

  static const _cardBorder = Color(0xFFDCE8FF);

  Widget _stat(String value, String label, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    ),
  );

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
  );

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text)),
      subtitle: subtitle == null ? null : Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11))),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 0, 10),
          child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: const Color(0xFF3D5BB8).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: _cardBorder)),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i != rows.length - 1) const Divider(height: 1, indent: 74, endIndent: 16, color: Color(0xFFE8EFFC)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will need to sign in again to see your orders and wishlist.', style: TextStyle(color: AppColors.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              cart.value = [];
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (r) => false);
            },
            child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFF4F8FF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              icon: const Badge(smallSize: 9, backgroundColor: AppColors.accent, child: Icon(Icons.notifications_none_rounded, color: AppColors.text, size: 24)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // ---- Gradient profile card ----
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: brandGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 22, offset: const Offset(0, 12))],
            ),
            child: Stack(
              children: [
                Positioned(right: -50, top: -60, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withValues(alpha: 0.08))),
                Positioned(left: -40, bottom: -70, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05))),
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: ValueListenableBuilder<UserProfile>(valueListenable: profile, builder: (_, u, __) => CircleAvatar(radius: 32, backgroundColor: AppColors.primary, child: Text(u.initial, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ValueListenableBuilder<UserProfile>(valueListenable: profile, builder: (_, u, __) => Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))),
                              const SizedBox(height: 3),
                              ValueListenableBuilder<UserProfile>(valueListenable: profile, builder: (_, u, __) => Text(u.phone, style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _chip(Icons.verified_rounded, 'Verified'),
                                  _chip(Icons.workspace_premium_rounded, 'Member since 2025'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(13)),
                            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        children: [
                          ValueListenableBuilder<List<Order>>(
                            valueListenable: orders,
                            builder: (_, list, __) => _stat('${list.length}', 'Orders', Icons.receipt_long_rounded),
                          ),
                          Container(width: 1, height: 34, color: Colors.white24),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: wishlist,
                            builder: (_, set, __) => _stat('${set.length}', 'Wishlist', Icons.favorite_rounded),
                          ),
                          Container(width: 1, height: 34, color: Colors.white24),
                          _stat('${coupons.length}', 'Coupons', Icons.local_offer_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---- Account ----
          _section('My account', [
            ValueListenableBuilder<Set<String>>(
              valueListenable: wishlist,
              builder: (_, set, __) => _row(
                icon: Icons.favorite_border_rounded,
                color: AppColors.danger,
                title: 'Wishlist',
                subtitle: set.isEmpty ? 'Save phones you love' : '${set.length} saved ${set.length == 1 ? 'phone' : 'phones'}',
                onTap: () => openProfileItem(context, 'Wishlist'),
              ),
            ),
            ValueListenableBuilder<List<SavedAddress>>(
              valueListenable: savedAddresses,
              builder: (_, list, __) => _row(
                icon: Icons.location_on_outlined,
                color: AppColors.primary,
                title: 'Saved Addresses',
                subtitle: list.isEmpty ? 'Add a delivery address' : '${list.length} saved ${list.length == 1 ? 'address' : 'addresses'}',
                onTap: () => openProfileItem(context, 'Saved Addresses'),
              ),
            ),
            _row(
              icon: Icons.local_offer_outlined,
              color: AppColors.accent,
              title: 'Coupons & Offers',
              subtitle: 'Save more on every phone',
              trailing: _badge('${coupons.length} offers', AppColors.accent),
              onTap: () => openProfileItem(context, 'Coupons & Offers'),
            ),
          ]),
          const SizedBox(height: 22),

          // ---- Preferences ----
          _section('Preferences', [
            _row(
              icon: Icons.notifications_none_rounded,
              color: AppColors.success,
              title: 'Push notifications',
              subtitle: 'Order updates and offers',
              trailing: Switch(
                value: pushOn,
                activeColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => pushOn = v),
              ),
              onTap: () => setState(() => pushOn = !pushOn),
            ),
            _row(
              icon: Icons.headset_mic_outlined,
              color: AppColors.primary,
              title: 'Help & Support',
              subtitle: 'FAQs and contact us',
              onTap: () => openProfileItem(context, 'Help & Support'),
            ),
          ]),
          const SizedBox(height: 22),

          // ---- Logout ----
          Tap(
            onTap: _confirmLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.danger, size: 19),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(child: Text('PhoneHub v1.0.0', style: TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
