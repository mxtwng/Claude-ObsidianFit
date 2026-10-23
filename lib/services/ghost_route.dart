/// A saved `.gpx` track used as a static reference ("ghost") trace on the map
/// while recording, so a pre-planned trail or an earlier run can be followed.
library;

import 'package:path/path.dart' as p;

import 'FilePersistenceService.dart';
import 'activity_metrics.dart' show haversineMeters;
import 'gpx_service.dart';

class GhostRoute {
  const GhostRoute({
    required this.fileName,
    required this.name,
    required this.segments,
    required this.distanceM,
  });

  /// Bare file name inside `Tracks/`.
  final String fileName;

  /// Track name from the GPX, or the file name without extension.
  final String name;
  final List<List<TrackPoint>> segments;

  /// Length along the track; the gaps between segments are not counted.
  final double distanceM;

  double get distanceKm => distanceM / 1000;
  int get pointCount => segments.fold(0, (n, s) => n + s.length);

  /// Sum of the point-to-point distances inside each segment.
  static double lengthMeters(List<List<TrackPoint>> segments) {
    var total = 0.0;
    for (final segment in segments) {
      for (var i = 1; i < segment.length; i++) {
        final a = segment[i - 1];
        final b = segment[i];
        total += haversineMeters(a.lat, a.lon, b.lat, b.lon);
      }
    }
    return total;
  }

  /// Reads and parses `Tracks/<fileName>`. Throws [FormatException] for a
  /// track without points, and the parser's or the file system's exception
  /// for unreadable files.
  static Future<GhostRoute> load(
    FilePersistenceService vault,
    String fileName,
  ) async {
    final track = GpxService.parse(await vault.readTrack(fileName));
    if (track.isEmpty) {
      throw FormatException('No track points in $fileName');
    }
    return GhostRoute(
      fileName: fileName,
      name: track.name.isEmpty
          ? p.basenameWithoutExtension(fileName)
          : track.name,
      segments: track.segments,
      distanceM: lengthMeters(track.segments),
    );
  }
}
