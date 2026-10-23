/// Weekly aggregates for the multi-sport dashboard (pure Dart, no IO):
/// total lifting volume (kg), total distance (km) and total mobility time
/// (minutes), per calendar week starting on Monday.
///
/// What counts:
///  * **Volume**: the note's `total_volume_kg`, or the sets' tonnage
///    (warmups excluded) when the note has none. Same rule as the history
///    cards.
///  * **Distance**: `distance_km` of every activity (runs, rides, walks...).
///  * **Mobility**: hold time (`Hold: <s>s` sets) of stretching and mobility
///    work: every hold in a session whose split, title or tags say
///    mobility/stretch/yoga/flexibility, plus the holds of any exercise
///    named like a stretch, plus the duration of `yoga`, `stretch` and
///    `mobility` activities.
library;

import '../models/Models.dart';

class WeeklyTotals {
  const WeeklyTotals({
    required this.weekStart,
    this.volumeKg = 0,
    this.distanceKm = 0,
    this.mobilityMinutes = 0,
    this.workoutCount = 0,
    this.activityCount = 0,
  });

  /// Local midnight of the Monday that starts the week.
  final DateTime weekStart;
  final double volumeKg;
  final double distanceKm;
  final double mobilityMinutes;
  final int workoutCount;
  final int activityCount;
}

class _Accumulator {
  double volumeKg = 0;
  double distanceKm = 0;
  double mobilitySeconds = 0;
  int workouts = 0;
  int activities = 0;
}

class WeeklyStatsService {
  const WeeklyStatsService._();

  static final RegExp _mobilityExercise = RegExp(
    r"(stretch|mobility|yoga|flexib|foam.?roll|pigeon|cat.?cow|"
    r"child'?s pose|downward dog)",
    caseSensitive: false,
  );
  static final RegExp _mobilitySession =
      RegExp(r'(mobility|stretch|yoga|flexib)', caseSensitive: false);
  static final RegExp _mobilityCategory =
      RegExp(r'(yoga|stretch|mobility)', caseSensitive: false);

  /// Local midnight of the Monday on or before [date].
  static DateTime weekStartOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  /// Lifting volume of one session in kg.
  static double workoutVolumeKg(WorkoutSession s) =>
      s.totalVolumeKg ?? s.computedVolumeKg();

  /// Stretching / mobility hold time of one session in seconds.
  static double mobilitySeconds(WorkoutSession s) {
    final wholeSession = _mobilitySession.hasMatch(
      '${s.split} ${s.title} ${s.tags.join(' ')}',
    );
    var seconds = 0.0;
    for (final exercise in s.exercises) {
      if (!wholeSession && !_mobilityExercise.hasMatch(exercise.name)) {
        continue;
      }
      for (final set in exercise.sets) {
        seconds += set.durationSeconds ?? 0;
      }
    }
    return seconds;
  }

  /// Totals for the [weeks] weeks ending with the week of [now], oldest
  /// first (the last element is the current week). Sessions outside that
  /// range are ignored.
  static List<WeeklyTotals> compute({
    Iterable<WorkoutSession> workouts = const [],
    Iterable<ActivitySession> activities = const [],
    DateTime? now,
    int weeks = 8,
  }) {
    if (weeks <= 0) return const [];
    final current = weekStartOf(now ?? DateTime.now());
    final starts = [
      for (var i = weeks - 1; i >= 0; i--)
        DateTime(current.year, current.month, current.day - 7 * i),
    ];
    final buckets = {
      for (final s in starts) formatIsoDate(s): _Accumulator(),
    };

    for (final w in workouts) {
      final b = buckets[formatIsoDate(weekStartOf(w.date))];
      if (b == null) continue;
      b.workouts++;
      b.volumeKg += workoutVolumeKg(w);
      b.mobilitySeconds += mobilitySeconds(w);
    }
    for (final a in activities) {
      final b = buckets[formatIsoDate(weekStartOf(a.date))];
      if (b == null) continue;
      b.activities++;
      b.distanceKm += a.distanceKm ?? 0;
      if (_mobilityCategory.hasMatch(a.category)) {
        b.mobilitySeconds += a.effectiveDurationSeconds;
      }
    }

    return [
      for (final s in starts)
        WeeklyTotals(
          weekStart: s,
          volumeKg: buckets[formatIsoDate(s)]!.volumeKg,
          distanceKm: buckets[formatIsoDate(s)]!.distanceKm,
          mobilityMinutes: buckets[formatIsoDate(s)]!.mobilitySeconds / 60,
          workoutCount: buckets[formatIsoDate(s)]!.workouts,
          activityCount: buckets[formatIsoDate(s)]!.activities,
        ),
    ];
  }
}
