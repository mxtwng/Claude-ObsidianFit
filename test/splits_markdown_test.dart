import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/services/splits_markdown.dart';
import 'package:obsidian_fit/services/splits_service.dart';

import 'support/track_fixtures.dart';

/// Phase 6: the Markdown split table stored in an activity note, and the
/// parser that turns it back into rows for the native table widget.
void main() {
  // 1 km in 5:12 with a 4 m climb, then a 420 m remainder in 2:10.
  const fullKm = Split(
    index: 1,
    distanceM: 1000,
    duration: Duration(minutes: 5, seconds: 12),
    elevationDeltaM: 2.4,
    elevationGainM: 4.0,
    avgHr: 150,
  );
  const partial = Split(
    index: 2,
    distanceM: 420,
    duration: Duration(minutes: 2, seconds: 10),
    elevationDeltaM: -1.0,
    elevationGainM: 0.0,
    partial: true,
  );

  const kmTable = '## Splits\n'
      '\n'
      '| Km | Time | Pace /km | Gain (m) | Net (m) | HR |\n'
      '|---:|---:|---:|---:|---:|---:|\n'
      '| 1 | 5:12 | 5:12 | 4 | +2 | 150 |\n'
      '| 2 (0.42) | 2:10 | 5:10 | 0 | -1 | -- |';

  group('SplitUnit.fromHeading', () {
    test('reads the table heading and the short name, any case', () {
      expect(SplitUnit.fromHeading('Km'), SplitUnit.km);
      expect(SplitUnit.fromHeading('km'), SplitUnit.km);
      expect(SplitUnit.fromHeading(' KM '), SplitUnit.km);
      expect(SplitUnit.fromHeading('Mile'), SplitUnit.mi);
      expect(SplitUnit.fromHeading('mi'), SplitUnit.mi);
    });

    test('unknown text gives null', () {
      expect(SplitUnit.fromHeading('Furlong'), isNull);
      expect(SplitUnit.fromHeading(''), isNull);
    });
  });

  group('SplitsMarkdown.render', () {
    test('an empty list renders nothing', () {
      expect(SplitsMarkdown.render(const [], SplitUnit.km), '');
    });

    test('km table: header, alignment row, full and partial rows', () {
      expect(
        SplitsMarkdown.render(const [fullKm, partial], SplitUnit.km),
        kmTable,
      );
    });

    test('the output has no trailing newline', () {
      final out = SplitsMarkdown.render(const [fullKm], SplitUnit.km);
      expect(out.endsWith('\n'), isFalse);
    });

    test('mile table: the header and the pace label follow the unit', () {
      const mile = Split(
        index: 1,
        distanceM: 1609.344,
        duration: Duration(minutes: 8, seconds: 30),
      );
      final lines =
          SplitsMarkdown.render(const [mile], SplitUnit.mi).split('\n');
      expect(
        lines[2],
        '| Mile | Time | Pace /mi | Gain (m) | Net (m) | HR |',
      );
      expect(lines[4], startsWith('| 1 | 8:30 | 8:30 |'));
    });

    test('missing elevation and heart rate are written as --', () {
      const bare = Split(
        index: 3,
        distanceM: 1000,
        duration: Duration(minutes: 4, seconds: 59),
      );
      final row =
          SplitsMarkdown.render(const [bare], SplitUnit.km).split('\n').last;
      expect(row, '| 3 | 4:59 | 4:59 | -- | -- | -- |');
    });

    test('net elevation is signed: +, -, and a bare 0', () {
      Split withNet(double net) => Split(
            index: 1,
            distanceM: 1000,
            duration: const Duration(minutes: 5),
            elevationDeltaM: net,
            elevationGainM: 0,
          );
      String netCell(double net) => SplitsMarkdown.render(
            [withNet(net)],
            SplitUnit.km,
          ).split('\n').last.split('|')[5].trim();

      expect(netCell(7.4), '+7');
      expect(netCell(-3.6), '-4');
      expect(netCell(0), '0');
    });

    test('a split over an hour uses h:mm:ss for the time', () {
      const slow = Split(
        index: 1,
        distanceM: 1000,
        duration: Duration(hours: 1, minutes: 5, seconds: 3),
      );
      final row =
          SplitsMarkdown.render(const [slow], SplitUnit.km).split('\n').last;
      expect(row, startsWith('| 1 | 1:05:03 |'));
    });
  });

  group('SplitRow.fromSplit', () {
    test('times are rounded to whole seconds, like the table', () {
      const split = Split(
        index: 1,
        distanceM: 1000,
        duration: Duration(milliseconds: 312600),
      );
      final row = SplitRow.fromSplit(split, SplitUnit.km);
      expect(row.duration, const Duration(seconds: 313));
    });

    test('a full split has no partial distance; a partial one has', () {
      final full = SplitRow.fromSplit(fullKm, SplitUnit.km);
      final short = SplitRow.fromSplit(partial, SplitUnit.km);
      expect(full.isPartial, isFalse);
      expect(full.partialDistance, isNull);
      expect(short.isPartial, isTrue);
      expect(short.partialDistance, closeTo(0.42, 1e-9));
    });

    test('elevation cells are blank without elevation data', () {
      const noEle = Split(
        index: 1,
        distanceM: 1000,
        duration: Duration(minutes: 5),
        elevationGainM: 0,
      );
      final row = SplitRow.fromSplit(noEle, SplitUnit.km);
      expect(row.gainM, isNull);
      expect(row.netM, isNull);
    });

    test('effectivePaceSecPerUnit falls back to time over distance', () {
      const row = SplitRow(
        number: 2,
        duration: Duration(minutes: 2, seconds: 10),
        partialDistance: 0.5,
      );
      expect(row.effectivePaceSecPerUnit, closeTo(260, 1e-9));
      const stated = SplitRow(
        number: 1,
        duration: Duration(minutes: 5),
        paceSecPerUnit: 301,
      );
      expect(stated.effectivePaceSecPerUnit, 301);
    });
  });

  group('SplitsMarkdown.append', () {
    test('adds the table after the notes, separated by a blank line', () {
      expect(
        SplitsMarkdown.append(
          '- Felt strong on the hill.',
          const [fullKm, partial],
          SplitUnit.km,
        ),
        '- Felt strong on the hill.\n\n$kmTable',
      );
    });

    test('empty notes give just the table', () {
      expect(
        SplitsMarkdown.append('', const [fullKm, partial], SplitUnit.km),
        kmTable,
      );
      expect(
        SplitsMarkdown.append('  \n ', const [fullKm, partial], SplitUnit.km),
        kmTable,
      );
    });

    test('surrounding blank lines of the notes are trimmed', () {
      expect(
        SplitsMarkdown.append('\n- Note\n\n', const [fullKm], SplitUnit.km),
        startsWith('- Note\n\n## Splits'),
      );
    });

    test('no splits leaves the body untouched', () {
      expect(SplitsMarkdown.append('- Note\n', const [], SplitUnit.km),
          '- Note\n');
      expect(SplitsMarkdown.append('', const [], SplitUnit.km), '');
    });
  });

  group('SplitsMarkdown.extract', () {
    test('parses the rendered table back into rows', () {
      final out = SplitsMarkdown.extract(kmTable);
      expect(out.hasSplits, isTrue);
      expect(out.unit, SplitUnit.km);
      expect(out.notes, '');
      expect(out.rows, hasLength(2));

      final a = out.rows[0];
      expect(a.number, 1);
      expect(a.duration, const Duration(minutes: 5, seconds: 12));
      expect(a.paceSecPerUnit, 312);
      expect(a.isPartial, isFalse);
      expect(a.gainM, 4);
      expect(a.netM, 2); // "+2"
      expect(a.avgHr, 150);

      final b = out.rows[1];
      expect(b.number, 2);
      expect(b.duration, const Duration(minutes: 2, seconds: 10));
      expect(b.paceSecPerUnit, 310);
      expect(b.isPartial, isTrue);
      expect(b.partialDistance, closeTo(0.42, 1e-9));
      expect(b.gainM, 0);
      expect(b.netM, -1);
      expect(b.avgHr, isNull); // "--"
    });

    test('append then extract returns the notes and the table separately', () {
      final body = SplitsMarkdown.append(
        '- Felt strong on the hill.\n- Cadence 175.',
        const [fullKm, partial],
        SplitUnit.km,
      );
      final out = SplitsMarkdown.extract(body);
      expect(out.notes, '- Felt strong on the hill.\n- Cadence 175.');
      expect(out.rows, hasLength(2));
      expect(out.unit, SplitUnit.km);
    });

    test('a mile table is recognised from its first header cell', () {
      const mile = Split(
        index: 1,
        distanceM: 1609.344,
        duration: Duration(minutes: 8, seconds: 30),
      );
      final out = SplitsMarkdown.extract(
        SplitsMarkdown.render(const [mile], SplitUnit.mi),
      );
      expect(out.unit, SplitUnit.mi);
      expect(out.rows.single.duration, const Duration(minutes: 8, seconds: 30));
      expect(out.rows.single.paceSecPerUnit, 510);
    });

    test('text before and after the table is kept as notes', () {
      final out =
          SplitsMarkdown.extract('Intro line\n\n$kmTable\n\nOutro line');
      expect(out.notes, 'Intro line\n\nOutro line');
      expect(out.rows, hasLength(2));
    });

    test('the heading match ignores case', () {
      final out = SplitsMarkdown.extract(
          kmTable.replaceFirst('## Splits', '## SPLITS'));
      expect(out.rows, hasLength(2));
    });

    test('rows that are not splits are skipped, the rest are kept', () {
      const body = '## Splits\n'
          '\n'
          '| Km | Time | Pace /km | Gain (m) | Net (m) | HR |\n'
          '|---:|---:|---:|---:|---:|---:|\n'
          '| 1 | 5:12 | 5:12 | 4 | +2 | 150 |\n'
          '| garbage | row |\n'
          '| 2 | 5:00 | 5:00 | -- | -- | -- |';
      final out = SplitsMarkdown.extract(body);
      expect(out.rows.map((r) => r.number), [1, 2]);
      final second = out.rows[1];
      expect(second.gainM, isNull);
      expect(second.netM, isNull);
      expect(second.avgHr, isNull);
      expect(second.paceSecPerUnit, 300);
    });

    test('an hour-long split parses h:mm:ss', () {
      const body = '## Splits\n'
          '\n'
          '| Km | Time | Pace /km | Gain (m) | Net (m) | HR |\n'
          '|---:|---:|---:|---:|---:|---:|\n'
          '| 1 | 1:05:03 | 65:03 | -- | -- | -- |';
      final row = SplitsMarkdown.extract(body).rows.single;
      expect(row.duration, const Duration(hours: 1, minutes: 5, seconds: 3));
      expect(row.paceSecPerUnit, 3903);
    });

    test('a body without a table comes back untouched', () {
      const body = '- Felt strong.\n- Cadence 175.';
      final out = SplitsMarkdown.extract(body);
      expect(out.notes, body);
      expect(out.hasSplits, isFalse);
      expect(out.unit, isNull);
      expect(out.rows, isEmpty);
    });

    test('a heading with no table below it comes back untouched', () {
      const body = '## Splits\n\nnothing here';
      final out = SplitsMarkdown.extract(body);
      expect(out.notes, body);
      expect(out.hasSplits, isFalse);
    });

    test('a table with an unknown unit comes back untouched', () {
      const body = '## Splits\n'
          '\n'
          '| Furlong | Time | Pace | Gain (m) | Net (m) | HR |\n'
          '|---:|---:|---:|---:|---:|---:|\n'
          '| 1 | 5:12 | 5:12 | 4 | +2 | 150 |';
      final out = SplitsMarkdown.extract(body);
      expect(out.notes, body);
      expect(out.hasSplits, isFalse);
    });
  });

  group('from a recorded track', () {
    test('2.5 km at 5:00 /km gives two full splits and a 0.50 remainder', () {
      final splits = SplitCalculator.compute([
        steadySegment(steps: 250),
      ]);
      expect(splits, hasLength(3));
      expect(splits.map((s) => s.partial), [false, false, true]);

      expect(
        SplitsMarkdown.render(splits, SplitUnit.km),
        '## Splits\n'
        '\n'
        '| Km | Time | Pace /km | Gain (m) | Net (m) | HR |\n'
        '|---:|---:|---:|---:|---:|---:|\n'
        '| 1 | 5:00 | 5:00 | -- | -- | -- |\n'
        '| 2 | 5:00 | 5:00 | -- | -- | -- |\n'
        '| 3 (0.50) | 2:30 | 5:00 | -- | -- | -- |',
      );
    });

    test('elevation and heart rate flow into the table', () {
      // Climbs 1 m per 10 m step (100 m per km), heart rate fixed at 150.
      final splits = SplitCalculator.compute([
        steadySegment(
          steps: 200,
          ele: (i) => 100.0 + i,
          hr: (_) => 150,
        ),
      ]);
      final rows = SplitsMarkdown.extract(
        SplitsMarkdown.render(splits, SplitUnit.km),
      ).rows;

      expect(rows, hasLength(2));
      for (final r in rows) {
        expect(r.avgHr, 150);
        expect(r.netM, closeTo(100, 1));
        expect(r.gainM, closeTo(100, 5));
      }
    });
  });
}
