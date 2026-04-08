import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/platform/platform_utils.dart';

final _pipelineProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/calendar/pipeline');
  return resp.data as Map<String, dynamic>;
});

final _agentHealthProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/admin/health');
  return resp.data as Map<String, dynamic>;
});

final _connectionsProvider = FutureProvider.autoDispose((ref) async {
  try {
    final resp = await ApiClient().get('/auth/all/status');
    return resp.data as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pipeline = ref.watch(_pipelineProvider);
    final health = ref.watch(_agentHealthProvider);
    final connections = ref.watch(_connectionsProvider);
    final wide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF00D2FF), Color(0xFF7B2FF7)],
          ).createShader(b),
          child: const Text('PHANTOM', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.monitor_heart_outlined),
            onPressed: () => context.push('/agent-control')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_pipelineProvider);
          ref.invalidate(_agentHealthProvider);
          ref.invalidate(_connectionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Agent status
            health.when(
              data: (h) => _StatusCard(status: h['status'] ?? 'unknown'),
              loading: () => const _StatusCard(status: 'loading'),
              error: (_, __) => const _StatusCard(status: 'error'),
            ),
            const SizedBox(height: 16),

            // Quick actions
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _QuickAction(icon: Icons.add_photo_alternate, label: 'New Post',
                  color: cs.primary, onTap: () => context.push('/media-browser')),
                _QuickAction(icon: Icons.folder_special, label: 'Media Sources',
                  color: const Color(0xFF00D2FF), onTap: () => context.push('/media-sources')),
                if (!isDesktop)
                  _QuickAction(icon: Icons.camera_alt, label: 'Snap Post',
                    color: const Color(0xFFFFFC00), onTap: () => context.push('/snap-post')),
                _QuickAction(icon: Icons.link, label: 'Connect',
                  color: const Color(0xFFFF6B35), onTap: () => context.go('/connections')),
              ],
            ),
            const SizedBox(height: 20),

            // Connected accounts summary
            connections.when(
              data: (c) => _ConnectionsSummary(data: c),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Pipeline overview
            pipeline.when(
              data: (p) => _PipelineCard(data: p),
              loading: () => const Card(child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )),
              error: (_, __) => const Card(child: Padding(
                padding: EdgeInsets.all(24), child: Text('Failed to load pipeline'),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'ok' || status == 'healthy';
    return Card(
      color: isOk ? const Color(0xFF0D3320) : const Color(0xFF331111),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(
            shape: BoxShape.circle, color: isOk ? Colors.green : Colors.red,
            boxShadow: [BoxShadow(color: (isOk ? Colors.green : Colors.red).withOpacity(0.5), blurRadius: 8)],
          )),
          const SizedBox(width: 12),
          Text(isOk ? 'Agent Online' : 'Agent ${status.toUpperCase()}',
            style: TextStyle(color: isOk ? Colors.green[200] : Colors.red[200], fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('Phantom v0.1', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 600;
    return SizedBox(
      width: wide ? 150 : (MediaQuery.of(context).size.width - 44) / 2,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ConnectionsSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ConnectionsSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connected Accounts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: data.entries.map((e) {
              final platform = e.key;
              final info = e.value as Map<String, dynamic>? ?? {};
              final connected = info['connected'] == true;
              return Expanded(child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: connected ? Colors.green : Colors.grey,
                )),
                const SizedBox(width: 6),
                Text(platform[0].toUpperCase() + platform.substring(1),
                  style: TextStyle(fontSize: 12, color: connected ? null : Colors.grey[500])),
              ]));
            }).toList()),
          ],
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PipelineCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Draft', data['draft'] ?? 0, Colors.grey),
      ('Queued', data['queued'] ?? 0, Colors.blue),
      ('Publishing', data['publishing'] ?? 0, Colors.orange),
      ('Published', data['published'] ?? 0, Colors.green),
      ('Failed', data['failed'] ?? 0, Colors.red),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Content Pipeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${data['total'] ?? 0} total', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: items.map((e) {
              final count = e.$2 as int;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: e.$3.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: e.$3)),
                  const SizedBox(width: 6),
                  Text('${e.$1}: $count', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: e.$3)),
                ]),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }
}
