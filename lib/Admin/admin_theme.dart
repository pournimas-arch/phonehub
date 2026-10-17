import 'package:flutter/material.dart';
import 'package:phonehub/app_text.dart';

/// Same palette as the PhoneHub customer app so both apps feel like one product.
class AC {
  static const primary = Color(0xFF1B2A5C);
  static const primaryDark = Color(0xFF121C40);
  static const accent = Color(0xFFFF8A4C);
  static const bg = Color(0xFFF5F6FA);
  static const text = Color(0xFF1B1B2F);
  static const muted = Color(0xFF8A8FA3);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF2563EB);
  static const border = Color(0xFFE6E8F0);
}

const adminGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1B2A5C), Color(0xFF3D5BB8)],
);

ThemeData buildAdminTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AC.primary, primary: AC.primary),
    scaffoldBackgroundColor: AC.bg,
    textTheme: buildAppTextTheme(AC.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AC.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: AC.text,
      titleTextStyle: TextStyle(color: AC.text, fontSize: AppText.title, fontWeight: FontWeight.w700),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AC.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AC.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AC.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AC.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AC.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AC.primary, width: 1.6)),
      labelStyle: const TextStyle(color: AC.muted, fontSize: AppText.body),
    ),
  );
}

BoxDecoration cardDeco({double radius = 18, Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: const Color(0xFF1B1B2F).withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 5)),
    ],
  );
}

/// Indian number format: 1,24,999
String inr(int v) {
  final neg = v < 0;
  final s = v.abs().toString();
  if (s.length <= 3) return '${neg ? '-' : ''}₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${neg ? '-' : ''}₹${parts.join(',')},$last3';
}

String fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
}

String fmtDateTime(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]}, $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}

Color statusColor(String s) {
  switch (s) {
    case 'Delivered':
    case 'Success':
    case 'Resolved':
    case 'Refunded':
    case 'Approved':
    case 'Active':
    case 'In stock':
      return AC.success;
    case 'Cancelled':
    case 'Failed':
    case 'Rejected':
    case 'Blocked':
    case 'Out of stock':
    case 'Inactive':
      return AC.danger;
    case 'Pending':
    case 'Requested':
    case 'Open':
    case 'Low stock':
    case 'Order Placed':
      return AC.warning;
    case 'Out for Delivery':
    case 'In Progress':
      return AC.accent;
    default:
      return AC.info;
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color? color;
  const StatusChip(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? statusColor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: c, fontSize: AppText.small, fontWeight: FontWeight.w800)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AC.text))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AC.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.subtitle, color: AC.text)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AC.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small coloured square with an icon, used in lists and stat cards.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge(this.icon, this.color, {super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchBox({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AC.muted, fontSize: AppText.body),
        prefixIcon: const Icon(Icons.search_rounded, color: AC.muted),
      ),
    );
  }
}

/// Horizontal row of selectable chips (filters / tabs).
class ChipTabs extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;
  const ChipTabs({super.key, required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = items[i] == selected;
          return GestureDetector(
            onTap: () => onSelect(items[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AC.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? AC.primary : AC.border),
              ),
              child: Text(items[i], style: TextStyle(color: on ? Colors.white : AC.text, fontWeight: FontWeight.w700, fontSize: AppText.small)),
            ),
          );
        },
      ),
    );
  }
}

/// Key / value row used on detail screens.
class KV extends StatelessWidget {
  final String k, v;
  final bool bold;
  final Color? color;
  const KV(this.k, this.v, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(color: AC.muted, fontSize: AppText.body, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(v, textAlign: TextAlign.right, style: TextStyle(color: color ?? AC.text, fontSize: AppText.body, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String yes = 'Confirm', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(color: AC.muted, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes, style: TextStyle(fontWeight: FontWeight.w800, color: danger ? AC.danger : AC.primary)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Labelled text field helper to keep forms short.
Widget formField(String label, TextEditingController c, {TextInputType? type, int maxLines = 1, String? prefix, bool obscure = false, String? Function(String?)? validator}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      obscureText: obscure,
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(labelText: label, prefixText: prefix),
    ),
  );
}

/// Simple vertical bar chart drawn with plain widgets (no packages).
class MiniBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double height;
  const MiniBarChart({super.key, required this.labels, required this.values, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxV == 0 ? 1.0 : maxV;
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(values[i] >= 1000 ? '${(values[i] / 1000).toStringAsFixed(0)}k' : values[i].toStringAsFixed(0), style: const TextStyle(fontSize: AppText.caption, color: AC.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: (height - 20) * (values[i] / safeMax) + 4,
                    decoration: BoxDecoration(
                      gradient: i == values.length - 1 ? const LinearGradient(colors: [AC.accent, Color(0xFFFFB27F)], begin: Alignment.bottomCenter, end: Alignment.topCenter) : adminGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i], style: const TextStyle(fontSize: AppText.caption, color: AC.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
