/// Multi-sport dashboard: this week's totals per discipline (lifted volume,
/// distance, stretch time), an 8-week trend chart, and the all-time personal
/// records.
///
/// Data comes from [VaultStatsController], which parses the vault notes and
/// reloads whenever the index changes. Pull down to force a reload.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/pr_service.dart';
import '../../services/weekly_stats.dart';
import '../common/pr_badge.dart';
import '../common/vault_stats_controller.dart';
import '../theme/app_theme.dart';
import 'weekly_bar_chart.dart';

/// Weeks shown in the trend chart, current week included.
const int kDashboardWeeks = 8;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.controller});

  final VaultStatsController controller;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  WeeklyMetric _metric = WeeklyMetric.volume;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final stats = c.stats;
          if (stats == null) {
            return c.loading
                ? const Center(child: CircularProgressIndicator())
                : _LoadError(error: c.error, onRetry: c.refresh);
          }

          final weeks = stats.weekly(weeks: kDashboardWeeks);
          final isEmpty = stats.workouts.isEmpty && stats.activities.isEmpty;
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                if (isEmpty)
                  const _EmptyDashboard()
                else ...[
                  _ThisWeekCard(totals: weeks.last),
                  const SizedBox(height: 14),
                  _TrendCard(
                    weeks: weeks,
                    metric: _metric,
                    onMetric: (m) => setState(() => _metric = m),
                  ),
                ],
                const SizedBox(height: 22),
                const Text(
                  'Personal records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _RecordsGrid(snapshot: stats.records),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// This week
// =============================================================================

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({required this.totals});

  final WeeklyTotals totals;

  @override
  Widget build(BuildContext context) {
    final start = totals.weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);
    final range = '${DateFormat('d MMM').format(start)} – '
        '${DateFormat('d MMM').format(end)}';
    final counts = [
      '${totals.workoutCount} ${totals.workoutCount == 1 ? 'workout' : 'workouts'}',
      '${totals.activityCount} ${totals.activityCount == 1 ? 'activity' : 'activities'}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'This week',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                range,
                style: const TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final m in WeeklyMetric.values)
                Expanded(child: _WeekTile(metric: m, totals: totals)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            counts,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.metric, required this.totals});

  final WeeklyMetric metric;
  final WeeklyTotals totals;

  @override
  Widget build(BuildContext context) {
    final value = metric.valueOf(totals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            metric.format(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: value > 0 ? metric.color : AppColors.textDim,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          style: const TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      ],
    );
  }
}

// =============================================================================
// Trend
// =============================================================================

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.weeks,
    required this.metric,
    required this.onMetric,
  });

  final List<WeeklyTotals> weeks;
  final WeeklyMetric metric;
  final ValueChanged<WeeklyMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    final total = weeks.fold<double>(0, (sum, w) => sum + metric.valueOf(w));
    final average = weeks.isEmpty ? 0.0 : total / weeks.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Last ${weeks.length} weeks',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'avg ${metric.format(average)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<WeeklyMetric>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final m in WeeklyMetric.values)
                ButtonSegment<WeeklyMetric>(value: m, label: Text(m.label)),
            ],
            selected: {metric},
            onSelectionChanged: (s) => onMetric(s.first),
          ),
          const SizedBox(height: 14),
          WeeklyBarChart(weeks: weeks, metric: metric),
        ],
      ),
    );
  }
}

// =============================================================================
// Records
// =============================================================================

class _RecordsGrid extends StatelessWidget {
  const _RecordsGrid({required this.snapshot});

  final PrSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in PrKind.values)
              SizedBox(
                width: width,
                child: PrBadge(kind: kind, record: snapshot[kind]),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Empty and error states
// =============================================================================

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.insights, size: 44, color: AppColors.textDim),
          SizedBox(height: 12),
          Text(
            'No sessions yet.\nLog a workout or record an activity and your '
            'weekly totals show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              'Could not read your vault.\n${error ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
