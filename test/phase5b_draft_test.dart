import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:obsidian_fit/ui/workout/workout_draft.dart';

void main() {
  group('WorkoutDraft (Phase 5B)', () {
    test('backdated multi-modality session maps to the Phase 5 note format',
        () {
      final started = DateTime(2026, 10, 18, 7, 15);
      final finished = DateTime(2026, 10, 22, 14, 5, 12);

      final draft = WorkoutDraft(
        split: 'Calisthenics A',
        startedAt: started,
        manual: true,
      )..manualDurationMin = 48;

      draft.addExercise('Pull-ups');
      draft.exercises[0].sets[0]
        ..isBodyweight = true
        ..extraWeightKg = 10
        ..reps = 6
        ..done = true;

      draft.addExercise('Plank');
      draft.exercises[1].sets[0]
        ..isBodyweight = true
        ..isHold = true
        ..durationSeconds = 60
        ..done = true;

      draft.addExercise('Box Jumps');
      draft.exercises[2].sets[0]
        ..isBodyweight = true
        ..reps = 5
        ..boxHeightCm = 60
        ..contactTimeMs = 210
        ..done = true;

      final session = draft.toSession(finished);

      expect(session.durationMin, 48);
      expect(session.timeStarted, '07:15');
      expect(session.startTime, started.toUtc());
      expect(session.dateLogged, finished.toUtc());
      // Only added weight x reps counts: 10 kg x 6. Holds and pure bodyweight
      // jumps add nothing.
      expect(session.totalVolumeKg, 60);

      final md = FilePersistenceService.renderWorkout(session);
      expect(md, contains('- Set 1: BW+10kg x 6 reps | Type: N'));
      expect(md, contains('- Set 1: BW+0kg | Hold: 60s | Type: N'));
      expect(md, contains('Box: 60cm | Contact: 210ms | Type: N'));
      expect(
        md,
        matches(RegExp(r'start_time: "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"')),
      );
      expect(
        md,
        matches(RegExp(r'date_logged: "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"')),
      );

      final back = FilePersistenceService.parseWorkout(md);
      expect(back.startTime, session.startTime);
      expect(back.dateLogged, session.dateLogged);
      expect(back.exercises[1].sets.single.durationSeconds, 60);
      expect(back.exercises[1].sets.single.reps, isNull);
      expect(back.exercises[2].sets.single.boxHeightCm, 60);
    });

    test('live session writes the same instant for start_time and date_logged',
        () {
      final started = DateTime(2026, 10, 23, 18, 0);
      final draft = WorkoutDraft(split: 'Push Day A', startedAt: started);
      draft.addExercise('Barbell Bench Press');
      draft.exercises.single.sets.single
        ..weightKg = 80
        ..reps = 8
        ..done = true;

      final session = draft.toSession(started.add(const Duration(minutes: 52)));

      expect(session.durationMin, 52);
      expect(session.startTime, started.toUtc());
      expect(session.dateLogged, session.startTime);
      expect(session.totalVolumeKg, 640);
    });

    test('new sets inherit load, modality and plyometric data', () {
      final draft = WorkoutDraft(split: 'x');
      draft.addExercise('Plank');
      final first = draft.exercises.single.sets.single
        ..isBodyweight = true
        ..isHold = true
        ..durationSeconds = 45
        ..rpe = 8
        ..done = true;

      draft.addSet(draft.exercises.single);
      final second = draft.exercises.single.sets.last;

      expect(second, isNot(same(first)));
      expect(second.isBodyweight, isTrue);
      expect(second.isHold, isTrue);
      expect(second.durationSeconds, 45);
      expect(second.rpe, isNull);
      expect(second.done, isFalse);
      expect(second.type, SetType.normal);
    });
  });
}
