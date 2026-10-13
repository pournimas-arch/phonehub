import 'package:flutter/material.dart';
import 'product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  const ProductCard({super.key, required this.product, required this.onTap, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE5EAF2))),
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            Container(width: double.infinity, color: const Color(0xFFF1F5FB), child: Icon(product.icon, size: 66, color: const Color(0xFF2459D3))),
            Positioned(top: 9, left: 9, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text(product.condition, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)))),
            Positioned(right: 8, bottom: 8, child: Material(color: const Color(0xFF2459D3), borderRadius: BorderRadius.circular(12), child: InkWell(onTap: onAdd, borderRadius: BorderRadius.circular(12), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add_shopping_cart, color: Colors.white, size: 18))))),
          ])),
          Padding(padding: const EdgeInsets.all(11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 5),
            Text(formatPrice(product.price), style: const TextStyle(color: Color(0xFF2459D3), fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${product.storage} · ${product.color}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}
