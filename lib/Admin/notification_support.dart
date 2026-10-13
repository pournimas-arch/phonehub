import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_data.dart';

/// Notifications: Send push | History | My alerts.
class AdminNotificationsScreen extends StatelessWidget {
  final int initialTab;
  const AdminNotificationsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          bottom: const TabBar(
            labelColor: AC.primary,
            indicatorColor: AC.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: [Tab(text: 'Send'), Tab(text: 'History'), Tab(text: 'Alerts')],
          ),
        ),
        body: const TabBarView(children: [_SendTab(), _HistoryTab(), _AlertsTab()]),
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
  static const audiences = ['All customers', 'Customers with orders', 'New customers (no orders)', 'Customers with wishlist items'];
  static const templates = [
    ('Festive Sale', 'Up to 60% off on refurbished phones. Shop now!'),
    ('Price drop', 'A phone on your wishlist just got cheaper.'),
    ('New arrivals', 'Fresh like-new phones just landed on PhoneHub.'),
  ];

  int get _reach {
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
    final ok = await confirmDialog(context, 'Send to $_reach customers?', '"${_title.text.trim()}" will be sent as a push notification to: $audience.', yes: 'Send');
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text('Quick templates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in templates)
              ActionChip(
                label: Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                backgroundColor: Colors.white,
                onPressed: () => setState(() {
                  _title.text = t.$1;
                  _body.text = t.$2;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(controller: _title, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Title')),
        const SizedBox(height: 12),
        TextField(controller: _body, onChanged: (_) => setState(() {}), maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: audience,
          decoration: const InputDecoration(labelText: 'Send to'),
          items: [for (final a in audiences) DropdownMenuItem(value: a, child: Text(a))],
          onChanged: (v) => setState(() => audience = v ?? audience),
        ),
        const SectionTitle('Preview'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDeco(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(Icons.local_offer_rounded, AC.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title.text.isEmpty ? 'Notification title' : _title.text, style: TextStyle(fontWeight: FontWeight.w800, color: _title.text.isEmpty ? AC.muted : AC.text)),
                    const SizedBox(height: 2),
                    Text(_body.text.isEmpty ? 'Your message will appear here' : _body.text, style: const TextStyle(color: AC.muted, fontSize: 12.5, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Reaches about $_reach customers', style: const TextStyle(color: AC.muted, fontSize: 12)),
        const SizedBox(height: 18),
        ElevatedButton.icon(onPressed: _send, icon: const Icon(Icons.send_rounded, size: 18), label: const Text('Send notification')),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => store.sentNotifs.isEmpty
          ? const EmptyState(icon: Icons.history_rounded, title: 'Nothing sent yet')
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          for (final n in store.sentNotifs)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: cardDeco(radius: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(Icons.campaign_rounded, AC.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(n.body, style: const TextStyle(color: AC.muted, fontSize: 12.5, height: 1.35)),
                        const SizedBox(height: 6),
                        Text('${n.audience} • ${timeAgo(n.time)}', style: const TextStyle(color: AC.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              decoration: cardDeco(radius: 14),
              child: SwitchListTile(
                value: store.pushAlerts,
                activeColor: AC.success,
                onChanged: (v) {
                  store.pushAlerts = v;
                  store.changed();
                },
                title: const Text('Alert me on this phone', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('New orders, cancellations and low stock', style: TextStyle(fontSize: 12, color: AC.muted)),
              ),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.notifications_none_rounded, title: 'All caught up', subtitle: 'No new alerts')),
            for (final a in list)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(radius: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(a.icon, a.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(a.body, style: const TextStyle(color: AC.muted, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                    Text(timeAgo(a.time), style: const TextStyle(color: AC.muted, fontSize: 11)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Support tickets list.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.tickets.where((t) => filter == 'All' || t.status == filter).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Support'),
            actions: [IconButton(icon: const Icon(Icons.quiz_rounded), tooltip: 'Edit FAQs', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaqEditorScreen())))],
          ),
          body: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 0, 10), child: ChipTabs(items: const ['All', 'Open', 'In Progress', 'Resolved'], selected: filter, onSelect: (v) => setState(() => filter = v))),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.headset_mic_outlined, title: 'No tickets')
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    for (final t in list)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: cardDeco(radius: 16),
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: t.id))),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: IconBadge(Icons.chat_bubble_rounded, statusColor(t.status)),
                          title: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          subtitle: Text('#${t.id} • ${store.customerName(t.customerId)}\n${t.messages.last.text}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AC.muted, fontSize: 12, height: 1.4)),
                          isThreeLine: true,
                          trailing: StatusChip(t.status),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        final t = store.tickets.firstWhere((x) => x.id == widget.ticketId);
        final c = store.customerById(t.customerId);
        return Scaffold(
          appBar: AppBar(
            title: Text('#${t.id}'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  t.status = v;
                  store.changed();
                },
                itemBuilder: (_) => [for (final s in ['Open', 'In Progress', 'Resolved']) PopupMenuItem(value: s, child: Text('Mark as $s'))],
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: cardDeco(radius: 16),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: AC.primary, child: Text(c?.initial ?? '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w800)), Text(c?.name ?? '', style: const TextStyle(color: AC.muted, fontSize: 12))])),
                    StatusChip(t.status),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    for (final m in t.messages)
                      Align(
                        alignment: m.fromAdmin ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: m.fromAdmin ? AC.primary : Colors.white,
                            borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(m.fromAdmin ? 16 : 4), bottomRight: Radius.circular(m.fromAdmin ? 4 : 16)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m.text, style: TextStyle(color: m.fromAdmin ? Colors.white : AC.text, fontSize: 13.5, height: 1.35)),
                              const SizedBox(height: 3),
                              Text(timeAgo(m.time), style: TextStyle(color: m.fromAdmin ? Colors.white60 : AC.muted, fontSize: 10)),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: t.status == 'Resolved'
                      ? OutlinedButton(
                    onPressed: () {
                      t.status = 'Open';
                      store.changed();
                    },
                    child: const Text('Reopen ticket'),
                  )
                      : Row(
                    children: [
                      Expanded(child: TextField(controller: _reply, decoration: const InputDecoration(hintText: 'Type your reply...'))),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AC.primary, minimumSize: const Size(50, 50)),
                        onPressed: () {
                          final text = _reply.text.trim();
                          if (text.isEmpty) return;
                          store.addTicketReply(t, text);
                          _reply.clear();
                        },
                        icon: const Icon(Icons.send_rounded),
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

/// Edit the FAQs shown on the customer Help & Support screen.
class FaqEditorScreen extends StatelessWidget {
  const FaqEditorScreen({super.key});

  Future<void> _edit(BuildContext context, {Faq? faq}) async {
    final q = TextEditingController(text: faq?.q ?? '');
    final a = TextEditingController(text: faq?.a ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(faq == null ? 'Add FAQ' : 'Edit FAQ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: q, decoration: const InputDecoration(labelText: 'Question')),
            const SizedBox(height: 12),
            TextField(controller: a, maxLines: 3, decoration: const InputDecoration(labelText: 'Answer')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (q.text.trim().isEmpty || a.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      if (faq == null) {
        store.faqs.add(Faq(q.text.trim(), a.text.trim()));
      } else {
        faq
          ..q = q.text.trim()
          ..a = a.text.trim();
      }
      store.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('FAQs')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context), backgroundColor: AC.accent, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Add FAQ', style: TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          children: [
            for (final f in store.faqs)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDeco(radius: 16),
                child: ListTile(
                  onTap: () => _edit(context, faq: f),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(f.q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(f.a, style: const TextStyle(color: AC.muted, fontSize: 12.5, height: 1.35))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AC.danger),
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'Delete this FAQ?', f.q, yes: 'Delete', danger: true);
                      if (ok) {
                        store.faqs.remove(f);
                        store.changed();
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
