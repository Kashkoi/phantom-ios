import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';

/// Session 7.4 — Snapchat Quick-Post Screen
///
/// Opens from push notification. Full-width 9:16 preview, caption card with
/// copy button, save to camera roll, open Snapchat, mark as posted.
/// Swipeable PageView for multiple ready snaps.

final _snapQueueProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/snapchat/pending');
  return List<Map<String, dynamic>>.from(resp.data);
});

class SnapPostScreen extends ConsumerStatefulWidget {
  const SnapPostScreen({super.key});
  @override
  ConsumerState<SnapPostScreen> createState() => _SnapPostScreenState();
}

class _SnapPostScreenState extends ConsumerState<SnapPostScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(_snapQueueProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Snap Post'),
        centerTitle: true,
      ),
      body: queue.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No Snap posts pending',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ));
          }
          return Column(
            children: [
              // Page indicator
              if (items.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(items.length, (i) => Container(
                      width: i == _currentPage ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _currentPage
                            ? const Color(0xFFFFFC00)
                            : Colors.grey[700],
                      ),
                    )),
                  ),
                ),

              // Swipeable snap cards
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _SnapCard(
                    data: items[i],
                    onPosted: () => ref.invalidate(_snapQueueProvider),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFFC00))),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _SnapCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onPosted;
  const _SnapCard({required this.data, required this.onPosted});
  @override
  State<_SnapCard> createState() => _SnapCardState();
}

class _SnapCardState extends State<_SnapCard> {
  bool _copied = false;
  bool _saved = false;
  bool _marking = false;

  Map<String, dynamic> get d => widget.data;
  String get snapId => d['id'] ?? '';
  String get mediaUrl => d['media_url'] ?? '';
  String get caption => d['caption'] ?? '';
  List<String> get hashtags => List<String>.from(d['hashtags'] ?? []);

  @override
  Widget build(BuildContext context) {
    final preparedAt = DateTime.tryParse(d['prepared_at'] ?? '') ?? DateTime.now();
    final ago = timeago.format(preparedAt);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Timer
          Text('Prepared $ago', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 12),

          // Media preview (9:16)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A2E),
                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Caption card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                if (hashtags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 4, children: hashtags.map((tag) {
                    return GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: tag));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied: $tag'), duration: const Duration(seconds: 1)),
                        );
                      },
                      child: Text(tag, style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 13)),
                    );
                  }).toList()),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _copyCaption,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                    label: Text(_copied ? 'Copied!' : 'Copy Caption'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(child: _ActionButton(
                icon: Icons.save_alt,
                label: _saved ? 'Saved!' : 'Save to\nCamera Roll',
                color: Colors.blue,
                onTap: _saved ? null : _saveToCameraRoll,
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(
                icon: Icons.camera,
                label: 'Open\nSnapchat',
                color: const Color(0xFFFFFC00),
                textColor: Colors.black,
                onTap: _openSnapchat,
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ActionButton(
                icon: Icons.check_circle,
                label: 'Mark as\nPosted',
                color: Colors.green,
                onTap: _marking ? null : _markPosted,
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(
                icon: Icons.skip_next,
                label: 'Skip\nThis Post',
                color: Colors.grey[700]!,
                onTap: _skipPost,
              )),
            ],
          ),
        ],
      ),
    );
  }

  void _copyCaption() {
    final fullText = '$caption\n\n${hashtags.join(' ')}';
    Clipboard.setData(ClipboardData(text: fullText));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _saveToCameraRoll() async {
    try {
      // In production: download image from mediaUrl, save via image_gallery_saver
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving to camera roll...')),
      );
      setState(() => _saved = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _openSnapchat() async {
    final snapUri = Uri.parse('snapchat://');
    final storeUri = Uri.parse('https://apps.apple.com/app/snapchat/id447188370');

    if (await canLaunchUrl(snapUri)) {
      await launchUrl(snapUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markPosted() async {
    setState(() => _marking = true);
    try {
      await ApiClient().post('/snapchat/$snapId/posted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as posted!')),
        );
        widget.onPosted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _skipPost() async {
    try {
      // Skip by dismissing — in production call a skip endpoint
      widget.onPosted();
    } catch (_) {}
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon, required this.label, required this.color,
    this.textColor = Colors.white, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
