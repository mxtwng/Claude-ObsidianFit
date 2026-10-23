/// Auto-laps: post-activity split breakdown and live lap detection
/// (pure Dart, no IO).
///
///  * [SplitCalculator] cuts a recorded track into 1 km / 1 mile splits,
///    interpolating the exact crossing time and elevation inside a GPS step.
///    Pauses are excluded (see `track_math.dart`).
///  * [LiveLapDetector] watches cumulative distance + elapsed time during a
///    recording and reports each completed lap, so the UI can buzz.
library;

import 'activity_metrics.dart';
import 'gpx_service.dart';
import 'track_math.dart';

enum SplitUnit {
  km(1000, 'km', 'Km'),
  mi(1609.344, 'mi', 'Mile');

  const SplitUnit(this.meters, this.short, this.heading);

  /// Length of one split in metres.
  final double meters;

  /// `km` / `mi`, used in labels such as `Pace /km`.
  final String short;

  /// First column heading of the split table: `Km` / `Mile`.
  final String heading;

  static SplitUnit? fromHeading(String text) {
    final t = text.trim().toLowerCase();
    for (final u in SplitUnit.values) {
      if (u.heading.toLowerCase() == t || u.short == t) return u;
    }
    return null;
  }
}

/// A trailing remainder shorter than this is dropped from the split list.
const double kMinPartialSplitM = 50;

class Split {
  const Split({
    required this.index,
    required this.distanceM,
    required this.duration,
    this.elevationDeltaM,
    this.elevationGainM,
    this.avgHr,
    this.partial = false,
  });

  /// 1-based lap number.
  final int index;

  /// Length of this split: the full unit, or the remainder for a partial one.
  final double distanceM;

  /// Moving time spent on this split.
  final Duration duration;

  /// Net elevation change (end minus start), null without elevation data.
  final double? elevationDeltaM;

  /// Noise-filtered climb inside the split.
  final double? elevationGainM;
  final int? avgHr;

  /// True for the trailing, shorter-than-a-unit split.
  final bool partial;

  /// Pace in seconds per [unit], normalised to the split's real length.
  double? paceSecPer(SplitUnit unit) {
    if (distanceM <= 0) return null;
    return (duration.inMilliseconds / 1000) / (distanceM / unit.meters);
  }
}

class SplitCalculator {
  const SplitCalculator._();

  static Split _make({
    required int index,
    required double distanceM,
    required double seconds,
    required double? startEle,
    required double? endEle,
    required ElevationGain gain,
    required int hrSum,
    required int hrCount,
    required bool partial,
  }) {
    return Split(
      index: index,
      distanceM: distanceM,
      duration: Duration(milliseconds: (seconds * 1000).round()),
      elevationDeltaM:
          (startEle != null && endEle != null) ? endEle - startEle : null,
      elevationGainM: gain.gainM,
      avgHr: hrCount == 0 ? null : (hrSum / hrCount).round(),
      partial: partial,
    );
  }

  /// Splits [segments] into laps of one [unit]. Returns an empty list for a
  /// track with fewer than two points.
  static List<Split> compute(
    List<List<TrackPoint>> segments, {
    SplitUnit unit = SplitUnit.km,
  }) {
    final track = CumulativeTrack.from(segments);
    final n = track.length;
    if (n < 2) return const [];

    final d = track.distanceM;
    final t = track.timeS;
    final pts = track.points;
    final unitM = unit.meters;
    // Tolerance so 999.9999999 m at the end of a km still closes the lap.
    const eps = 1e-6;

    final out = <Split>[];
    var boundary = unitM;
    var startD = 0.0;
    var startT = t.first;
    double? startEle = pts.first.ele;
    var gain = ElevationGain();
    if (startEle != null) gain.add(startEle);
    var hrSum = 0;
    var hrCount = 0;
    final firstHr = pts.first.hr;
    if (firstHr != null) {
      hrSum += firstHr;
      hrCount++;
    }

    for (var i = 1; i < n; i++) {
      while (d[i] + eps >= boundary && d[i] > d[i - 1]) {
        final span = d[i] - d[i - 1];
        final f = ((boundary - d[i - 1]) / span).clamp(0.0, 1.0).toDouble();
        final tB = t[i - 1] + f * (t[i] - t[i - 1]);
        final e0 = pts[i - 1].ele;
        final e1 = pts[i].ele;
        final double? eB =
            (e0 != null && e1 != null) ? e0 + f * (e1 - e0) : (e1 ?? e0);

        if (eB != null) gain.add(eB);
        out.add(
          _make(
            index: out.length + 1,
            distanceM: unitM,
            seconds: tB - startT,
            startEle: startEle,
            endEle: eB,
            gain: gain,
            hrSum: hrSum,
            hrCount: hrCount,
            partial: false,
          ),
        );

        startD = boundary;
        startT = tB;
        startEle = eB;
        gain = ElevationGain();
        if (eB != null) gain.add(eB);
        hrSum = 0;
        hrCount = 0;
        boundary = unitM * (out.length + 1);
      }

      final e = pts[i].ele;
      if (e != null) gain.add(e);
      final hr = pts[i].hr;
      if (hr != null) {
        hrSum += hr;
        hrCount++;
      }
    }

    final remainder = d.last - startD;
    if (remainder >= kMinPartialSplitM) {
      out.add(
        _make(
          index: out.length + 1,
          distanceM: remainder,
          seconds: t.last - startT,
          startEle: startEle,
          endEle: pts.last.ele,
          gain: gain,
          hrSum: hrSum,
          hrCount: hrCount,
          partial: true,
        ),
      );
    }
    return out;
  }
}

/// One completed lap during a live recording.
class LapEvent {
  const LapEvent({
    required this.number,
    required this.lapTime,
    required this.totalTime,
    required this.unit,
  });

  /// 1-based lap number.
  final int number;
  final Duration lapTime;

  /// Recording time at the moment the lap was completed.
  final Duration totalTime;
  final SplitUnit unit;

  /// Pace of this lap, seconds per [unit] (one full unit per lap).
  double get paceSecPerUnit => lapTime.inMilliseconds / 1000;

  /// `Km 3` / `Mile 2`.
  String get label => '${unit.heading} $number';

  /// `5:12`, or null for a degenerate lap.
  String? get paceText => formatPace(paceSecPerUnit);
}

/// Turns the recorder's running distance and elapsed time into lap events.
///
/// Feed it after every accepted GPS fix. When a fix jumps across one or more
/// lap boundaries, the crossing time is interpolated between the previous and
/// the current fix, so lap times stay accurate with a sparse fix rate.
class LiveLapDetector {
  LiveLapDetector({this.unit = SplitUnit.km});

  final SplitUnit unit;

  int _done = 0;
  double _prevDistanceM = 0;
  Duration _prevElapsed = Duration.zero;
  Duration _lastCross = Duration.zero;

  int get lapsCompleted => _done;

  /// Laps completed by [distanceM] (cumulative moving distance) at [elapsed]
  /// (moving time, pauses excluded). Empty when no boundary was crossed.
  List<LapEvent> update({
    required double distanceM,
    required Duration elapsed,
  }) {
    final events = <LapEvent>[];
    final due = (distanceM / unit.meters + 1e-9).floor();
    if (due > _done) {
      final span = distanceM - _prevDistanceM;
      final prevUs = _prevElapsed.inMicroseconds;
      final nowUs = elapsed.inMicroseconds;
      while (_done < due) {
        final boundary = unit.meters * (_done + 1);
        final f = span <= 0
            ? 1.0
            : ((boundary - _prevDistanceM) / span).clamp(0.0, 1.0).toDouble();
        final cross =
            Duration(microseconds: (prevUs + f * (nowUs - prevUs)).round());
        _done++;
        events.add(
          LapEvent(
            number: _done,
            lapTime: cross - _lastCross,
            totalTime: cross,
            unit: unit,
          ),
        );
        _lastCross = cross;
      }
    }
    _prevDistanceM = distanceM;
    _prevElapsed = elapsed;
    return events;
  }
}
