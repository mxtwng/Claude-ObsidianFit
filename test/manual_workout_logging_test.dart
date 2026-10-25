import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:obsidian_fit/services/app_database.dart';
import 'package:obsidian_fit/services/vault_reindexer_service.dart';
import 'package:obsidian_fit/ui/app_services.dart';
import 'package:obsidian_fit/ui/common/start_time_card.dart';
import 'package:obsidian_fit/ui/workout/set_row.dart';
import 'package:obsidian_fit/ui/workout/workout_draft.dart';
import 'package:obsidian_fit/ui/workout/workout_session_page.dart';

const String _weightMessage =
    'enter the weight, or turn on Bodyweight for no external load';

WorkoutDraft _manualDraft() => WorkoutDraft(
      split: 'Push Day A',
      startedAt: DateTime(2026, 10, 18, 18, 30),
      manual: true,
    );

/// Adds [name] and returns its first row.
DraftSet _addRow(WorkoutDraft draft, String name) {
  draft.addExercise(name);
  return draft.exercises.last.sets.first;
}

/// A vault that records what the logger saves instead of touching the disk,
/// so a widget test can finish a workout without real file IO (which cannot
/// complete under the widget tester's fake clock). Writing the real note and
/// reading it back is covered by the plain-Dart `manual save and re-index`
/// group below.
class _RecordingVault extends FilePersistenceService {
  _RecordingVault(super.vaultDir);

  final List<WorkoutSession> saved = [];

  @override
  Future<File> saveWorkout(WorkoutSession s, {String? relativePath}) async {
    saved.add(s);
    return File('${vaultDir.path}/Workouts/recorded.md');
  }
}

/// Counts re-index requests without scanning anything.
class _CountingReindexer extends VaultReindexerService {
  _CountingReindexer({required super.vault, required super.database});

  int calls = 0;

  @override
  Future<ReindexReport> reindex() async {
    calls++;
    return const ReindexReport();
  }
}

/// Home screen that opens the logger the way a caller does and reports what
/// the route returns (true = saved).
class _LoggerLauncher extends StatelessWidget {
  const _LoggerLauncher({required this.backdateTo, required this.onResult});

  final DateTime backdateTo;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => WorkoutSessionPage(
                  split: 'Push Day A',
                  backdateTo: backdateTo,
                ),
              ),
            );
            onResult(saved);
          },
          child: const Text('Open logger'),
        ),
      ),
    );
  }
}

void main() {
  group('DraftSet.problems: rules follow the set modality', () {
    test('weighted lift needs a load above 0 and at least 1 rep', () {
      expect(DraftSet(weightKg: 80, reps: 8).problems(), isEmpty);
      expect(DraftSet(weightKg: 0, reps: 8).problems(), [_weightMessage]);
      expect(
        DraftSet(weightKg: 80, reps: 0).problems(),
        ['enter at least 1 rep'],
      );
    });

    test('bodyweight with no added load is valid (BW+0kg)', () {
      expect(
        DraftSet(isBodyweight: true, extraWeightKg: 0, reps: 12).problems(),
        isEmpty,
      );
      expect(
        DraftSet(isBodyweight: true, extraWeightKg: 10, reps: 6).problems(),
        isEmpty,
      );
      // The inactive external weight is ignored.
      expect(
        DraftSet(isBodyweight: true, weightKg: 0, reps: 5).problems(),
        isEmpty,
      );
      expect(
        DraftSet(isBodyweight: true, extraWeightKg: -2.5, reps: 5).problems(),
        ['added weight cannot be negative'],
      );
    });

    test('bodyweight still needs reps', () {
      expect(
        DraftSet(isBodyweight: true, reps: 0).problems(),
        ['enter at least 1 rep'],
      );
    });

    test('a hold needs a duration, not reps', () {
      // Reps are irrelevant to a hold, so an unentered rep count is fine.
      expect(
        DraftSet(
          isBodyweight: true,
          isHold: true,
          reps: 0,
          durationSeconds: 60,
        ).problems(),
        isEmpty,
      );
      expect(
        DraftSet(isBodyweight: true, isHold: true, durationSeconds: 0)
            .problems(),
        ['enter a hold time of at least 1 second'],
      );
    });

    test('a hold with external load needs that load; without it, BW', () {
      expect(
        DraftSet(weightKg: 20, isHold: true, durationSeconds: 30).problems(),
        isEmpty,
      );
      expect(
        DraftSet(weightKg: 0, isHold: true, durationSeconds: 30).problems(),
        [_weightMessage],
      );
    });

    test('a rep set ignores the hold duration placeholder', () {
      final row = DraftSet.blank()
        ..weightKg = 80
        ..reps = 5;
      expect(row.durationSeconds, 0);
      expect(row.problems(), isEmpty);
    });

    test('plyometrics: jump count, optional box and contact must be > 0', () {
      expect(
        DraftSet(
          isBodyweight: true,
          reps: 5,
          boxHeightCm: 60,
          contactTimeMs: 210,
        ).problems(),
        isEmpty,
      );
      expect(
        DraftSet(isBodyweight: true, reps: 5, boxHeightCm: 0).problems(),
        ['box height must be above 0 cm'],
      );
      expect(
        DraftSet(isBodyweight: true, reps: 5, contactTimeMs: 0).problems(),
        ['contact time must be above 0 ms'],
      );
    });

    test('RPE, when present, must be within 1-10', () {
      expect(DraftSet(weightKg: 80, rpe: 1).problems(), isEmpty);
      expect(DraftSet(weightKg: 80, rpe: 10).problems(), isEmpty);
      expect(
        DraftSet(weightKg: 80, rpe: 0.5).problems(),
        ['RPE must be between 1 and 10'],
      );
      expect(
        DraftSet(weightKg: 80, rpe: 11).problems(),
        ['RPE must be between 1 and 10'],
      );
    });
  });

  group('manual draft', () {
    test('a new exercise starts unentered, not as 0 kg x 8 reps', () {
      final draft = _manualDraft();
      final row = _addRow(draft, 'Deadlift');

      expect(draft.recordsAllSets, isTrue);
      expect(row.weightKg, 0);
      expect(row.reps, 0);
      expect(row.durationSeconds, 0);
      expect(row.done, isFalse);
      draft.dispose();
    });

    test('a live draft keeps the existing defaults and checkbox model', () {
      final draft = WorkoutDraft(split: 'Push Day A');
      final row = _addRow(draft, 'Deadlift');

      expect(draft.recordsAllSets, isFalse);
      expect(row.reps, 8);
      expect(row.durationSeconds, 30);
      draft.dispose();
    });

    test('an unentered row is reported with its exercise and set number', () {
      final draft = _manualDraft();
      _addRow(draft, 'Deadlift');

      final issues = draft.validateForSave();
      expect(issues.map((i) => i.toString()), [
        'Deadlift · Set 1: enter at least 1 rep',
        'Deadlift · Set 1: $_weightMessage',
      ]);
      draft.dispose();
    });

    test('issues point at the right exercise and set', () {
      final draft = _manualDraft();
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8;
      final pullUps = _addRow(draft, 'Pull-ups')
        ..isBodyweight = true
        ..reps = 10;
      draft.addSet(draft.exercises[1]); // set 2 inherits the entered values
      draft.addSet(draft.exercises[1]); // set 3
      draft.exercises[1].sets[2].reps = 0;
      expect(pullUps.problems(), isEmpty);

      final issues = draft.validateForSave();
      expect(issues, hasLength(1));
      expect(issues.single.exercise, 'Pull-ups');
      expect(issues.single.setNumber, 3);
      expect(issues.single.message, 'enter at least 1 rep');
      draft.dispose();
    });

    test('deleting an invalid row clears its issue', () {
      final draft = _manualDraft();
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8;
      final bench = draft.exercises.single;
      draft.addSet(bench);
      bench.sets.last.reps = 0;
      expect(draft.validateForSave(), hasLength(1));

      draft.removeSet(bench, bench.sets.last);
      expect(draft.validateForSave(), isEmpty);
      draft.dispose();
    });

    test('legitimate bodyweight, hold and weighted rows all validate', () {
      final draft = _manualDraft();
      _addRow(draft, 'Pull-ups')
        ..isBodyweight = true
        ..reps = 12;
      _addRow(draft, 'Plank')
        ..isBodyweight = true
        ..isHold = true
        ..durationSeconds = 60;
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8;

      expect(draft.validateForSave(), isEmpty);
      draft.dispose();
    });

    test('every row is saved without ticking anything', () {
      final draft = _manualDraft();
      _addRow(draft, 'Pull-ups')
        ..isBodyweight = true
        ..reps = 12;
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8;
      draft.addSet(draft.exercises[1]);

      expect(draft.completedSets, 3);
      expect(draft.pendingSets, 0);

      final session = draft.toSession(DateTime(2026, 10, 22, 14, 5, 12));
      expect(session.exercises.map((e) => e.name), ['Pull-ups', 'Bench Press']);
      expect(session.exercises.map((e) => e.sets.length), [1, 2]);
      expect(session.totalVolumeKg, 1280); // 80 kg x 8 x 2; BW adds nothing
      draft.dispose();
    });

    test('a manual draft with no rows has nothing to save', () {
      final draft = _manualDraft();
      expect(draft.completedSets, 0);

      _addRow(draft, 'Bench Press');
      final bench = draft.exercises.single;
      draft.removeSet(bench, bench.sets.single);
      expect(draft.completedSets, 0);
      expect(
        draft.toSession(DateTime(2026, 10, 22, 14, 5, 12)).exercises,
        isEmpty,
      );
      draft.dispose();
    });

    test('inheriting a previous set copies entered values', () {
      final draft = _manualDraft();
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8;
      draft.addSet(draft.exercises.single);

      final second = draft.exercises.single.sets.last;
      expect(second.weightKg, 80);
      expect(second.reps, 8);
      draft.dispose();
    });
  });

  group('live draft keeps checkbox semantics', () {
    test('only ticked sets are saved and nothing is validated', () {
      final draft = WorkoutDraft(
        split: 'Push Day A',
        startedAt: DateTime(2026, 10, 22, 18, 0),
      );
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8
        ..done = true;
      draft.addSet(draft.exercises.single); // not ticked
      _addRow(draft, 'Overhead Press'); // untouched defaults, not ticked

      expect(draft.completedSets, 1);
      expect(draft.pendingSets, 2);
      expect(draft.validateForSave(), isEmpty);

      final session = draft.toSession(DateTime(2026, 10, 22, 18, 50));
      expect(session.exercises.map((e) => e.name), ['Bench Press']);
      expect(session.exercises.single.sets, hasLength(1));
      draft.dispose();
    });

    test('backdating a live draft keeps its checkboxes and tick semantics', () {
      final draft = WorkoutDraft(
        split: 'Push Day A',
        startedAt: DateTime(2026, 10, 22, 18, 0),
      );
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8
        ..done = true;
      draft.addSet(draft.exercises.single); // never ticked

      draft.setStart(DateTime(2026, 10, 18, 18, 30));

      expect(draft.isManual, isTrue); // no rest timer, typed duration
      expect(draft.recordsAllSets, isFalse); // but unticked sets stay out
      expect(draft.validateForSave(), isEmpty);
      final session = draft.toSession(DateTime(2026, 10, 22, 18, 50));
      expect(session.exercises.single.sets, hasLength(1));
      draft.dispose();
    });
  });

  group('manual logger UI', () {
    Future<void> open(WidgetTester tester, {DateTime? backdateTo}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSessionPage(split: 'Push Day A', backdateTo: backdateTo),
        ),
      );
      await tester.pump();
    }

    Future<void> addExercise(WidgetTester tester) async {
      await tester.tap(find.text('Add exercise'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'Deadlift');
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 300));
    }

    final past = DateTime(2026, 10, 18, 18, 30);

    testWidgets('manual rows have no checkbox; live rows do', (tester) async {
      await open(tester, backdateTo: past);
      await addExercise(tester);
      expect(find.byType(Checkbox), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await open(tester);
      await addExercise(tester);
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Finish blocks an unentered row and names exercise and set',
        (tester) async {
      await open(tester, backdateTo: past);
      await addExercise(tester);

      await tester.tap(find.text('Finish'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Fix these sets'), findsOneWidget);
      expect(
        find.textContaining('Deadlift · Set 1: enter at least 1 rep'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Deadlift · Set 1: $_weightMessage'),
        findsOneWidget,
      );

      // The user is returned to the logger to correct or delete the row.
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Fix these sets'), findsNothing);
      expect(find.text('Finish'), findsOneWidget);
    });

    testWidgets('a manual workout with no sets keeps the discard confirmation',
        (tester) async {
      await open(tester, backdateTo: past);

      await tester.tap(find.text('Finish'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No sets logged'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No sets logged'), findsNothing);
    });
  });

  group('live bodyweight logging is not blocked', () {
    test('ticked bodyweight and hold sets need no external weight', () {
      final draft = WorkoutDraft(
        split: 'Calisthenics A',
        startedAt: DateTime(2026, 10, 22, 7, 0),
      );
      _addRow(draft, 'Pull-ups')
        ..isBodyweight = true
        ..reps = 10
        ..done = true;
      _addRow(draft, 'Plank')
        ..isBodyweight = true
        ..isHold = true
        ..durationSeconds = 60
        ..done = true;

      expect(draft.validateForSave(), isEmpty);
      final session = draft.toSession(DateTime(2026, 10, 22, 7, 45));

      final pullUp = session.exercises[0].sets.single;
      expect(pullUp.isBodyweight, isTrue);
      expect(pullUp.extraWeightKg, 0);
      expect(pullUp.reps, 10);
      final plank = session.exercises[1].sets.single;
      expect(plank.isBodyweight, isTrue);
      expect(plank.durationSeconds, 60);
      draft.dispose();
    });
  });

  group('backdating a live draft', () {
    // [clock] is fixed so the elapsed time is exact.
    WorkoutDraft liveDraft({
      required DateTime startedAt,
      required DateTime now,
    }) =>
        WorkoutDraft(
          split: 'Push Day A',
          startedAt: startedAt,
          clock: () => now,
        );

    test('keeps the measured elapsed time, not the 60 min default', () {
      final draft = liveDraft(
        startedAt: DateTime(2026, 10, 22, 18, 0),
        now: DateTime(2026, 10, 22, 18, 42, 20),
      );

      expect(draft.setStart(DateTime(2026, 10, 18, 18, 30)), isTrue);

      expect(draft.isManual, isTrue);
      expect(draft.manualDurationMin, 42);
      expect(draft.manualDurationMin, isNot(kDefaultManualDurationMin));
      draft.dispose();
    });

    test('saves the preserved duration with date_logged as the save time', () {
      final draft = liveDraft(
        startedAt: DateTime(2026, 10, 22, 18, 0),
        now: DateTime(2026, 10, 22, 18, 42, 20),
      );
      draft.setStart(DateTime(2026, 10, 18, 18, 30));
      final finished = DateTime(2026, 10, 22, 18, 50);

      final session = draft.toSession(finished);

      expect(session.durationMin, 42);
      expect(session.date, DateTime(2026, 10, 18));
      expect(session.timeStarted, '18:30');
      // start_time is the picked (historical) start; date_logged is when the
      // note is written: not the live start, not the picked start.
      expect(session.startTime, DateTime(2026, 10, 18, 18, 30).toUtc());
      expect(session.dateLogged, finished.toUtc());
      expect(session.dateLogged!.isBefore(session.startTime!), isFalse);
      draft.dispose();
    });

    test('under a minute of measured time still saves the 1 min minimum', () {
      final draft = liveDraft(
        startedAt: DateTime(2026, 10, 22, 18, 0),
        now: DateTime(2026, 10, 22, 18, 0, 20),
      );
      draft.setStart(DateTime(2026, 10, 18, 18, 30));

      expect(draft.manualDurationMin, 1);
      draft.dispose();
    });

    test('a typed duration survives further start changes', () {
      final draft = liveDraft(
        startedAt: DateTime(2026, 10, 22, 18, 0),
        now: DateTime(2026, 10, 22, 18, 42, 20),
      );
      draft.setStart(DateTime(2026, 10, 18, 18, 30));
      draft.setManualDuration(75);

      expect(draft.setStart(DateTime(2026, 10, 17, 9, 0)), isTrue);
      expect(draft.manualDurationMin, 75);
      draft.dispose();
    });

    test('a draft opened as manual keeps the default and can move later', () {
      final draft = _manualDraft();
      expect(draft.manualDurationMin, kDefaultManualDurationMin);

      expect(draft.setStart(DateTime(2026, 10, 18, 19, 15)), isTrue);
      expect(draft.startedAt, DateTime(2026, 10, 18, 19, 15));
      expect(draft.manualDurationMin, kDefaultManualDurationMin);
      draft.dispose();
    });

    test('a live draft refuses a start at or after its real one', () {
      final started = DateTime(2026, 10, 22, 18, 0, 45);
      final draft = liveDraft(
        startedAt: started,
        now: DateTime(2026, 10, 22, 18, 41, 30),
      );
      var notifications = 0;
      draft.addListener(() => notifications++);

      // What a pick later than the session start used to be clamped to: the
      // current minute, 40 minutes after the workout really began.
      expect(draft.setStart(DateTime(2026, 10, 22, 18, 41)), isFalse);
      expect(draft.setStart(started), isFalse);

      expect(draft.isManual, isFalse);
      expect(draft.startedAt, started);
      expect(notifications, 0);

      expect(draft.setStart(DateTime(2026, 10, 22, 17, 30)), isTrue);
      expect(draft.isManual, isTrue);
      expect(notifications, 1);
      draft.dispose();
    });
  });

  group('clampStartPick', () {
    final now = DateTime(2026, 10, 22, 18, 41, 30);

    test('a past pick is kept, to the minute', () {
      final pick = clampStartPick(
        picked: DateTime(2026, 10, 22, 17, 5, 59),
        now: now,
      );
      expect(pick.value, DateTime(2026, 10, 22, 17, 5));
      expect(pick.wasClamped, isFalse);
    });

    test('a pick in the current minute is not clamped', () {
      final pick = clampStartPick(
        picked: DateTime(2026, 10, 22, 18, 41, 10),
        now: now,
      );
      expect(pick.value, DateTime(2026, 10, 22, 18, 41));
      expect(pick.wasClamped, isFalse);
    });

    test('a future pick is clamped to the current minute', () {
      final pick = clampStartPick(
        picked: DateTime(2026, 10, 22, 23, 0),
        now: now,
      );
      expect(pick.value, DateTime(2026, 10, 22, 18, 41));
      expect(pick.wasClamped, isTrue);
    });

    test('a live session caps picks at its real start, not at now', () {
      final liveStart = DateTime(2026, 10, 22, 18, 0, 45);

      // Clamping to now (18:41) would start the session 41 minutes after it
      // really began. Clamped to its own start it equals the start minute,
      // which StartTimeCard treats as "no change".
      final future = clampStartPick(
        picked: DateTime(2026, 10, 22, 23, 0),
        now: now,
        latest: liveStart,
      );
      expect(future.value, truncateToMinute(liveStart));
      expect(future.wasClamped, isTrue);

      final laterButPast = clampStartPick(
        picked: DateTime(2026, 10, 22, 18, 35),
        now: now,
        latest: liveStart,
      );
      expect(laterButPast.value, truncateToMinute(liveStart));
      expect(laterButPast.wasClamped, isTrue);

      final earlier = clampStartPick(
        picked: DateTime(2026, 10, 22, 17, 0),
        now: now,
        latest: liveStart,
      );
      expect(earlier.value, DateTime(2026, 10, 22, 17, 0));
      expect(earlier.wasClamped, isFalse);
    });

    test('latest never loosens the limit beyond now', () {
      final pick = clampStartPick(
        picked: DateTime(2026, 10, 22, 18, 50),
        now: now,
        latest: DateTime(2026, 10, 22, 19, 0),
      );
      expect(pick.value, DateTime(2026, 10, 22, 18, 41));
      expect(pick.wasClamped, isTrue);
    });
  });

  group('manual logger: finish and save', () {
    final past = DateTime(2026, 10, 18, 18, 30);

    late _RecordingVault vault;
    late AppDatabase db;
    late _CountingReindexer reindexer;
    bool? result;

    setUp(() {
      result = null;
      // Never touched: _RecordingVault does no IO, and the counting
      // reindexer scans nothing.
      vault = _RecordingVault(Directory('unused-vault'));
      db = AppDatabase(NativeDatabase.memory());
      reindexer = _CountingReindexer(vault: vault, database: db);
    });

    tearDown(() async {
      reindexer.dispose();
      await db.close();
    });

    // Fixed frames: nothing in a manual session ticks, but a route
    // transition and dialogs need a few frames each.
    Future<void> pumpFrames(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Opens the logger from a launcher screen, on a tall surface.
    Future<void> openLogger(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppScope(
          services: AppServices(
            database: db,
            vault: vault,
            reindexer: reindexer,
          ),
          child: MaterialApp(
            home: _LoggerLauncher(
              backdateTo: past,
              onResult: (saved) => result = saved,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open logger'));
      await pumpFrames(tester);
    }

    Future<void> addExercise(WidgetTester tester, String name) async {
      final add = find.text('Add exercise');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.text('OK'));
      await pumpFrames(tester);
    }

    /// Taps [target] (a stepper value), types [value] into the number prompt
    /// it opens and confirms.
    Future<void> enterNumber(
      WidgetTester tester,
      Finder target,
      String value,
    ) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text('Set'));
      await pumpFrames(tester);
    }

    testWidgets('a valid manual workout is saved once and the logger closes',
        (tester) async {
      await openLogger(tester);
      expect(find.byType(Checkbox), findsNothing);

      // Deadlift: 80 kg x 8. (Only one row exists, so 'kg' and 'reps' are the
      // unit labels under its two steppers.)
      await addExercise(tester, 'Deadlift');
      await enterNumber(tester, find.text('kg'), '80');
      await enterNumber(tester, find.text('reps'), '8');

      // Pull-ups: bodyweight with no added load, 12 reps. The second
      // exercise's controls are the last matches.
      await addExercise(tester, 'Pull-ups');
      final bodyweight = find.text('Bodyweight').last;
      await tester.ensureVisible(bodyweight);
      await tester.tap(bodyweight);
      await tester.pump();
      expect(find.text('BW+0kg'), findsOneWidget);
      await enterNumber(tester, find.text('reps').last, '12');

      // Nothing is blocking and nothing needs confirming.
      await tester.tap(find.text('Finish'));
      await pumpFrames(tester);
      expect(find.text('Fix these sets'), findsNothing);

      // Let the route finish popping and the snackbar's timer and exit
      // animation run out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));

      expect(result, isTrue);
      expect(find.byType(WorkoutSessionPage), findsNothing);
      expect(reindexer.calls, 1);

      // Exactly one note, with exactly what was entered.
      expect(vault.saved, hasLength(1));
      final session = vault.saved.single;
      expect(session.split, 'Push Day A');
      expect(session.exercises.map((e) => e.name), ['Deadlift', 'Pull-ups']);

      final deadlift = session.exercises[0].sets.single;
      expect(deadlift.isBodyweight, isFalse);
      expect(deadlift.weightKg, 80);
      expect(deadlift.reps, 8);
      final pullUp = session.exercises[1].sets.single;
      expect(pullUp.isBodyweight, isTrue);
      expect(pullUp.extraWeightKg, 0);
      expect(pullUp.reps, 12);
      expect(session.totalVolumeKg, 640); // 80 x 8; bodyweight adds nothing

      // A manual entry: picked start, default duration, date_logged = save time.
      expect(session.startTime, past.toUtc());
      expect(session.timeStarted, '18:30');
      expect(session.durationMin, kDefaultManualDurationMin.toDouble());
      expect(session.dateLogged!.isBefore(session.startTime!), isFalse);
      expect(session.dateLogged, isNot(session.startTime));

      // The note it would write round-trips.
      final md = FilePersistenceService.renderWorkout(session);
      expect(md, contains('- Set 1: 80kg x 8 reps | Type: N'));
      expect(md, contains('- Set 1: BW+0kg x 12 reps | Type: N'));
      expect(
        FilePersistenceService.renderWorkout(
          FilePersistenceService.parseWorkout(md),
        ),
        md,
      );
    });

    testWidgets('deleting the only set before finishing leaves nothing to save',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');
      expect(find.byType(SetRow), findsOneWidget);

      // Delete the still-unentered row from its set menu.
      await tester.tap(find.byTooltip('Set type'));
      await pumpFrames(tester);
      await tester.tap(find.text('Delete set'));
      await pumpFrames(tester);
      expect(find.byType(SetRow), findsNothing);
      expect(find.text('Deadlift'), findsOneWidget);

      // The deleted row's problems are gone; there is simply nothing to save.
      await tester.tap(find.text('Finish'));
      await pumpFrames(tester);
      expect(find.text('Fix these sets'), findsNothing);
      expect(find.text('No sets logged'), findsOneWidget);

      // Cancel keeps the logger open and saves nothing.
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(find.text('No sets logged'), findsNothing);
      expect(find.byType(WorkoutSessionPage), findsOneWidget);
      expect(vault.saved, isEmpty);

      // Discard leaves without saving or re-indexing.
      await tester.tap(find.text('Finish'));
      await pumpFrames(tester);
      await tester.tap(find.text('Discard'));
      await pumpFrames(tester);
      await tester.pump();
      expect(find.byType(WorkoutSessionPage), findsNothing);
      expect(result, isFalse);
      expect(vault.saved, isEmpty);
      expect(reindexer.calls, 0);
    });
  });

  group('reps stepper', () {
    testWidgets('one tap on -1 removes exactly one rep and stops at 0',
        (tester) async {
      final draft = WorkoutDraft(split: 'Push Day A');
      addTearDown(draft.dispose);
      draft.addExercise('Deadlift');
      final exercise = draft.exercises.single;
      final set = exercise.sets.single; // live default: 0 kg x 8 reps
      expect(set.reps, 8);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: draft,
              builder: (context, _) => SetRow(
                set: set,
                number: 1,
                draft: draft,
                exercise: exercise,
                onToggleDone: () {},
                onPlates: (_) {},
              ),
            ),
          ),
        ),
      );

      var notifications = 0;
      draft.addListener(() => notifications++);

      /// One tap on the reps "−1" button. Returns how many times the draft
      /// notified, so a duplicated mutation would show up as 2, not 1.
      Future<int> tapMinus() async {
        final before = notifications;
        await tester.tap(find.text('\u22121'));
        await tester.pump();
        return notifications - before;
      }

      // 8 -> 7 -> 6, one rep per tap, one notification per tap.
      expect(await tapMinus(), 1);
      expect(set.reps, 7);
      expect(find.text('7'), findsOneWidget);

      expect(await tapMinus(), 1);
      expect(set.reps, 6);
      expect(find.text('6'), findsOneWidget);

      // From 1 the next tap reaches 0, and a further tap stays at 0.
      draft.mutate(() => set.reps = 1);
      await tester.pump();

      expect(await tapMinus(), 1);
      expect(set.reps, 0);

      expect(await tapMinus(), 1);
      expect(set.reps, 0);
      expect(find.text('-1'), findsNothing);

      // Only reps changed: the load is untouched.
      expect(set.weightKg, 0);
    });
  });

  group('SetRow on a narrow phone (360 x 800)', () {
    // 360 x 800 logical pixels, devicePixelRatio 1.0 (physical == logical).
    void useNarrowPhone(WidgetTester tester) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    /// One exercise with three rows: a plain weighted set, a copy of it, and
    /// the widest set the logger can show (bodyweight + added load, a hold,
    /// RPE, box height and contact time), so the control row has to wrap.
    WorkoutDraft draftWithWideRows({required bool manual}) {
      final draft = manual ? _manualDraft() : WorkoutDraft(split: 'Push Day A');
      addTearDown(draft.dispose);
      draft.addExercise('Barbell Bench Press');
      final exercise = draft.exercises.single;
      exercise.sets.first
        ..weightKg = 80
        ..reps = 8;
      draft.addSet(exercise);
      draft.addSet(exercise);
      exercise.sets.last
        ..isBodyweight = true
        ..extraWeightKg = 22.5
        ..isHold = true
        ..durationSeconds = 120
        ..rpe = 8.5
        ..boxHeightCm = 60
        ..contactTimeMs = 210;
      return draft;
    }

    /// Pumps the rows inside a Scaffold and list as the session page does.
    /// The horizontal inset mirrors the page: 16 list padding + 10 card
    /// padding + 1 card border. Fixed frames, not pumpAndSettle.
    Future<void> pumpRows(WidgetTester tester, WorkoutDraft draft) async {
      final exercise = draft.exercises.single;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: draft,
              builder: (context, _) => ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 27, vertical: 8),
                children: [
                  for (var i = 0; i < exercise.sets.length; i++)
                    SetRow(
                      key: ObjectKey(exercise.sets[i]),
                      set: exercise.sets[i],
                      number: i + 1,
                      draft: draft,
                      exercise: exercise,
                      onToggleDone: () {},
                      onPlates: (_) {},
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// A RenderFlex overflow is reported as a FlutterError, which the test
    /// binding records. takeException() returns it, so a failure names the
    /// overflow instead of only failing the test at the end.
    void expectNoLayoutErrors(WidgetTester tester) {
      expect(tester.takeException(), isNull);
    }

    void expectRowsFitScreen(WidgetTester tester, int rows) {
      final sets = find.byType(SetRow);
      expect(sets, findsNWidgets(rows));
      for (var i = 0; i < rows; i++) {
        final rect = tester.getRect(sets.at(i));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }
    }

    testWidgets('live rows lay out without overflow', (tester) async {
      useNarrowPhone(tester);
      final draft = draftWithWideRows(manual: false);
      await pumpRows(tester, draft);

      expectNoLayoutErrors(tester);
      expectRowsFitScreen(tester, 3);
      // Live rows keep their completion checkbox.
      expect(find.byType(Checkbox), findsNWidgets(3));

      // Opening the RPE slider adds another row of controls.
      await tester.tap(find.textContaining('RPE  8.5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Slider), findsOneWidget);
      expectNoLayoutErrors(tester);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('manual rows (no checkbox) lay out without overflow',
        (tester) async {
      useNarrowPhone(tester);
      final draft = draftWithWideRows(manual: true);
      await pumpRows(tester, draft);

      expectNoLayoutErrors(tester);
      expectRowsFitScreen(tester, 3);
      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(find.textContaining('RPE  8.5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Slider), findsOneWidget);
      expectNoLayoutErrors(tester);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('manual save and re-index', () {
    late Directory tmp;
    late FilePersistenceService vault;
    late AppDatabase db;
    late VaultReindexerService reindexer;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('obsidianfit_manual_');
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

    WorkoutDraft validManualDraft() {
      final draft = _manualDraft();
      _addRow(draft, 'Pull-ups')
        ..isBodyweight = true
        ..reps = 12;
      _addRow(draft, 'Plank')
        ..isBodyweight = true
        ..isHold = true
        ..durationSeconds = 60;
      _addRow(draft, 'Bench Press')
        ..weightKg = 80
        ..reps = 8;
      return draft;
    }

    test('one valid note is written, round-trips and is indexed', () async {
      final draft = validManualDraft();
      expect(draft.validateForSave(), isEmpty);

      final session = draft.toSession(DateTime(2026, 10, 22, 14, 5, 12));
      final file = await vault.saveWorkout(session);
      final md = file.readAsStringSync();

      expect(md, contains('- Set 1: BW+0kg x 12 reps | Type: N'));
      expect(md, contains('- Set 1: BW+0kg | Hold: 60s | Type: N'));
      expect(md, contains('- Set 1: 80kg x 8 reps | Type: N'));
      expect(md, isNot(contains('- Set 1: 0kg')));
      expect(
        FilePersistenceService.renderWorkout(
          FilePersistenceService.parseWorkout(md),
        ),
        md,
      );

      final report = await reindexer.reindex();
      expect(report.upserted, 1);
      final rows = await db.select(db.workoutsIndex).get();
      expect(rows, hasLength(1));
      expect(rows.single.split, 'Push Day A');
      expect(
        [rows.single.date.year, rows.single.date.month, rows.single.date.day],
        [2026, 10, 18],
      );
      expect(
        vault.relativePath(file),
        startsWith('Workouts/2026-10-18_1830_Push_Day_A'),
      );
      draft.dispose();
    });

    test('saving the same session again never overwrites the first note',
        () async {
      final draft = validManualDraft();
      final session = draft.toSession(DateTime(2026, 10, 22, 14, 5, 12));

      final first = await vault.saveWorkout(session);
      final firstText = first.readAsStringSync();
      final second = await vault.saveWorkout(session);

      expect(second.path, isNot(first.path));
      expect(second.path, endsWith('_2.md'));
      expect(first.readAsStringSync(), firstText);
      draft.dispose();
    });
  });
}
