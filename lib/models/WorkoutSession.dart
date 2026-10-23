import 'ExerciseEntry.dart';
import 'ModelUtils.dart';

/// A gym session. Mirrors `schemas/workout_schema.md` plus the Phase 5
/// extensions in `schemas/workout_schema.phase5.md`.
///
/// Frontmatter <-> model mapping is handled here; the `# Title` and
/// `## Exercise` body is rendered/parsed by `FilePersistenceService`.
class WorkoutSession {
  const WorkoutSession({
    this.type = 'strength',
    required this.split,
    required this.date,
    required this.timeStarted,
    this.startTime,
    this.dateLogged,
    required this.durationMin,
    this.totalVolumeKg,
    this.tssScore,
    this.readinessScore,
    this.tags = const [],
    this.title = '',
    this.exercises = const [],
    this.preamble = '',
    this.extraFrontmatter = const {},
  });

  /// Frontmatter `type` (always `strength` for gym sessions).
  final String type;
  final String split;

  /// Date-only.
  final DateTime date;

  /// `HH:mm` (24h), kept as a string for lossless round trip.
  final String timeStarted;

  /// When the session actually began (UTC, second precision). For a backdated
  /// entry this is the historical time the user picked. Null on legacy notes,
  /// which fall back to [date] + [timeStarted]. Serialized as
  /// `"2026-10-18T11:30:00Z"`.
  final DateTime? startTime;

  /// When the note was written (UTC, second precision). Set once at creation.
  /// Null on legacy notes. Serialized like [startTime].
  final DateTime? dateLogged;
  final double durationMin;
  final double? totalVolumeKg;
  final int? tssScore;
  final int? readinessScore;
  final List<String> tags;

  /// The `# H1` heading text (e.g. "Push Day Session").
  final String title;
  final List<ExerciseEntry> exercises;

  /// Free text between the H1 and the first `## Exercise` heading.
  final String preamble;

  /// Unknown frontmatter keys, preserved verbatim.
  final Map<String, Object?> extraFrontmatter;

  static const Set<String> knownKeys = {
    'type',
    'split',
    'date',
    'time_started',
    'start_time',
    'date_logged',
    'duration_min',
    'total_volume_kg',
    'tss_score',
    'readiness_score',
    'tags',
  };

  /// Sum of `load x reps` over all sets. Warmups excluded by default. Pure
  /// bodyweight and hold sets contribute `0`; only added weight counts.
  double computedVolumeKg({bool includeWarmups = false}) => exercises.fold(
        0.0,
        (sum, e) => sum + e.volumeKg(includeWarmups: includeWarmups),
      );

  int get totalSets => exercises.fold(0, (n, e) => n + e.sets.length);

  WorkoutSession copyWith({
    String? type,
    String? split,
    DateTime? date,
    String? timeStarted,
    DateTime? startTime,
    DateTime? dateLogged,
    double? durationMin,
    double? totalVolumeKg,
    int? tssScore,
    int? readinessScore,
    List<String>? tags,
    String? title,
    List<ExerciseEntry>? exercises,
    String? preamble,
    Map<String, Object?>? extraFrontmatter,
  }) {
    return WorkoutSession(
      type: type ?? this.type,
      split: split ?? this.split,
      date: date ?? this.date,
      timeStarted: timeStarted ?? this.timeStarted,
      startTime: startTime ?? this.startTime,
      dateLogged: dateLogged ?? this.dateLogged,
      durationMin: durationMin ?? this.durationMin,
      totalVolumeKg: totalVolumeKg ?? this.totalVolumeKg,
      tssScore: tssScore ?? this.tssScore,
      readinessScore: readinessScore ?? this.readinessScore,
      tags: tags ?? this.tags,
      title: title ?? this.title,
      exercises: exercises ?? this.exercises,
      preamble: preamble ?? this.preamble,
      extraFrontmatter: extraFrontmatter ?? this.extraFrontmatter,
    );
  }

  /// Ordered map matching schema key order. `date` is a [DateTime] so the
  /// codec can emit it as an unquoted YAML date; strings are quoted by the codec.
  /// `start_time` / `date_logged` are written as UTC `...Z` strings (second
  /// precision) and omitted when null.
  Map<String, Object?> toFrontmatter() {
    return <String, Object?>{
      'type': type,
      'split': split,
      'date': date,
      'time_started': timeStarted,
      if (startTime != null) 'start_time': formatUtcTimestamp(startTime!),
      if (dateLogged != null) 'date_logged': formatUtcTimestamp(dateLogged!),
      'duration_min': durationMin,
      if (totalVolumeKg != null) 'total_volume_kg': totalVolumeKg,
      if (tssScore != null) 'tss_score': tssScore,
      if (readinessScore != null) 'readiness_score': readinessScore,
      if (tags.isNotEmpty) 'tags': tags,
      ...extraFrontmatter,
    };
  }

  /// Builds a session from parsed frontmatter plus already-parsed body parts.
  factory WorkoutSession.fromFrontmatter(
    Map<String, Object?> fm, {
    String title = '',
    String preamble = '',
    List<ExerciseEntry> exercises = const [],
  }) {
    return WorkoutSession(
      type: coerceString(fm['type']) ?? 'strength',
      split: coerceString(fm['split']) ?? '',
      date: coerceDate(fm['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      timeStarted: coerceString(fm['time_started']) ?? '00:00',
      startTime: coerceUtcTimestamp(fm['start_time']),
      dateLogged: coerceUtcTimestamp(fm['date_logged']),
      durationMin: coerceDouble(fm['duration_min']) ?? 0,
      totalVolumeKg: coerceDouble(fm['total_volume_kg']),
      tssScore: coerceInt(fm['tss_score']),
      readinessScore: coerceInt(fm['readiness_score']),
      tags: coerceStringList(fm['tags']),
      title: title,
      exercises: exercises,
      preamble: preamble,
      extraFrontmatter: extractExtras(fm, knownKeys),
    );
  }

  @override
  String toString() =>
      'WorkoutSession($split, ${formatIsoDate(date)} $timeStarted, '
      '${exercises.length} exercises)';
}
