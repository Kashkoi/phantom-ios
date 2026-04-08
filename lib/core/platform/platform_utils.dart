import 'dart:io';
import 'media_source.dart';
import 'media_source_windows.dart';
import 'media_source_ios.dart';

bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
bool get isMobile => Platform.isIOS || Platform.isAndroid;

/// Returns the appropriate MediaSourceProvider for the current platform.
MediaSourceProvider createMediaSourceProvider() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return WindowsMediaSourceProvider();
  }
  return IOSMediaSourceProvider();
}
