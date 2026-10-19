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

// ---------------------------------------------------------------------------
// Limits used by the Add / Edit phone form (one place, so they are easy to change)
// ---------------------------------------------------------------------------

/// Highest selling price / MRP the admin can type (stops typing mistakes like 9999999999).
const int kMaxPhonePrice = 500000;

/// Highest stock for one phone or one variant.
const int kMaxStock = 9999;

const int kMinPhoneNameLength = 3;
const int kMaxPhoneNameLength = 60;

/// Longest text for one specification row (display, processor, RAM ...).
const int kMaxSpecLength = 60;

/// Longest custom quality-check / in-the-box item.
const int kMaxItemLength = 40;

const int kMaxVariants = 8;
const int kMaxQualityChecks = 20;
const int kMaxBoxItems = 15;

/// Photos are saved inside the product document and Firestore allows only 1 MiB per
/// document, so all photos together must stay well below that (the rest of the
/// document needs space too).
const int kMaxPhotoTotalBytes = 800 * 1024;

// ---------------------------------------------------------------------------
// Validators
// ---------------------------------------------------------------------------

/// Trims the text and turns several spaces / new lines into one space.
String cleanText(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Number validator used by the forms.
String? validateNumber(String? v, {int min = 0, int? max}) {
  final n = int.tryParse((v ?? '').trim());
  if (n == null) return 'Enter a number';
  if (n < min) return 'Minimum $min';
  if (max != null && n > max) return 'Maximum $max';
  return null;
}

/// Phone name: required, 3 to 60 characters, must contain letters.
String? validatePhoneName(String? v) {
  final t = cleanText(v ?? '');
  if (t.isEmpty) return 'Enter the phone name';
  if (t.length < kMinPhoneNameLength) return 'Name is too short (minimum $kMinPhoneNameLength characters)';
  if (t.length > kMaxPhoneNameLength) return 'Name is too long (maximum $kMaxPhoneNameLength characters)';
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(t)) return 'Name must contain letters, not only numbers or symbols';
  return null;
}

/// Selling price / MRP: whole rupees from 1 up to [kMaxPhonePrice].
String? validatePrice(String? v, {String label = 'price'}) {
  final text = (v ?? '').trim();
  if (text.isEmpty) return 'Enter the $label';
  final n = int.tryParse(text);
  if (n == null) return 'Use digits only (no decimals)';
  if (n < 1) return 'Minimum ${inr(1)}';
  if (n > kMaxPhonePrice) return 'Maximum ${inr(kMaxPhonePrice)}';
  return null;
}

/// MRP: same rules as the price, and it can not be lower than the selling price.
String? validateMrp(String? v, String priceText) {
  final base = validatePrice(v, label: 'MRP');
  if (base != null) return base;
  final mrp = int.parse(v!.trim());
  final price = int.tryParse(priceText.trim());
  if (price != null && mrp < price) return 'MRP cannot be lower than the selling price';
  return null;
}

/// Stock: whole number from 0 up to [kMaxStock].
String? validateStock(String? v) {
  final text = (v ?? '').trim();
  if (text.isEmpty) return 'Enter the stock';
  final n = int.tryParse(text);
  if (n == null) return 'Use digits only';
  if (n < 0) return 'Minimum 0';
  if (n > kMaxStock) return 'Maximum $kMaxStock';
  return null;
}

/// Optional specification text (blank is fine, the row is hidden for customers).
/// [needDigit] is for values that must contain a number (RAM, camera, battery capacity ...).
String? validateSpec(String? v, {bool needDigit = false}) {
  final t = cleanText(v ?? '');
  if (t.isEmpty) return null;
  if (t.length > kMaxSpecLength) return 'Too long (maximum $kMaxSpecLength characters)';
  if (needDigit && !RegExp(r'\d').hasMatch(t)) return 'Include a number, for example 8 GB';
  return null;
}

/// Checks a custom quality-check / box item. [existing] is what is already selected.
String? validateItemText(String? v, {List<String> existing = const []}) {
  final t = cleanText(v ?? '');
  if (t.isEmpty) return 'Enter a name';
  if (t.length < 2) return 'Too short';
  if (t.length > kMaxItemLength) return 'Too long (maximum $kMaxItemLength characters)';
  if (!RegExp(r'[\p{L}\d]', unicode: true).hasMatch(t)) return 'Use letters or numbers';
  if (existing.any((e) => e.toLowerCase() == t.toLowerCase())) return '$t is already added';
  return null;
}

// ---------------------------------------------------------------------------
// Photo size helpers (photos live inside the Firestore product document)
// ---------------------------------------------------------------------------

/// Stored size of one image string. Local photos are base64 data URIs and count in full;
/// a normal web link is tiny, so it counts as 0.
int storedImageBytes(String source) => source.startsWith('data:') ? source.length : 0;

int storedImagesBytes(Iterable<String> sources) => sources.fold<int>(0, (sum, s) => sum + storedImageBytes(s));

String formatKb(int bytes) => '${(bytes / 1024).round()} KB';

/// Returns an error text when all photos together are too big to be saved, else null.
String? validatePhotoTotal(int totalBytes) {
  if (totalBytes <= kMaxPhotoTotalBytes) return null;
  return 'Photos are too large (${formatKb(totalBytes)}). The limit is ${formatKb(kMaxPhotoTotalBytes)} in total. Remove a photo or choose smaller ones.';
}

/// Same look as [formField] (label, ₹ prefix, spacing) with a keyboard filter and a length limit.
Widget phoneFormField(
    String label,
    TextEditingController c, {
      TextInputType? type,
      String? prefix,
      int? maxLength,
      bool digitsOnly = false,
      TextCapitalization capitalization = TextCapitalization.none,
      String? Function(String?)? validator,
    }) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: type,
      textCapitalization: capitalization,
      inputFormatters: [
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(labelText: label, prefixText: prefix),
    ),
  );
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

/// Dialog to type an exact stock number (0 to [kMaxStock]). Returns null if cancelled.
Future<int?> askStockDialog(BuildContext context, String name, int current) async {
  final c = TextEditingController(text: '$current');
  String? error;
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        void submit() {
          final err = validateStock(c.text);
          if (err != null) {
            setLocal(() => error = err);
            return;
          }
          Navigator.pop(ctx, int.parse(c.text.trim()));
        }

        return AlertDialog(
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                onChanged: (_) {
                  if (error != null) setLocal(() => error = null);
                },
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(labelText: 'Units in stock', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: submit,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    ),
  );
  c.dispose();
  return result;
}

/// Dialog to type a short text (custom quality check / box item). Returns null if cancelled.
/// Pass [existing] to stop the same item being added twice. The dialog stays open and shows
/// the problem under the field until the text is valid.
Future<String?> askTextDialog(BuildContext context, String title, String label, {List<String> existing = const []}) async {
  final c = TextEditingController();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        void submit() {
          final err = validateItemText(c.text, existing: existing);
          if (err != null) {
            setLocal(() => error = err);
            return;
          }
          Navigator.pop(ctx, cleanText(c.text));
        }

        return AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(kMaxItemLength)],
            onChanged: (_) {
              if (error != null) setLocal(() => error = null);
            },
            decoration: InputDecoration(labelText: label, errorText: error),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: submit, child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
        );
      },
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