import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/platform/media_source.dart';
import '../../core/platform/platform_utils.dart';

/// Session 7.2 — Media Browser
///
/// Windows: file_picker grid showing files from selected folder.
/// iOS: (photo_manager — requires Codemagic iOS build with photo_manager in pubspec).

final _selectedFilesProvider = StateProvider<List<String>>((ref) => []);

class MediaBrowserScreen extends ConsumerStatefulWidget {
  const MediaBrowserScreen({super.key});
  @override
  ConsumerState<MediaBrowserScreen> createState() => _MediaBrowserState();
}

class _MediaBrowserState extends ConsumerState<MediaBrowserScreen> {
  final _captionCtrl = TextEditingController();
  final _platforms = {'instagram': true, 'tiktok': true, 'snapchat': false};
  String _postType = 'image';
  String _schedule = 'optimal';
  bool _uploading = false;
  double _uploadProgress = 0;
  List<File> _files = [];
  String? _folderPath;

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(_selectedFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Media'),
        actions: [
          if (selected.isNotEmpty)
            TextButton(
              onPressed: _showPostOptions,
              child: Text('Next (${selected.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Folder picker button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: Text(_folderPath != null
                      ? _folderPath!.split(Platform.pathSeparator).last
                      : 'Select a folder...'),
                ),
              ),
              if (_folderPath != null) ...[
                const SizedBox(width: 8),
                Text('${_files.length} files', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ]),
          ),

          // File grid
          Expanded(
            child: _files.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text('Pick a folder to browse media', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ))
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 2, mainAxisSpacing: 2,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (_, i) {
                      final file = _files[i];
                      final path = file.path;
                      final isSelected = selected.contains(path);
                      final selIndex = selected.indexOf(path);
                      final isVideo = MediaFile.isVideoExtension(
                          path.substring(path.lastIndexOf('.')));

                      return GestureDetector(
                        onTap: () {
                          final current = List<String>.from(selected);
                          if (isSelected) {
                            current.remove(path);
                          } else {
                            current.add(path);
                          }
                          ref.read(_selectedFilesProvider.notifier).state = current;
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail
                            if (!isVideo)
                              Image.file(file, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF1A1A2E),
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ))
                            else
                              Container(
                                color: const Color(0xFF1A1A2E),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam, color: Colors.grey, size: 28),
                                    SizedBox(height: 4),
                                    Text('Video', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              ),

                            // Selection overlay
                            if (isSelected)
                              Container(
                                color: Colors.blue.withOpacity(0.3),
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.all(6),
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.blue,
                                  child: Text('${selIndex + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          if (_uploading)
            LinearProgressIndicator(value: _uploadProgress,
                color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select media folder',
    );
    if (result == null) return;

    final dir = Directory(result);
    final mediaFiles = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = entity.path.substring(entity.path.lastIndexOf('.'));
        if (MediaFile.isMediaExtension(ext)) {
          mediaFiles.add(entity);
        }
      }
    }
    mediaFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      _folderPath = result;
      _files = mediaFiles;
    });
    ref.read(_selectedFilesProvider.notifier).state = [];
  }

  void _showPostOptions() {
    final selected = ref.read(_selectedFilesProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${selected.length} items selected',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Platforms', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: _platforms.keys.map((p) {
              return FilterChip(
                label: Text(p[0].toUpperCase() + p.substring(1)),
                selected: _platforms[p]!,
                onSelected: (v) => setState(() => _platforms[p] = v),
              );
            }).toList()),
            const SizedBox(height: 16),
            const Text('Post Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'image', label: Text('Image')),
                ButtonSegment(value: 'reel', label: Text('Reel')),
                ButtonSegment(value: 'carousel', label: Text('Carousel')),
                ButtonSegment(value: 'story', label: Text('Story')),
              ],
              selected: {_postType},
              onSelectionChanged: (s) => setState(() => _postType = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add notes for AI caption generation...',
                labelText: 'Raw Caption / Notes',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'optimal', label: Text('Optimal')),
                ButtonSegment(value: 'now', label: Text('Post Now')),
                ButtonSegment(value: 'draft', label: Text('Draft')),
              ],
              selected: {_schedule},
              onSelectionChanged: (s) => setState(() => _schedule = s.first),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () { Navigator.pop(ctx); _queuePost(); },
                child: const Text('Queue Post'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); _generatePreview(); },
                child: const Text('Caption Preview'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePreview() async {
    final selected = ref.read(_selectedFilesProvider);
    if (!mounted) return;
    context.push('/caption-preview', extra: {
      'files': selected,
      'platforms': _platforms.entries.where((e) => e.value).map((e) => e.key).toList(),
      'post_type': _postType,
      'raw_caption': _captionCtrl.text,
      'schedule': _schedule,
    });
  }

  Future<void> _queuePost() async {
    final selected = ref.read(_selectedFilesProvider);
    setState(() { _uploading = true; _uploadProgress = 0; });
    try {
      final uploadResp = await ApiClient().upload(
        '/content/upload', selected,
        onProgress: (sent, total) {
          setState(() => _uploadProgress = sent / total);
        },
      );
      final mediaUrls = List<String>.from(uploadResp.data['urls'] ?? []);
      await ApiClient().post('/content/', data: {
        'media_urls': mediaUrls,
        'raw_caption': _captionCtrl.text,
        'platforms': _platforms.entries.where((e) => e.value).map((e) => e.key).toList(),
        'post_type': _postType,
        'generate_caption': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post queued!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
