import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

// Text sizes (same as the Coupons & Offers screen)
const double _fHeader = 18;
const double _fTitle = 12;
const double _fBody = 10.5;
const double _fSmall = 9.5;

// -----------------------------------------------------------------------------
// Small shared helpers
// -----------------------------------------------------------------------------

AppBar _appBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
  centerTitle: false,
  leadingWidth: 48,
  titleSpacing: 4,
  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fHeader)),
  actions: actions,
  bottom: bottom,
);

InputDecoration _dec(String label, {String? hint, String? error}) => InputDecoration(
  labelText: label,
  hintText: hint,
  errorText: error,
  isDense: true,
  labelStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
  hintStyle: const TextStyle(fontSize: _fBody, color: AC.muted),
  errorStyle: const TextStyle(fontSize: _fSmall),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .22))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.muted.withValues(alpha: .22))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.primary, width: 1.3)),
);

Widget _searchBox(String hint, ValueChanged<String> onChanged) => Padding(
  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
  child: SizedBox(
    height: 42,
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: _fBody + 1),
      decoration: InputDecoration(
        hintText: hint,
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
);

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

Widget _statusPill(String status) {
  final c = statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Text(status, style: TextStyle(color: c, fontSize: _fSmall, fontWeight: FontWeight.w800)),
  );
}

Widget _iconBox(IconData icon, Color color) => Container(
  width: 34,
  height: 34,
  decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
  child: Icon(icon, size: 18, color: color),
);

Widget _card({required Widget child, VoidCallback? onTap}) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  decoration: cardDeco(radius: 16),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Material(
      color: Colors.white,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(12), child: child)),
    ),
  ),
);

Widget _label(String t) => Padding(
  padding: const EdgeInsets.only(top: 6, bottom: 8),
  child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
);

Widget _bigButton(String text, VoidCallback onTap, {IconData? icon}) => ElevatedButton.icon(
  onPressed: onTap,
  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46), textStyle: const TextStyle(fontSize: _fBody + 2, fontWeight: FontWeight.w800)),
  icon: Icon(icon ?? Icons.check_rounded, size: 17),
  label: Text(text),
);

// -----------------------------------------------------------------------------
// Notifications: Compose | History | Alerts
// -----------------------------------------------------------------------------

class AdminNotificationsScreen extends StatelessWidget {
  final int initialTab;
  const AdminNotificationsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(textTheme: base.textTheme.apply(fontSizeDelta: -2)),
      child: DefaultTabController(
        length: 3,
        initialIndex: initialTab.clamp(0, 2),
        child: Scaffold(
          appBar: _appBar(
            'Notifications',
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.muted.withValues(alpha: .15)))),
                child: const TabBar(
                  labelPadding: EdgeInsets.zero, // 3 equal tabs
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AC.primary,
                  unselectedLabelColor: AC.muted,
                  indicatorColor: AC.primary,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1),
                  tabs: [
                    Tab(height: 44, icon: Icon(Icons.send_rounded, size: 16), text: 'Compose'),
                    Tab(height: 44, icon: Icon(Icons.history_rounded, size: 16), text: 'History'),
                    Tab(height: 44, icon: Icon(Icons.notifications_active_rounded, size: 16), text: 'Alerts'),
                  ],
                ),
              ),
            ),
          ),
          body: const TabBarView(children: [_SendTab(), _HistoryTab(), _AlertsTab()]),
        ),
      ),
    );
  }
}

class _SendTab extends StatefulWidget {
  const _SendTab();

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String audience = 'All customers';

  static const audiences = ['All customers', 'Customers with orders', 'New customers (no orders)', 'Customers with wishlist items', 'Delivery partners'];

  /// Quick templates are written from the store's real data (best discount, a live coupon,
  /// phones in stock). Nothing is built in, so no made-up offer can be sent by mistake.
  List<(String, String)> get templates {
    final list = <(String, String)>[];
    final inStock = store.phones.where((p) => p.active && p.stock > 0).toList();
    final best = inStock.fold<int>(0, (m, p) => p.off > m ? p.off : m);
    if (best > 0) list.add(('Best offers', 'Up to $best% off on refurbished phones. Shop now!'));
    final live = store.coupons.where((c) => c.active && !c.expired).toList();
    if (live.isNotEmpty) {
      final c = live.first;
      list.add(('Coupon ${c.code}', 'Use code ${c.code}${c.title.isEmpty ? '' : ' - ${c.title}'} on your next order.'));
    }
    if (inStock.isNotEmpty) {
      list.add(('In stock now', '${inStock.length} phone(s) are available on PhoneHub right now. Take a look!'));
    }
    return list;
  }

  bool get _toPartners => audience == 'Delivery partners';
  String get _noun => _toPartners ? 'delivery partners' : 'customers';

  int get _reach {
    // Only partners who have logged in at least once have an app to receive it.
    if (_toPartners) return store.partners.where((p) => p.active && p.uid.isNotEmpty).length;
    switch (audience) {
      case 'Customers with orders':
        return store.customers.where((c) => store.ordersOf(c.id).isNotEmpty).length;
      case 'New customers (no orders)':
        return store.customers.where((c) => store.ordersOf(c.id).isEmpty).length;
      case 'Customers with wishlist items':
        return store.customers.where((c) => c.wishlist.isNotEmpty).length;
    }
    return store.customers.where((c) => !c.blocked).length;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      snack(context, 'Add a title and a message');
      return;
    }
    final ok = await confirmDialog(context, 'Send to $_reach $_noun?', '"${_title.text.trim()}" will be sent to: $audience.', yes: 'Send');
    if (!ok) return;
    store.sendNotification(_title.text.trim(), _body.text.trim(), audience);
    _title.clear();
    _body.clear();
    setState(() {});
    if (mounted) snack(context, 'Notification sent');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        if (templates.isNotEmpty) ...[
          _label('Quick templates'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final t in templates)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() {
                    _title.text = t.$1;
                    _body.text = t.$2;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AC.primary.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AC.primary.withValues(alpha: .25)),
                    ),
                    child: Text(t.$1, style: const TextStyle(fontSize: _fSmall, fontWeight: FontWeight.w700, color: AC.primary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          maxLength: 60,
          style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
          decoration: _dec('Notification title').copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          onChanged: (_) => setState(() {}),
          maxLines: 3,
          maxLength: 240,
          style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
          decoration: _dec('Message').copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: audience,
          isExpanded: true,
          style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600, color: AC.text),
          decoration: _dec('Audience'),
          items: [for (final a in audiences) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => audience = v ?? audience),
        ),
        _label('Preview'),
        _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(Icons.local_offer_rounded, AC.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.text.isEmpty ? 'Notification title' : _title.text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle, color: _title.text.isEmpty ? AC.muted : AC.text)),
                    const SizedBox(height: 2),
                    Text(_body.text.isEmpty ? 'Your message will appear here' : _body.text, style: const TextStyle(color: AC.muted, fontSize: _fBody, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(Icons.groups_2_rounded, size: 16, color: AC.muted),
            const SizedBox(width: 6),
            const Expanded(child: Text('Estimated audience', style: TextStyle(color: AC.muted, fontSize: _fSmall))),
            Text('$_reach $_noun', style: const TextStyle(color: AC.primary, fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
          ],
        ),
        const SizedBox(height: 16),
        _bigButton('Review and send', _send, icon: Icons.send_rounded),
        const SizedBox(height: 8),
        const Text(
          'Note: sending is recorded in the app history. Real device push delivery requires Firebase Cloud Messaging integration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AC.muted, fontSize: _fSmall - 1, height: 1.4),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.sentNotifs;
        final items = all.where((n) => '${n.title} ${n.body} ${n.audience}'.toLowerCase().contains(query.toLowerCase())).toList();
        return Column(
          children: [
            _searchBox('Search notification history', (v) => setState(() => query = v)),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                icon: Icons.history_rounded,
                title: all.isEmpty ? 'Nothing sent yet' : 'No matching notifications',
                subtitle: all.isEmpty ? 'Your sent messages will appear here.' : 'Try another search.',
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  for (final n in items)
                    _card(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconBox(Icons.campaign_rounded, AC.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                                const SizedBox(height: 2),
                                Text(n.body, style: const TextStyle(color: AC.muted, fontSize: _fBody, height: 1.35)),
                                const SizedBox(height: 6),
                                Text('${n.audience} • ${timeAgo(n.time)}', style: const TextStyle(color: AC.primary, fontSize: _fSmall, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.alerts;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: cardDeco(radius: 12),
              child: Row(
                children: [
                  const Icon(Icons.phone_android_rounded, size: 18, color: AC.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alert me on this phone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: _fBody + 1)),
                        Text('New orders, cancellations and low stock', style: TextStyle(color: AC.muted, fontSize: _fSmall)),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: .85,
                    child: Switch(
                      value: store.pushAlerts,
                      activeColor: AC.success,
                      onChanged: (v) {
                        store.pushAlerts = v;
                        store.changed();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.notifications_none_rounded, title: 'All caught up', subtitle: 'No new alerts')),
            for (final a in list)
              _card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(a.icon, a.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                          const SizedBox(height: 2),
                          Text(a.body, style: const TextStyle(color: AC.muted, fontSize: _fBody, height: 1.35)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo(a.time), style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Support tickets
// -----------------------------------------------------------------------------

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String filter = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(textTheme: base.textTheme.apply(fontSizeDelta: -2)),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final all = store.tickets;
          int count(String s) => s == 'All' ? all.length : all.where((t) => t.status == s).length;
          final list = all.where((t) => (filter == 'All' || t.status == filter) && '${t.subject} ${t.id} ${store.ticketSender(t)}'.toLowerCase().contains(query.toLowerCase())).toList();

          return Scaffold(
            appBar: _appBar(
              'Support',
              actions: [
                IconButton(
                  icon: const Icon(Icons.quiz_rounded, size: 22),
                  tooltip: 'Edit FAQs',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaqEditorScreen())),
                ),
              ],
            ),
            body: Column(
              children: [
                _searchBox('Search by ticket, customer or subject', (v) => setState(() => query = v)),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final s in const ['All', 'Open', 'In Progress', 'Resolved'])
                        Padding(padding: const EdgeInsets.only(right: 7), child: _pill(s, count(s), filter == s, () => setState(() => filter = s))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(
                    icon: Icons.headset_mic_outlined,
                    title: all.isEmpty ? 'No tickets' : 'No matching tickets',
                    subtitle: all.isEmpty ? 'Customer support requests appear here' : 'Try another search or status',
                  )
                      : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    children: [
                      for (final t in list)
                        _card(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: t.id))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _iconBox(Icons.chat_bubble_rounded, statusColor(t.status)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                                    const SizedBox(height: 2),
                                    Text('#${t.id} • ${store.ticketSender(t)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                                    const SizedBox(height: 4),
                                    Text(t.messages.isEmpty ? 'No messages yet' : t.messages.last.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.text, fontSize: _fBody, height: 1.3)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusPill(t.status),
                            ],
                          ),
                        ),
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
}

/// One ticket: chat with the customer, change status.
class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final matches = store.tickets.where((x) => x.id == widget.ticketId);
        if (matches.isEmpty) {
          return Scaffold(appBar: _appBar('Support ticket'), body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Ticket not found', subtitle: 'This ticket may have been removed.'));
        }
        final t = matches.first;
        final c = store.customerById(t.customerId);
        final sender = store.ticketSender(t);

        return Scaffold(
          appBar: _appBar(
            '#${t.id}',
            actions: [
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  t.status = v;
                  store.changed();
                },
                itemBuilder: (_) => [
                  for (final s in ['Open', 'In Progress', 'Resolved']) PopupMenuItem(value: s, height: 38, child: Text('Mark as $s', style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                padding: const EdgeInsets.all(12),
                decoration: cardDeco(radius: 16),
                child: Row(
                  children: [
                    CircleAvatar(radius: 18, backgroundColor: AC.primary, child: Text(c?.initial ?? (sender.isEmpty ? '?' : sender[0].toUpperCase()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: _fTitle))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                          Text(t.partnerId.isNotEmpty ? sender : (c?.name ?? ''), style: const TextStyle(color: AC.muted, fontSize: _fSmall)),
                        ],
                      ),
                    ),
                    _statusPill(t.status),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  children: [
                    for (final m in t.messages)
                      Align(
                        alignment: m.fromAdmin ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: m.fromAdmin ? AC.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(m.fromAdmin ? 14 : 4),
                              bottomRight: Radius.circular(m.fromAdmin ? 4 : 14),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m.text, style: TextStyle(color: m.fromAdmin ? Colors.white : AC.text, fontSize: _fBody + 1, height: 1.35)),
                              const SizedBox(height: 3),
                              Text(timeAgo(m.time), style: TextStyle(color: m.fromAdmin ? Colors.white60 : AC.muted, fontSize: _fSmall - 1)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: t.status == 'Resolved'
                      ? OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), textStyle: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w800)),
                    onPressed: () {
                      t.status = 'Open';
                      store.changed();
                    },
                    child: const Text('Reopen ticket'),
                  )
                      : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          style: const TextStyle(fontSize: _fBody + 1),
                          decoration: _dec('', hint: 'Type your reply...').copyWith(labelText: null, filled: true, fillColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AC.primary, minimumSize: const Size(46, 46)),
                        onPressed: () {
                          final text = _reply.text.trim();
                          if (text.isEmpty) return;
                          store.addTicketReply(t, text);
                          _reply.clear();
                        },
                        icon: const Icon(Icons.send_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// FAQs shown on the customer Help & Support screen
// -----------------------------------------------------------------------------

class FaqEditorScreen extends StatelessWidget {
  const FaqEditorScreen({super.key});

  Future<void> _edit(BuildContext context, {Faq? faq}) async {
    final result = await showModalBottomSheet<({String q, String a})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FaqEditor(faq: faq),
    );
    if (result == null) return;
    if (faq == null) {
      store.faqs.add(Faq(result.q, result.a));
    } else {
      faq
        ..q = result.q
        ..a = result.a;
    }
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: _appBar('FAQs'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context),
          backgroundColor: AC.primary,
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add FAQ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: _fBody + 1)),
        ),
        body: store.faqs.isEmpty
            ? const EmptyState(icon: Icons.quiz_outlined, title: 'No FAQs yet', subtitle: 'Add common questions to help customers find answers faster.')
            : ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
          children: [
            for (final f in store.faqs)
              _card(
                onTap: () => _edit(context, faq: f),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(Icons.help_outline_rounded, AC.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: _fTitle)),
                          const SizedBox(height: 3),
                          Text(f.a, style: const TextStyle(color: AC.muted, fontSize: _fBody, height: 1.35)),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, color: AC.danger, size: 20),
                      onPressed: () async {
                        final ok = await confirmDialog(context, 'Delete this FAQ?', f.q, yes: 'Delete', danger: true);
                        if (ok) {
                          store.faqs.remove(f);
                          store.changed();
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The sheet owns (and disposes) its own text controllers.
class _FaqEditor extends StatefulWidget {
  final Faq? faq;
  const _FaqEditor({required this.faq});

  @override
  State<_FaqEditor> createState() => _FaqEditorState();
}

class _FaqEditorState extends State<_FaqEditor> {
  late final _q = TextEditingController(text: widget.faq?.q ?? '');
  late final _a = TextEditingController(text: widget.faq?.a ?? '');
  bool _tried = false;

  @override
  void dispose() {
    _q.dispose();
    _a.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _tried = true);
    final q = _q.text.trim();
    final a = _a.text.trim();
    if (q.isEmpty || a.isEmpty) return;
    Navigator.pop(context, (q: q, a: a));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.faq == null ? 'Add FAQ' : 'Edit FAQ', style: const TextStyle(fontSize: _fHeader - 2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _q,
            style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
            decoration: _dec('Question', error: _tried && _q.text.trim().isEmpty ? 'Required' : null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _a,
            maxLines: 3,
            style: const TextStyle(fontSize: _fBody + 1, fontWeight: FontWeight.w600),
            decoration: _dec('Answer', error: _tried && _a.text.trim().isEmpty ? 'Required' : null),
          ),
          const SizedBox(height: 16),
          _bigButton('Save', _save),
        ],
      ),
    );
  }
}