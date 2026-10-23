/// Shared "when did this session physically happen" helper (pure Dart).
library;

/// The instant a session started.
///
/// [startTime] (the note's `start_time`, UTC) wins when present. Legacy notes
/// fall back to the local [date] combined with [timeStarted] (`HH:mm`,
/// device-local). Same rule as `SessionEntry.sortInstant` in the UI layer, so
/// "earliest holder of a record" and "newest first" agree.
DateTime sessionInstant({
  required DateTime date,
  required String timeStarted,
  DateTime? startTime,
}) {
  if (startTime != null) return startTime;
  final parts = timeStarted.split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, h, m);
}
