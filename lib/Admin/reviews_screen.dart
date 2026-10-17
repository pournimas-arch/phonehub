import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';
import 'package:phonehub/app_text.dart';

import 'admin_theme.dart';

/// Customer reviews of phones (collection `reviews`, written by the customer app).
/// The admin can read every review and delete the ones that do not belong in the store.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _AdminReview {
  final String id, productName, userName, text;
  final int stars;
  final bool verified;
  final DateTime? date;

  const _AdminReview({
    required this.id,
    required this.productName,
    required this.userName,
    required this.text,
    required this.stars,
    required this.verified,
    required this.date,
  });

  factory _AdminReview.from(fs.QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final raw = m['createdAt'];
    final s = m['stars'];
    return _AdminReview(
      id: d.id,
      productName: (m['productName'] ?? 'Phone').toString(),
      userName: (m['userName'] ?? 'Customer').toString(),
      text: (m['text'] ?? '').toString(),
      stars: s is num ? s.toInt().clamp(1, 5).toInt() : 1,
      verified: m['verified'] == true,
      date: raw is fs.Timestamp ? raw.toDate() : null,
    );
  }
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final TextEditingController _search = TextEditingController();
  String _filter = 'All';

  static const _filters = ['All', '5★', '4★', '3★', '2★', '1★'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _delete(_AdminReview r) async {
    final ok = await confirmDialog(
      context,
      'Delete review?',
      'This review by ${r.userName} will be removed for all customers.',
      yes: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await fs.FirebaseFirestore.instance.collection('reviews').doc(r.id).delete();
      if (mounted) snack(context, 'Review deleted');
    } catch (_) {
      if (mounted) snack(context, 'Could not delete the review. Please try again.');
    }
  }

  Widget _stars(int n) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(i <= n ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: AC.warning),
    ],
  );

  Widget _card(_AdminReview r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AC.primary.withValues(alpha: .10),
                child: Text(
                  r.userName.trim().isEmpty ? '?' : r.userName.trim()[0].toUpperCase(),
                  style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body)),
                    Text(r.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: AppText.small)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete review',
                icon: const Icon(Icons.delete_outline_rounded, color: AC.danger, size: 20),
                onPressed: () => _delete(r),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stars(r.stars),
              const SizedBox(width: 8),
              if (r.verified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AC.success.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Verified purchase', style: TextStyle(color: AC.success, fontSize: AppText.small - 1, fontWeight: FontWeight.w800)),
                ),
              const Spacer(),
              Text(_date(r.date), style: const TextStyle(color: AC.muted, fontSize: AppText.small)),
            ],
          ),
          if (r.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.text.trim(), style: const TextStyle(fontSize: AppText.body, height: 1.4)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: StreamBuilder<fs.QuerySnapshot<Map<String, dynamic>>>(
        stream: fs.FirebaseFirestore.instance.collection('reviews').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyState(icon: Icons.error_outline, title: 'Could not load reviews', subtitle: 'Please check your internet and try again');
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!.docs.map(_AdminReview.from).toList()
            ..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
          if (all.isEmpty) {
            return const EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews yet', subtitle: 'Customer reviews will appear here');
          }

          final q = _search.text.trim().toLowerCase();
          final list = all.where((r) {
            final starOk = _filter == 'All' || r.stars == int.parse(_filter[0]);
            final textOk = q.isEmpty || r.productName.toLowerCase().contains(q) || r.userName.toLowerCase().contains(q) || r.text.toLowerCase().contains(q);
            return starOk && textOk;
          }).toList();
          final avg = all.fold<int>(0, (s, r) => s + r.stars) / all.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: adminGradient, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(avg.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                          const SizedBox(height: 3),
                          const Text('Average rating', style: TextStyle(color: Colors.white70, fontSize: AppText.small)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('${all.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                          const SizedBox(height: 3),
                          const Text('Total reviews', style: TextStyle(color: Colors.white70, fontSize: AppText.small)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search phone, customer or review', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final sel = f == _filter;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? AC.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AC.primary : AC.muted.withValues(alpha: .25)),
                        ),
                        child: Text(f, style: TextStyle(fontSize: AppText.small, fontWeight: FontWeight.w800, color: sel ? Colors.white : AC.muted)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyState(icon: Icons.search_off_rounded, title: 'No matching reviews'),
                ),
              for (final r in list) _card(r),
            ],
          );
        },
      ),
    );
  }
}