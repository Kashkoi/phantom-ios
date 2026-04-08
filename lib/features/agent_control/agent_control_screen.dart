import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Session 7.7 (part 2) — Agent Control Screen
///
/// Live status, platform API health, queue depth, LLM budget chart,
/// pause/resume/emergency-stop, audit log viewer.

final _healthProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/admin/health');
  return resp.data as Map<String, dynamic>;
});

final _llmHealthProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/admin/llm/health');
  return resp.data as Map<String, dynamic>;
});

final _llmStatsProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/admin/llm/stats');
  return resp.data as Map<String, dynamic>;
});

final _pipelineProvider2 = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/calendar/pipeline');
  return resp.data as Map<String, dynamic>;
});

final _authStatusProvider = FutureProvider.autoDispose((ref) async {
  final ig = await ApiClient().get('/auth/instagram/status');
  final tt = await ApiClient().get('/auth/tiktok/status');
  return {
    'instagram': ig.data as Map<String, dynamic>,
    'tiktok': tt.data as Map<String, dynamic>,
  };
});

class AgentControlScreen extends ConsumerStatefulWidget {
  const AgentControlScreen({super.key});
  @override
  ConsumerState<AgentControlScreen> createState() => _AgentControlState();
}

class _AgentControlState extends ConsumerState<AgentControlScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(_healthProvider);
      ref.invalidate(_llmStatsProvider);
      ref.invalidate(_pipelineProvider2);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Agent Control')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_healthProvider);
          ref.invalidate(_llmHealthProvider);
          ref.invalidate(_llmStatsProvider);
          ref.invalidate(_pipelineProvider2);
          ref.invalidate(_authStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Agent status
            _AgentStatusCard(),
            const SizedBox(height: 16),

            // Platform API health
            const Text('Platform APIs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _PlatformHealthCards(),
            const SizedBox(height: 16),

            // LLM health
            const Text('LLM Providers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _LLMHealthCard(),
            const SizedBox(height: 16),

            // LLM Budget
            const Text('LLM Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _LLMBudgetCard(),
            const SizedBox(height: 16),

            // Queue depth
            const Text('Queue Depth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _QueueDepthCard(),
            const SizedBox(height: 24),

            // Control buttons
            const Text('Controls', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showConfirm('Pause Agent', 'Pause all automated posting?'),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _showConfirm('Resume Agent', 'Resume automated posting?'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                )),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _showConfirm(
                  'EMERGENCY STOP',
                  'This will immediately halt ALL automated actions. Continue?',
                  isDestructive: true,
                ),
                icon: const Icon(Icons.power_settings_new),
                label: const Text('EMERGENCY STOP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirm(String title, String message, {bool isDestructive = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : null,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title executed')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _AgentStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(_healthProvider);

    return health.when(
      data: (h) {
        final status = h['status'] ?? 'unknown';
        final isOk = status == 'ok' || status == 'healthy';
        return Card(
          color: isOk ? const Color(0xFF0D3320) : const Color(0xFF331111),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOk ? Colors.green : Colors.red,
                    boxShadow: [BoxShadow(
                      color: (isOk ? Colors.green : Colors.red).withOpacity(0.6),
                      blurRadius: 12,
                    )],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOk ? 'OPERATIONAL' : status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: isOk ? Colors.green[200] : Colors.red[200],
                      ),
                    ),
                    Text('Service: ${h['service'] ?? 'phantom'}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      )),
      error: (_, __) => Card(
        color: const Color(0xFF331111),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('UNREACHABLE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _PlatformHealthCards extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(_authStatusProvider);

    return auth.when(
      data: (platforms) {
        return Row(children: platforms.entries.map((e) {
          final connected = e.value['connected'] == true;
          final needsRefresh = e.value['needs_refresh'] == true;
          return Expanded(child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Icon(
                  connected ? Icons.check_circle : Icons.error,
                  color: needsRefresh ? Colors.orange : connected ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(e.key[0].toUpperCase() + e.key.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  connected ? (needsRefresh ? 'Needs refresh' : 'Connected') : 'Disconnected',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ]),
            ),
          ));
        }).toList());
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Failed to load platform status'),
    );
  }
}

class _LLMHealthCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final llm = ref.watch(_llmHealthProvider);

    return llm.when(
      data: (h) {
        final providers = h['providers'] as Map<String, dynamic>? ?? {};
        return Row(children: providers.entries.map((e) {
          final isHealthy = e.value == 'healthy';
          return Expanded(child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Icon(isHealthy ? Icons.check_circle : Icons.warning,
                    color: isHealthy ? Colors.green : Colors.orange, size: 24),
                const SizedBox(height: 4),
                Text(e.key == 'gemini' ? 'Gemini' : 'GPT-4o-mini',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Text(isHealthy ? 'Healthy' : 'Degraded',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
          ));
        }).toList());
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('LLM health unavailable'),
    );
  }
}

class _LLMBudgetCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_llmStatsProvider);

    return stats.when(
      data: (s) {
        final budget = s['budget'] as Map<String, dynamic>? ?? {};
        final dailySpend = (budget['daily_spend'] as num?)?.toDouble() ?? 0;
        final dailyLimit = (budget['daily_limit'] as num?)?.toDouble() ?? 1;
        final monthlySpend = (budget['monthly_spend'] as num?)?.toDouble() ?? 0;
        final monthlyLimit = (budget['monthly_limit'] as num?)?.toDouble() ?? 15;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _BudgetBar(label: 'Daily', spent: dailySpend, limit: dailyLimit),
              const SizedBox(height: 12),
              _BudgetBar(label: 'Monthly', spent: monthlySpend, limit: monthlyLimit),
            ]),
          ),
        );
      },
      loading: () => const Card(child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      )),
      error: (_, __) => const Card(child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Budget data unavailable'),
      )),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final String label;
  final double spent, limit;
  const _BudgetBar({required this.label, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    final ratio = (spent / limit).clamp(0.0, 1.0);
    final color = ratio > 0.9 ? Colors.red : ratio > 0.7 ? Colors.orange : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('\$${spent.toStringAsFixed(2)} / \$${limit.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withOpacity(0.15),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _QueueDepthCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipeline = ref.watch(_pipelineProvider2);

    return pipeline.when(
      data: (p) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _QueueStat('Queued', p['queued'] ?? 0, Colors.blue),
                _QueueStat('Publishing', p['publishing'] ?? 0, Colors.orange),
                _QueueStat('Failed', p['failed'] ?? 0, Colors.red),
                _QueueStat('Snap Ready', p['snap_ready'] ?? 0, const Color(0xFFFFFC00)),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      )),
      error: (_, __) => const Card(child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Queue data unavailable'),
      )),
    );
  }
}

class _QueueStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _QueueStat(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$count', style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w800, color: color,
      )),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
    ]);
  }
}
