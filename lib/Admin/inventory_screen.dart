import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

// Text sizes (same as the Coupons & Offers screen)
const double _fHeader = 18;
const double _fTitle = 12;
const double _fBody = 10.5;
const double _fSmall = 9.5;

const int _lowStockLimit = 3; // this many or fewer = "Low stock"

// Same limit as the "Stock (units)" field of the phone form (4 digits).
const int _maxStock = 9999;

/// Validates the typed stock. Returns an error message, or null when it is fine.
String? _validateStockText(String raw, int current) {
  final s = raw.trim();
  if (s.isEmpty) return 'Enter the number of units';
  if (!RegExp(r'^\d+$').hasMatch(s)) return 'Use digits only (no minus or decimal)';
  final n = int.tryParse(s);
  if (n == null) return 'Enter a valid number';
  if (n > _maxStock) return 'Stock cannot be more than $_maxStock';
  if (n == current) return 'This is already the current stock';
  return null;
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = 'All';
  String _query = '';

  static const _filters = ['All', 'In stock', 'Low stock', 'Out of stock'];

  bool _matches(dynamic p, String f) {
    switch (f) {
      case 'In stock':
        return p.stock > _lowStockLimit;
      case 'Low stock':
        return p.stock > 0 && p.stock <= _lowStockLimit;
      case 'Out of stock':
        return p.stock == 0;
      default:
        return true;
    }
  }

  Future<void> _setExact(dynamic p) async {
    final value = await showDialog<int>(context: context, builder: (_) => _StockDialog(name: p.name, stock: p.stock));
    if (value != null) store.setStock(p, value);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(textTheme: base.textTheme.apply(fontSizeDelta: -2)),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = store.phones;
          final items = all.where((p) => _matches(p, _filter) && p.name.toLowerCase().contains(_query.toLowerCase())).toList()
            ..sort((a, b) => a.stock.compareTo(b.stock)); // lowest stock first

          return Scaffold(
            appBar: AppBar(
              centerTitle: false,
              leadingWidth: 48,
              titleSpacing: 4,
              title: const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
            ),
            body: Column(
              children: [
                // ---- search ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: _fBody + 1),
                      decoration: InputDecoration(
                        hintText: 'Search phone',
                        hintStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
                        isDense: true,
                        prefixIcon: const Icon(Icons.search_rounded, size: 19),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .18))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .18))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.2)),
                      ),
                    ),
                  ),
                ),

                // ---- filter pills ----
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final f in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: _pill(f, all.where((p) => _matches(p, f)).length, _filter == f, () => setState(() => _filter = f)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ---- list ----
                Expanded(
                  child: items.isEmpty
                      ? EmptyState(
                    icon: all.isEmpty ? Icons.inventory_2_outlined : Icons.search_off_rounded,
                    title: all.isEmpty ? 'No phones yet' : 'No matching phones',
                    subtitle: all.isEmpty ? 'Add phones to manage their stock' : 'Try another search or filter',
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _phoneCard(items[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _phoneCard(dynamic p) {
    final out = p.stock == 0;
    final low = p.stock > 0 && p.stock <= _lowStockLimit;
    final color = out ? AC.danger : (low ? AC.warning : AC.success);
    final text = out ? 'Out of stock' : (low ? 'Low stock' : 'In stock');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: cardDeco(radius: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.smartphone_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                  child: Text(text, style: TextStyle(color: color, fontSize: _fSmall, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
            onPressed: p.stock > 0 ? () => store.setStock(p, p.stock - 1) : null,
          ),
          InkWell(
            onTap: () => _setExact(p), // tap the number to type an exact stock
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 32),
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              child: Text('${p.stock}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: _fTitle + 3)),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            onPressed: p.stock < _maxStock ? () => store.setStock(p, p.stock + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int count, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AC.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AC.primary : AC.muted.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: _fBody, fontWeight: FontWeight.w800, color: selected ? Colors.white : AC.muted)),
          const SizedBox(width: 5),
          Text('$count', style: TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w800, color: selected ? Colors.white70 : AC.muted)),
        ],
      ),
    ),
  );
}

/// Type an exact stock number. Owns and disposes its own text controller.
class _StockDialog extends StatefulWidget {
  final String name;
  final int stock;
  const _StockDialog({required this.name, required this.stock});

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final _c = TextEditingController(text: '${widget.stock}');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final err = _validateStockText(_c.text, widget.stock);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, int.parse(_c.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Set stock', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle + 2)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fBody)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Units in stock',
              errorText: _error,
              isDense: true,
              labelStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
              errorStyle: const TextStyle(fontSize: _fSmall),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.3)),
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}