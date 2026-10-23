/// Markdown form of the split table stored in an activity note, and the parser
/// that turns it back into GUI rows (pure Dart, no IO).
///
/// The user never sees this Markdown: the app writes it so the note stays
/// readable in Obsidian, and `SplitsTable` renders the parsed rows as a native
/// widget. Layout (header cells follow the unit):
///
/// ```text
/// ## Splits
///
/// | Km | Time | Pace /km | Gain (m) | Net (m) | HR |
/// |---:|---:|---:|---:|---:|---:|
/// | 1 | 5:12 | 5:12 | 4 | +2 | 150 |
/// | 2 (0.42) | 2:10 | 5:10 | 0 | -1 | -- |
/// ```
///
/// A partial last split shows its length in the unit, in brackets. `--` means
/// "no data" (no elevation or no heart rate).
library;

import 'activity_metrics.dart';
import 'splits_service.dart';

Duration _wholeSeconds(Duration d) =>
    Duration(seconds: (d.inMilliseconds / 1000).round());

/// One row of the split table in display form.
class SplitRow {
  const SplitRow({
    required this.number,
    required this.duration,
    this.paceSecPerUnit,
    this.partialDistance,
    this.gainM,
    this.netM,
    this.avgHr,
  });

  /// Display row for a freshly computed [Split]. Times are rounded to whole
  /// seconds, which is what the Markdown table stores.
  factory SplitRow.fromSplit(Split split, SplitUnit unit) {
    final hasElevation = split.elevationDeltaM != null;
    return SplitRow(
      number: split.index,
      duration: _wholeSeconds(split.duration),
      paceSecPerUnit: split.paceSecPer(unit),
      partialDistance: split.partial ? split.distanceM / unit.meters : null,
      gainM: hasElevation ? split.elevationGainM?.round() : null,
      netM: split.elevationDeltaM?.round(),
      avgHr: split.avgHr,
    );
  }

  /// 1-based lap number.
  final int number;
  final Duration duration;

  /// Seconds per unit, null when the table said `--`.
  final double? paceSecPerUnit;

  /// Length of a partial last split in the table unit; null for full splits.
  final double? partialDistance;
  final int? gainM;

  /// Net elevation change in metres (end minus start).
  final int? netM;
  final int? avgHr;

  bool get isPartial => partialDistance != null;

  /// [paceSecPerUnit], or derived from [duration] and the split length.
  double get effectivePaceSecPerUnit {
    final p = paceSecPerUnit;
    if (p != null) return p;
    final d = partialDistance ?? 1.0;
    return d <= 0 ? 0 : duration.inSeconds / d;
  }
}

/// A note body split into the user's own notes and the parsed split table.
class SplitsExtract {
  const SplitsExtract({
    required this.notes,
    this.unit,
    this.rows = const [],
  });

  /// Everything except the split table, with blank lines trimmed.
  final String notes;

  /// Unit named by the table's first header cell; null without a table.
  final SplitUnit? unit;
  final List<SplitRow> rows;

  bool get hasSplits => rows.isNotEmpty;
}

class SplitsMarkdown {
  const SplitsMarkdown._();

  static const String heading = '## Splits';
  static const String _missing = '--';

  /// The split section, or an empty string for an empty list. No trailing
  /// newline.
  static String render(List<Split> splits, SplitUnit unit) {
    if (splits.isEmpty) return '';
    final b = StringBuffer()
      ..writeln(heading)
      ..writeln()
      ..writeln(
        '| ${unit.heading} | Time | Pace /${unit.short} | Gain (m) | '
        'Net (m) | HR |',
      )
      ..writeln('|---:|---:|---:|---:|---:|---:|');
    for (final split in splits) {
      b.writeln(_row(SplitRow.fromSplit(split, unit)));
    }
    return b.toString().trimRight();
  }

  /// [body] followed by the split section, separated by a blank line. Returns
  /// [body] unchanged when there are no splits.
  static String append(String body, List<Split> splits, SplitUnit unit) {
    final table = render(splits, unit);
    if (table.isEmpty) return body;
    final trimmed = body.trim();
    return trimmed.isEmpty ? table : '$trimmed\n\n$table';
  }

  /// Separates the split table from the rest of [bodyText]. A body without a
  /// well-formed table comes back untouched in [SplitsExtract.notes].
  static SplitsExtract extract(String bodyText) {
    final lines = bodyText.split('\n');
    final start = lines.indexWhere(
      (l) => l.trim().toLowerCase() == heading.toLowerCase(),
    );
    if (start < 0) return SplitsExtract(notes: bodyText);

    var i = start + 1;
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    final tableStart = i;
    while (i < lines.length && lines[i].trim().startsWith('|')) {
      i++;
    }
    final table = lines.sublist(tableStart, i);
    if (table.length < 3) return SplitsExtract(notes: bodyText);

    final unit = SplitUnit.fromHeading(_cells(table.first).first);
    if (unit == null) return SplitsExtract(notes: bodyText);

    final rows = <SplitRow>[];
    for (final line in table.skip(2)) {
      final row = _parseRow(_cells(line));
      if (row != null) rows.add(row);
    }

    final before = _trimBlank(lines.sublist(0, start));
    final after = _trimBlank(lines.sublist(i));
    final notes = [before, after].where((s) => s.isNotEmpty).join('\n\n');
    return SplitsExtract(notes: notes, unit: unit, rows: rows);
  }

  // ---- rendering helpers ----------------------------------------------------

  static String _row(SplitRow r) {
    final label = r.isPartial
        ? '${r.number} (${r.partialDistance!.toStringAsFixed(2)})'
        : '${r.number}';
    final pace = formatPace(r.paceSecPerUnit) ?? _missing;
    return '| $label | ${formatDuration(r.duration)} | $pace | '
        '${_plain(r.gainM)} | ${_signed(r.netM)} | ${_plain(r.avgHr)} |';
  }

  static String _plain(int? v) => v == null ? _missing : '$v';

  static String _signed(int? v) =>
      v == null ? _missing : (v > 0 ? '+$v' : '$v');

  // ---- parsing helpers ------------------------------------------------------

  static final RegExp _label =
      RegExp(r'^(\d+)(?:\s*\(\s*(\d+(?:\.\d+)?)\s*\))?$');

  static List<String> _cells(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s.split('|').map((c) => c.trim()).toList();
  }

  static SplitRow? _parseRow(List<String> c) {
    if (c.length < 6) return null;
    final label = _label.firstMatch(c[0]);
    if (label == null) return null;
    final number = int.tryParse(label.group(1)!);
    final duration = _parseDuration(c[1]);
    if (number == null || duration == null) return null;
    return SplitRow(
      number: number,
      duration: duration,
      paceSecPerUnit: _parseDuration(c[2])?.inSeconds.toDouble(),
      partialDistance: double.tryParse(label.group(2) ?? ''),
      gainM: int.tryParse(c[3]),
      netM: int.tryParse(c[4]),
      avgHr: int.tryParse(c[5]),
    );
  }

  /// `m:ss` or `h:mm:ss`; null for `--` and anything else.
  static Duration? _parseDuration(String text) {
    final parts = text.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final n = [for (final p in parts) int.tryParse(p)];
    if (n.any((v) => v == null)) return null;
    return parts.length == 2
        ? Duration(minutes: n[0]!, seconds: n[1]!)
        : Duration(hours: n[0]!, minutes: n[1]!, seconds: n[2]!);
  }

  static String _trimBlank(List<String> lines) {
    var start = 0;
    var end = lines.length;
    while (start < end && lines[start].trim().isEmpty) {
      start++;
    }
    while (end > start && lines[end - 1].trim().isEmpty) {
      end--;
    }
    return lines.sublist(start, end).join('\n');
  }
}
