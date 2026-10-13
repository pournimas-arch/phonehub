import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/customer/data.dart';
import 'package:phonehub/customer/product_list_screen.dart';
import 'package:phonehub/customer/shared_ui.dart';
import 'package:phonehub/customer/theme.dart';

const Color _pageTop = Color(0xFFF4F8FF);
const Color _pageBottom = Color(0xFFE8F0FF);
const Color _line = Color(0xFFDCE7FB);
const Color _subText = Color(0xFF55657F);

BoxDecoration _surface({double radius = 20, Color? tint}) => BoxDecoration(
  color: tint ?? Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _line, width: 1),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF2A4BA8).withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 7),
    ),
  ],
);

const LinearGradient _pageGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_pageTop, _pageBottom],
);

class _Glow extends StatelessWidget {
  final double size;
  final double opacity;
  const _Glow({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    ),
  );
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  void _open(BuildContext context, [String? brand]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => brand == null
            ? const ProductListScreen()
            : ProductListScreen(brand: brand),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _pageTop,
        body: Container(
          decoration: const BoxDecoration(gradient: _pageGradient),
          child: Stack(
            children: [
              const Positioned(top: -75, right: -85,
                  child: _Glow(size: 240, opacity: 0.55)),
              const Positioned(top: 430, left: -125,
                  child: _Glow(size: 280, opacity: 0.32)),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      sliver: SliverToBoxAdapter(child: _header(context)),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _searchCard(context),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                      sliver: SliverToBoxAdapter(
                        child: _sectionTitle(
                          'Shop by brand',
                          'View all',
                              () => _open(context),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                              _brandCard(context, brands[index]),
                          childCount: brands.length,
                        ),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.91,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        child: _trustStrip(),
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

  Widget _header(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.24),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.grid_view_rounded,
            color: Colors.white, size: 22),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FIND YOUR NEXT PHONE',
                style: TextStyle(
                  color: _subText, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.0,
                )),
            SizedBox(height: 3),
            Text('Categories',
                style: TextStyle(
                  color: AppColors.text, fontSize: 22,
                  fontWeight: FontWeight.w900, letterSpacing: -0.6,
                )),
          ],
        ),
      ),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProductListScreen(autofocus: true),
            ),
          ),
          child: Container(
            width: 46,
            height: 46,
            decoration: _surface(radius: 15),
            child: const Icon(Icons.search_rounded,
                color: AppColors.text, size: 23),
          ),
        ),
      ),
    ],
  );

  Widget _searchCard(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProductListScreen(autofocus: true),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: _surface(radius: 17),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.primary, size: 21),
            SizedBox(width: 10),
            Expanded(
              child: Text('Search phones, brands and models',
                  style: TextStyle(
                    color: _subText, fontSize: 13,
                    fontWeight: FontWeight.w500,
                  )),
            ),
            Icon(Icons.tune_rounded, color: AppColors.primary, size: 19),
          ],
        ),
      ),
    ),
  );

  Widget _sectionTitle(
      String title, String action, VoidCallback onTap,
      ) => Row(
    children: [
      Container(
        width: 4, height: 21,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(title,
            style: const TextStyle(
              color: AppColors.text, fontSize: 18,
              fontWeight: FontWeight.w900, letterSpacing: -0.4,
            )),
      ),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action,
                  style: const TextStyle(
                    color: AppColors.primary, fontSize: 11,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  size: 13, color: AppColors.primary),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _brandCard(BuildContext context, String brand) {
    final color = brandColors[brand] ?? AppColors.primary;
    final count = phones.where((phone) => phone.brand == brand).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _open(context, brand),
        child: Ink(
          decoration: _surface(radius: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  top: -33, right: -31,
                  child: Container(
                    width: 105, height: 105,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.09),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 104, height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withValues(alpha: 0.07),
                                ),
                              ),
                              Transform.rotate(
                                angle: -0.12,
                                child: Container(
                                  width: 48, height: 78,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.65),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.16),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 5, left: 5,
                                        child: Container(
                                          width: 15, height: 22,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius:
                                            BorderRadius.circular(5),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            color: color, size: 11,
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              bottom: 5),
                                          width: 13, height: 3,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.3),
                                            borderRadius:
                                            BorderRadius.circular(5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 7, bottom: 8,
                                child: Container(
                                  width: 31, height: 31,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white, width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    brand.isNotEmpty ? brand[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(brand,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text, fontSize: 15,
                            fontWeight: FontWeight.w900, letterSpacing: -0.2,
                          )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$count ${count == 1 ? 'phone' : 'phones'}',
                              style: const TextStyle(
                                color: _subText, fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            width: 29, height: 29,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.arrow_outward_rounded,
                                size: 16, color: color),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trustStrip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: _surface(radius: 18, tint: Colors.white.withValues(alpha: 0.78)),
    child: const Row(
      children: [
        Icon(Icons.verified_user_rounded,
            color: AppColors.success, size: 21),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shop with confidence',
                  style: TextStyle(
                    color: AppColors.text, fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  )),
              SizedBox(height: 3),
              Text('Quality-checked phones from PhoneHub',
                  style: TextStyle(
                    color: _subText, fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded,
            color: AppColors.primary, size: 20),
      ],
    ),
  );
}
