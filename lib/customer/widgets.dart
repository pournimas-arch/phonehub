import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'product_detail_screen.dart';
import 'phone_mockup.dart';


Color conditionColor(String c) {
  switch (c) {
    case 'Like New':
      return AppColors.success;
    case 'Good':
      return AppColors.primary;
    default:
      return AppColors.accent;
  }
}

/// Placeholder phone "image" – gradient with a phone icon (no network needed).
class PhoneImage extends StatelessWidget {
  final Phone phone;
  final double? height;
  final double radius;
  final double iconSize;
  const PhoneImage({super.key, required this.phone, this.height, this.radius = 0, this.iconSize = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: phone.colors),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: -20, right: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.12))),
          Positioned(bottom: -30, left: -20, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withValues(alpha: 0.10))),
          PhoneMockup(phone: phone, height: (height ?? 120) * 0.78),
        ],
      ),
    );
  }
}

class WishHeart extends StatelessWidget {
  final String id;
  const WishHeart({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: wishlist,
      builder: (_, set, __) {
        final on = set.contains(id);
        return GestureDetector(
          onTap: () => toggleWish(id),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8)],
            ),
            child: Icon(
              on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: on ? AppColors.danger : AppColors.muted,
            ),
          ),
        );
      },
    );
  }
}

class ConditionChip extends StatelessWidget {
  final String label;
  const ConditionChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = conditionColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class PhoneCard extends StatelessWidget {
  final Phone phone;
  const PhoneCard({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(phone: phone))),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PhoneImage(phone: phone, height: 130),
                Positioned(top: 8, right: 8, child: WishHeart(id: phone.id)),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                    child: Text('${phone.off}% OFF', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phone.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.text)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ConditionChip(phone.condition),
                      const SizedBox(width: 6),
                      Text(phone.storage, style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rupee(phone.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(rupee(phone.mrp), overflow: TextOverflow.ellipsis, style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}