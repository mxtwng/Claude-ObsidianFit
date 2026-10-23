/// All-time personal records (pure Dart, no IO): estimated 1RM bench press,
/// longest plank hold, longest run and fastest 5K.
///
/// Rules, so the numbers can be trusted:
///  * Ties go to the earliest holder: records are folded oldest first and a
///    later session must be strictly better to take over.
///  * Warmup sets never count.
///  * **1RM bench** is the Epley estimate `w x (1 + reps / 30)` of the best
///    external-load set of 1 to 12 reps on a flat bench press. Incline,
///    decline, dumbbell, close-grip, smith/machine, cable, floor and paused
///    variations are different lifts and are skipped.
///  * **Max plank** is the longest hold under an exercise whose name contains
///    "plank" (weighted planks included; side and reverse planks are not).
///  * **Longest run** is the largest `distance_km` of any `run` activity
///    (`trail_run`, `treadmill_run`, ...).
///  * **Fastest 5K** is the best moving-time window of 5000 m inside a run's
///    GPX track. A run logged without GPS only counts when it is a 5K effort
///    (5.00 to 5.25 km), scaled to exactly 5 km and flagged as estimated.
library;

import '../models/Models.dart';
import 'activity_metrics.dart' show formatDuration, formatPace;
import 'gpx_service.dart';
import 'session_time.dart';
import 'track_math.dart';

enum PrKind {
  bench1rm('1RM Bench'),
  maxPlank('Max Plank'),
  longestRun('Longest Run'),
  fastest5k('Fastest 5K', lowerIsBetter: true);

  const PrKind(this.label, {this.lowerIsBetter = false});

  final String label;

  /// True when a smaller value wins (a time).
  final bool lowerIsBetter;

  bool isBetter(double candidate, double current) =>
      lowerIsBetter ? candidate < current : candidate > current;
}

/// The best performance for one [PrKind].
///
/// [value] units: kg (bench1rm), seconds (maxPlank, fastest5k), km
/// (longestRun).
class PersonalRecord {
  const PersonalRecord({
    required this.kind,
    required this.value,
    required this.achievedAt,
    required this.date,
    required this.sourcePath,
    required this.isWorkout,
    this.detail = '',
    this.estimated = false,
  });

  final PrKind kind;
  final double value;

  /// When the session started (for ordering).
  final DateTime achievedAt;

  /// Calendar date of the session (for display).
  final DateTime date;

  /// Vault-relative path of the note that holds the record.
  final String sourcePath;
  final bool isWorkout;

  /// Short context, e.g. `85 kg × 6` or `Plank`.
  final String detail;

  /// True when the value was extrapolated (a manual 5K-ish run).
  final bool estimated;

  /// Value formatted for display.
  String get display => switch (kind) {
        PrKind.bench1rm => '${formatDecimal((value * 10).round() / 10)} kg',
        PrKind.maxPlank => formatDuration(Duration(seconds: value.round())),
        PrKind.longestRun => '${value.toStringAsFixed(2)} km',
        PrKind.fastest5k =>
          '${estimated ? '~' : ''}${formatDuration(Duration(seconds: value.round()))}',
      };
}

/// The current best [PersonalRecord] per [PrKind].
class PrSnapshot {
  const PrSnapshot(this.records);

  static const PrSnapshot empty = PrSnapshot(<PrKind, PersonalRecord>{});

  final Map<PrKind, PersonalRecord> records;

  PersonalRecord? operator [](PrKind kind) => records[kind];

  bool get isEmpty => records.isEmpty;
}

class PrWorkoutSource {
  const PrWorkoutSource({required this.path, required this.session});

  /// Vault-relative note path.
  final String path;
  final WorkoutSession session;
}

class PrActivitySource {
  const PrActivitySource({
    required this.path,
    required this.session,
    this.hasTrack = false,
    this.trackFastest5kSeconds,
  });

  /// Builds a source from a parsed track, computing the fastest 5K once.
  factory PrActivitySource.fromSegments({
    required String path,
    required ActivitySession session,
    required List<List<TrackPoint>> segments,
  }) {
    return PrActivitySource(
      path: path,
      session: session,
      hasTrack: segments.any((s) => s.isNotEmpty),
      trackFastest5kSeconds:
          fastestWindowSeconds(segments, PrService.fiveKilometresM),
    );
  }

  final String path;
  final ActivitySession session;

  /// True when the note has a GPX track (even one that is unreadable). A run
  /// with a track is never scored from its summary numbers.
  final bool hasTrack;

  /// Fastest moving time for 5000 m on the track, null if shorter or absent.
  final double? trackFastest5kSeconds;
}

class PrService {
  const PrService._();

  static const double fiveKilometresM = 5000;

  /// Longest manual run (km) still accepted as a 5K effort.
  static const double manualFiveKMaxKm = 5.25;

  /// Epley is unreliable above this many reps.
  static const int maxRepsForOneRepMax = 12;

  /// Epley one-rep-max estimate. One rep is the weight itself.
  static double oneRepMax(double weightKg, int reps) =>
      reps <= 1 ? weightKg : weightKg * (1 + reps / 30);

  static final RegExp _notFlatBarbell = RegExp(
    r'\b(incline|decline|dumbbells?|dumbells?|db|smith|machine|close|narrow|'
    r'floor|cable|seated|single|one[- ]arm|paused?|spoto|reverse|hammer)\b',
  );
  static final RegExp _notStandardPlank = RegExp(r'\b(side|reverse)\b');
  static final RegExp _runCategory = RegExp(r'(^|[^a-z])run($|[^a-z])');

  static bool isBenchPress(String name) {
    final n = name.toLowerCase().trim();
    if (!n.contains('bench')) return false;
    if (!n.contains('press') && n != 'bench') return false;
    return !_notFlatBarbell.hasMatch(n);
  }

  static bool isPlank(String name) {
    final n = name.toLowerCase();
    return n.contains('plank') && !_notStandardPlank.hasMatch(n);
  }

  static bool isRun(String category) =>
      _runCategory.hasMatch(category.toLowerCase());

  /// Folds every candidate into the best record per kind.
  static PrSnapshot compute({
    Iterable<PrWorkoutSource> workouts = const [],
    Iterable<PrActivitySource> activities = const [],
  }) {
    final all = <PersonalRecord>[
      for (final w in workouts) ..._workoutCandidates(w),
      for (final a in activities) ..._activityCandidates(a),
    ];
    // Oldest first, input order as the tie-break, so ties stay with the
    // earliest holder.
    final order = List<int>.generate(all.length, (i) => i)
      ..sort((x, y) {
        final c = all[x].achievedAt.compareTo(all[y].achievedAt);
        return c != 0 ? c : x.compareTo(y);
      });

    final best = <PrKind, PersonalRecord>{};
    for (final i in order) {
      final candidate = all[i];
      final current = best[candidate.kind];
      if (current == null ||
          candidate.kind.isBetter(candidate.value, current.value)) {
        best[candidate.kind] = candidate;
      }
    }
    return PrSnapshot(Map<PrKind, PersonalRecord>.unmodifiable(best));
  }

  /// The kinds in which the given new sessions beat [current] (or set a first
  /// record). Equal values do not count as broken. Kinds come in [PrKind]
  /// order.
  static List<PrKind> recordsBrokenBy(
    PrSnapshot current, {
    Iterable<PrWorkoutSource> workouts = const [],
    Iterable<PrActivitySource> activities = const [],
  }) {
    final candidates = compute(workouts: workouts, activities: activities);
    final broken = <PrKind>[];
    for (final kind in PrKind.values) {
      final candidate = candidates[kind];
      if (candidate == null) continue;
      final existing = current[kind];
      if (existing == null || kind.isBetter(candidate.value, existing.value)) {
        broken.add(kind);
      }
    }
    return broken;
  }

  // ---- candidates -----------------------------------------------------------

  static Iterable<PersonalRecord> _workoutCandidates(
    PrWorkoutSource source,
  ) sync* {
    final s = source.session;
    final at = sessionInstant(
      date: s.date,
      timeStarted: s.timeStarted,
      startTime: s.startTime,
    );
    for (final exercise in s.exercises) {
      final bench = isBenchPress(exercise.name);
      final plank = isPlank(exercise.name);
      if (!bench && !plank) continue;
      for (final set in exercise.sets) {
        if (set.type == SetType.warmup) continue;
        if (bench) {
          final reps = set.reps;
          if (!set.isBodyweight &&
              reps != null &&
              reps >= 1 &&
              reps <= maxRepsForOneRepMax &&
              set.weightKg > 0) {
            yield PersonalRecord(
              kind: PrKind.bench1rm,
              value: oneRepMax(set.weightKg, reps),
              achievedAt: at,
              date: s.date,
              sourcePath: source.path,
              isWorkout: true,
              detail: reps == 1
                  ? '${formatDecimal(set.weightKg)} kg single'
                  : '${formatDecimal(set.weightKg)} kg × $reps',
            );
          }
        }
        if (plank) {
          final seconds = set.durationSeconds;
          if (seconds != null && seconds > 0) {
            yield PersonalRecord(
              kind: PrKind.maxPlank,
              value: seconds.toDouble(),
              achievedAt: at,
              date: s.date,
              sourcePath: source.path,
              isWorkout: true,
              detail: exercise.name,
            );
          }
        }
      }
    }
  }

  static Iterable<PersonalRecord> _activityCandidates(
    PrActivitySource source,
  ) sync* {
    final a = source.session;
    if (!isRun(a.category)) return;
    final at = sessionInstant(
      date: a.date,
      timeStarted: a.timeStarted,
      startTime: a.startTime,
    );
    final km = a.distanceKm;

    if (km != null && km > 0) {
      final seconds = a.effectiveDurationSeconds;
      yield PersonalRecord(
        kind: PrKind.longestRun,
        value: km,
        achievedAt: at,
        date: a.date,
        sourcePath: source.path,
        isWorkout: false,
        detail: seconds > 0 ? formatDuration(Duration(seconds: seconds)) : '',
      );
    }

    var fiveK = source.trackFastest5kSeconds;
    var estimated = false;
    if (fiveK == null &&
        !source.hasTrack &&
        km != null &&
        km >= 5.0 &&
        km <= manualFiveKMaxKm) {
      final seconds = a.effectiveDurationSeconds;
      if (seconds > 0) {
        fiveK = seconds * 5.0 / km;
        estimated = (km - 5.0).abs() > 1e-9;
      }
    }
    if (fiveK != null && fiveK > 0) {
      final pace = formatPace(fiveK / 5);
      yield PersonalRecord(
        kind: PrKind.fastest5k,
        value: fiveK,
        achievedAt: at,
        date: a.date,
        sourcePath: source.path,
        isWorkout: false,
        detail: pace == null ? '' : '$pace /km',
        estimated: estimated,
      );
    }
  }
}
