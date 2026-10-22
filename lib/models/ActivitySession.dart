import 'ModelUtils.dart';

/// A GPS/cardio activity. Mirrors `schemas/activity_schema.md`.
class ActivitySession {
  const ActivitySession({
    this.type = 'activity',
    required this.category,
    required this.date,
    required this.timeStarted,
    required this.durationMin,
    this.distanceKm,
    this.elevationGainM,
    this.avgHr,
    this.maxHr,
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
  final double durationMin;
  final double? distanceKm;
  final double? elevationGainM;
  final int? avgHr;
  final int? maxHr;

  /// `m:ss` per km, kept as the original string (e.g. `"6:02"`).
  final String? avgPaceMinKm;
  final int? tssScore;

  /// Bare GPX target extracted from the `gpx_file` wikilink,
  /// e.g. `2026-10-22_1730_Route.gpx`.
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
    'duration_min',
    'distance_km',
    'elevation_gain_m',
    'avg_hr',
    'max_hr',
    'avg_pace_min_km',
    'tss_score',
    'gpx_file',
    'tags',
  };

  static final RegExp _wikilink = RegExp(r'\[\[\s*([^\]|#]+?)\s*(?:[#|][^\]]*)?\]\]');

  /// `"[[Route.gpx]]"` -> `Route.gpx`. Also accepts a bare filename.
  /// Returns null for null/empty input.
  static String? extractWikilinkTarget(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = _wikilink.firstMatch(s);
    return m != null ? m.group(1) : s;
  }

  /// `Route.gpx` -> `[[Route.gpx]]`.
  static String toWikilink(String fileName) => '[[$fileName]]';

  /// Average pace derived from distance and duration, formatted `m:ss`.
  /// Null if distance is missing or zero.
  String? get computedPaceMinKm {
    final d = distanceKm;
    if (d == null || d <= 0) return null;
    final totalSeconds = (durationMin / d * 60).round();
    final m = totalSeconds ~/ 60;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  ActivitySession copyWith({
    String? type,
    String? category,
    DateTime? date,
    String? timeStarted,
    double? durationMin,
    double? distanceKm,
    double? elevationGainM,
    int? avgHr,
    int? maxHr,
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
      durationMin: durationMin ?? this.durationMin,
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      avgHr: avgHr ?? this.avgHr,
      maxHr: maxHr ?? this.maxHr,
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
  /// wikilink; `date` stays a [DateTime] for the codec to emit unquoted.
  Map<String, Object?> toFrontmatter() {
    return <String, Object?>{
      'type': type,
      'category': category,
      'date': date,
      'time_started': timeStarted,
      'duration_min': durationMin,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
      if (avgHr != null) 'avg_hr': avgHr,
      if (maxHr != null) 'max_hr': maxHr,
      if (avgPaceMinKm != null) 'avg_pace_min_km': avgPaceMinKm,
      if (tssScore != null) 'tss_score': tssScore,
      if (gpxFileName != null) 'gpx_file': toWikilink(gpxFileName!),
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
      durationMin: coerceDouble(fm['duration_min']) ?? 0,
      distanceKm: coerceDouble(fm['distance_km']),
      elevationGainM: coerceDouble(fm['elevation_gain_m']),
      avgHr: coerceInt(fm['avg_hr']),
      maxHr: coerceInt(fm['max_hr']),
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
