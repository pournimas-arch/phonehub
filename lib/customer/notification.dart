import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'checkout_ui.dart' show CheckoutBackground;
import 'package:phonehub/app_text.dart';

const Color _cardBorder = Color(0xFFDCE8FF);
const Color _softBlue = Color(0xFFEAF1FF);
const Color _divider = Color(0xFFE5EAF4);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _buildStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  void _retry() {
    setState(() {
      _stream = _buildStream();
    });
  }

  // ------------------------------------------------------------
  // NOTIFICATION ICONS AND COLORS
  // ------------------------------------------------------------

  IconData _iconFor(String type) {
    switch (type.toLowerCase().trim()) {
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

      case 'payment':
        return Icons.account_balance_wallet_rounded;

      case 'wishlist':
        return Icons.favorite_rounded;

      case 'cancelled':
      case 'order_cancelled':
        return Icons.cancel_rounded;

      case 'return':
      case 'refund':
        return Icons.currency_rupee_rounded;

      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type.toLowerCase().trim()) {
      case 'offer':
      case 'promotion':
        return AppColors.accent;

      case 'price_drop':
        return AppColors.success;

      case 'cancelled':
      case 'order_cancelled':
        return AppColors.danger;

      default:
        return AppColors.primary;
    }
  }

  // ------------------------------------------------------------
  // DATE AND TIME HELPERS
  // ------------------------------------------------------------

  DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _timeLabel(dynamic value) {
    final date = _dateOf(value);

    if (date == null) return 'Just now';

    final difference = DateTime.now().difference(date);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _groupOf(dynamic value) {
    final date = _dateOf(value);

    if (date == null) return 'Today';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    if (difference <= 0) return 'Today';
    if (difference == 1) return 'Yesterday';

    return 'Earlier';
  }

  // ------------------------------------------------------------
  // FIRESTORE ACTIONS
  // ------------------------------------------------------------

  Future<void> _markRead(
      DocumentReference<Map<String, dynamic>> reference,
      ) async {
    await reference.update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAllRead(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
    final unreadDocs = docs
        .where((doc) => doc.data()['isRead'] != true)
        .toList();

    if (unreadDocs.isEmpty) return;

    final firestore = FirebaseFirestore.instance;

    // Firestore batches support a maximum of 500 operations.
    for (var start = 0; start < unreadDocs.length; start += 450) {
      final end = (start + 450 < unreadDocs.length)
          ? start + 450
          : unreadDocs.length;

      final batch = firestore.batch();

      for (final doc in unreadDocs.sublist(start, end)) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }

    _toast('All notifications marked as read.');
  }

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CheckoutBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 12),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER - MATCHES WISHLIST SCREEN
  // ------------------------------------------------------------

  Widget _header() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final unreadCount = docs
            .where((doc) => doc.data()['isRead'] != true)
            .length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                _headerButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'YOUR LATEST UPDATES',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Text(
                    '$unreadCount new',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTENT
  // ------------------------------------------------------------

  Widget _content() {
    final stream = _stream;

    if (stream == null) {
      return _centerMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Please sign in',
        subtitle: 'Sign in to view your notifications.',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _centerMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load notifications',
            subtitle: 'Check your connection and try again.',
            action: _actionButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: _retry,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        final docs = snapshot.data?.docs.toList() ?? [];

        docs.sort((a, b) {
          final aDate = _dateOf(a.data()['createdAt']);
          final bDate = _dateOf(b.data()['createdAt']);

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return _emptyState();
        }

        final unreadCount = docs
            .where((doc) => doc.data()['isRead'] != true)
            .length;

        final items = <Object>[];
        String? lastGroup;

        for (final doc in docs) {
          final group = _groupOf(doc.data()['createdAt']);

          if (group != lastGroup) {
            items.add(group);
            lastGroup = group;
          }

          items.add(doc);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 17,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your Updates',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: AppText.body,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    '${docs.length} ${docs.length == 1 ? 'notification' : 'notifications'}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mark_email_unread_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$unreadCount unread',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: AppText.caption,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        try {
                          await _markAllRead(docs);
                        } catch (_) {
                          _toast(
                            'Could not mark notifications as read.',
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: AppText.small,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  if (item is String) {
                    return _sectionHeader(item);
                  }

                  final doc = item
                  as QueryDocumentSnapshot<Map<String, dynamic>>;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _notificationCard(doc),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SECTION HEADER
  // ------------------------------------------------------------

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: AppText.body,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // NOTIFICATION CARD - WISHLIST GLASS CARD STYLE
  // ------------------------------------------------------------

  Widget _notificationCard(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    final title = (data['title'] ?? 'Notification').toString();
    final body = (data['body'] ?? data['message'] ?? '').toString();
    final type = (data['type'] ?? '').toString();
    final unread = data['isRead'] != true;
    final color = _colorFor(type);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: unread ? 0.96 : 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread ? _cardBorder : _divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(
              alpha: unread ? 0.07 : 0.035,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: unread
              ? () async {
            try {
              await _markRead(doc.reference);
            } catch (_) {
              _toast('Could not mark notification as read.');
            }
          }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: color.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Icon(
                    _iconFor(type),
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppText.body,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: AppColors.text,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: AppText.small,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: AppColors.muted.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _timeLabel(data['createdAt']),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: AppText.caption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _softBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: AppColors.success,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE - MATCHES WISHLIST EMPTY STATE
  // ------------------------------------------------------------

  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _cardBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppText.subtitle,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your order updates, delivery information and special offers will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: AppText.small,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cardBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'You are all caught up',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: AppText.caption,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ERROR AND SIGN-IN STATES
  // ------------------------------------------------------------

  Widget _centerMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _cardBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: AppText.subtitle,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: AppText.small,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: AppText.small,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        side: const BorderSide(color: _cardBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}