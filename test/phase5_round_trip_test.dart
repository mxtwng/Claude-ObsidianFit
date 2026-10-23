import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';

/// Phase 5A: Markdown -> model -> Markdown round trips for the Phase 5
/// sidecar schemas (schemas/workout_schema.phase5.md and
/// schemas/activity_schema.phase5.md), using fixtures in
/// test/fixtures/phase5/. The baseline fixtures in schemas/ are covered by
/// round_trip_test.dart and are not touched here.

String _fixture(String name) =>
    File('test/fixtures/phase5/$name').readAsStringSync();

/// Fixtures that are already in canonical form, so render(parse(x)) == x.
const List<String> _workoutFixtures = [
  'workout_retro_calisthenics.md',
  'workout_bodyweight.md',
  'workout_isometric_holds.md',
  'workout_plyometrics.md',
];

const List<String> _activityFixtures = [
  'activity_manual_run.md',
  'activity_manual_ride_minimal.md',
];

/// Minimal workout note with [extra] frontmatter lines (each ending in `\n`)
/// inserted after `time_started`.
String _workoutNote(String extra) =>
    '---\ntype: strength\nsplit: "A"\ndate: 2026-10-18\n'
    'time_started: "07:15"\n$extra'
    'duration_min: 30\n---\n\n# A\n';

/// Minimal activity note with [extra] frontmatter lines (each ending in `\n`)
/// inserted after `duration_min`.
String _activityNote(String extra) =>
    '---\ntype: activity\ncategory: run\ndate: 2026-10-19\n'
    'time_started: "06:15"\nduration_min: 30\n$extra---\n\n# Run\n';

void main() {
  group('Phase 5 workout fixtures', () {
    for (final name in _workoutFixtures) {
      test('$name: render(parse(x)) == x', () {
        final src = _fixture(name);
        expect(
          FilePersistenceService.renderWorkout(
            FilePersistenceService.parseWorkout(src),
          ),
          src,
        );
      });

      test('$name: dispatches to WorkoutSession via parseAny', () {
        expect(
          FilePersistenceService.parseAny(_fixture(name)),
          isA<WorkoutSession>(),
        );
      });
    }

    test('retroactive timestamps parse as UTC and render with a Z suffix', () {
      final src = _fixture('workout_retro_calisthenics.md');
      final w = FilePersistenceService.parseWorkout(src);

      expect(w.startTime, DateTime.utc(2026, 10, 18, 0, 15));
      expect(w.dateLogged, DateTime.utc(2026, 10, 22, 14, 5, 12));
      expect(w.startTime!.isUtc, isTrue);
      expect(w.dateLogged!.isUtc, isTrue);
      expect(w.dateLogged!.isAfter(w.startTime!), isTrue);

      // Local rendering stays as written.
      expect(w.date, DateTime(2026, 10, 18));
      expect(w.timeStarted, '07:15');

      final out = FilePersistenceService.renderWorkout(w);
      expect(out, contains('start_time: "2026-10-18T00:15:00Z"\n'));
      expect(out, contains('date_logged: "2026-10-22T14:05:12Z"\n'));
      // New keys are known keys, not preserved as extras.
      expect(w.extraFrontmatter, isEmpty);
    });

    test('start_time and date_logged sit between time_started and duration',
        () {
      final out = FilePersistenceService.renderWorkout(
        FilePersistenceService.parseWorkout(
          _fixture('workout_retro_calisthenics.md'),
        ),
      );
      final i = out.indexOf('time_started:');
      final j = out.indexOf('start_time:');
      final k = out.indexOf('date_logged:');
      final l = out.indexOf('duration_min:');
      expect(i, lessThan(j));
      expect(j, lessThan(k));
      expect(k, lessThan(l));
    });

    test('retro note mixes bodyweight, hold and plyometric sets', () {
      final w = FilePersistenceService.parseWorkout(
        _fixture('workout_retro_calisthenics.md'),
      );
      expect(
          w.exercises.map((e) => e.name), ['Pull-ups', 'Plank', 'Box Jumps']);

      final pullUps = w.exercises[0].sets;
      expect(
        pullUps.map((s) => s.type),
        [SetType.warmup, SetType.normal, SetType.failure],
      );
      expect(pullUps.every((s) => s.isBodyweight), isTrue);
      expect(pullUps.map((s) => s.extraWeightKg), [0, 10, 10]);
      expect(pullUps.map((s) => s.reps), [10, 6, 5]);

      final plank = w.exercises[1].sets.single;
      expect(plank.durationSeconds, 60);
      expect(plank.reps, isNull);
      expect(plank.rpe, 7.0);

      final jump = w.exercises[2].sets.single;
      expect(jump.reps, 5);
      expect(jump.boxHeightCm, 60);
      expect(jump.contactTimeMs, 210);
    });

    test('computed volume matches total_volume_kg in every fixture', () {
      const expected = <String, double>{
        'workout_retro_calisthenics.md': 110,
        'workout_bodyweight.md': 870,
        'workout_isometric_holds.md': 0,
        'workout_plyometrics.md': 100,
      };
      expected.forEach((name, kg) {
        final w = FilePersistenceService.parseWorkout(_fixture(name));
        expect(w.computedVolumeKg(), kg, reason: name);
        expect(w.totalVolumeKg, kg, reason: name);
      });
    });

    test('plyometric segments are independent per set', () {
      final w = FilePersistenceService.parseWorkout(
        _fixture('workout_plyometrics.md'),
      );
      final box = w.exercises[0].sets;
      expect(box.map((s) => s.boxHeightCm), [60, 70, 52.5]);
      expect(box.map((s) => s.contactTimeMs), [210, 195, null]);
      expect(box.map((s) => s.rpe), [null, 8.0, null]);

      final broad = w.exercises[1].sets;
      expect(broad.map((s) => s.boxHeightCm), [null, null]);
      expect(broad.map((s) => s.contactTimeMs), [null, 180]);
    });

    test('legacy notes without the new keys parse with null timestamps', () {
      final w = FilePersistenceService.parseWorkout(
        _fixture('workout_bodyweight.md'),
      );
      expect(w.startTime, isNull);
      expect(w.dateLogged, isNull);
      final out = FilePersistenceService.renderWorkout(w);
      expect(out, isNot(contains('start_time')));
      expect(out, isNot(contains('date_logged')));
    });

    test('an offset timestamp is normalised to UTC with a Z suffix', () {
      final w = FilePersistenceService.parseWorkout(
        _workoutNote('start_time: "2026-10-18T07:15:00+07:00"\n'),
      );
      expect(w.startTime, DateTime.utc(2026, 10, 18, 0, 15));
      expect(
        FilePersistenceService.renderWorkout(w),
        contains('start_time: "2026-10-18T00:15:00Z"\n'),
      );
    });

    test('fractional seconds are dropped (second precision)', () {
      final w = FilePersistenceService.parseWorkout(
        _workoutNote('start_time: "2026-10-18T00:15:00.123Z"\n'),
      );
      expect(w.startTime, DateTime.utc(2026, 10, 18, 0, 15));
      expect(
        FilePersistenceService.renderWorkout(w),
        contains('start_time: "2026-10-18T00:15:00Z"\n'),
      );
    });

    test('an unquoted timestamp (hand-edited in Obsidian) is accepted', () {
      final w = FilePersistenceService.parseWorkout(
        _workoutNote('start_time: 2026-10-18T00:15:00Z\n'),
      );
      expect(w.startTime, DateTime.utc(2026, 10, 18, 0, 15));
    });

    test('unknown keys still survive next to the new keys', () {
      final w = FilePersistenceService.parseWorkout(
        _workoutNote('start_time: "2026-10-18T00:15:00Z"\nmood: great\n'),
      );
      expect(w.extraFrontmatter.keys, ['mood']);
      expect(FilePersistenceService.renderWorkout(w), contains('mood: great'));
    });
  });

  group('Phase 5 activity fixtures', () {
    for (final name in _activityFixtures) {
      test('$name: render(parse(x)) == x', () {
        final src = _fixture(name);
        expect(
          FilePersistenceService.renderActivity(
            FilePersistenceService.parseActivity(src),
          ),
          src,
        );
      });

      test('$name: dispatches to ActivitySession via parseAny', () {
        expect(
          FilePersistenceService.parseAny(_fixture(name)),
          isA<ActivitySession>(),
        );
      });
    }

    test('manual run: every Phase 5 field is read', () {
      final a = FilePersistenceService.parseActivity(
        _fixture('activity_manual_run.md'),
      );
      expect(a.category, 'run');
      expect(a.date, DateTime(2026, 10, 19));
      expect(a.timeStarted, '06:15');
      expect(a.startTime, DateTime.utc(2026, 10, 18, 23, 15));
      expect(a.dateLogged, DateTime.utc(2026, 10, 22, 14, 20, 41));
      expect(a.durationSeconds, 2712);
      expect(a.durationMin, 45.2);
      expect(a.distanceKm, 7.5);
      expect(a.elevationGainM, 85);
      expect(a.avgHr, 152);
      expect(a.maxHr, isNull);
      expect(a.rpe, 7.0);
      expect(a.gpxFileName, isNull);
      expect(a.title, '7.5km Easy Run (logged afterwards)');
      expect(a.bodyText, startsWith('- Treadmill was broken'));
      expect(a.computedPaceMinKm, '6:02');
      expect(a.extraFrontmatter, isEmpty);

      final out = FilePersistenceService.renderActivity(a);
      expect(out, isNot(contains('gpx_file')));
      expect(out, contains('start_time: "2026-10-18T23:15:00Z"\n'));
      expect(out, contains('date_logged: "2026-10-22T14:20:41Z"\n'));
    });

    test('minimal manual ride: no heart rate, no body, no GPS', () {
      final a = FilePersistenceService.parseActivity(
        _fixture('activity_manual_ride_minimal.md'),
      );
      expect(a.category, 'ride');
      expect(a.durationSeconds, 5400);
      expect(a.durationMin, 90);
      expect(a.distanceKm, 32);
      expect(a.elevationGainM, 0);
      expect(a.rpe, 6);
      expect(a.avgHr, isNull);
      expect(a.gpxFileName, isNull);
      expect(a.title, isEmpty);
      expect(a.bodyText, isEmpty);
      expect(a.computedPaceMinKm, '2:49');
      expect(
        FilePersistenceService.renderActivity(a),
        isNot(contains('avg_hr')),
      );
    });

    test('RPE accepts halves', () {
      final src = _fixture('activity_manual_run.md')
          .replaceFirst('rpe: 7\n', 'rpe: 7.5\n');
      final a = FilePersistenceService.parseActivity(src);
      expect(a.rpe, 7.5);
      expect(FilePersistenceService.renderActivity(a), src);
    });

    test('rpe sits after avg_hr and before the tags', () {
      final out = FilePersistenceService.renderActivity(
        FilePersistenceService.parseActivity(
          _fixture('activity_manual_run.md'),
        ),
      );
      expect(out.indexOf('avg_hr:'), lessThan(out.indexOf('rpe:')));
      expect(out.indexOf('rpe:'), lessThan(out.indexOf('tags:')));
      expect(
        out.indexOf('duration_seconds:'),
        lessThan(out.indexOf('duration_min:')),
      );
    });

    test('duration_seconds wins over a mismatched duration_min', () {
      final src = _fixture('activity_manual_run.md')
          .replaceFirst('duration_min: 45.2', 'duration_min: 50');
      final a = FilePersistenceService.parseActivity(src);
      expect(a.durationMin, 50);
      expect(a.effectiveDurationSeconds, 2712);
      expect(a.computedPaceMinKm, '6:02');
    });

    test('GPS activities without duration_seconds derive it from minutes', () {
      final a = FilePersistenceService.parseActivity(_activityNote(''));
      expect(a.durationSeconds, isNull);
      expect(a.effectiveDurationSeconds, 1800);
    });

    test('unknown keys survive next to the new keys', () {
      final a = FilePersistenceService.parseActivity(
        _activityNote('rpe: 6\nmood: great\n'),
      );
      expect(a.rpe, 6);
      expect(a.extraFrontmatter.keys, ['mood']);
      expect(FilePersistenceService.renderActivity(a), contains('mood: great'));
    });
  });

  group('activity with no GPS track', () {
    const noTrackForms = <String, String>{
      'key omitted': '',
      'null': 'gpx_file: null\n',
      'empty string': 'gpx_file: ""\n',
      'empty wikilink': 'gpx_file: "[[]]"\n',
      'blank wikilink': 'gpx_file: "[[  ]]"\n',
    };

    noTrackForms.forEach((label, line) {
      test('gpx_file $label reads as no track and is never re-written', () {
        final a = FilePersistenceService.parseActivity(_activityNote(line));
        expect(a.gpxFileName, isNull);
        final out = FilePersistenceService.renderActivity(a);
        expect(out, isNot(contains('gpx_file')));
        expect(out, isNot(contains('[[]]')));
      });
    });

    test('gpx_file: null fixture is normalised by dropping the key', () {
      final src = _fixture('activity_gpx_null.md');
      final a = FilePersistenceService.parseActivity(src);
      expect(a.gpxFileName, isNull);
      expect(a.distanceKm, 2.5);
      expect(
        FilePersistenceService.renderActivity(a),
        src.replaceFirst('gpx_file: null\n', ''),
      );
    });

    test('a real wikilink is unchanged', () {
      final a = FilePersistenceService.parseActivity(
        _activityNote('gpx_file: "[[2026-10-22_1730_Route.gpx]]"\n'),
      );
      expect(a.gpxFileName, '2026-10-22_1730_Route.gpx');
      expect(
        FilePersistenceService.renderActivity(a),
        contains('gpx_file: "[[2026-10-22_1730_Route.gpx]]"\n'),
      );
      expect(
        FilePersistenceService.renderActivity(a.copyWith(clearGpx: true)),
        isNot(contains('gpx_file')),
      );
    });

    test('extractWikilinkTarget', () {
      expect(ActivitySession.extractWikilinkTarget(null), isNull);
      expect(ActivitySession.extractWikilinkTarget(''), isNull);
      expect(ActivitySession.extractWikilinkTarget('   '), isNull);
      expect(ActivitySession.extractWikilinkTarget('[[]]'), isNull);
      expect(ActivitySession.extractWikilinkTarget('[[  ]]'), isNull);
      expect(
        ActivitySession.extractWikilinkTarget('[[Route.gpx]]'),
        'Route.gpx',
      );
      expect(
        ActivitySession.extractWikilinkTarget('[[Route.gpx|My route]]'),
        'Route.gpx',
      );
      expect(ActivitySession.extractWikilinkTarget('Route.gpx'), 'Route.gpx');
    });

    test('an empty file name is never written as an empty wikilink', () {
      final a = ActivitySession(
        category: 'run',
        date: DateTime(2026, 10, 19),
        timeStarted: '06:15',
        durationMin: 30,
        gpxFileName: '',
      );
      expect(a.toFrontmatter().containsKey('gpx_file'), isFalse);
    });
  });
}
