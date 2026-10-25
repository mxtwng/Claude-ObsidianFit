// Soft warning on Finish for live sets that would be saved with no external
// weight (Bodyweight off, 0 kg).
//
// The detection rules are plain-Dart tests on WorkoutDraft. The Finish dialog
// is tested through the real logger screen with a vault that records saves
// instead of writing files (real file IO cannot complete under the widget
// tester's fake clock; writing and re-reading a note is covered elsewhere).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:obsidian_fit/services/app_database.dart';
import 'package:obsidian_fit/services/screen_awake.dart';
import 'package:obsidian_fit/services/vault_reindexer_service.dart';
import 'package:obsidian_fit/ui/app_services.dart';
import 'package:obsidian_fit/ui/workout/workout_draft.dart';
import 'package:obsidian_fit/ui/workout/workout_session_page.dart';

const String _weightMessage =
    'enter the weight, or turn on Bodyweight for no external load';
const String _warningTitle = 'No weight on some sets';

/// A vault that records what the logger saves instead of touching the disk.
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
/// the route returns (true = saved). A null [backdateTo] is a live session.
class _LoggerLauncher extends StatelessWidget {
  const _LoggerLauncher({this.backdateTo, required this.onResult});

  final DateTime? backdateTo;
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

/// Adds [name] to a live [draft] and replaces its default row with [sets].
void _addExercise(WorkoutDraft draft, String name, List<DraftSet> sets) {
  draft.addExercise(name);
  draft.exercises.last.sets
    ..clear()
    ..addAll(sets);
}

void main() {
  group('WorkoutDraft.zeroLoadWarnings', () {
    test('reports a checked set with no external weight, by row number', () {
      final draft = WorkoutDraft(split: 'Push Day A');
      addTearDown(draft.dispose);
      _addExercise(draft, 'Barbell Bench Press', [
        DraftSet(weightKg: 80, done: true),
        DraftSet(weightKg: 0, done: true),
      ]);

      final warnings = draft.zeroLoadWarnings();
      expect(warnings, hasLength(1));
      expect(warnings.single.exercise, 'Barbell Bench Press');
      expect(warnings.single.setNumber, 2);
      expect(
        warnings.single.toString(),
        'Barbell Bench Press · Set 2: no weight entered',
      );
    });

    test('ignores an unchecked set, and row numbers still count it', () {
      final draft = WorkoutDraft(split: 'Push Day A');
      addTearDown(draft.dispose);

      _addExercise(draft, 'Deadlift', [DraftSet(weightKg: 0, done: false)]);
      expect(draft.zeroLoadWarnings(), isEmpty);

      draft.exercises.last.sets.add(DraftSet(weightKg: 0, done: true));
      final warnings = draft.zeroLoadWarnings();
      expect(warnings, hasLength(1));
      expect(warnings.single.setNumber, 2);
    });

    test('weighted sets, bodyweight sets (BW+0kg) and holds are valid', () {
      final draft = WorkoutDraft(split: 'Calisthenics A');
      addTearDown(draft.dispose);
      _addExercise(draft, 'Squat', [DraftSet(weightKg: 20, done: true)]);
      _addExercise(draft, 'Pull-ups', [
        DraftSet(isBodyweight: true, extraWeightKg: 0, done: true),
        DraftSet(isBodyweight: true, extraWeightKg: 10, done: true),
      ]);
      _addExercise(draft, 'Plank', [
        DraftSet(
          isBodyweight: true,
          isHold: true,
          extraWeightKg: 0,
          durationSeconds: 45,
          done: true,
        ),
      ]);

      expect(draft.zeroLoadWarnings(), isEmpty);
      // The same rows are flagged only when they have no bodyweight mode.
      expect(DraftSet().hasNoExternalLoad, isTrue);
      expect(DraftSet(isBodyweight: true).hasNoExternalLoad, isFalse);
      expect(DraftSet(weightKg: 20).hasNoExternalLoad, isFalse);
    });

    test('does not warn for a draft opened as a manual entry', () {
      final draft = WorkoutDraft(
        split: 'Push Day A',
        startedAt: DateTime(2026, 10, 18, 18, 30),
        manual: true,
      );
      addTearDown(draft.dispose);
      draft.addExercise('Deadlift');
      draft.exercises.last.sets.single.reps = 8;

      expect(draft.zeroLoadWarnings(), isEmpty);
      // Manual validation is the hard rule and is unchanged.
      final issues = draft.validateForSave();
      expect(issues, hasLength(1));
      expect(issues.single.message, _weightMessage);
    });

    test('a live draft that was backdated still warns about ticked sets', () {
      final draft = WorkoutDraft(split: 'Push Day A');
      addTearDown(draft.dispose);
      _addExercise(draft, 'Deadlift', [DraftSet(weightKg: 0, done: true)]);

      expect(draft.setStart(DateTime(2020, 1, 15, 18, 30)), isTrue);
      expect(draft.isManual, isTrue);
      expect(draft.recordsAllSets, isFalse);
      expect(draft.zeroLoadWarnings(), hasLength(1));
      expect(draft.validateForSave(), isEmpty);
    });

    test('detecting a zero-weight set never converts it to bodyweight', () {
      final draft = WorkoutDraft(split: 'Push Day A');
      addTearDown(draft.dispose);
      final set = DraftSet(weightKg: 0, done: true);
      _addExercise(draft, 'Deadlift', [set]);

      expect(draft.zeroLoadWarnings(), hasLength(1));
      expect(set.isBodyweight, isFalse);
      expect(set.weightKg, 0);

      final saved =
          draft.toSession(DateTime.now()).exercises.single.sets.single;
      expect(saved.isBodyweight, isFalse);
      expect(saved.weightKg, 0);
      expect(saved.extraWeightKg, isNull);
    });
  });

  group('live logger: zero-weight warning on Finish', () {
    final past = DateTime(2026, 10, 18, 18, 30);

    late _RecordingVault vault;
    late AppDatabase db;
    late _CountingReindexer reindexer;
    bool? result;

    setUp(() async {
      // ScreenAwake keeps its requested state in a static.
      await ScreenAwake.disable();
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

    // Fixed frames, not pumpAndSettle: a live session's elapsed clock and
    // rest timer tick.
    Future<void> pumpFrames(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Lets the route finish popping and the snackbar run out.
    Future<void> pumpUntilClosed(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> openLogger(WidgetTester tester, {DateTime? backdateTo}) async {
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
              backdateTo: backdateTo,
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

    /// Ticks the completion checkbox of the [index]th set row.
    Future<void> tickSet(WidgetTester tester, int index) async {
      final box = find.byType(Checkbox).at(index);
      await tester.ensureVisible(box);
      await tester.tap(box);
      // Pump one frame: ticking a live set starts a ticking rest timer.
      await tester.pump();
    }

    /// Taps the app bar's Finish button (call only while no dialog is open).
    Future<void> tapFinish(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await pumpFrames(tester);
    }

    testWidgets('a checked zero-weight set triggers the warning',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');
      await tickSet(tester, 0); // 0 kg x 8, Bodyweight off

      await tapFinish(tester);

      expect(find.text(_warningTitle), findsOneWidget);
      expect(find.text('• Deadlift · Set 1'), findsOneWidget);
      expect(find.text('Go back and fix'), findsOneWidget);
      expect(find.text('Save anyway'), findsOneWidget);
      // Nothing is written until the user decides.
      expect(vault.saved, isEmpty);
      expect(reindexer.calls, 0);
    });

    testWidgets('an unchecked zero-weight set does not trigger it',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');
      final addSet = find.text('Add set');
      await tester.ensureVisible(addSet);
      await tester.tap(addSet);
      await tester.pump();
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Row 1: 80 kg, checked. Row 2: still 0 kg and left unchecked.
      await enterNumber(tester, find.text('kg').first, '80');
      await tickSet(tester, 0);

      await tapFinish(tester);
      // Only the existing "not checked off" confirmation appears.
      expect(find.text('Finish workout?'), findsOneWidget);
      expect(find.text(_warningTitle), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Finish'),
        ),
      );
      await pumpFrames(tester);
      expect(find.text(_warningTitle), findsNothing);

      await pumpUntilClosed(tester);
      expect(vault.saved, hasLength(1));
      final sets = vault.saved.single.exercises.single.sets;
      expect(sets, hasLength(1));
      expect(sets.single.weightKg, 80);
    });

    testWidgets('Go back and fix leaves the workout open and saves nothing',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');
      await tickSet(tester, 0);
      await tapFinish(tester);
      expect(find.text(_warningTitle), findsOneWidget);

      await tester.tap(find.text('Go back and fix'));
      await pumpFrames(tester);

      expect(find.text(_warningTitle), findsNothing);
      expect(find.byType(WorkoutSessionPage), findsOneWidget);
      expect(result, isNull); // the route was not popped
      expect(vault.saved, isEmpty);
      expect(reindexer.calls, 0);

      // The draft is unchanged: still checked, not turned into bodyweight.
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(find.text('Bodyweight'), findsOneWidget);
      // And Finish is usable again (not stuck saving).
      final finish = find.widgetWithText(FilledButton, 'Finish');
      expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
    });

    testWidgets('fixing the weight after Go back saves without a warning',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');
      await tickSet(tester, 0);
      await tapFinish(tester);
      await tester.tap(find.text('Go back and fix'));
      await pumpFrames(tester);

      await enterNumber(tester, find.text('kg'), '80');
      await tapFinish(tester);
      expect(find.text(_warningTitle), findsNothing);

      await pumpUntilClosed(tester);
      expect(result, isTrue);
      expect(vault.saved, hasLength(1));
      expect(vault.saved.single.exercises.single.sets.single.weightKg, 80);
    });

    testWidgets('Save anyway saves exactly once and closes the session',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');
      await tickSet(tester, 0);
      await tapFinish(tester);
      expect(find.text(_warningTitle), findsOneWidget);

      await tester.tap(find.text('Save anyway'));
      await pumpFrames(tester);
      // The warning is not shown a second time on the way to the save.
      expect(find.text(_warningTitle), findsNothing);

      await pumpUntilClosed(tester);
      expect(result, isTrue);
      expect(find.byType(WorkoutSessionPage), findsNothing);
      expect(find.text(_warningTitle), findsNothing);
      expect(vault.saved, hasLength(1));
      expect(reindexer.calls, 1);

      // Saved as entered: never silently converted to bodyweight.
      final set = vault.saved.single.exercises.single.sets.single;
      expect(set.isBodyweight, isFalse);
      expect(set.weightKg, 0);
      expect(set.reps, 8);
    });

    testWidgets('bodyweight sets (BW+0kg) and bodyweight holds do not warn',
        (tester) async {
      await openLogger(tester);

      await addExercise(tester, 'Pull-ups');
      final bodyweight = find.text('Bodyweight');
      await tester.ensureVisible(bodyweight);
      await tester.tap(bodyweight);
      await tester.pump();
      expect(find.text('BW+0kg'), findsOneWidget);
      await tickSet(tester, 0);

      // A hold with no external weight becomes a bodyweight hold (BW+0kg).
      await addExercise(tester, 'Plank');
      final hold = find.text('Hold').last;
      await tester.ensureVisible(hold);
      await tester.tap(hold);
      await tester.pump();
      expect(find.text('BW+0kg'), findsNWidgets(2));
      await tickSet(tester, 1);

      await tapFinish(tester);
      expect(find.text(_warningTitle), findsNothing);

      await pumpUntilClosed(tester);
      expect(result, isTrue);
      expect(vault.saved, hasLength(1));
      final pullUp = vault.saved.single.exercises[0].sets.single;
      expect(pullUp.isBodyweight, isTrue);
      expect(pullUp.extraWeightKg, 0);
      final plank = vault.saved.single.exercises[1].sets.single;
      expect(plank.isBodyweight, isTrue);
      expect(plank.durationSeconds, 30);
      expect(plank.reps, isNull);
    });

    testWidgets('set completion and rest timer are not interrupted',
        (tester) async {
      await openLogger(tester);
      await addExercise(tester, 'Deadlift');

      // Completing a zero-weight set shows no warning and starts rest as
      // before.
      await tickSet(tester, 0);
      expect(find.text(_warningTitle), findsNothing);
      expect(find.byTooltip('Skip rest'), findsOneWidget);

      // The warning on Finish leaves the running rest timer alone.
      await tapFinish(tester);
      expect(find.text(_warningTitle), findsOneWidget);
      await tester.tap(find.text('Go back and fix'));
      await pumpFrames(tester);
      expect(find.byTooltip('Skip rest'), findsOneWidget);
    });

    testWidgets('manual entry keeps its hard validation and gets no warning',
        (tester) async {
      await openLogger(tester, backdateTo: past);
      expect(find.byType(Checkbox), findsNothing);
      await addExercise(tester, 'Deadlift');
      await enterNumber(tester, find.text('reps'), '8'); // weight left at 0

      await tapFinish(tester);

      expect(find.text('Fix these sets'), findsOneWidget);
      expect(find.textContaining(_weightMessage), findsOneWidget);
      expect(find.text(_warningTitle), findsNothing);
      expect(find.text('Save anyway'), findsNothing);
      expect(vault.saved, isEmpty);
    });
  });
}
