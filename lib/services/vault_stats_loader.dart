/// Reads the whole vault into the inputs of the PR engine and the weekly
/// dashboard.
///
/// The Drift index does not hold per-set data (a 1RM needs the sets), so this
/// parses the `.md` notes directly. That stays cheap because the only costly
/// part, parsing a run's GPX for its fastest 5K, is cached by file identity.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/Models.dart';
import 'FilePersistenceService.dart';
import 'gpx_service.dart';
import 'pr_service.dart';
import 'track_math.dart';
import 'weekly_stats.dart';

class VaultStats {
  const VaultStats({
    required this.workouts,
    required this.activities,
    required this.records,
  });

  final List<PrWorkoutSource> workouts;
  final List<PrActivitySource> activities;
  final PrSnapshot records;

  /// Weekly totals for the last [weeks] weeks, oldest first.
  List<WeeklyTotals> weekly({DateTime? now, int weeks = 8}) =>
      WeeklyStatsService.compute(
        workouts: [for (final w in workouts) w.session],
        activities: [for (final a in activities) a.session],
        now: now,
        weeks: weeks,
      );
}

class VaultStatsLoader {
  VaultStatsLoader(this.vault);

  final FilePersistenceService vault;

  /// `path|mtime|size` -> fastest 5K seconds (null: shorter than 5 km or
  /// unreadable). Tracks are immutable once saved, but a sync can replace one,
  /// hence the mtime and size in the key.
  static final Map<String, double?> _fiveKCache = {};

  static void clearCache() => _fiveKCache.clear();

  /// Scans `Workouts/` and `Activities/`. Notes that cannot be parsed are
  /// skipped. Syncthing conflict copies are never read (see
  /// [FilePersistenceService.listMarkdownFiles]).
  Future<VaultStats> load() async {
    final files = await vault.listMarkdownFiles(
      folders: const [
        FilePersistenceService.workoutsFolder,
        FilePersistenceService.activitiesFolder,
      ],
    );
    final workouts = <PrWorkoutSource>[];
    final activities = <PrActivitySource>[];
    for (final file in files) {
      try {
        final parsed =
            FilePersistenceService.parseAny(await file.readAsString());
        final rel = vault.relativePath(file);
        switch (parsed) {
          case WorkoutSession w:
            workouts.add(PrWorkoutSource(path: rel, session: w));
          case ActivitySession a:
            activities.add(await _activitySource(rel, a));
          default:
            break;
        }
      } catch (_) {
        // Unreadable or invalid note: the re-indexer reports it, stats skip it.
      }
    }
    return VaultStats(
      workouts: workouts,
      activities: activities,
      records: PrService.compute(workouts: workouts, activities: activities),
    );
  }

  Future<PrActivitySource> _activitySource(
    String relativePath,
    ActivitySession a,
  ) async {
    final gpx = a.gpxFileName;
    final km = a.distanceKm;
    // Only runs of 5 km or more can hold a 5K time.
    final needsTrack =
        gpx != null && PrService.isRun(a.category) && (km == null || km >= 5);
    if (!needsTrack) {
      return PrActivitySource(
        path: relativePath,
        session: a,
        hasTrack: gpx != null,
      );
    }

    double? fastest;
    try {
      final file = File(
        p.join(vault.vaultDir.path, FilePersistenceService.tracksFolder, gpx),
      );
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.notFound) {
        final key =
            '${file.path}|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
        if (_fiveKCache.containsKey(key)) {
          fastest = _fiveKCache[key];
        } else {
          fastest = fastestWindowSeconds(
            GpxService.parse(await file.readAsString()).segments,
            PrService.fiveKilometresM,
          );
          _fiveKCache[key] = fastest;
        }
      }
    } catch (_) {
      // Missing (not synced yet) or malformed track: no 5K from this run.
    }
    return PrActivitySource(
      path: relativePath,
      session: a,
      hasTrack: true,
      trackFastest5kSeconds: fastest,
    );
  }
}
