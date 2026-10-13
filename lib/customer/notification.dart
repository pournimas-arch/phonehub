import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Customer notifications backed by Firestore.
/// Expected document fields: userId, title, body, type, isRead, createdAt.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'delivery':
      case 'shipping':
      case 'out_for_delivery':
        return Icons.local_shipping_rounded;
      case 'offer':
      case 'promotion':
        return Icons.local_offer_rounded;
      case 'price_drop':
        return Icons.trending_down_rounded;
      case 'order':
      case 'order_confirmed':
        return Icons.verified_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type.toLowerCase()) {
      case 'offer':
      case 'promotion':
        return AppColors.accent;
      case 'price_drop':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _timeLabel(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (date == null) return 'Just now';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hrs ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _markRead(DocumentReference<Map<String, dynamic>> ref) async {
    await ref.update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> _markAllRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      if (doc.data()['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true, 'readAt': FieldValue.serverTimestamp()});
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications.')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.muted),
                  const SizedBox(height: 10),
                  const Text('Could not load notifications', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Check your connection and Firestore Rules.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () {}, child: const Text('Retry by reopening')),
                ]),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final aDate = a.data()['createdAt'];
            final bDate = b.data()['createdAt'];
            final aMs = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
            final bMs = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;
            return bMs.compareTo(aMs);
          });
          final hasUnread = docs.any((d) => d.data()['isRead'] != true);

          return Column(children: [
            if (hasUnread)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: TextButton(
                    onPressed: () async {
                      try {
                        await _markAllRead(docs);
                      } catch (_) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not mark notifications as read.')));
                      }
                    },
                    child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none_rounded, size: 80, color: AppColors.muted),
                SizedBox(height: 10),
                Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ]))
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final title = (data['title'] ?? 'Notification').toString();
                  final body = (data['body'] ?? data['message'] ?? '').toString();
                  final type = (data['type'] ?? '').toString();
                  final unread = data['isRead'] != true;
                  final color = _colorFor(type);
                  return GestureDetector(
                    onTap: unread ? () async {
                      try { await _markRead(doc.reference); }
                      catch (_) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not mark notification as read.'))); }
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: cardDeco(),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(_iconFor(type), color: color, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text)),), if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle))]),
                          const SizedBox(height: 4),
                          Text(body, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
                          const SizedBox(height: 6),
                          Text(_timeLabel(data['createdAt']), style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                        ])),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
