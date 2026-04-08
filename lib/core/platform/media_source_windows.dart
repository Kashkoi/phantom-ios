import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;
import 'media_source.dart';

/// Windows implementation: file_picker for folder selection + watcher for auto-detect.
class WindowsMediaSourceProvider implements MediaSourceProvider {
  final Map<String, StreamSubscription> _watchers = {};
  final Map<String, StreamController<MediaFile>> _controllers = {};

  @override
  Future<MediaSourceConfig?> pickSource() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a media folder for Phantom to watch',
    );
    if (result == null) return null;

    final dir = Directory(result);
    final name = p.basename(result);
    final id = 'folder_${DateTime.now().millisecondsSinceEpoch}';

    // Count existing media files
    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && MediaFile.isMediaExtension(p.extension(entity.path))) {
        count++;
      }
    }

    return MediaSourceConfig(
      id: id,
      displayName: name,
      path: result,
      type: 'folder',
      fileCount: count,
    );
  }

  @override
  Stream<MediaFile> watchSource(MediaSourceConfig source) {
    final controller = StreamController<MediaFile>.broadcast();
    _controllers[source.id] = controller;

    final watcher = DirectoryWatcher(source.path);
    final sub = watcher.events.listen((event) {
      if (event.type == ChangeType.ADD) {
        final ext = p.extension(event.path);
        if (MediaFile.isMediaExtension(ext)) {
          final file = File(event.path);
          try {
            final stat = file.statSync();
            controller.add(MediaFile(
              path: event.path,
              name: p.basename(event.path),
              extension: ext,
              sizeBytes: stat.size,
              detectedAt: DateTime.now(),
              isVideo: MediaFile.isVideoExtension(ext),
            ));
          } catch (_) {}
        }
      }
    });
    _watchers[source.id] = sub;

    return controller.stream;
  }

  @override
  Future<List<MediaFile>> listMedia(MediaSourceConfig source) async {
    final dir = Directory(source.path);
    final files = <MediaFile>[];

    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = p.extension(entity.path);
        if (MediaFile.isMediaExtension(ext)) {
          final stat = await entity.stat();
          files.add(MediaFile(
            path: entity.path,
            name: p.basename(entity.path),
            extension: ext,
            sizeBytes: stat.size,
            detectedAt: stat.modified,
            isVideo: MediaFile.isVideoExtension(ext),
          ));
        }
      }
    }

    files.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return files;
  }

  @override
  void stopWatching(String sourceId) {
    _watchers[sourceId]?.cancel();
    _watchers.remove(sourceId);
    _controllers[sourceId]?.close();
    _controllers.remove(sourceId);
  }

  @override
  void dispose() {
    for (final sub in _watchers.values) sub.cancel();
    for (final ctrl in _controllers.values) ctrl.close();
    _watchers.clear();
    _controllers.clear();
  }
}
