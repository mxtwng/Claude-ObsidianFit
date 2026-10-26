import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory vaultDir;
  late Directory outsideDir;
  late File outsideFile;
  late FilePersistenceService vault;

  late WorkoutSession workout;
  late ActivitySession activity;
  late PlanProgram plan;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('obsidianfit_write_path_');
    vaultDir = Directory(p.join(root.path, 'vault'));
    outsideDir = Directory(p.join(root.path, 'outside'));
    await outsideDir.create();
    outsideFile = File(p.join(outsideDir.path, 'keep.md'));
    await outsideFile.writeAsString('outside content must remain unchanged');

    vault = FilePersistenceService(vaultDir);
    await vault.ensureStructure();

    workout = FilePersistenceService.parseWorkout(
      File('schemas/workout_schema.md').readAsStringSync(),
    );
    activity = FilePersistenceService.parseActivity(
      File('schemas/activity_schema.md').readAsStringSync(),
    );
    plan = FilePersistenceService.parsePlan(
      File('schemas/plan_schema.md').readAsStringSync(),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> expectOutsideUnchanged() async {
    expect(await outsideFile.exists(), isTrue);
    expect(
      await outsideFile.readAsString(),
      'outside content must remain unchanged',
    );
  }

  test('generated save paths stay inside their expected folders', () async {
    final workoutFile = await vault.saveWorkout(workout);
    final activityFile = await vault.saveActivity(activity);
    final planFile = await vault.savePlan(plan);
    final gpxFile = await vault.saveGpx(
      DateTime(2026, 10, 22, 17, 30),
      '<gpx version="1.1"><trk/></gpx>',
    );

    expect(vault.relativePath(workoutFile), startsWith('Workouts/'));
    expect(vault.relativePath(activityFile), startsWith('Activities/'));
    expect(vault.relativePath(planFile), startsWith('Plans/'));
    expect(vault.relativePath(gpxFile), startsWith('Tracks/'));
  });

  test('legitimate relative paths can overwrite existing notes', () async {
    final first = await vault.saveActivity(activity);
    final rel = vault.relativePath(first);
    final updated = activity.copyWith(bodyText: 'updated safely');

    final overwritten = await vault.saveActivity(updated, relativePath: rel);

    expect(overwritten.path, first.path);
    expect(
      FilePersistenceService.parseActivity(await overwritten.readAsString())
          .bodyText,
      'updated safely',
    );
  });

  test('rejects traversal, absolute paths, wrong roots and nested paths',
      () async {
    final invalidPaths = <String>[
      '../outside/keep.md',
      'Activities/../../outside/keep.md',
      outsideFile.path,
      '/tmp/escaped.md',
      r'C:\outside\escaped.md',
      'Workouts/record.md',
      'Activities/nested/record.md',
      'Activities/..',
      'Activities/record.txt',
    ];

    for (final path in invalidPaths) {
      await expectLater(
        vault.saveWorkout(workout, relativePath: path),
        throwsA(isA<FileSystemException>()),
        reason: 'saveWorkout should reject $path',
      );
      await expectLater(
        vault.saveActivity(activity, relativePath: path),
        throwsA(isA<FileSystemException>()),
        reason: 'saveActivity should reject $path',
      );
      await expectLater(
        vault.savePlan(plan, relativePath: path),
        throwsA(isA<FileSystemException>()),
        reason: 'savePlan should reject $path',
      );
    }

    await expectOutsideUnchanged();
  });

  test('rejects a data folder symlink that escapes the vault', () async {
    final activitiesDir =
        Directory(p.join(vaultDir.path, FilePersistenceService.activitiesFolder));
    await activitiesDir.delete(recursive: true);
    await Link(activitiesDir.path).create(outsideDir.path);

    await expectLater(
      vault.saveActivity(activity),
      throwsA(isA<FileSystemException>()),
    );

    await expectOutsideUnchanged();
  });

  test('rejects an existing note path that is a symlink', () async {
    final target = File(
      p.join(vaultDir.path, FilePersistenceService.workoutsFolder, 'linked.md'),
    );
    await Link(target.path).create(outsideFile.path);

    await expectLater(
      vault.saveWorkout(workout, relativePath: 'Workouts/linked.md'),
      throwsA(isA<FileSystemException>()),
    );

    await expectOutsideUnchanged();
    expect(await Link(target.path).exists(), isTrue);
  });
}
