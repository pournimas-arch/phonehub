import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/Admin/phone_extras.dart';
import 'package:phonehub/app_text.dart';

// ===========================================================================
// Shared helpers used by the Products, Product detail, Phone form and
// Inventory screens (same style as the Orders screen)
// ===========================================================================

/// App bar: same as Orders screen (18 / w800, left aligned, back arrow 40px).
AppBar phoneAppBar(BuildContext context, String title, {List<Widget>? actions}) {
  final bool canPop = Navigator.of(context).canPop();
  return AppBar(
    centerTitle: false,
    titleSpacing: canPop ? 0 : 16,
    leadingWidth: canPop ? 40 : null,
    leading: canPop
        ? IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
    )
        : null,
    title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    actions: actions,
  );
}

/// Small rounded label.
Widget phonePill(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
      Text(text, maxLines: 1, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ],
  ),
);

/// Gradient summary strip (Orders style).
Widget phoneSummaryCard(List<Widget> stats) => Container(
  margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
  decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(18)),
  child: Row(children: stats),
);

Widget phoneStat(IconData icon, String label, String value) => Expanded(
  child: Column(
    children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(height: 4),
      FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: (AppText.subtitle - 2), fontWeight: FontWeight.w900))),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: (AppText.small - 1)))),
    ],
  ),
);

Widget phoneStatDivider() => Container(width: 1, height: 38, color: Colors.white24);

/// Chip group used inside the filter sheet.
Widget phoneFilterGroup(String title, List<String> items, String value, void Function(String) onPick) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: (AppText.body - 1))),
    ),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final x in items)
          ChoiceChip(
            label: Text(x, style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: x == value ? Colors.white : AC.text)),
            selected: x == value,
            showCheckmark: false,
            selectedColor: AC.primary,
            backgroundColor: AC.bg,
            side: BorderSide(color: x == value ? AC.primary : AC.border),
            onSelected: (_) => onPick(x),
          ),
      ],
    ),
  ],
);

/// Removable chip showing an active filter.
Widget phoneActiveChip(String label, VoidCallback onRemove) => Chip(
  label: Text(label, style: const TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: AC.primary)),
  backgroundColor: AC.primary.withValues(alpha: 0.08),
  side: BorderSide.none,
  deleteIcon: const Icon(Icons.close_rounded, size: 15, color: AC.primary),
  onDeleted: onRemove,
  visualDensity: VisualDensity.compact,
);

/// Number validator used by the forms.
String? validateNumber(String? v, {int min = 0, int? max}) {
  final n = int.tryParse((v ?? '').trim());
  if (n == null) return 'Enter a number';
  if (n < min) return 'Minimum $min';
  if (max != null && n > max) return 'Maximum $max';
  return null;
}

/// Single-select pill chips (used inside the variant sheet).
Widget phoneChoiceChips(List<String> items, String value, ValueChanged<String> onPick) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    for (final x in items)
      ChoiceChip(
        label: Text(x, style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: x == value ? Colors.white : AC.text)),
        selected: x == value,
        showCheckmark: false,
        selectedColor: AC.primary,
        backgroundColor: AC.bg,
        side: BorderSide(color: x == value ? AC.primary : AC.border),
        onSelected: (_) => onPick(x),
      ),
  ],
);

/// Dialog to type an exact stock number. Returns null if cancelled.
Future<int?> askStockDialog(BuildContext context, String name, int current) async {
  final c = TextEditingController(text: '$current');
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Set stock', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: AppText.small)),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Units in stock'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim()) ?? current),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  c.dispose();
  return result;
}

/// Dialog to type a short text (custom quality check / box item). Returns null if cancelled.
Future<String?> askTextDialog(BuildContext context, String title, String label) async {
  final c = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800))),
      ],
    ),
  );
  c.dispose();
  return (result == null || result.isEmpty) ? null : result;
}

/// Plain text used when sharing a phone.
String phoneShareText(Phone p) => [
  'PhoneHub - ${p.name}',
  '${p.brand} | ${p.storage} | ${p.condition}',
  'Price: ${inr(p.price)} (MRP ${inr(p.mrp)}, ${p.off}% OFF)',
  'Battery health: ${p.battery}%',
  'Stock: ${p.stock} units (${p.stockLabel})',
].join('\n');

/// Creates a copy of a phone and returns it.
Phone duplicatePhone(Phone p) {
  final copy = Phone(
    id: store.nextPhoneId(),
    name: '${p.name} (copy)',
    brand: p.brand,
    storage: p.storage,
    condition: p.condition,
    price: p.price,
    mrp: p.mrp,
    battery: p.battery,
    rating: p.rating,
    colors: List<Color>.from(p.colors),
    stock: p.stock,
    images: List<String>.from(p.images),
    details: p.details.copy(),
  );
  store.addPhone(copy);
  return copy;
}

// ===========================================================================
// Images
// ===========================================================================

/// Displays either a remote image URL or a locally stored data URI.
class PhoneProductImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  const PhoneProductImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('data:')) {
      try {
        final comma = source.indexOf(',');
        if (comma < 0) throw const FormatException('Invalid image data');
        final bytes = base64Decode(source.substring(comma + 1));
        return Image.memory(bytes, fit: fit, errorBuilder: errorBuilder);
      } catch (error, stackTrace) {
        return errorBuilder?.call(context, error, stackTrace) ?? const Center(child: Icon(Icons.broken_image_outlined));
      }
    }
    return Image.network(source, fit: fit, errorBuilder: errorBuilder, loadingBuilder: loadingBuilder);
  }
}

/// Drawn phone thumbnail using the phone's two colours (no image files needed).
class PhoneThumb extends StatelessWidget {
  final dynamic phone;
  final double size;
  const PhoneThumb(this.phone, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final List cols = phone.colors as List;
    final Color c1 = cols.isNotEmpty ? cols.first as Color : AC.primary;
    final Color c2 = cols.length > 1 ? cols[1] as Color : c1;
    final String? imageUrl = phone.cover as String?;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? PhoneProductImage(
        source: imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.smartphone_rounded, color: Colors.white.withValues(alpha: 0.9), size: size * 0.55),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Center(child: SizedBox(width: size * 0.24, height: size * 0.24, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
      )
          : Icon(Icons.smartphone_rounded, color: Colors.white.withValues(alpha: 0.9), size: size * 0.55),
    );
  }
}