/// Bar chart of the weekly totals shown on the dashboard.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

import '../../services/weekly_stats.dart';
import '../theme/app_theme.dart';

/// The discipline the chart (and the "this week" tiles) show.
enum WeeklyMetric {
  volume('Lifted', 'kg', AppColors.accent),
  distance('Distance', 'km', AppColors.activity),
  mobility('Stretch', 'min', AppColors.done);

  const WeeklyMetric(this.label, this.unit, this.color);

  final String label;
  final String unit;
  final Color color;

  double valueOf(WeeklyTotals w) => switch (this) {
        WeeklyMetric.volume => w.volumeKg,
        WeeklyMetric.distance => w.distanceKm,
        WeeklyMetric.mobility => w.mobilityMinutes,
      };

  /// Full number with unit, e.g. `4,850 kg`, `32.5 km`, `45 min`.
  String format(double v) => switch (this) {
        WeeklyMetric.volume =>
          '${NumberFormat.decimalPattern().format(v.round())} $unit',
        WeeklyMetric.distance => '${v.toStringAsFixed(1)} $unit',
        WeeklyMetric.mobility => '${v.round()} $unit',
      };

  /// Short number for the bar label (no unit): `4.9K`, `32.5`, `45`.
  String formatShort(double v) => switch (this) {
        WeeklyMetric.volume => NumberFormat.compact().format(v.round()),
        WeeklyMetric.distance =>
          v >= 100 ? v.round().toString() : v.toStringAsFixed(1),
        WeeklyMetric.mobility => v.round().toString(),
      };
}

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.weeks,
    required this.metric,
    this.height = 150,
  });

  /// Oldest first; the last entry is the current week.
  final List<WeeklyTotals> weeks;
  final WeeklyMetric metric;
  final double height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _BarsPainter(
          values: [for (final w in weeks) metric.valueOf(w)],
          labels: [
            for (var i = 0; i < weeks.length; i++)
              i == weeks.length - 1
                  ? 'Now'
                  : DateFormat('d/M').format(weeks[i].weekStart),
          ],
          shortValue: metric.formatShort,
          color: metric.color,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.labels,
    required this.shortValue,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final String Function(double) shortValue;
  final Color color;

  static const double _labelHeight = 18;
  static const double _valueHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plotTop = _valueHeight;
    final plotBottom = size.height - _labelHeight;
    final plotHeight = math.max(1.0, plotBottom - plotTop);
    final maxValue = values.fold<double>(0, math.max);
    final slot = size.width / values.length;
    final barWidth = slot * 0.56;

    canvas.drawLine(
      Offset(0, plotBottom),
      Offset(size.width, plotBottom),
      Paint()
        ..color = AppColors.outline
        ..strokeWidth = 1,
    );

    for (var i = 0; i < values.length; i++) {
      final isCurrent = i == values.length - 1;
      final value = values[i];
      final centerX = slot * i + slot / 2;

      if (value > 0 && maxValue > 0) {
        final h = math.max(3.0, value / maxValue * plotHeight);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(centerX - barWidth / 2, plotBottom - h, barWidth, h),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = isCurrent ? color : color.withAlpha(110),
        );
        _text(
          canvas,
          shortValue(value),
          Offset(centerX, plotBottom - h - 14),
          TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isCurrent ? AppColors.text : AppColors.textDim,
          ),
        );
      } else {
        // An empty week: a thin stub, so the slot still reads as "zero".
        canvas.drawRect(
          Rect.fromLTWH(centerX - barWidth / 2, plotBottom - 2, barWidth, 2),
          Paint()..color = AppColors.outline,
        );
      }

      _text(
        canvas,
        labels[i],
        Offset(centerX, plotBottom + 4),
        TextStyle(
          fontSize: 10,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
          color: isCurrent ? AppColors.text : AppColors.textDim,
        ),
      );
    }
  }

  /// Draws [text] horizontally centred on `anchor.dx`, top at `anchor.dy`.
  void _text(Canvas canvas, String text, Offset anchor, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(anchor.dx - painter.width / 2, anchor.dy));
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color ||
      old.values.length != values.length ||
      !_same(old.values, values) ||
      !_sameLabels(old.labels, labels);

  static bool _same(List<double> a, List<double> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameLabels(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
