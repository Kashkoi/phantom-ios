import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';

/// Session 7.3 — Caption Preview & Approval
///
/// POST /commentary/preview → 3 AI variants in cards with engagement scores.
/// Editable caption with per-platform character counters.
/// Actions: Approve & Queue, Post Now, Save as Draft, Edit More.

class CaptionPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? args;
  const CaptionPreviewScreen({super.key, this.args});
  @override
  ConsumerState<CaptionPreviewScreen> createState() => _CaptionPreviewState();
}

class _CaptionPreviewState extends ConsumerState<CaptionPreviewScreen> {
  List<Map<String, dynamic>> _variants = [];
  List<String> _hashtags = [];
  int _selectedVariant = 0;
  bool _loading = true;
  String? _error;
  late TextEditingController _captionCtrl;
  String _previewPlatform = 'instagram';

  static const _charLimits = {
    'instagram': 2200,
    'tiktok': 150,
    'snapchat': 250,
  };

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient().post('/commentary/preview', data: {
        'media_urls': widget.args?['files'] ?? [],
        'media_description': widget.args?['raw_caption'],
        'platform': (widget.args?['platforms'] as List?)?.first ?? 'instagram',
        'persona_name': 'Andre',
        'context': widget.args?['raw_caption'],
      });
      final data = resp.data;
      setState(() {
        _variants = List<Map<String, dynamic>>.from(data['variants'] ?? []);
        _hashtags = List<String>.from(data['suggested_hashtags'] ?? []);
        if (_variants.isNotEmpty) {
          _captionCtrl.text = _variants[0]['caption'] ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final platforms = List<String>.from(widget.args?['platforms'] ?? ['instagram']);

    return Scaffold(
      appBar: AppBar(title: const Text('Caption Preview')),
      body: _loading
          ? const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating captions...'),
              ],
            ))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Platform preview selector
                    SegmentedButton<String>(
                      segments: platforms.map((p) => ButtonSegment(
                        value: p,
                        label: Text(p[0].toUpperCase() + p.substring(1)),
                      )).toList(),
                      selected: {_previewPlatform},
                      onSelectionChanged: (s) => setState(() => _previewPlatform = s.first),
                    ),
                    const SizedBox(height: 16),

                    // Platform mockup preview
                    _PlatformPreview(
                      platform: _previewPlatform,
                      caption: _captionCtrl.text,
                      postType: widget.args?['post_type'] ?? 'image',
                    ),
                    const SizedBox(height: 20),

                    // Variant cards
                    const Text('AI-Generated Variants',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ...List.generate(_variants.length, (i) {
                      final v = _variants[i];
                      final isSelected = i == _selectedVariant;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _VariantCard(
                          index: i,
                          caption: v['caption'] ?? '',
                          angle: v['angle'] ?? '',
                          engagement: v['predicted_engagement'] ?? 'unknown',
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedVariant = i;
                              _captionCtrl.text = v['caption'] ?? '';
                            });
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Editable caption
                    const Text('Edit Caption',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _captionCtrl,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Edit your caption...',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Character counters per platform
                    Wrap(spacing: 12, children: platforms.map((p) {
                      final limit = _charLimits[p] ?? 2200;
                      final len = _captionCtrl.text.length;
                      final over = len > limit;
                      return Text(
                        '${p[0].toUpperCase() + p.substring(1)}: $len/$limit',
                        style: TextStyle(
                          fontSize: 12,
                          color: over ? Colors.red : Colors.grey[500],
                          fontWeight: over ? FontWeight.w700 : FontWeight.normal,
                        ),
                      );
                    }).toList()),
                    const SizedBox(height: 16),

                    // Suggested hashtags
                    if (_hashtags.isNotEmpty) ...[
                      const Text('Suggested Hashtags',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: _hashtags.map((tag) {
                        return ActionChip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            _captionCtrl.text += ' $tag';
                            setState(() {});
                          },
                        );
                      }).toList()),
                      const SizedBox(height: 24),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => _submit('draft'),
                          child: const Text('Save Draft'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(
                          onPressed: () => _submit('queue'),
                          child: const Text('Approve & Queue'),
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.tertiary,
                        ),
                        onPressed: () => _submit('now'),
                        child: const Text('Post Now'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _submit(String action) async {
    try {
      await ApiClient().post('/content/', data: {
        'media_urls': widget.args?['files'] ?? [],
        'raw_caption': widget.args?['raw_caption'],
        'ai_caption': _captionCtrl.text,
        'platforms': widget.args?['platforms'] ?? ['instagram'],
        'post_type': widget.args?['post_type'] ?? 'image',
        'generate_caption': false,
        'status': action == 'draft' ? 'draft' : 'queued',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'draft' ? 'Saved as draft' :
              action == 'now' ? 'Publishing now...' : 'Queued for optimal time'),
        ));
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _VariantCard extends StatelessWidget {
  final int index;
  final String caption, angle, engagement;
  final bool isSelected;
  final VoidCallback onTap;

  const _VariantCard({
    required this.index, required this.caption, required this.angle,
    required this.engagement, required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isSelected ? cs.primary : Colors.grey[700],
                  child: Text('${index + 1}', style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                  )),
                ),
                const SizedBox(width: 8),
                Text(angle, style: TextStyle(
                  fontSize: 12, color: Colors.grey[500],
                )),
                const Spacer(),
                _EngagementBadge(level: engagement),
              ]),
              const SizedBox(height: 10),
              Text(caption, maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngagementBadge extends StatelessWidget {
  final String level;
  const _EngagementBadge({required this.level});
  @override
  Widget build(BuildContext context) {
    final color = level == 'high' ? Colors.green
        : level == 'medium' ? Colors.orange : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(level.toUpperCase(), style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: color,
      )),
    );
  }
}

class _PlatformPreview extends StatelessWidget {
  final String platform, caption, postType;
  const _PlatformPreview({
    required this.platform, required this.caption, required this.postType,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = postType == 'reel' || postType == 'story' || platform == 'tiktok';
    final aspect = isVertical ? 9.0 / 16.0 : 4.0 / 5.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mock header
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              const CircleAvatar(radius: 16, backgroundColor: Color(0xFF7B2FF7),
                  child: Text('AI', style: TextStyle(color: Colors.white, fontSize: 10))),
              const SizedBox(width: 8),
              Text(platform == 'instagram' ? 'alpha.inception'
                  : platform == 'tiktok' ? '@alphainception' : 'alphainception',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
          // Media placeholder
          AspectRatio(
            aspectRatio: aspect,
            child: Container(
              color: const Color(0xFF1A1A2E),
              child: const Center(child: Icon(Icons.image, size: 48, color: Colors.grey)),
            ),
          ),
          // Caption preview
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              caption.isEmpty ? 'Caption will appear here...' : caption,
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
