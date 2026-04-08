import 'dart:async';
import 'media_source.dart';

/// iOS implementation stub.
/// On Windows builds, this is never instantiated (platform_utils.dart guards it).
/// On iOS Codemagic builds, add photo_manager back to pubspec and use the full implementation.
class IOSMediaSourceProvider implements MediaSourceProvider {
  @override
  Future<MediaSourceConfig?> pickSource() async => null;

  @override
  Stream<MediaFile> watchSource(MediaSourceConfig source) => const Stream.empty();

  @override
  Future<List<MediaFile>> listMedia(MediaSourceConfig source) async => [];

  @override
  void stopWatching(String sourceId) {}

  @override
  void dispose() {}
}
