import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';

/// Phase 5A: pipe-syntax parsing, rendering and volume maths for every set
/// modality (weighted, bodyweight, isometric hold, plyometric).
/// Spec: schemas/workout_schema.phase5.md.
void main() {
  group('weighted lifts (Phase 1 compatibility)', () {
    const line = '- Set 1: 80kg x 8 reps | RPE 7.0 | Type: N';

    test('parses the Phase 1 line', () {
      final s = SetEntry.tryParseLine(line)!;
      expect(s.isBodyweight, isFalse);
      expect(s.weightKg, 80);
      expect(s.reps, 8);
      expect(s.rpe, 7.0);
      expect(s.type, SetType.normal);
      expect(s.extraWeightKg, isNull);
      expect(s.durationSeconds, isNull);
      expect(s.boxHeightCm, isNull);
      expect(s.contactTimeMs, isNull);
      expect(s.loadKg, 80);
      expect(s.isHold, isFalse);
    });

    test('renders the Phase 1 line unchanged', () {
      expect(SetEntry.tryParseLine(line)!.toMarkdownLine(1), line);
    });

    test('RPE and Type are optional on read; Type is always written', () {
      final s = SetEntry.tryParseLine('- Set 3: 82.5kg x 5 reps')!;
      expect(s.weightKg, 82.5);
      expect(s.reps, 5);
      expect(s.rpe, isNull);
      expect(s.type, SetType.normal);
      expect(s.toMarkdownLine(3), '- Set 3: 82.5kg x 5 reps | Type: N');
    });

    test('existing call sites (weightKg + reps only) still work', () {
      const s = SetEntry(weightKg: 100, reps: 5);
      expect(s.isBodyweight, isFalse);
      expect(s.computedVolumeKg, 500);
      expect(s.volumeKg, 500);
    });

    test('lines that are not sets return null', () {
      for (final l in const [
        '',
        '## Heading',
        'Felt strong today',
        '- Set one: 80kg x 8 reps',
        '- 80kg x 8 reps',
        '- Set 1:',
      ]) {
        expect(SetEntry.tryParseLine(l), isNull, reason: l);
      }
    });
  });

  group('bodyweight and weighted bodyweight', () {
    test('strict bodyweight: BW+0kg', () {
      final s = SetEntry.tryParseLine(
        '- Set 1: BW+0kg x 12 reps | RPE 7.0 | Type: N',
      )!;
      expect(s.isBodyweight, isTrue);
      expect(s.extraWeightKg, 0);
      expect(s.weightKg, 0);
      expect(s.reps, 12);
      expect(s.rpe, 7.0);
      expect(s.durationSeconds, isNull);
      expect(s.loadKg, 0);
      expect(s.computedVolumeKg, 0);
    });

    test('weighted bodyweight: BW+10kg', () {
      final s = SetEntry.tryParseLine(
        '- Set 2: BW+10kg x 6 reps | RPE 8.5 | Type: N',
      )!;
      expect(s.isBodyweight, isTrue);
      expect(s.extraWeightKg, 10);
      expect(s.reps, 6);
      expect(s.rpe, 8.5);
      expect(s.type, SetType.normal);
      expect(s.loadKg, 10);
      expect(s.computedVolumeKg, 60);
    });

    test('decimal added weight survives', () {
      final s = SetEntry.tryParseLine('- Set 1: BW+2.5kg x 8 reps | Type: D')!;
      expect(s.extraWeightKg, 2.5);
      expect(s.type, SetType.drop);
      expect(s.computedVolumeKg, 20);
      expect(s.toMarkdownLine(1), '- Set 1: BW+2.5kg x 8 reps | Type: D');
    });

    test('bare BW is read as BW+0kg and written as BW+0kg', () {
      final s = SetEntry.tryParseLine('- Set 1: BW x 12 reps | Type: N')!;
      expect(s.isBodyweight, isTrue);
      expect(s.extraWeightKg, 0);
      expect(s.toMarkdownLine(1), '- Set 1: BW+0kg x 12 reps | Type: N');
    });

    test('a null extraWeightKg is written as BW+0kg', () {
      const s = SetEntry(isBodyweight: true, reps: 10);
      expect(s.toMarkdownLine(1), '- Set 1: BW+0kg x 10 reps | Type: N');
    });
  });

  group('isometric holds', () {
    test('parses Hold: <s>s with no reps', () {
      final s = SetEntry.tryParseLine(
        '- Set 1: BW+0kg | Hold: 60s | RPE 8.0 | Type: N',
      )!;
      expect(s.isBodyweight, isTrue);
      expect(s.extraWeightKg, 0);
      expect(s.reps, isNull);
      expect(s.durationSeconds, 60);
      expect(s.isHold, isTrue);
      expect(s.rpe, 8.0);
      expect(s.type, SetType.normal);
    });

    test('hold without RPE', () {
      final s = SetEntry.tryParseLine('- Set 1: BW+0kg | Hold: 20s | Type: N')!;
      expect(s.durationSeconds, 20);
      expect(s.rpe, isNull);
      expect(s.toMarkdownLine(1), '- Set 1: BW+0kg | Hold: 20s | Type: N');
    });

    test('weighted hold keeps its added weight', () {
      final s = SetEntry.tryParseLine(
        '- Set 1: BW+10kg | Hold: 30s | RPE 8.0 | Type: N',
      )!;
      expect(s.extraWeightKg, 10);
      expect(s.durationSeconds, 30);
      expect(s.reps, isNull);
    });

    test('hold sets contribute 0 volume, weighted or not', () {
      final plain = SetEntry.tryParseLine('- Set 1: BW+0kg | Hold: 60s')!;
      final loaded = SetEntry.tryParseLine('- Set 1: BW+10kg | Hold: 30s')!;
      expect(plain.computedVolumeKg, 0);
      expect(loaded.computedVolumeKg, 0);
    });
  });

  group('plyometrics', () {
    test('box height and contact time', () {
      final s = SetEntry.tryParseLine(
        '- Set 1: BW+0kg x 5 reps | Box: 60cm | Contact: 210ms | Type: N',
      )!;
      expect(s.isBodyweight, isTrue);
      expect(s.reps, 5);
      expect(s.boxHeightCm, 60);
      expect(s.contactTimeMs, 210);
      expect(s.rpe, isNull);
      expect(s.computedVolumeKg, 0);
    });

    test('Box and Contact are independent and optional', () {
      final boxOnly = SetEntry.tryParseLine(
        '- Set 3: BW+0kg x 3 reps | Box: 52.5cm | Type: N',
      )!;
      expect(boxOnly.boxHeightCm, 52.5);
      expect(boxOnly.contactTimeMs, isNull);

      final contactOnly = SetEntry.tryParseLine(
        '- Set 2: BW+0kg x 6 reps | Contact: 180ms | Type: N',
      )!;
      expect(contactOnly.boxHeightCm, isNull);
      expect(contactOnly.contactTimeMs, 180);
    });

    test('loaded plyometric counts added weight x reps', () {
      final s = SetEntry.tryParseLine('- Set 1: BW+20kg x 5 reps | Type: N')!;
      expect(s.computedVolumeKg, 100);
    });

    test('the reader accepts any segment order, the writer is canonical', () {
      // Spec example 3.3 writes RPE after Contact; the grammar puts it first.
      const loose =
          '- Set 2: BW+0kg x 5 reps | Box: 70cm | Contact: 195ms | RPE 8.0 | Type: N';
      const canonical =
          '- Set 2: BW+0kg x 5 reps | RPE 8.0 | Box: 70cm | Contact: 195ms | Type: N';
      final s = SetEntry.tryParseLine(loose)!;
      expect(s.rpe, 8.0);
      expect(s.boxHeightCm, 70);
      expect(s.contactTimeMs, 195);
      expect(s.toMarkdownLine(2), canonical);
      expect(SetEntry.tryParseLine(canonical), s);
    });
  });

  group('invalid set lines are left to the notes', () {
    test('reps and hold together', () {
      expect(
        SetEntry.tryParseLine('- Set 1: BW+0kg x 5 reps | Hold: 30s'),
        isNull,
      );
    });

    test('neither reps nor hold', () {
      expect(SetEntry.tryParseLine('- Set 1: BW+0kg | Type: N'), isNull);
      expect(SetEntry.tryParseLine('- Set 1: 80kg'), isNull);
    });

    test('unknown segment', () {
      expect(
        SetEntry.tryParseLine('- Set 1: 80kg x 8 reps | Tempo: 3010'),
        isNull,
      );
    });

    test('repeated segment', () {
      expect(
        SetEntry.tryParseLine('- Set 1: 80kg x 8 reps | RPE 7.0 | RPE 8.0'),
        isNull,
      );
    });

    test('malformed load', () {
      expect(SetEntry.tryParseLine('- Set 1: BW+kg x 8 reps'), isNull);
      expect(SetEntry.tryParseLine('- Set 1: heavy x 8 reps'), isNull);
    });
  });

  group('lossless line round trip', () {
    const canonicalLines = <String>[
      '- Set 1: 80kg x 8 reps | RPE 7.0 | Type: N',
      '- Set 4: 100kg x 3 reps | Box: 40cm | Type: W',
      '- Set 1: BW+0kg x 12 reps | RPE 7.0 | Type: N',
      '- Set 2: BW+10kg x 6 reps | RPE 8.5 | Type: N',
      '- Set 3: BW+10kg x 5 reps | RPE 9.5 | Type: F',
      '- Set 1: BW+2.5kg x 8 reps | Type: D',
      '- Set 1: BW+0kg | Hold: 60s | RPE 8.0 | Type: N',
      '- Set 1: BW+10kg | Hold: 30s | Type: F',
      '- Set 1: 20kg | Hold: 30s | Type: N',
      '- Set 1: BW+0kg x 5 reps | Box: 60cm | Contact: 210ms | Type: N',
      '- Set 2: BW+0kg x 5 reps | RPE 8.0 | Box: 70cm | Contact: 195ms | Type: N',
      '- Set 3: BW+0kg x 3 reps | Box: 52.5cm | Type: N',
      '- Set 2: BW+0kg x 6 reps | Contact: 180ms | Type: N',
    ];

    test('parse then render reproduces every canonical line', () {
      for (final line in canonicalLines) {
        final n = int.parse(RegExp(r'Set (\d+):').firstMatch(line)!.group(1)!);
        final s = SetEntry.tryParseLine(line);
        expect(s, isNotNull, reason: line);
        expect(s!.toMarkdownLine(n), line, reason: line);
        expect(SetEntry.tryParseLine(s.toMarkdownLine(n)), s, reason: line);
      }
    });
  });

  group('volume', () {
    test('only added weight counts: pull-up example totals 110 kg', () {
      const pullUps = ExerciseEntry(
        name: 'Pull-ups',
        sets: [
          SetEntry(
              isBodyweight: true,
              extraWeightKg: 0,
              reps: 10,
              type: SetType.warmup),
          SetEntry(isBodyweight: true, extraWeightKg: 10, reps: 6),
          SetEntry(
              isBodyweight: true,
              extraWeightKg: 10,
              reps: 5,
              type: SetType.failure),
        ],
      );
      expect(pullUps.volumeKg(), 110);
    });

    test('warmups are excluded unless requested', () {
      const e = ExerciseEntry(
        name: 'Pull-ups',
        sets: [
          SetEntry(
              isBodyweight: true,
              extraWeightKg: 5,
              reps: 10,
              type: SetType.warmup),
          SetEntry(isBodyweight: true, extraWeightKg: 10, reps: 6),
        ],
      );
      expect(e.volumeKg(), 60);
      expect(e.volumeKg(includeWarmups: true), 110);
    });

    test('external-load and bodyweight exercises add up in a session', () {
      final session = WorkoutSession(
        split: 'Mixed',
        date: DateTime(2026, 10, 20),
        timeStarted: '07:00',
        durationMin: 30,
        exercises: const [
          ExerciseEntry(name: 'Row', sets: [SetEntry(weightKg: 60, reps: 10)]),
          ExerciseEntry(
            name: 'Weighted Dips',
            sets: [SetEntry(isBodyweight: true, extraWeightKg: 20, reps: 8)],
          ),
          ExerciseEntry(
            name: 'Plank',
            sets: [SetEntry(isBodyweight: true, durationSeconds: 60)],
          ),
        ],
      );
      expect(session.computedVolumeKg(), 760);
      expect(session.totalSets, 3);
    });
  });

  group('copyWith and equality', () {
    test('a rep set can become a hold only by clearing reps', () {
      const base = SetEntry(isBodyweight: true, reps: 12);
      final hold = base.copyWith(durationSeconds: 30, clearReps: true);
      expect(hold.reps, isNull);
      expect(hold.durationSeconds, 30);
      expect(hold.isHold, isTrue);
      expect(
        () => base.copyWith(durationSeconds: 30),
        throwsA(isA<AssertionError>()),
      );
    });

    test('clear flags remove optional fields', () {
      const s = SetEntry(
        isBodyweight: true,
        extraWeightKg: 10,
        reps: 5,
        rpe: 8,
        boxHeightCm: 60,
        contactTimeMs: 200,
      );
      final cleared = s.copyWith(
        clearRpe: true,
        clearBoxHeight: true,
        clearContactTime: true,
        clearExtraWeight: true,
      );
      expect(cleared.rpe, isNull);
      expect(cleared.boxHeightCm, isNull);
      expect(cleared.contactTimeMs, isNull);
      expect(cleared.extraWeightKg, isNull);
      expect(cleared.loadKg, 0);
    });

    test('pure bodyweight is equal whether extra weight is null or 0', () {
      const a = SetEntry(isBodyweight: true, reps: 5);
      const b = SetEntry(isBodyweight: true, extraWeightKg: 0, reps: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
