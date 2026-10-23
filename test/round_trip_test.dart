import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';

String _schema(String name) => File('schemas/$name').readAsStringSync();

void main() {
  group('workout_schema.md', () {
    final src = _schema('workout_schema.md');

    test('parses expected structure', () {
      final w = FilePersistenceService.parseWorkout(src);
      expect(w.split, 'Push Day A');
      expect(w.timeStarted, '18:00');
      expect(w.durationMin, 52);
      expect(w.exercises.length, 3);
      expect(w.exercises[0].sets.length, 3);
      expect(w.exercises[0].sets[2].type, SetType.failure);
      expect(w.exercises[2].sets[1].type, SetType.drop);
    });

    test('render(parse(x)) == x', () {
      final w = FilePersistenceService.parseWorkout(src);
      expect(FilePersistenceService.renderWorkout(w), src);
    });
  });

  group('activity_schema.md', () {
    final src = _schema('activity_schema.md');

    test('extracts GPX wikilink and pace', () {
      final a = FilePersistenceService.parseActivity(src);
      expect(a.gpxFileName, '2026-10-22_1730_Route.gpx');
      expect(a.avgPaceMinKm, '6:02');
      expect(a.distanceKm, 7.5);
      expect(a.title, '7.5km Tempo Run');
    });

    test('render is stable after one normalisation pass', () {
      // The schema writes distance_km as 7.50; formatDecimal emits 7.5.
      final once = FilePersistenceService.renderActivity(
        FilePersistenceService.parseActivity(src),
      );
      final twice = FilePersistenceService.renderActivity(
        FilePersistenceService.parseActivity(once),
      );
      expect(twice, once);
      expect(once, contains('gpx_file: "[[2026-10-22_1730_Route.gpx]]"'));
    });
  });

  group('plan_schema.md', () {
    final src = _schema('plan_schema.md');

    test('parses rotation and habits', () {
      final plan = FilePersistenceService.parsePlan(src);
      expect(plan.programName, '4-Week Strength Block');
      expect(plan.weeklyRotation.length, 7);
      expect(plan.sessionFor('thursday'), 'Leg Day A');
      expect(plan.dailyHabits.length, 3);
    });

    test('render(parse(x)) == x', () {
      final plan = FilePersistenceService.parsePlan(src);
      expect(FilePersistenceService.renderPlan(plan), src);
    });
  });

  test('parseAny returns null for non-ObsidianFit notes', () {
    expect(FilePersistenceService.parseAny('# just a note\n'), isNull);
  });

  test('unknown frontmatter keys survive a round trip', () {
    const src = '---\ntype: strength\nsplit: "A"\ndate: 2026-10-22\n'
        'time_started: "07:00"\nduration_min: 30\nmood: great\n---\n\n'
        '# T\n';
    final w = FilePersistenceService.parseWorkout(src);
    expect(w.extraFrontmatter['mood'], 'great');
    expect(FilePersistenceService.renderWorkout(w), contains('mood: great'));
  });
}
