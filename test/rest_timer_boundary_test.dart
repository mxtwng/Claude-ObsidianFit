import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/ui/workout/workout_draft.dart';
import 'package:obsidian_fit/ui/workout/workout_session_page.dart';

void main() {
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
    await tester.pumpAndSettle();
  }

  Future<void> addExercise(WidgetTester tester) async {
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Deadlift');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> toggleFirstSet(WidgetTester tester) async {
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  }

  testWidgets('manual workout set completion never starts rest timer', (
    tester,
  ) async {
    await openSession(
      tester,
      backdateTo: DateTime(2026, 10, 18, 18, 30),
    );
    await addExercise(tester);

    await toggleFirstSet(tester);
    expect(find.byTooltip('Skip rest'), findsNothing);

    // Corrections to a historical entry must not start rest either.
    await toggleFirstSet(tester);
    await toggleFirstSet(tester);
    expect(find.byTooltip('Skip rest'), findsNothing);
  });

  testWidgets('live workout set completion still starts rest timer', (
    tester,
  ) async {
    await openSession(tester);
    await addExercise(tester);

    await toggleFirstSet(tester);
    expect(find.byTooltip('Skip rest'), findsOneWidget);
  });

  test('backdating a draft switches it to manual mode', () {
    final draft = WorkoutDraft(split: 'Push Day A');
    expect(draft.isManual, isFalse);

    draft.setStart(DateTime(2026, 10, 18, 18, 30));
    expect(draft.isManual, isTrue);

    draft.dispose();
  });
}
