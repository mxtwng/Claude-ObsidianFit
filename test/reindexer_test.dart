import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:obsidian_fit/services/app_database.dart';
import 'package:obsidian_fit/services/vault_reindexer_service.dart';

void main() {
  group('PlanProgram.extraBody', () {
    const src = '---\n'
        'type: program_plan\n'
        'program_name: "P"\n'
        'duration_weeks: 2\n'
        '---\n'
        '\n'
        '# P\n'
        '\n'
        '## Weekly Rotation\n'
        '- **Monday:** Push\n'
        '\n'
        '## Notes\n'
        'Deload in week 2.\n'
        '\n'
        '## Daily Habit Checklist\n'
        '- [ ] Water\n';

    test('captures free-form sections and restores them', () {
      final plan = FilePersistenceService.parsePlan(src);
      expect(plan.weeklyRotation.length, 1);
      expect(plan.dailyHabits.length, 1);
      expect(plan.extraBody, '## Notes\nDeload in week 2.');

      final rendered = FilePersistenceService.renderPlan(plan);
      expect(rendered, contains('## Notes\nDeload in week 2.'));
      expect(
          FilePersistenceService.parsePlan(rendered).extraBody, plan.extraBody);
    });
  });

  group('VaultReindexerService', () {
    late Directory tmp;
    late FilePersistenceService vault;
    late AppDatabase db;
    late VaultReindexerService reindexer;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('obsidianfit_test_');
      vault = FilePersistenceService(tmp);
      await vault.ensureStructure();
      db = AppDatabase(NativeDatabase.memory());
      reindexer = VaultReindexerService(vault: vault, database: db);
    });

    tearDown(() async {
      reindexer.dispose();
      await db.close();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('indexes, skips unchanged, re-indexes edits, removes deletions',
        () async {
      final workout = FilePersistenceService.parseWorkout(
        File('schemas/workout_schema.md').readAsStringSync(),
      );
      final file = await vault.saveWorkout(workout);
      final rel = vault.relativePath(file);
      expect(rel, startsWith('Workouts/2026-10-22_1800_'));

      var report = await reindexer.reindex();
      expect(report.upserted, 1);
      expect(
          (await db.select(db.workoutsIndex).get()).single.split, 'Push Day A');

      report = await reindexer.reindex();
      expect(report.unchanged, 1);
      expect(report.upserted, 0);

      // Edit the note and make sure its mtime moves on by whole seconds.
      await vault.saveWorkout(workout.copyWith(split: 'Push Day B'),
          relativePath: rel);
      await file
          .setLastModified(DateTime.now().add(const Duration(seconds: 5)));
      report = await reindexer.reindex();
      expect(report.upserted, 1);
      final rows = await db.select(db.workoutsIndex).get();
      expect(rows.length, 1);
      expect(rows.single.split, 'Push Day B');

      await file.delete();
      report = await reindexer.reindex();
      expect(report.removed, 1);
      expect(await db.select(db.workoutsIndex).get(), isEmpty);
    });

    test('missing vault leaves the index untouched', () async {
      final activity = FilePersistenceService.parseActivity(
        File('schemas/activity_schema.md').readAsStringSync(),
      );
      await vault.saveActivity(activity);
      await reindexer.reindex();
      expect((await db.select(db.activitiesIndex).get()).length, 1);

      await tmp.delete(recursive: true);
      final report = await reindexer.reindex();
      expect(report.errors, isNotEmpty);
      expect((await db.select(db.activitiesIndex).get()).length, 1);
    });
  });
}
