/// SQLite (Drift) read cache over the vault.
///
/// The `.md` files are the source of truth; every row here is disposable and
/// can be rebuilt by `VaultReindexerService`. `filePath` is vault-relative
/// with forward slashes (e.g. `Workouts/2026-10-22_1800_Push_Day_A.md`).
///
/// `updatedAt` stores the source file's modified time **truncated to whole
/// seconds** (Drift stores DateTime as unix seconds), so the re-indexer can
/// compare it for equality.
///
/// Generate the part file with:
///   dart run build_runner build --delete-conflicting-outputs
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('WorkoutIndexRow')
class WorkoutsIndex extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get split => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get timeStarted => text()();
  RealColumn get durationMin => real()();
  RealColumn get totalVolumeKg => real().nullable()();
  IntColumn get tssScore => integer().nullable()();
  IntColumn get readinessScore => integer().nullable()();

  /// `start_time` / `date_logged` frontmatter (UTC instants). Null on legacy
  /// notes written before Phase 5.
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get dateLogged => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('ActivityIndexRow')
class ActivitiesIndex extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get category => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get timeStarted => text()();
  RealColumn get durationMin => real()();
  RealColumn get distanceKm => real().nullable()();
  RealColumn get elevationGainM => real().nullable()();
  IntColumn get avgHr => integer().nullable()();
  IntColumn get tssScore => integer().nullable()();
  TextColumn get gpxFileName => text().nullable()();

  /// Phase 5 metadata. `startTime` / `dateLogged` are UTC instants (null on
  /// legacy notes); `durationSeconds` and `rpe` are written by the manual
  /// outdoor logger.
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get dateLogged => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get rpe => real().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('PlanIndexRow')
class PlansIndex extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get programName => text()();
  IntColumn get durationWeeks => integer()();
  IntColumn get daysPerWeek => integer().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(tables: [WorkoutsIndex, ActivitiesIndex, PlansIndex])
class AppDatabase extends _$AppDatabase {
  /// Pass an [executor] in tests (e.g. `NativeDatabase.memory()`); the default
  /// opens the on-device database.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'obsidian_fit_index'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // The index is a cache: on any schema change drop it and let the
        // re-indexer rebuild it from the vault.
        onUpgrade: (m, from, to) async {
          for (final table in allTables.toList()) {
            await m.deleteTable(table.actualTableName);
          }
          await m.createAll();
        },
      );

  // ---- re-indexer support ---------------------------------------------------

  /// `filePath -> updatedAt` across all three index tables.
  Future<Map<String, DateTime>> indexedTimestamps() async {
    final out = <String, DateTime>{};
    for (final r in await select(workoutsIndex).get()) {
      out[r.filePath] = r.updatedAt;
    }
    for (final r in await select(activitiesIndex).get()) {
      out[r.filePath] = r.updatedAt;
    }
    for (final r in await select(plansIndex).get()) {
      out[r.filePath] = r.updatedAt;
    }
    return out;
  }

  /// Inserts or updates the workout row for `row.filePath`. Also clears the
  /// path from the other tables in case the note's `type` changed.
  Future<void> upsertWorkout(WorkoutsIndexCompanion row) =>
      transaction(() async {
        final path = row.filePath.value;
        await _deletePath(activitiesIndex, path);
        await _deletePath(plansIndex, path);
        await into(workoutsIndex).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [workoutsIndex.filePath]),
        );
      });

  Future<void> upsertActivity(ActivitiesIndexCompanion row) =>
      transaction(() async {
        final path = row.filePath.value;
        await _deletePath(workoutsIndex, path);
        await _deletePath(plansIndex, path);
        await into(activitiesIndex).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [activitiesIndex.filePath]),
        );
      });

  Future<void> upsertPlan(PlansIndexCompanion row) => transaction(() async {
        final path = row.filePath.value;
        await _deletePath(workoutsIndex, path);
        await _deletePath(activitiesIndex, path);
        await into(plansIndex).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [plansIndex.filePath]),
        );
      });

  /// Deletes index rows for [paths] from every table. Returns rows removed.
  Future<int> removePaths(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return 0;
    var removed = 0;
    await transaction(() async {
      // Stay under SQLite's bound-variable limit.
      for (var i = 0; i < list.length; i += 500) {
        final chunk =
            list.sublist(i, i + 500 > list.length ? list.length : i + 500);
        removed += await (delete(workoutsIndex)
              ..where((t) => t.filePath.isIn(chunk)))
            .go();
        removed += await (delete(activitiesIndex)
              ..where((t) => t.filePath.isIn(chunk)))
            .go();
        removed += await (delete(plansIndex)
              ..where((t) => t.filePath.isIn(chunk)))
            .go();
      }
    });
    return removed;
  }

  Future<void> _deletePath(
    TableInfo<Table, dynamic> table,
    String path,
  ) async {
    await customUpdate(
      'DELETE FROM ${table.actualTableName} WHERE file_path = ?',
      variables: [Variable<String>(path)],
      updates: {table},
    );
  }

  // ---- UI streams -----------------------------------------------------------

  Stream<List<WorkoutIndexRow>> watchWorkouts() => (select(workoutsIndex)
        ..orderBy([
          (t) => OrderingTerm.desc(t.date),
          (t) => OrderingTerm.desc(t.timeStarted),
        ]))
      .watch();

  Stream<List<ActivityIndexRow>> watchActivities() => (select(activitiesIndex)
        ..orderBy([
          (t) => OrderingTerm.desc(t.date),
          (t) => OrderingTerm.desc(t.timeStarted),
        ]))
      .watch();

  Stream<List<PlanIndexRow>> watchPlans() =>
      (select(plansIndex)..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
          .watch();
}
