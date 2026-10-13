import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';
import 'data.dart';

/// Coupons & Offers – every coupon works in the cart. Copy the code (or tap the code
/// chip inside the cart) and the discount is applied before payment.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons & Offers')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('coupons')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Keep the existing offers available if the collection is not yet
          // populated. Once active Firestore coupons exist, use those instead.
          final List<Coupon> items;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            items = snapshot.data!.docs.map((doc) {
              final data = doc.data();
              return Coupon(
                code: (data['code'] ?? doc.id).toString(),
                title: (data['title'] ?? 'Special offer').toString(),
                note: (data['note'] ?? data['description'] ?? '').toString(),
                flat: (data['flat'] as num?)?.toInt() ?? 0,
                percent: (data['percent'] as num?)?.toInt() ?? 0,
                maxOff: (data['maxOff'] as num?)?.toInt() ?? 0,
                minOrder: (data['minOrder'] as num?)?.toInt() ?? 0,
                freeDelivery: data['freeDelivery'] == true,
                firstOrderOnly: data['firstOrderOnly'] == true,
              );
            }).toList();
          } else {
            items = coupons;
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final c = items[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text)),
                          const SizedBox(height: 4),
                          Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.primary, letterSpacing: 0.6)),
                          const SizedBox(height: 2),
                          Text(c.note, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${c.code} copied. Paste it in your cart.')),
                        );
                      },
                      child: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
