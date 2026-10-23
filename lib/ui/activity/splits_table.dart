/// Native table for the parsed split rows of an activity. The note stores the
/// splits as a Markdown table (see `splits_markdown.dart`); this widget is
/// what the user actually sees.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/activity_metrics.dart' show formatDuration, formatPace;
import '../../services/splits_markdown.dart';
import '../../services/splits_service.dart';
import '../theme/app_theme.dart';

class SplitsTable extends StatelessWidget {
  const SplitsTable({super.key, required this.unit, required this.rows});

  final SplitUnit unit;
  final List<SplitRow> rows;

  // Column flex factors: label, time, pace (with bar), gain, net, HR.
  static const List<int> _flex = [13, 15, 30, 11, 11, 11];

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Fastest and slowest pace over the rows that have a usable pace; the
    // bar of a split is its speed relative to the fastest one.
    double? fastest;
    for (final r in rows) {
      final pace = r.effectivePaceSecPerUnit;
      if (pace > 0) fastest = fastest == null ? pace : math.min(fastest, pace);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          cells: [
            _head(unit.heading),
            _head('Time'),
            _head('Pace /${unit.short}'),
            _head('Gain'),
            _head('Net'),
            _head('HR'),
          ],
        ),
        const Divider(height: 8),
        for (final r in rows)
          _SplitRowView(row: r, fastestPace: fastest, flex: _flex),
      ],
    );
  }

  static Widget _head(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textDim,
        ),
      );

  static Widget _row({required List<Widget> cells}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: _flex[i], child: cells[i]),
        ],
      ),
    );
  }
}

class _SplitRowView extends StatelessWidget {
  const _SplitRowView({
    required this.row,
    required this.fastestPace,
    required this.flex,
  });

  final SplitRow row;
  final double? fastestPace;
  final List<int> flex;

  static String _signed(int? v) => v == null ? '--' : (v > 0 ? '+$v' : '$v');

  @override
  Widget build(BuildContext context) {
    final pace = row.effectivePaceSecPerUnit;
    final isFastest = fastestPace != null && pace > 0 && pace == fastestPace;
    final barColor = isFastest ? AppColors.done : AppColors.accent;
    final fraction = (fastestPace == null || pace <= 0)
        ? 0.0
        : (fastestPace! / pace).clamp(0.35, 1.0).toDouble();

    const tabular = [FontFeature.tabularFigures()];
    const cell = TextStyle(fontSize: 13, fontFeatures: tabular);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: flex[0],
            child: Text(
              row.isPartial
                  ? '${row.number} (${row.partialDistance!.toStringAsFixed(2)})'
                  : '${row.number}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cell.copyWith(
                color: row.isPartial ? AppColors.textDim : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: flex[1],
            child: Text(formatDuration(row.duration), style: cell),
          ),
          Expanded(
            flex: flex[2],
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: barColor.withAlpha(isFastest ? 90 : 60),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      formatPace(pace) ?? '--',
                      style: cell.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isFastest ? AppColors.done : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: flex[3],
            child: Text(row.gainM?.toString() ?? '--', style: cell),
          ),
          Expanded(
            flex: flex[4],
            child: Text(_signed(row.netM), style: cell),
          ),
          Expanded(
            flex: flex[5],
            child: Text(row.avgHr?.toString() ?? '--', style: cell),
          ),
        ],
      ),
    );
  }
}
