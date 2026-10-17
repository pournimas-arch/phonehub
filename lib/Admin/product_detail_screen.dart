import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phonehub/Admin/admin_theme.dart';
import 'package:phonehub/Admin/admin_data.dart';
import 'package:phonehub/Admin/phone_extras.dart';
import 'package:phonehub/app_text.dart';
import 'package:phonehub/Admin/phone_shared_widgets.dart';
import 'package:phonehub/Admin/phone_form_screen.dart';

// ===========================================================================
// Phone detail
// ===========================================================================

/// Phone detail: specs, stock, visibility, edit, duplicate, share and delete.
class ProductDetailScreen extends StatelessWidget {
  final Phone phone;
  const ProductDetailScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = phone;
        final d = p.details;
        final sold = store.validOrders.fold<int>(0, (s, o) => s + o.items.where((i) => i.phoneId == p.id).fold<int>(0, (a, i) => a + i.qty));
        final revenue = store.validOrders.fold<int>(0, (s, o) => s + o.items.where((i) => i.phoneId == p.id).fold<int>(0, (a, i) => a + (i.qty * i.price as int)));
        final saved = p.mrp - p.price;

        return Scaffold(
          appBar: phoneAppBar(
            context,
            'Phone details',
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share',
                onPressed: () => Share.share(phoneShareText(p), subject: 'PhoneHub - ${p.name}'),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhoneFormScreen(phone: p))),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                height: 240,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.colors.isNotEmpty ? p.colors.first : AC.primary, p.colors.length > 1 ? p.colors[1] : (p.colors.isNotEmpty ? p.colors.first : AC.primary)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (p.cover != null && p.cover!.isNotEmpty)
                      Padding(padding: const EdgeInsets.all(6), child: PhoneProductImage(source: p.cover!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.smartphone_rounded, size: 110, color: Colors.white.withValues(alpha: 0.9)))))
                    else
                      Center(child: Icon(Icons.smartphone_rounded, size: 110, color: Colors.white.withValues(alpha: 0.9))),
                    Positioned(top: 14, right: 14, child: StatusChip(p.active ? 'Active' : 'Inactive')),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                        child: Text('${p.off}% OFF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: AppText.small)),
                      ),
                    ),
                  ],
                ),
              ),
              // photo strip when there is more than one photo
              if (p.images.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: p.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Container(
                      width: 56,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
                      child: PhoneProductImage(source: p.images[i], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AC.muted)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(inr(p.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AC.primary)),
                  const SizedBox(width: 8),
                  Text(inr(p.mrp), style: const TextStyle(color: AC.muted, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 8),
                  if (saved > 0) phonePill('Save ${inr(saved)}', AC.success),
                  const Spacer(),
                  const Icon(Icons.star_rounded, color: AC.warning, size: 18),
                  Text(' ${p.rating}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              // low stock / out of stock warning
              if (p.stock == 0 || p.stock <= 3) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (p.stock == 0 ? AC.danger : AC.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: p.stock == 0 ? AC.danger : AC.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.stock == 0 ? 'Out of stock. Customers cannot buy this phone.' : 'Low stock: only ${p.stock} left. Restock soon.',
                          style: TextStyle(color: p.stock == 0 ? AC.danger : AC.warning, fontSize: (AppText.small - 1), fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SectionTitle('Sales'),
              Row(
                children: [
                  _miniStat('Units sold', '$sold', AC.primary),
                  const SizedBox(width: 10),
                  _miniStat('Revenue', inr(revenue), AC.success),
                ],
              ),
              SectionTitle('Specifications'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(radius: 12),
                child: Column(
                  children: [
                    KV('Brand', p.brand),
                    KV('Storage', p.storage),
                    KV('Condition', p.condition),
                    KV('Battery health', '${p.battery}%'),
                    for (final r in d.specRows) KV(r.$1, r.$2),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Text('Colours', style: TextStyle(color: AC.muted, fontSize: AppText.body)),
                          const Spacer(),
                          for (final c in p.colors) Container(width: 20, height: 20, margin: const EdgeInsets.only(left: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AC.border))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (d.variants.isNotEmpty) ...[
                SectionTitle('Other variants'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardDeco(radius: 12),
                  child: Column(
                    children: [
                      for (final v in d.variants)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(child: Text('${v.storage} • ${v.condition}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppText.small))),
                              Text(inr(v.price), style: const TextStyle(fontWeight: FontWeight.w900, color: AC.primary, fontSize: AppText.small)),
                              const SizedBox(width: 8),
                              phonePill('${v.stock} left', v.stock == 0 ? AC.danger : (v.stock <= 3 ? AC.warning : AC.success)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (d.qualityChecks.isNotEmpty) ...[
                SectionTitle('Quality check (${d.qualityChecks.length})'),
                _chipsCard(d.qualityChecks, Icons.check_circle_rounded, AC.success),
              ],
              if (d.inBox.isNotEmpty) ...[
                SectionTitle("What's in the box"),
                _chipsCard(d.inBox, Icons.check_rounded, AC.primary),
              ],
              SectionTitle('Warranty & delivery'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(radius: 12),
                child: Column(
                  children: [
                    KV('Seller warranty', d.warrantyMonths > 0 ? '${d.warrantyMonths} months' : 'None'),
                    KV('Return window', d.returnDays > 0 ? '${d.returnDays} days' : 'No returns'),
                    KV('Delivery time', '${d.deliveryDays} days'),
                    KV('Cash on delivery', d.cod ? 'Available' : 'Not available'),
                    KV('No-cost EMI', d.noCostEmi ? 'Available' : 'Not available'),
                  ],
                ),
              ),
              SectionTitle('Stock'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(radius: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final n = await askStockDialog(context, p.name, p.stock);
                          if (n != null) store.setStock(p, n);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${p.stock} units', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 14, color: AC.muted),
                              ],
                            ),
                            const SizedBox(height: 4),
                            StatusChip(p.stockLabel),
                          ],
                        ),
                      ),
                    ),
                    _roundBtn(Icons.remove_rounded, () => store.setStock(p, p.stock - 1)),
                    const SizedBox(width: 10),
                    _roundBtn(Icons.add_rounded, () => store.setStock(p, p.stock + 1)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: cardDeco(radius: 12),
                child: SwitchListTile(
                  value: p.active,
                  activeColor: AC.success,
                  onChanged: (v) {
                    p.active = v;
                    store.changed();
                  },
                  title: const Text('Visible to customers', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Turn off to hide this phone in the customer app', style: TextStyle(fontSize: AppText.small, color: AC.muted)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhoneFormScreen(phone: p))),
                child: const Text('Edit phone'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final copy = duplicatePhone(p);
                  snack(context, '${copy.name} created');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Duplicate phone'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AC.danger, side: const BorderSide(color: AC.danger, width: 1.4)),
                onPressed: () async {
                  final ok = await confirmDialog(context, 'Delete ${p.name}?', 'This removes the phone from your catalogue. Past orders are not affected.', yes: 'Delete', danger: true);
                  if (ok) {
                    store.deletePhone(p);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Delete phone'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipsCard(List<String> items, IconData icon, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(radius: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final x in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(x, style: TextStyle(fontSize: (AppText.small - 1), fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
      ],
    ),
  );


  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AC.muted, fontSize: (AppText.small - 1))),
        ],
      ),
    ),
  );

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AC.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AC.primary)),
  );
}