import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';

/// Session 7.5 — Engagement Dashboard & Review Queue
///
/// Real-time feed (30s auto-refresh), flagged review queue with
/// approve/edit/skip/block, DM inbox with conversation threads.

final _flaggedProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/engagement/flagged', params: {'limit': '50'});
  return List<Map<String, dynamic>>.from(resp.data);
});

final _dmStatusProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/engagement/dm/status');
  return resp.data as Map<String, dynamic>;
});

final _dmConvosProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/engagement/dm/conversations');
  return List<Map<String, dynamic>>.from(resp.data);
});

final _commentRateProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/engagement/comments/rate-status');
  return resp.data as Map<String, dynamic>;
});

class EngagementScreen extends ConsumerStatefulWidget {
  const EngagementScreen({super.key});
  @override
  ConsumerState<EngagementScreen> createState() => _EngagementScreenState();
}

class _EngagementScreenState extends ConsumerState<EngagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(_flaggedProvider);
      ref.invalidate(_dmConvosProvider);
      ref.invalidate(_commentRateProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagement'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Review Queue'),
            Tab(text: 'DM Inbox'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ReviewQueueTab(),
          _DMInboxTab(),
          _EngagementStatsTab(),
        ],
      ),
    );
  }
}

class _ReviewQueueTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = ref.watch(_flaggedProvider);

    return flagged.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 48, color: Colors.green),
              SizedBox(height: 12),
              Text('All clear — no items to review'),
            ],
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) => _FlaggedItemCard(item: items[i], onAction: () {
            ref.invalidate(_flaggedProvider);
          }),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _FlaggedItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAction;
  const _FlaggedItemCard({required this.item, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sentiment = (item['sentiment_score'] as num?)?.toDouble() ?? 0;
    final sentimentColor = sentiment < -0.5 ? Colors.red
        : sentiment < 0 ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_platformIcon(item['platform']), size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text('@${item['user_handle'] ?? 'unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${sentiment.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: sentimentColor, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(item['content'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
            if (item['flag_reason'] != null) ...[
              const SizedBox(height: 6),
              Text(item['flag_reason'], style: TextStyle(
                fontSize: 11, color: Colors.red[300], fontStyle: FontStyle.italic,
              )),
            ],
            const SizedBox(height: 12),
            Row(children: [
              _MiniButton(label: 'Approve', color: Colors.green, onTap: () async {
                await ApiClient().post('/engagement/flagged/${item['id']}/resolve');
                onAction();
              }),
              const SizedBox(width: 6),
              _MiniButton(label: 'Skip', color: Colors.grey, onTap: () async {
                await ApiClient().post('/engagement/flagged/${item['id']}/resolve');
                onAction();
              }),
            ]),
          ],
        ),
      ),
    );
  }

  IconData _platformIcon(String? p) => switch (p) {
    'instagram' => Icons.photo_camera,
    'tiktok' => Icons.music_note,
    _ => Icons.public,
  };
}

class _MiniButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _DMInboxTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convos = ref.watch(_dmConvosProvider);
    final dmStatus = ref.watch(_dmStatusProvider);

    return Column(
      children: [
        // DM system status bar
        dmStatus.when(
          data: (s) => Container(
            padding: const EdgeInsets.all(12),
            color: (s['global_manual_mode'] == true)
                ? Colors.orange.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            child: Row(children: [
              Icon(
                s['global_manual_mode'] == true ? Icons.pan_tool : Icons.smart_toy,
                size: 16,
                color: s['global_manual_mode'] == true ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                s['global_manual_mode'] == true ? 'Manual Mode' : 'Auto-Reply Active',
                style: TextStyle(
                  fontSize: 13,
                  color: s['global_manual_mode'] == true ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: s['global_manual_mode'] != true,
                onChanged: (v) async {
                  await ApiClient().post('/engagement/dm/global-mode', data: {'manual_mode': !v});
                  ref.invalidate(_dmStatusProvider);
                },
              ),
            ]),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Conversation list
        Expanded(
          child: convos.when(
            data: (list) {
              if (list.isEmpty) return const Center(child: Text('No DM conversations'));
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${(c['sender_id'] ?? '?')[0]}')),
                    title: Text(c['sender_id'] ?? 'Unknown'),
                    subtitle: Text(
                      c['manual_takeover'] == true
                          ? 'Manual takeover'
                          : '${c['remaining_auto_replies']} auto-replies left',
                    ),
                    trailing: Switch(
                      value: c['manual_takeover'] != true,
                      onChanged: (v) async {
                        await ApiClient().post(
                          '/engagement/dm/conversations/${c['sender_id']}/takeover',
                          data: {'takeover': !v},
                        );
                        ref.invalidate(_dmConvosProvider);
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ),
      ],
    );
  }
}

class _EngagementStatsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(_commentRateProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: rate.when(
        data: (r) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comment Reply Limits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _StatRow('Hourly remaining', '${r['remaining_hourly']}/${r['hourly_limit']}'),
            _StatRow('Daily remaining', '${r['remaining_daily']}/${r['daily_limit']}'),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
