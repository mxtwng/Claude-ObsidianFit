/// Canvas charts for a recorded track: rolling pace and smoothed elevation
/// against distance. Both read a [TrackProfile] (already down-sampled), so
/// painting stays cheap for multi-hour activities.
///
///  * [TrackProfileCharts] draws the charts for a profile in memory (review
///    screen after recording).
///  * [SavedTrackCharts] loads `Tracks/<file>.gpx` and draws the same charts
///    for a saved activity (session preview).
///
/// Tap or drag across a chart to read the value at that distance; tapping the
/// same spot again hides the cursor.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/activity_metrics.dart' show formatPace;
import '../../services/gpx_service.dart';
import '../../services/track_profile.dart';
import '../app_services.dart';
import '../theme/app_theme.dart';

class TrackProfileCharts extends StatelessWidget {
  const TrackProfileCharts({super.key, required this.profile});

  final TrackProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty || (!profile.hasPace && !profile.hasElevation)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (profile.hasPace) _ProfileChart.pace(profile),
        if (profile.hasPace && profile.hasElevation) const SizedBox(height: 14),
        if (profile.hasElevation) _ProfileChart.elevation(profile),
      ],
    );
  }
}

/// Loads a saved track and shows its charts. Renders nothing while loading
/// or when the file is missing (not synced yet), empty or unreadable: the
/// route map above it already reports that case.
class SavedTrackCharts extends StatefulWidget {
  const SavedTrackCharts({super.key, required this.gpxFileName});

  final String gpxFileName;

  @override
  State<SavedTrackCharts> createState() => _SavedTrackChartsState();
}

class _SavedTrackChartsState extends State<SavedTrackCharts> {
  Future<TrackProfile>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(AppScope.of(context));
  }

  Future<TrackProfile> _load(AppServices services) async {
    try {
      final track =
          GpxService.parse(await services.vault.readTrack(widget.gpxFileName));
      return TrackProfile.build(track.segments);
    } catch (_) {
      return TrackProfile.empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrackProfile>(
      future: _future,
      builder: (context, snap) {
        final profile = snap.data;
        if (profile == null || profile.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TrackProfileCharts(profile: profile),
        );
      },
    );
  }
}

// =============================================================================
// One chart
// =============================================================================

class _ProfileChart extends StatefulWidget {
  const _ProfileChart._({
    required this.title,
    required this.color,
    required this.profile,
    required this.values,
    required this.minValue,
    required this.maxValue,
    required this.invert,
    required this.format,
    required this.summary,
  });

  /// Rolling pace: faster (smaller number) is drawn higher.
  factory _ProfileChart.pace(TrackProfile profile) {
    final range = profile.paceRange!;
    final avg = formatPace(profile.avgPaceSecPerKm);
    return _ProfileChart._(
      title: 'Pace',
      color: AppColors.activity,
      profile: profile,
      values: [for (final s in profile.samples) s.paceSecPerKm],
      minValue: range.fast,
      maxValue: range.slow,
      invert: true,
      format: (v) => '${formatPace(v) ?? '--'} /km',
      summary: avg == null ? '' : 'avg $avg /km',
    );
  }

  factory _ProfileChart.elevation(TrackProfile profile) {
    final range = profile.elevationRange!;
    return _ProfileChart._(
      title: 'Elevation',
      color: AppColors.accent,
      profile: profile,
      values: [for (final s in profile.samples) s.eleM],
      minValue: range.min,
      maxValue: range.max,
      invert: false,
      format: (v) => '${v.round()} m',
      summary: '${range.min.round()}–${range.max.round()} m',
    );
  }

  final String title;
  final Color color;
  final TrackProfile profile;
  final List<double?> values;
  final double minValue;
  final double maxValue;

  /// True when a smaller value is "better" and goes to the top (pace).
  final bool invert;
  final String Function(double value) format;

  /// Short text shown at the right of the header while no cursor is set.
  final String summary;

  @override
  State<_ProfileChart> createState() => _ProfileChartState();
}

class _ProfileChartState extends State<_ProfileChart> {
  static const double _chartHeight = 120;

  int? _cursor;

  void _scrub(double dx, double width, {bool toggle = false}) {
    final total = widget.profile.totalDistanceM;
    if (width <= 0 || total <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final index = widget.profile.indexAtDistance(fraction * total);
    setState(() => _cursor = (toggle && _cursor == index) ? null : index);
  }

  String _header() {
    final i = _cursor;
    if (i == null) return widget.summary;
    final value = widget.values[i];
    final km = widget.profile.samples[i].distanceM / 1000;
    return '${value == null ? '--' : widget.format(value)} '
        '· ${km.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              _header(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _cursor == null ? AppColors.textDim : widget.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _scrub(d.localPosition.dx, width, toggle: true),
              onHorizontalDragStart: (d) => _scrub(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx, width),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(width, _chartHeight),
                  painter: ProfileChartPainter(
                    distancesM: [
                      for (final s in widget.profile.samples) s.distanceM,
                    ],
                    values: widget.values,
                    minValue: widget.minValue,
                    maxValue: widget.maxValue,
                    color: widget.color,
                    invert: widget.invert,
                    cursorIndex: _cursor,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Line + gradient fill of [values] against [distancesM].
///
/// Values outside `[minValue, maxValue]` are clamped to the chart edge, so a
/// stop (a huge pace) does not leave the canvas. A `null` value breaks the
/// line. Exposed (not private) so a golden or widget test can paint it.
class ProfileChartPainter extends CustomPainter {
  ProfileChartPainter({
    required this.distancesM,
    required this.values,
    required this.minValue,
    required this.maxValue,
    required this.color,
    this.invert = false,
    this.cursorIndex,
  }) : assert(distancesM.length == values.length);

  final List<double> distancesM;
  final List<double?> values;
  final double minValue;
  final double maxValue;
  final Color color;

  /// Smaller values at the top instead of the bottom.
  final bool invert;
  final int? cursorIndex;

  static const double _axisHeight = 16;
  static const double _topPad = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (distancesM.length < 2) return;
    final total = distancesM.last;
    if (total <= 0) return;

    final plotTop = _topPad;
    final plotBottom = size.height - _axisHeight;
    final plotHeight = math.max(1.0, plotBottom - plotTop);
    final span = maxValue - minValue;

    double xOf(double d) => d / total * size.width;
    double yOf(double v) {
      final t = span <= 0 ? 0.5 : ((v - minValue) / span).clamp(0.0, 1.0);
      return invert ? plotTop + t * plotHeight : plotBottom - t * plotHeight;
    }

    // Grid.
    final grid = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plotTop + plotHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Runs of consecutive non-null values.
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    final fillBase = invert ? plotTop : plotBottom;
    var run = <Offset>[];

    void flush() {
      if (run.length >= 2) {
        final stroke = Path()..moveTo(run.first.dx, run.first.dy);
        for (final p in run.skip(1)) {
          stroke.lineTo(p.dx, p.dy);
        }
        final area = Path.from(stroke)
          ..lineTo(run.last.dx, fillBase)
          ..lineTo(run.first.dx, fillBase)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: invert ? Alignment.bottomCenter : Alignment.topCenter,
              end: invert ? Alignment.topCenter : Alignment.bottomCenter,
              colors: [color.withAlpha(70), color.withAlpha(0)],
            ).createShader(Rect.fromLTWH(0, plotTop, size.width, plotHeight)),
        );
        canvas.drawPath(stroke, line);
      }
      run = <Offset>[];
    }

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        flush();
      } else {
        run.add(Offset(xOf(distancesM[i]), yOf(v)));
      }
    }
    flush();

    // Axis labels: distance along the bottom edge.
    const dim = TextStyle(fontSize: 10, color: AppColors.textDim);
    _text(canvas, '0', Offset(0, size.height - _axisHeight + 3), dim);
    _text(
      canvas,
      '${(total / 1000).toStringAsFixed(total >= 10000 ? 0 : 1)} km',
      Offset(size.width, size.height - _axisHeight + 3),
      dim,
      alignRight: true,
    );

    // Cursor.
    final c = cursorIndex;
    if (c != null && c >= 0 && c < values.length) {
      final x = xOf(distancesM[c]);
      canvas.drawLine(
        Offset(x, plotTop),
        Offset(x, plotBottom),
        Paint()
          ..color = Colors.white.withAlpha(140)
          ..strokeWidth = 1,
      );
      final v = values[c];
      if (v != null) {
        final center = Offset(x, yOf(v));
        canvas.drawCircle(center, 5, Paint()..color = Colors.black);
        canvas.drawCircle(center, 4, Paint()..color = color);
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    TextStyle style, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(alignRight ? anchor.dx - painter.width : anchor.dx, anchor.dy),
    );
  }

  @override
  bool shouldRepaint(ProfileChartPainter old) =>
      old.cursorIndex != cursorIndex ||
      old.color != color ||
      old.invert != invert ||
      old.minValue != minValue ||
      old.maxValue != maxValue ||
      !identical(old.values, values) && !_sameValues(old.values, values) ||
      !identical(old.distancesM, distancesM) &&
          !_sameDistances(old.distancesM, distancesM);

  static bool _sameValues(List<double?> a, List<double?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameDistances(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
