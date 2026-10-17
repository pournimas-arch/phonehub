import 'package:flutter/material.dart';
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';
import 'package:phonehub/delivery%20partner/delivery_ui.dart';

/// Earnings: live from the partner's delivered orders (Firestore `earning` field).
/// Hero card (this month), Today / This Week / This Month cards and the
/// recent transactions list with a period filter.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  static const filters = ['This Week', 'Last Week', 'This Month'];
  static const int _preview = 5;

  int filter = 0;
  bool showAll = false;

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  int _sum(List<EarningRecord> l) => l.fold<int>(0, (s, e) => s + e.amount);

  void _showDetails(EarningRecord e) {
    Widget row(String label, String value, {Color? color, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: bold ? 15 : 12.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color ?? AppColors.text))),
        ],
      ),
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 38, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            const Text('Delivery Commission', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 10),
            row('Order', '#${e.orderId}'),
            row('Customer', e.customer),
            row('Date', e.dayOffset == 0 ? 'Today' : e.dateLabel),
            const Divider(height: 18, color: AppColors.border),
            row('Earned', '+${rupee(e.amount)}', color: AppColors.success, bold: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DPage(
      title: 'Earnings',
      child: ValueListenableBuilder<List<DeliveryOrder>>(
        valueListenable: orders,
        builder: (context, _, __) {
          final week = earningsFor(0);
          final month = earningsFor(2);
          final today = week.where((e) => e.dayOffset == 0).toList();
          final monthTotal = _sum(month);
          final avg = month.isEmpty ? 0 : (monthTotal / month.length).round();

          final list = earningsFor(filter);
          final shown = showAll ? list : list.take(_preview).toList();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _hero(monthTotal, month.length, avg),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _mini('Today', _sum(today))),
                    const SizedBox(width: 10),
                    Expanded(child: _mini('This Week', _sum(week))),
                    const SizedBox(width: 10),
                    Expanded(child: _mini('This Month', monthTotal)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text))),
                    if (list.length > _preview)
                      GestureDetector(
                        onTap: () => setState(() => showAll = !showAll),
                        child: Text(showAll ? 'Show less' : 'View All', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _filterRow(),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  _empty()
                else
                  Container(
                    decoration: cardDeco(radius: 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          _tile(shown[i]),
                          if (i != shown.length - 1) const Divider(height: 1, indent: 64, color: AppColors.border),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(int total, int count, int avg) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B5E57), AppColors.primary, Color(0xFF14B8A6)]),
      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Earnings (This Month)', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: total.toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(rupee(v.round()), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 6),
              Text('$count deliver${count == 1 ? 'y' : 'ies'}  •  avg ${rupee(avg)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
        ),
      ],
    ),
  );

  Widget _mini(String label, int value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
    decoration: cardDeco(radius: 16),
    child: Column(
      children: [
        FittedBox(child: Text(rupee(value), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    ),
  );

  Widget _filterRow() => SizedBox(
    height: 32,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: filters.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final on = filter == i;
        return GestureDetector(
          onTap: () => setState(() {
            filter = i;
            showAll = false;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? AppColors.primary : AppColors.border),
            ),
            child: Text(filters[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? AppColors.primary : AppColors.muted)),
          ),
        );
      },
    ),
  );

  Widget _tile(EarningRecord e) => InkWell(
    onTap: () => _showDetails(e),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_upward_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Commission',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(e.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(height: 1),
                Text(e.dayOffset == 0 ? 'Today' : e.dateLabel,
                    style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
              ],
            ),
          ),
          Text('+${rupee(e.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: AppColors.success)),
        ],
      ),
    ),
  );

  Widget _empty() => Container(
    padding: const EdgeInsets.symmetric(vertical: 36),
    decoration: cardDeco(radius: 16),
    child: const Column(
      children: [
        Icon(Icons.account_balance_wallet_outlined, size: 40, color: AppColors.muted),
        SizedBox(height: 10),
        Text('No earnings yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        SizedBox(height: 3),
        Text('Delivered orders will appear here', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
      ],
    ),
  );
}