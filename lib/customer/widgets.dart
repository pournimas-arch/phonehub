import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'product_detail_screen.dart';
import 'phone_mockup.dart';
import 'package:phonehub/app_text.dart';


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

/// Decoded photos kept in memory so a list does not decode the same base64 again on every rebuild.
final Map<int, Uint8List> _photoBytes = <int, Uint8List>{};

Uint8List? _decodePhoto(String source) {
  final key = source.hashCode;
  final hit = _photoBytes[key];
  if (hit != null) return hit;
  try {
    final comma = source.indexOf(',');
    if (comma < 0) return null;
    final bytes = base64Decode(source.substring(comma + 1));
    if (_photoBytes.length >= 40) _photoBytes.remove(_photoBytes.keys.first);
    _photoBytes[key] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// Shows a product photo the admin added. The admin app saves photos as `data:` URIs
/// (base64 inside Firestore); normal http(s) links are supported too.
class PhonePhoto extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget? fallback;
  const PhonePhoto({super.key, required this.source, this.fit = BoxFit.contain, this.cacheWidth, this.fallback});

  @override
  Widget build(BuildContext context) {
    final broken = fallback ?? const Center(child: Icon(Icons.broken_image_outlined, color: Colors.black38));
    if (source.startsWith('data:')) {
      final bytes = _decodePhoto(source);
      if (bytes == null) return broken;
      return Image.memory(bytes, fit: fit, gaplessPlayback: true, cacheWidth: cacheWidth, errorBuilder: (_, __, ___) => broken);
    }
    return Image.network(source, fit: fit, cacheWidth: cacheWidth, errorBuilder: (_, __, ___) => broken);
  }
}

/// Cut-outs (photo with its plain background removed), kept so each photo is processed once.
final Map<int, Future<ui.Image?>> _cutouts = <int, Future<ui.Image?>>{};

Future<ui.Image?> _cutoutOf(String source) {
  if (_cutouts.length >= 20) _cutouts.remove(_cutouts.keys.first);
  return _cutouts.putIfAbsent(source.hashCode, () => _makeCutout(source));
}

/// Removes the plain background (white, black ...) that touches the photo's edges and
/// makes it transparent. Only pixels connected to the border are removed, so white or
/// black parts INSIDE the phone stay. Returns null when the photo has no plain background.
Future<ui.Image?> _makeCutout(String source) async {
  try {
    final bytes = source.startsWith('data:') ? _decodePhoto(source) : null;
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 700);
    final img = (await codec.getNextFrame()).image;
    final w = img.width, h = img.height;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final px = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));

    // Background colour = the four corners (they must look alike, otherwise there is no plain background).
    final corners = [0, (w - 1) * 4, (h - 1) * w * 4, ((h - 1) * w + (w - 1)) * 4];
    final br = (corners.map((o) => px[o]).reduce((a, b) => a + b)) ~/ 4;
    final bg = (corners.map((o) => px[o + 1]).reduce((a, b) => a + b)) ~/ 4;
    final bb = (corners.map((o) => px[o + 2]).reduce((a, b) => a + b)) ~/ 4;
    // A black background is cut with a tighter limit, so the phone's own dark screen and bezel are not eaten.
    final tol = (br + bg + bb) < 120 ? 22 : 45;
    bool near(int i) {
      final o = i * 4;
      return px[o + 3] > 0 && (px[o] - br).abs() + (px[o + 1] - bg).abs() + (px[o + 2] - bb).abs() <= tol;
    }
    for (final o in corners) {
      if ((px[o] - br).abs() + (px[o + 1] - bg).abs() + (px[o + 2] - bb).abs() > tol) return null;
    }

    final visited = Uint8List(w * h);
    final stack = Int32List(w * h);
    var sp = 0, removed = 0;
    void push(int i) {
      if (visited[i] == 1 || !near(i)) return;
      visited[i] = 1;
      stack[sp++] = i;
    }
    for (var x = 0; x < w; x++) {
      push(x);
      push((h - 1) * w + x);
    }
    for (var y = 0; y < h; y++) {
      push(y * w);
      push(y * w + w - 1);
    }
    while (sp > 0) {
      final i = stack[--sp];
      final o = i * 4;
      px[o] = 0;
      px[o + 1] = 0;
      px[o + 2] = 0;
      px[o + 3] = 0;
      removed++;
      final x = i % w, y = i ~/ w;
      if (x > 0) push(i - 1);
      if (x < w - 1) push(i + 1);
      if (y > 0) push(i - w);
      if (y < h - 1) push(i + w);
    }
    // Nothing removed, or almost everything (the phone has the same colour as the background): keep the original.
    if (removed < w * h * 0.02 || removed > w * h * 0.92) return null;

    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
    return await done.future;
  } catch (_) {
    return null;
  }
}

/// The photo without its plain background, so only the phone shows on the screen's own colour.
/// While it is being prepared nothing is drawn (no white flash); photos that cannot be cut out
/// are shown as they are.
class PhoneCutout extends StatelessWidget {
  final String source;
  const PhoneCutout({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image?>(
      future: _cutoutOf(source),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.expand();
        final img = snap.data;
        if (img == null) return PhonePhoto(source: source, fit: BoxFit.contain);
        return RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
      },
    );
  }
}

/// Names shown for a phone's gallery pages: the admin's labels, else Front / Back / In the box.
List<String> phoneGalleryLabels(Phone p) {
  const defaults = ['Front view', 'Back view', 'In the box'];
  if (p.imageUrls.isEmpty) return defaults;
  return [
    for (var i = 0; i < p.imageUrls.length; i++)
      (i < p.imageLabels.length && p.imageLabels[i].isNotEmpty) ? p.imageLabels[i] : (i < defaults.length ? defaults[i] : 'Photo ${i + 1}'),
  ];
}

/// The phone's real photo (first photo = cover). Phones with no photo keep the drawn mockup.
class PhoneImage extends StatelessWidget {
  final Phone phone;
  final double? height;
  final double radius;
  final double iconSize;
  const PhoneImage({super.key, required this.phone, this.height, this.radius = 0, this.iconSize = 56});

  /// The blue gradient card (phone colours) with [centre] on top of it.
  Widget _card(Widget centre) {
    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: phone.colors),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: -20, right: -20, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.12))),
          Positioned(bottom: -30, left: -20, child: CircleAvatar(radius: 50, backgroundColor: Colors.white.withValues(alpha: 0.10))),
          centre,
        ],
      ),
    );
  }

  Widget _mockup() => _card(PhoneMockup(phone: phone, height: (height ?? 120) * 0.78));

  @override
  Widget build(BuildContext context) {
    if (phone.imageUrls.isEmpty) return _mockup();
    // Real photo: same blue gradient card as before, the photo (plain background removed) sits on it.
    final h = height ?? 120;
    return _card(
      SizedBox(
        height: h,
        width: double.infinity,
        child: Padding(padding: const EdgeInsets.all(8), child: PhoneCutout(source: phone.imageUrls.first)),
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
      child: Text(label, style: TextStyle(color: c, fontSize: AppText.small, fontWeight: FontWeight.w700)),
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
                    child: Text('${phone.off}% OFF', style: const TextStyle(color: Colors.white, fontSize: AppText.caption, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phone.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body, color: AppColors.text)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ConditionChip(phone.condition),
                      const SizedBox(width: 6),
                      Text(phone.storage, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(rupee(phone.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: AppText.subtitle, color: AppColors.primary)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(rupee(phone.mrp), overflow: TextOverflow.ellipsis, style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.muted, fontSize: AppText.small)),
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
        Text(title, style: const TextStyle(fontSize: AppText.title, fontWeight: FontWeight.w800, color: AppColors.text)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}