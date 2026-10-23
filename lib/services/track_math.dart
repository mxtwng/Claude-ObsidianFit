/// Shared track maths (pure Dart, no IO): a flattened track with cumulative
/// moving distance and moving time, and the fastest-window search used for
/// "Fastest 5K".
///
/// Each `<trkseg>` is a recording stretch between a Start/Resume and a
/// Pause/Stop. Nothing is accumulated *between* segments, so a pause adds no
/// distance and no time.
library;

import 'activity_metrics.dart' show haversineMeters;
import 'gpx_service.dart';

class CumulativeTrack {
  const CumulativeTrack._(this.points, this.distanceM, this.timeS);

  /// Flattens [segments]. `distanceM[i]` / `timeS[i]` are the moving distance
  /// (metres) and moving time (seconds) accumulated up to `points[i]`.
  factory CumulativeTrack.from(List<List<TrackPoint>> segments) {
    final points = <TrackPoint>[];
    final distance = <double>[];
    final time = <double>[];
    var cumD = 0.0;
    var cumT = 0.0;
    for (final segment in segments) {
      TrackPoint? prev;
      for (final p in segment) {
        if (prev != null) {
          cumD += haversineMeters(prev.lat, prev.lon, p.lat, p.lon);
          final dt = p.time.difference(prev.time).inMilliseconds / 1000.0;
          if (dt > 0) cumT += dt;
        }
        points.add(p);
        distance.add(cumD);
        time.add(cumT);
        prev = p;
      }
    }
    return CumulativeTrack._(points, distance, time);
  }

  final List<TrackPoint> points;
  final List<double> distanceM;
  final List<double> timeS;

  int get length => points.length;
  double get totalDistanceM => distanceM.isEmpty ? 0 : distanceM.last;
  double get totalTimeS => timeS.isEmpty ? 0 : timeS.last;
}

/// Fastest moving time, in seconds, to cover [targetM] metres anywhere in the
/// track (a sliding window with linear interpolation at the window start).
/// Null when the track is shorter than [targetM].
double? fastestWindowSeconds(List<List<TrackPoint>> segments, double targetM) {
  if (targetM <= 0) return null;
  final track = CumulativeTrack.from(segments);
  if (track.length < 2 || track.totalDistanceM < targetM) return null;

  final d = track.distanceM;
  final t = track.timeS;
  double? best;
  var k = 0;
  for (var j = 1; j < d.length; j++) {
    if (d[j] < targetM) continue;
    final startD = d[j] - targetM;
    // Latest index whose distance is at or before the window start.
    while (k + 1 < j && d[k + 1] <= startD) {
      k++;
    }
    final span = d[k + 1] - d[k];
    final startT =
        span > 0 ? t[k] + (startD - d[k]) / span * (t[k + 1] - t[k]) : t[k];
    final duration = t[j] - startT;
    if (duration > 0 && (best == null || duration < best)) best = duration;
  }
  return best;
}
