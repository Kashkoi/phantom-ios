import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/platform/media_source.dart';
import '../../core/platform/platform_utils.dart';

/// Manages 1-5 watched media source folders (Windows) or albums (iOS).
/// New media detected → auto-upload to backend → optionally auto-queue.

final _mediaSourcesProvider =
    StateNotifierProvider<MediaSourcesNotifier, MediaSourcesState>((ref) {
  return MediaSourcesNotifier();
});

class MediaSourcesState {
  final List<MediaSourceConfig> sources;
  final Map<String, int> newFilesCounts;
  final bool autoQueue;

  const MediaSourcesState({
    this.sources = const [],
    this.newFilesCounts = const {},
    this.autoQueue = false,
  });

  MediaSourcesState copyWith({
    List<MediaSourceConfig>? sources,
    Map<String, int>? newFilesCounts,
    bool? autoQueue,
  }) => MediaSourcesState(
    sources: sources ?? this.sources,
    newFilesCounts: newFilesCounts ?? this.newFilesCounts,
    autoQueue: autoQueue ?? this.autoQueue,
  );
}

class MediaSourcesNotifier extends StateNotifier<MediaSourcesState> {
  MediaSourcesNotifier() : super(const MediaSourcesState()) {
    _load();
  }

  late final MediaSourceProvider _provider = createMediaSourceProvider();
  final Map<String, StreamSubscription> _watchSubs = {};

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('media_sources');
    final autoQueue = prefs.getBool('media_auto_queue') ?? false;
    if (json != null) {
      final list = (jsonDecode(json) as List)
          .map((e) => MediaSourceConfig.fromJson(e))
          .toList();
      state = state.copyWith(sources: list, autoQueue: autoQueue);
      for (final src in list) {
        if (src.isWatching) _startWatching(src);
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'media_sources',
      jsonEncode(state.sources.map((e) => e.toJson()).toList()),
    );
    await prefs.setBool('media_auto_queue', state.autoQueue);
  }

  Future<bool> addSource() async {
    if (state.sources.length >= 5) return false;
    final config = await _provider.pickSource();
    if (config == null) return false;

    final updated = [...state.sources, config];
    state = state.copyWith(sources: updated);
    await _save();
    _startWatching(config);
    return true;
  }

  Future<void> removeSource(String id) async {
    _provider.stopWatching(id);
    _watchSubs[id]?.cancel();
    _watchSubs.remove(id);
    final updated = state.sources.where((s) => s.id != id).toList();
    state = state.copyWith(sources: updated);
    await _save();
  }

  void toggleWatching(String id) {
    final idx = state.sources.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final src = state.sources[idx];
    src.isWatching = !src.isWatching;
    if (src.isWatching) {
      _startWatching(src);
    } else {
      _provider.stopWatching(id);
      _watchSubs[id]?.cancel();
    }
    state = state.copyWith(sources: List.from(state.sources));
    _save();
  }

  void setAutoQueue(bool value) {
    state = state.copyWith(autoQueue: value);
    _save();
  }

  void _startWatching(MediaSourceConfig src) {
    final stream = _provider.watchSource(src);
    _watchSubs[src.id] = stream.listen((file) async {
      // Update count
      final counts = Map<String, int>.from(state.newFilesCounts);
      counts[src.id] = (counts[src.id] ?? 0) + 1;
      state = state.copyWith(newFilesCounts: counts);

      // Upload to backend
      try {
        await ApiClient().upload('/content/upload', [file.path]);
        if (state.autoQueue) {
          await ApiClient().post('/content/', data: {
            'media_urls': [file.path],
            'platforms': ['instagram'],
            'post_type': file.isVideo ? 'reel' : 'image',
            'generate_caption': true,
          });
        }
      } catch (_) {}
    });
  }

  Future<List<MediaFile>> listFiles(String sourceId) async {
    final src = state.sources.where((s) => s.id == sourceId).firstOrNull;
    if (src == null) return [];
    return _provider.listMedia(src);
  }

  @override
  void dispose() {
    _provider.dispose();
    for (final sub in _watchSubs.values) sub.cancel();
    super.dispose();
  }
}

class MediaSourcesScreen extends ConsumerWidget {
  const MediaSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_mediaSourcesProvider);
    final notifier = ref.read(_mediaSourcesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Media Sources')),
      floatingActionButton: state.sources.length < 5
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await notifier.addSource();
                if (!added && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No folder selected or max 5 reached')),
                  );
                }
              },
              icon: Icon(isDesktop ? Icons.folder_open : Icons.photo_album),
              label: Text(isDesktop ? 'Add Folder' : 'Add Album'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Auto-queue toggle
          Card(
            child: SwitchListTile(
              title: const Text('Auto-Queue New Media'),
              subtitle: const Text('Automatically create posts from new files'),
              value: state.autoQueue,
              onChanged: (v) => notifier.setAutoQueue(v),
            ),
          ),
          const SizedBox(height: 8),

          // Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  isDesktop
                      ? 'Add up to 5 folders. Phantom watches for new photos & videos and auto-uploads them.'
                      : 'Add up to 5 albums. Phantom watches for new photos & videos and auto-uploads them.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Source list
          if (state.sources.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  Icon(isDesktop ? Icons.folder_off : Icons.photo_album_outlined,
                      size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text('No media sources configured',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text(
                    isDesktop
                        ? 'Tap "Add Folder" to point Phantom at your media files'
                        : 'Tap "Add Album" to watch a photo album',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ]),
              ),
            )
          else
            ...state.sources.map((src) => _SourceCard(
              source: src,
              newFiles: state.newFilesCounts[src.id] ?? 0,
              onToggle: () => notifier.toggleWatching(src.id),
              onRemove: () => notifier.removeSource(src.id),
            )),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final MediaSourceConfig source;
  final int newFiles;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _SourceCard({
    required this.source, required this.newFiles,
    required this.onToggle, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                source.type == 'folder' ? Icons.folder : Icons.photo_album,
                color: source.isWatching ? const Color(0xFF00D2FF) : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(source.path, style: TextStyle(
                      fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (newFiles > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('+$newFiles new', style: const TextStyle(
                    fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700,
                  )),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('${source.fileCount} files',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(width: 12),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: source.isWatching ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 4),
              Text(source.isWatching ? 'Watching' : 'Paused',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const Spacer(),
              TextButton(onPressed: onToggle,
                  child: Text(source.isWatching ? 'Pause' : 'Resume')),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: onRemove,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
