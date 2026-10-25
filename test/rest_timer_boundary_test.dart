import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/services/screen_awake.dart';
import 'package:obsidian_fit/ui/workout/workout_draft.dart';
import 'package:obsidian_fit/ui/workout/workout_session_page.dart';

void main() {
  // ScreenAwake keeps its requested state in a static, so start every test
  // from "released".
  setUp(() async {
    await ScreenAwake.disable();
  });
  Future<void> openSession(
    WidgetTester tester, {
    DateTime? backdateTo,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutSessionPage(
          split: 'Push Day A',
          backdateTo: backdateTo,
        ),
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

  Future<void> toggleFirstSet(WidgetTester tester) async {
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    // A live rest timer intentionally ticks periodically, so pump one frame
    // instead of waiting for pumpAndSettle to observe a settled timer.
    await tester.pump();
  }

  // The date every backdating test picks, as the card's date button shows
  // it. 15 Jan 2020 is always in the past, so the picker never clamps it.
  const pickedDate = 'Wed, 15 Jan 2020';

  // Test logical size: 800 x 1200 (devicePixelRatio 1.0, so physical ==
  // logical). Wide enough for the session-time card's duration row, which the
  // test font (Ahem, every glyph a full square) makes much wider than a real
  // font would, and tall enough to keep the whole date-picker dialog on
  // screen. Same width as the default 800 x 600 test surface.
  void useTallSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Fixed frames, not pumpAndSettle: the live elapsed clock ticks.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Backdates the open live session to [pickedDate] through the real
  /// Backdate button and date picker, and asserts the start really moved.
  ///
  /// The date is typed in the picker's input mode: no month paging and no day
  /// cell that may be off screen or hidden mid-animation.
  Future<void> backdateThroughPicker(WidgetTester tester) async {
    expect(find.textContaining('Backdated'), findsNothing);

    final backdate = find.text('Backdate');
    await tester.ensureVisible(backdate);
    await tester.tap(backdate);
    await settle(tester);
    expect(find.text(pickedDate), findsNothing);

    final dateButton = find.byIcon(Icons.calendar_today);
    await tester.ensureVisible(dateButton);
    await tester.tap(dateButton);
    await settle(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to input'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '01/15/2020');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.byType(DatePickerDialog), findsNothing);

    // The start time really moved to the past date.
    expect(find.text(pickedDate), findsOneWidget);
    expect(find.textContaining('Backdated · 15 Jan'), findsOneWidget);
  }

  testWidgets(
    'manual workout entry and corrections never start rest timer',
    (tester) async {
      await openSession(
        tester,
        backdateTo: DateTime(2026, 10, 18, 18, 30),
      );
      await addExercise(tester);

      // Manual rows have no completion checkbox, so there is nothing to tick.
      expect(find.byType(Checkbox), findsNothing);

      // Entering and correcting values (weight, reps, reps) must not start
      // rest either.
      for (final label in ['+2.5', '+1', '+1']) {
        final button = find.text(label).first;
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }
      expect(find.byTooltip('Skip rest'), findsNothing);
    },
  );

  testWidgets(
    'live workout set completion still starts rest timer',
    (tester) async {
      await openSession(tester);
      await addExercise(tester);

      await toggleFirstSet(tester);
      expect(find.byTooltip('Skip rest'), findsOneWidget);
    },
  );

  testWidgets(
    'backdating a live workout keeps its checkbox and never starts rest',
    (tester) async {
      useTallSurface(tester);

      // Opened as a live session: not a manual entry, no backdating yet.
      await openSession(tester);
      await backdateThroughPicker(tester);
      // ...but the draft was opened live, so a row still has its checkbox.
      await addExercise(tester);
      expect(find.byType(Checkbox), findsOneWidget);

      await toggleFirstSet(tester);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).value,
        isTrue,
      );
      expect(find.byTooltip('Skip rest'), findsNothing);
    },
  );

  testWidgets(
    'backdating a live workout stops its running rest timer',
    (tester) async {
      useTallSurface(tester);

      // Live session: complete a set, which starts rest.
      await openSession(tester);
      await addExercise(tester);
      await toggleFirstSet(tester);
      expect(find.byTooltip('Skip rest'), findsOneWidget);

      // Backdate it through the real UI.
      await backdateThroughPicker(tester);

      // The rest bar renders whenever the controller is running or finished,
      // collapsed or not. Its absence therefore means the timer was stopped,
      // not merely hidden: neither the collapsed bar nor the expanded sheet
      // (or its "Go!" / finished state) is on screen.
      expect(find.byTooltip('Skip rest'), findsNothing);
      expect(find.textContaining('Rest '), findsNothing);
      expect(find.text('Rest timer'), findsNothing);

      // Backdating kept the live-origin checkboxes and the completed set.
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      // Completing another set after backdating must not restart rest.
      final addSet = find.text('Add set');
      await tester.ensureVisible(addSet);
      await tester.tap(addSet);
      await tester.pump();
      expect(find.byType(Checkbox), findsNWidgets(2));

      final second = find.byType(Checkbox).at(1);
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pump();

      expect(
          tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value, isTrue);
      expect(
          tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, isTrue);
      expect(find.byTooltip('Skip rest'), findsNothing);
      expect(find.textContaining('Rest '), findsNothing);
    },
  );

  testWidgets(
    'backdating a live workout releases the screen wake lock for good',
    (tester) async {
      useTallSurface(tester);

      // A live session keeps the display on.
      await openSession(tester);
      expect(ScreenAwake.isRequested, isTrue);
      await addExercise(tester);
      await toggleFirstSet(tester);
      expect(ScreenAwake.isRequested, isTrue);

      // Backdating it releases the lock at once.
      await backdateThroughPicker(tester);
      expect(ScreenAwake.isRequested, isFalse);

      // Completing more sets afterwards must not take it back.
      final addSet = find.text('Add set');
      await tester.ensureVisible(addSet);
      await tester.tap(addSet);
      await tester.pump();

      final second = find.byType(Checkbox).at(1);
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pump();

      expect(
          tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, isTrue);
      expect(ScreenAwake.isRequested, isFalse);
    },
  );

  testWidgets(
    'a session opened already backdated never takes the screen wake lock',
    (tester) async {
      await openSession(
        tester,
        backdateTo: DateTime(2026, 10, 18, 18, 30),
      );
      expect(ScreenAwake.isRequested, isFalse);

      await addExercise(tester);
      expect(ScreenAwake.isRequested, isFalse);
    },
  );

  testWidgets(
    'backdating a live workout keeps the measured time, not the 60 min default',
    (tester) async {
      useTallSurface(tester);

      await openSession(tester);
      await backdateThroughPicker(tester);

      // Only moments have passed since the session opened: the stats bar and
      // the duration row show that (the minimum, 1 min), not the placeholder.
      expect(find.text('60 min'), findsNothing);
      expect(find.text('1 min'), findsWidgets);
    },
  );

  test('backdating a draft switches it to manual mode', () {
    final draft = WorkoutDraft(split: 'Push Day A');
    expect(draft.isManual, isFalse);

    draft.setStart(DateTime(2026, 10, 18, 18, 30));
    expect(draft.isManual, isTrue);

    draft.dispose();
  });
}
