import 'ModelUtils.dart';

/// A GPS or manual (non-GPS) cardio activity. Mirrors
/// `schemas/activity_schema.md` plus the Phase 5 extensions in
/// `schemas/activity_schema.phase5.md`.
class ActivitySession {
  const ActivitySession({
    this.type = 'activity',
    required this.category,
    required this.date,
    required this.timeStarted,
    this.startTime,
    this.dateLogged,
    this.durationSeconds,
    required this.durationMin,
    this.distanceKm,
    this.elevationGainM,
    this.avgHr,
    this.maxHr,
    this.rpe,
    this.avgPaceMinKm,
    this.tssScore,
    this.gpxFileName,
    this.tags = const [],
    this.title = '',
    this.bodyText = '',
    this.extraFrontmatter = const {},
  });

  /// Frontmatter `type` (`activity`).
  final String type;

  /// e.g. `run`, `ride`, `walk`.
  final String category;
  final DateTime date;

  /// `HH:mm` (24h) kept as a string for lossless round trip.
  final String timeStarted;

  /// When the activity actually began (UTC, second precision). Null on legacy
  /// and GPS notes, which fall back to [date] + [timeStarted].
  final DateTime? startTime;

  /// When the note was written (UTC, second precision). Set once at creation.
  final DateTime? dateLogged;

  /// Canonical moving time in whole seconds for manual entries. Null for GPS
  /// activities, which only carry [durationMin]. On a mismatch this wins.
  final int? durationSeconds;
  final double durationMin;
  final double? distanceKm;
  final double? elevationGainM;
  final int? avgHr;
  final int? maxHr;

  /// Session RPE, 1 (very easy) to 10 (maximal); halves allowed (`7.5`).
  final double? rpe;

  /// `m:ss` per km, kept as the original string (e.g. `"6:02"`).
  final String? avgPaceMinKm;
  final int? tssScore;

  /// Bare GPX target extracted from the `gpx_file` wikilink,
  /// e.g. `2026-10-22_1730_Route.gpx`. Null for manual (non-GPS) activities,
  /// where the key is omitted (or `null` / `""` / `"[[]]"` when read).
  final String? gpxFileName;
  final List<String> tags;

  /// The `# H1` heading text.
  final String title;

  /// Everything after the H1 (user notes), trimmed of surrounding blank lines.
  final String bodyText;

  /// Unknown frontmatter keys, preserved verbatim.
  final Map<String, Object?> extraFrontmatter;

  static const Set<String> knownKeys = {
    'type',
    'category',
    'date',
    'time_started',
    'start_time',
    'date_logged',
    'duration_seconds',
    'duration_min',
    'distance_km',
    'elevation_gain_m',
    'avg_hr',
    'max_hr',
    'rpe',
    'avg_pace_min_km',
    'tss_score',
    'gpx_file',
    'tags',
  };

  static final RegExp _wikilink =
      RegExp(r'\[\[\s*([^\]|#]+?)\s*(?:[#|][^\]]*)?\]\]');

  /// `"[[Route.gpx]]"` -> `Route.gpx`. Also accepts a bare filename.
  /// Returns null when there is no track: null, empty or blank input, and an
  /// empty link such as `"[[]]"` or `"[[  ]]"`.
  static String? extractWikilinkTarget(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = _wikilink.firstMatch(s);
    if (m != null) {
      final target = m.group(1)?.trim();
      return (target == null || target.isEmpty) ? null : target;
    }
    // A link with no usable target (`[[]]`) is "no track", not a file name.
    if (s.startsWith('[[')) return null;
    return s;
  }

  /// `Route.gpx` -> `[[Route.gpx]]`.
  static String toWikilink(String fileName) => '[[$fileName]]';

  /// Duration in whole seconds: [durationSeconds] when present, otherwise
  /// derived from [durationMin].
  int get effectiveDurationSeconds =>
      durationSeconds ?? (durationMin * 60).round();

  /// Average pace derived from distance and duration, formatted `m:ss`.
  /// Null if distance is missing or zero.
  String? get computedPaceMinKm {
    final d = distanceKm;
    if (d == null || d <= 0) return null;
    final totalSeconds = (effectiveDurationSeconds / d).round();
    final m = totalSeconds ~/ 60;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  ActivitySession copyWith({
    String? type,
    String? category,
    DateTime? date,
    String? timeStarted,
    DateTime? startTime,
    DateTime? dateLogged,
    int? durationSeconds,
    double? durationMin,
    double? distanceKm,
    double? elevationGainM,
    int? avgHr,
    int? maxHr,
    double? rpe,
    String? avgPaceMinKm,
    int? tssScore,
    String? gpxFileName,
    bool clearGpx = false,
    List<String>? tags,
    String? title,
    String? bodyText,
    Map<String, Object?>? extraFrontmatter,
  }) {
    return ActivitySession(
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      timeStarted: timeStarted ?? this.timeStarted,
      startTime: startTime ?? this.startTime,
      dateLogged: dateLogged ?? this.dateLogged,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      durationMin: durationMin ?? this.durationMin,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      avgHr: avgHr ?? this.avgHr,
      maxHr: maxHr ?? this.maxHr,
      rpe: rpe ?? this.rpe,
      avgPaceMinKm: avgPaceMinKm ?? this.avgPaceMinKm,
      tssScore: tssScore ?? this.tssScore,
      gpxFileName: clearGpx ? null : (gpxFileName ?? this.gpxFileName),
      tags: tags ?? this.tags,
      title: title ?? this.title,
      bodyText: bodyText ?? this.bodyText,
      extraFrontmatter: extraFrontmatter ?? this.extraFrontmatter,
    );
  }

  /// Ordered map matching schema key order. `gpx_file` is re-wrapped as a
  /// wikilink and omitted when there is no track (never written as `"[[]]"`);
  /// `date` stays a [DateTime] for the codec to emit unquoted; `start_time` /
  /// `date_logged` are UTC `...Z` strings, omitted when null.
  Map<String, Object?> toFrontmatter() {
    final gpx = gpxFileName;
    return <String, Object?>{
      'type': type,
      'category': category,
      'date': date,
      'time_started': timeStarted,
      if (startTime != null) 'start_time': formatUtcTimestamp(startTime!),
      if (dateLogged != null) 'date_logged': formatUtcTimestamp(dateLogged!),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'duration_min': durationMin,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
      if (avgHr != null) 'avg_hr': avgHr,
      if (maxHr != null) 'max_hr': maxHr,
      if (rpe != null) 'rpe': rpe,
      if (avgPaceMinKm != null) 'avg_pace_min_km': avgPaceMinKm,
      if (tssScore != null) 'tss_score': tssScore,
      if (gpx != null && gpx.isNotEmpty) 'gpx_file': toWikilink(gpx),
      if (tags.isNotEmpty) 'tags': tags,
      ...extraFrontmatter,
    };
  }

  factory ActivitySession.fromFrontmatter(
    Map<String, Object?> fm, {
    String title = '',
    String bodyText = '',
  }) {
    return ActivitySession(
      type: coerceString(fm['type']) ?? 'activity',
      category: coerceString(fm['category']) ?? 'run',
      date: coerceDate(fm['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      timeStarted: coerceString(fm['time_started']) ?? '00:00',
      startTime: coerceUtcTimestamp(fm['start_time']),
      dateLogged: coerceUtcTimestamp(fm['date_logged']),
      durationSeconds: coerceInt(fm['duration_seconds']),
      durationMin: coerceDouble(fm['duration_min']) ?? 0,
      distanceKm: coerceDouble(fm['distance_km']),
      elevationGainM: coerceDouble(fm['elevation_gain_m']),
      avgHr: coerceInt(fm['avg_hr']),
      maxHr: coerceInt(fm['max_hr']),
      rpe: coerceDouble(fm['rpe']),
      avgPaceMinKm: coerceString(fm['avg_pace_min_km']),
      tssScore: coerceInt(fm['tss_score']),
      gpxFileName: extractWikilinkTarget(coerceString(fm['gpx_file'])),
      tags: coerceStringList(fm['tags']),
      title: title,
      bodyText: bodyText,
      extraFrontmatter: extractExtras(fm, knownKeys),
    );
  }

  @override
  String toString() =>
      'ActivitySession($category, ${formatIsoDate(date)} $timeStarted, '
      '${distanceKm ?? '?'} km)';
}
