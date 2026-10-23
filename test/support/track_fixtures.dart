/// Synthetic GPS tracks for the Phase 6 tests.
///
/// Every track runs due north along one meridian, so the Haversine distance
/// between two points is exactly `R * dLat` and the expected distances and
/// paces can be written down by hand.
library;

import 'dart:math' as math;

import 'package:obsidian_fit/services/activity_metrics.dart' show kEarthRadiusM;
import 'package:obsidian_fit/services/gpx_service.dart';

/// Metres per degree of latitude on the sphere the app's Haversine uses.
const double kMetersPerDegLat = kEarthRadiusM * math.pi / 180;

/// Fixed UTC start so the tests never depend on the wall clock.
final DateTime kTrackStart = DateTime.utc(2026, 10, 22, 10);

/// One `<trkseg>` made of constant-speed phases.
///
/// Each phase is `(steps, secondsPerStep)`; every step moves [stepM] metres.
/// The segment starts with a point at distance 0, so `n` steps in total give
/// `n + 1` points.
///
/// [ele] and [hr] receive the point index (0 for the first point).
List<TrackPoint> buildSegment(
  List<(int, double)> phases, {
  double stepM = 10,
  double startLat = 10,
  double lon = 106,
  DateTime? start,
  double? Function(int index)? ele,
  int? Function(int index)? hr,
}) {
  final t0 = start ?? kTrackStart;
  TrackPoint point(int i, double seconds) => TrackPoint(
        lat: startLat + i * stepM / kMetersPerDegLat,
        lon: lon,
        time: t0.add(Duration(milliseconds: (seconds * 1000).round())),
        ele: ele?.call(i),
        hr: hr?.call(i),
      );

  var i = 0;
  var seconds = 0.0;
  final points = <TrackPoint>[point(0, 0)];
  for (final (steps, secPerStep) in phases) {
    for (var s = 0; s < steps; s++) {
      i++;
      seconds += secPerStep;
      points.add(point(i, seconds));
    }
  }
  return points;
}

/// A single constant-pace segment of [steps] steps.
List<TrackPoint> steadySegment({
  required int steps,
  double secPerStep = 3,
  double stepM = 10,
  double startLat = 10,
  DateTime? start,
  double? Function(int index)? ele,
  int? Function(int index)? hr,
}) {
  return buildSegment(
    [(steps, secPerStep)],
    stepM: stepM,
    startLat: startLat,
    start: start,
    ele: ele,
    hr: hr,
  );
}
