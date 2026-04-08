import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Session 7.6 — Analytics Dashboard
///
/// Period selector (7d/30d/90d), metric cards with trend arrows,
/// engagement line chart, follower growth, top hashtags, AI insights.

final _periodProvider = StateProvider<int>((ref) => 30);

final _summaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, platform) async {
    final days = ref.watch(_periodProvider);
    final resp = await ApiClient().get('/analytics/summary/$platform', params: {'days': '$days'});
    return resp.data as Map<String, dynamic>;
  },
);

final _followerProvider = FutureProvider.autoDispose.family<List<dynamic>, String>(
  (ref, platform) async {
    final days = ref.watch(_periodProvider);
    final resp = await ApiClient().get('/analytics/followers/$platform', params: {'days': '$days'});
    return resp.data as List;
  },
);

final _insightsProvider = FutureProvider.autoDispose((ref) async {
  final resp = await ApiClient().get('/dashboard/insights', params: {'platform': 'instagram'});
  return resp.data as Map<String, dynamic>;
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_periodProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 30, label: Text('30d')),
              ButtonSegment(value: 90, label: Text('90d')),
            ],
            selected: {period},
            onSelectionChanged: (s) => ref.read(_periodProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 20),

          // Metric cards (Instagram)
          _MetricsSection(platform: 'instagram'),
          const SizedBox(height: 20),

          // Engagement chart
          const _SectionHeader('Engagement Over Time'),
          const SizedBox(height: 8),
          SizedBox(height: 200, child: _EngagementChart()),
          const SizedBox(height: 24),

          // Follower growth
          const _SectionHeader('Follower Growth'),
          const SizedBox(height: 8),
          _FollowerChart(platform: 'instagram'),
          const SizedBox(height: 24),

          // AI insights
          const _SectionHeader('AI Insights'),
          const SizedBox(height: 8),
          _AIInsightsCard(),
        ],
      ),
    );
  }
}

class _MetricsSection extends ConsumerWidget {
  final String platform;
  const _MetricsSection({required this.platform});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_summaryProvider(platform));

    return summary.when(
      data: (s) {
        return Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _MetricCard(label: 'Posts', value: '${s['total_posts'] ?? 0}', icon: Icons.grid_on),
            _MetricCard(
              label: 'Avg Engagement',
              value: '${((s['avg_engagement_rate'] ?? 0) * 100).toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              trend: (s['avg_engagement_rate'] ?? 0) > 0.03 ? 'up' : 'down',
            ),
            _MetricCard(
              label: 'Impressions',
              value: _formatNumber(s['total_impressions'] ?? 0),
              icon: Icons.visibility,
            ),
            _MetricCard(
              label: 'Reach',
              value: _formatNumber(s['total_reach'] ?? 0),
              icon: Icons.people,
            ),
            _MetricCard(label: 'Likes', value: _formatNumber(s['total_likes'] ?? 0), icon: Icons.favorite),
            _MetricCard(label: 'Comments', value: _formatNumber(s['total_comments'] ?? 0), icon: Icons.comment),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
    );
  }

  String _formatNumber(dynamic n) {
    final num val = n is num ? n : 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final String? trend;

  const _MetricCard({required this.label, required this.value, required this.icon, this.trend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 3,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 14, color: cs.primary),
                if (trend != null) ...[
                  const Spacer(),
                  Icon(
                    trend == 'up' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: trend == 'up' ? Colors.green : Colors.red,
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngagementChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(14, (i) => FlSpot(i.toDouble(), (3 + i * 0.5 + (i % 3) * 0.8))),
              isCurved: true,
              color: cs.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withOpacity(0.1),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

class _FollowerChart extends ConsumerWidget {
  final String platform;
  const _FollowerChart({required this.platform});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_followerProvider(platform));
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: data.when(
        data: (points) {
          if (points.isEmpty) return const Center(child: Text('No follower data yet'));
          final spots = List.generate(points.length, (i) {
            final count = (points[i]['follower_count'] as num?)?.toDouble() ?? 0;
            return FlSpot(i.toDouble(), count);
          });
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: cs.secondary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: cs.secondary.withOpacity(0.1)),
                  ),
                ],
              )),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _AIInsightsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(_insightsProvider);

    return insights.when(
      data: (data) {
        final text = data['insights'] ?? 'No insights available yet.';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('AI Analysis', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      )),
      error: (_, __) => const Card(child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Insights unavailable'),
      )),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }
}
