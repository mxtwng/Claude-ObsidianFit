/// Chart-ready series for a recorded track: smoothed elevation and rolling
/// pace against distance (pure Dart, no IO).
///
/// Built on [CumulativeTrack], so pauses add no distance and no time. The
/// series is down-sampled by distance to a few hundred samples, which keeps
/// the canvas painters cheap for multi-hour rides.
library;

import 'dart:math' as math;

import 'gpx_service.dart';
import 'track_math.dart';

class ProfileSample {
  const ProfileSample({
    required this.distanceM,
    required this.timeS,
    this.eleM,
    this.paceSecPerKm,
  });

  /// Moving distance from the start, metres.
  final double distanceM;

  /// Moving time from the start, seconds.
  final double timeS;

  /// Smoothed elevation, null when the track has none around this point.
  final double? eleM;

  /// Rolling pace over the last [TrackProfile.build]'s `paceWindowM`, seconds
  /// per km. Null at the very start of the track.
  final double? paceSecPerKm;
}

class TrackProfile {
  const TrackProfile(this.samples);

  static const TrackProfile empty = TrackProfile([]);

  /// Builds the profile.
  ///
  ///  * [maxSamples]: upper bound on the number of samples.
  ///  * [paceWindowM]: pace is the time taken for the last [paceWindowM]
  ///    metres (a shorter window until that much distance exists).
  ///  * [eleWindowM]: elevation is the mean within +/- [eleWindowM] metres,
  ///    which removes GPS altitude jitter.
  factory TrackProfile.build(
    List<List<TrackPoint>> segments, {
    int maxSamples = 400,
    double paceWindowM = 100,
    double eleWindowM = 30,
  }) {
    final track = CumulativeTrack.from(segments);
    final n = track.length;
    if (n < 2 || track.totalDistanceM <= 0 || maxSamples < 2) return empty;

    final d = track.distanceM;
    final t = track.timeS;

    // Prefix sums over the points that have an elevation.
    final eleSum = List<double>.filled(n + 1, 0);
    final eleCount = List<int>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      final e = track.points[i].ele;
      eleSum[i + 1] = eleSum[i] + (e ?? 0);
      eleCount[i + 1] = eleCount[i] + (e == null ? 0 : 1);
    }

    final indices = <int>[];
    if (n <= maxSamples) {
      for (var i = 0; i < n; i++) {
        indices.add(i);
      }
    } else {
      final total = d.last;
      var last = -1;
      for (var k = 0; k < maxSamples; k++) {
        final target = total * k / (maxSamples - 1);
        final idx = math.min(_lowerBound(d, target), n - 1);
        if (idx != last) {
          indices.add(idx);
          last = idx;
        }
      }
      if (indices.last != n - 1) indices.add(n - 1);
    }

    final samples = <ProfileSample>[];
    for (final i in indices) {
      final lo = _lowerBound(d, d[i] - eleWindowM);
      final hi = math.max(i, _upperBound(d, d[i] + eleWindowM) - 1);
      final count = eleCount[hi + 1] - eleCount[lo];
      final double? ele =
          count == 0 ? null : (eleSum[hi + 1] - eleSum[lo]) / count;

      var j = _upperBound(d, d[i] - paceWindowM) - 1;
      if (j < 0 && d[i] >= 30) j = 0;
      double? pace;
      if (j >= 0 && j < i) {
        final dd = d[i] - d[j];
        final dt = t[i] - t[j];
        if (dd > 0 && dt > 0) pace = dt / dd * 1000;
      }

      samples.add(
        ProfileSample(
          distanceM: d[i],
          timeS: t[i],
          eleM: ele,
          paceSecPerKm: pace,
        ),
      );
    }
    return TrackProfile(samples);
  }

  final List<ProfileSample> samples;

  bool get isEmpty => samples.isEmpty;
  double get totalDistanceM => samples.isEmpty ? 0 : samples.last.distanceM;
  double get totalTimeS => samples.isEmpty ? 0 : samples.last.timeS;

  bool get hasElevation => samples.any((s) => s.eleM != null);
  bool get hasPace => samples.any((s) => s.paceSecPerKm != null);

  /// Average pace over the whole track, seconds per km.
  double? get avgPaceSecPerKm {
    if (totalDistanceM <= 0 || totalTimeS <= 0) return null;
    return totalTimeS / (totalDistanceM / 1000);
  }

  /// Vertical range for the elevation chart, at least 10 m tall.
  ({double min, double max})? get elevationRange {
    double? lo;
    double? hi;
    for (final s in samples) {
      final e = s.eleM;
      if (e == null) continue;
      lo = lo == null ? e : math.min(lo, e);
      hi = hi == null ? e : math.max(hi, e);
    }
    if (lo == null || hi == null) return null;
    if (hi - lo < 10) {
      final mid = (lo + hi) / 2;
      return (min: mid - 5, max: mid + 5);
    }
    return (min: lo, max: hi);
  }

  /// Vertical range for the pace chart. Uses the 3rd and 97th percentile so
  /// a stop (a huge pace) does not flatten the rest, and is at least 30 s
  /// tall. `fast` is the smaller number of seconds.
  ({double fast, double slow})? get paceRange {
    final paces = [
      for (final s in samples)
        if (s.paceSecPerKm != null) s.paceSecPerKm!,
    ]..sort();
    if (paces.isEmpty) return null;
    double q(double f) => paces[(f * (paces.length - 1)).round()];
    var fast = q(0.03);
    var slow = q(0.97);
    if (slow - fast < 30) {
      final mid = (fast + slow) / 2;
      fast = mid - 15;
      slow = mid + 15;
    }
    return (fast: fast, slow: slow);
  }

  /// Index of the sample nearest to [distanceM]. Requires a non-empty profile.
  int indexAtDistance(double distanceM) {
    assert(samples.isNotEmpty);
    final dist = [for (final s in samples) s.distanceM];
    final i = _lowerBound(dist, distanceM);
    if (i <= 0) return 0;
    if (i >= dist.length) return dist.length - 1;
    return (distanceM - dist[i - 1]) <= (dist[i] - distanceM) ? i - 1 : i;
  }

  /// First index whose value is >= [x] (list is non-decreasing).
  static int _lowerBound(List<double> a, double x) {
    var lo = 0;
    var hi = a.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (a[mid] < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// First index whose value is > [x].
  static int _upperBound(List<double> a, double x) {
    var lo = 0;
    var hi = a.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (a[mid] <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
