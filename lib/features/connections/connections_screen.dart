import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/platform/oauth_handler.dart';

/// Social account connection dashboard.
/// Shows Instagram, TikTok, Snapchat with connect/disconnect/status.

final _connectionsProvider = FutureProvider.autoDispose((ref) async {
  final results = <String, Map<String, dynamic>>{};
  for (final platform in ['instagram', 'tiktok']) {
    try {
      final resp = await ApiClient().get('/auth/$platform/status');
      results[platform] = resp.data as Map<String, dynamic>;
    } catch (_) {
      results[platform] = {'platform': platform, 'connected': false};
    }
  }
  results['snapchat'] = {'platform': 'snapchat', 'connected': false, 'note': 'Manual posting via iOS app'};
  return results;
});

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(_connectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_connectionsProvider),
          ),
        ],
      ),
      body: connections.when(
        data: (platforms) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel('Social Platforms'),
            const SizedBox(height: 8),
            _PlatformCard(
              platform: 'instagram',
              icon: Icons.camera_alt,
              color: const Color(0xFFE4405F),
              data: platforms['instagram'] ?? {},
              onConnect: () => _connect(context, ref, 'instagram'),
              onDisconnect: () => _disconnect(ref, 'instagram'),
            ),
            const SizedBox(height: 10),
            _PlatformCard(
              platform: 'tiktok',
              icon: Icons.music_note,
              color: const Color(0xFF000000),
              data: platforms['tiktok'] ?? {},
              onConnect: () => _connect(context, ref, 'tiktok'),
              onDisconnect: () => _disconnect(ref, 'tiktok'),
            ),
            const SizedBox(height: 10),
            _PlatformCard(
              platform: 'snapchat',
              icon: Icons.camera,
              color: const Color(0xFFFFFC00),
              data: platforms['snapchat'] ?? {},
              onConnect: null,
              onDisconnect: null,
            ),
            const SizedBox(height: 24),

            const _SectionLabel('Quick Actions'),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.folder_open, color: Color(0xFF00D2FF)),
                  title: const Text('Media Sources'),
                  subtitle: const Text('Configure watched folders & albums'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).pushNamed('/media-sources'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.monitor_heart, color: Color(0xFF7B2FF7)),
                  title: const Text('Agent Control'),
                  subtitle: const Text('Health, LLM budget, kill switch'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.of(context).pushNamed('/agent-control'),
                ),
              ]),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref, String platform) async {
    final handler = OAuthHandler();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting $platform... Opening browser.')),
    );

    final result = await handler.startOAuth(platform);
    if (result != null && result['status'] == 'connected') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$platform connected!'), backgroundColor: Colors.green),
        );
      }
    }
    ref.invalidate(_connectionsProvider);
  }

  Future<void> _disconnect(WidgetRef ref, String platform) async {
    try {
      await ApiClient().post('/auth/$platform/revoke');
    } catch (_) {}
    ref.invalidate(_connectionsProvider);
  }
}

class _PlatformCard extends StatelessWidget {
  final String platform;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const _PlatformCard({
    required this.platform, required this.icon, required this.color,
    required this.data, this.onConnect, this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final connected = data['connected'] == true;
    final accountId = data['account_id'] as String? ?? '';
    final expiresIn = data['expires_in_days'] as int?;
    final needsRefresh = data['needs_refresh'] == true;
    final scopes = List<String>.from(data['scopes'] ?? []);
    final note = data['note'] as String?;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: connected
            ? BorderSide(color: Colors.green.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform[0].toUpperCase() + platform.substring(1),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        connected ? 'Connected ($accountId)' : (note ?? 'Not connected'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected
                        ? (needsRefresh ? Colors.orange : Colors.green)
                        : Colors.grey,
                    boxShadow: connected ? [BoxShadow(
                      color: (needsRefresh ? Colors.orange : Colors.green).withOpacity(0.5),
                      blurRadius: 6,
                    )] : null,
                  ),
                ),
              ],
            ),

            if (connected) ...[
              const SizedBox(height: 12),
              if (expiresIn != null)
                _InfoRow('Token expires', '$expiresIn days',
                    color: expiresIn < 7 ? Colors.orange : Colors.grey[500]!),
              if (scopes.isNotEmpty)
                _InfoRow('Scopes', scopes.join(', ')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: onDisconnect,
                  child: const Text('Disconnect'),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  onPressed: onConnect,
                  child: const Text('Reconnect'),
                )),
              ]),
            ] else if (onConnect != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.link, size: 18),
                  label: Text('Connect ${platform[0].toUpperCase()}${platform.substring(1)}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        Expanded(child: Text(value,
          style: TextStyle(fontSize: 12, color: color ?? Colors.grey[400]),
          overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2,
      color: Theme.of(context).colorScheme.primary,
    ));
  }
}
