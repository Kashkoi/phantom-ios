import 'dart:async';

/// Represents a single media file detected by the watcher.
class MediaFile {
  final String path;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime detectedAt;
  final bool isVideo;

  MediaFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.detectedAt,
    required this.isVideo,
  });

  static const _videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.webm'};
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif'};
  static const allExts = {..._videoExts, ..._imageExts};

  static bool isMediaExtension(String ext) => allExts.contains(ext.toLowerCase());
  static bool isVideoExtension(String ext) => _videoExts.contains(ext.toLowerCase());
}

/// Configuration for a watched media source.
class MediaSourceConfig {
  final String id;
  final String displayName;
  final String path; // folder path (Windows) or album ID (iOS)
  final String type; // 'folder' or 'album'
  bool isWatching;
  int fileCount;
  DateTime? lastDetectedAt;

  MediaSourceConfig({
    required this.id,
    required this.displayName,
    required this.path,
    required this.type,
    this.isWatching = true,
    this.fileCount = 0,
    this.lastDetectedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'displayName': displayName, 'path': path,
    'type': type, 'isWatching': isWatching,
  };

  factory MediaSourceConfig.fromJson(Map<String, dynamic> j) => MediaSourceConfig(
    id: j['id'], displayName: j['displayName'], path: j['path'],
    type: j['type'], isWatching: j['isWatching'] ?? true,
  );
}

/// Abstract interface for platform-specific media source implementations.
abstract class MediaSourceProvider {
  /// Let the user pick a folder (Windows) or album (iOS).
  Future<MediaSourceConfig?> pickSource();

  /// Start watching a configured source for new media files.
  Stream<MediaFile> watchSource(MediaSourceConfig source);

  /// List existing media files in a source.
  Future<List<MediaFile>> listMedia(MediaSourceConfig source);

  /// Stop watching a source.
  void stopWatching(String sourceId);

  /// Stop all watchers.
  void dispose();
}
