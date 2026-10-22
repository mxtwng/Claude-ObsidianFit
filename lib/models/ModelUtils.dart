/// Shared coercion + formatting helpers for the Markdown <-> Dart round trip.
///
/// YAML scalars arrive loosely typed (`52` may be int, `45.2` double, dates may
/// be String or DateTime depending on the parser), so every model reads its
/// frontmatter through these helpers instead of casting directly.
library;

String? coerceString(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s;
}

int? coerceInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString().trim());
}

double? coerceDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}

/// Returns a date-only [DateTime] (local midnight) from a DateTime or an
/// ISO-8601 `yyyy-MM-dd` string.
DateTime? coerceDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return DateTime(v.year, v.month, v.day);
  final parsed = DateTime.tryParse(v.toString().trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

List<String> coerceStringList(Object? v) {
  if (v == null) return const [];
  if (v is Iterable) return v.map((e) => e.toString()).toList(growable: false);
  return [v.toString()];
}

/// `yyyy-MM-dd`
String formatIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Formats a number without a trailing `.0` for whole values
/// (`80.0` -> `80`, `82.5` -> `82.5`). Keeps `52` / `45.2` lossless.
String formatDecimal(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// Copies [source] without the [knownKeys]; used to preserve unknown
/// frontmatter keys so user-added fields survive a round trip.
Map<String, Object?> extractExtras(
  Map<String, Object?> source,
  Set<String> knownKeys,
) {
  return {
    for (final e in source.entries)
      if (!knownKeys.contains(e.key)) e.key: e.value,
  };
}
