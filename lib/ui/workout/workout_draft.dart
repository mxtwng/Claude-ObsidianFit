/// Mutable, in-progress workout that the logger UI edits. Converted to an
/// immutable [WorkoutSession] when the user finishes.
library;

import 'package:flutter/foundation.dart';

import '../../models/Models.dart';

class DraftSet {
  DraftSet({
    this.weightKg = 0,
    this.reps = 8,
    this.rpe,
    this.type = SetType.normal,
    this.done = false,
  });

  double weightKg;
  int reps;

  /// Null until the user touches the RPE slider.
  double? rpe;
  SetType type;
  bool done;
}

class DraftExercise {
  DraftExercise({required this.name, List<DraftSet>? sets})
      : sets = sets ?? [DraftSet()];

  String name;
  final List<DraftSet> sets;
}

class WorkoutDraft extends ChangeNotifier {
  WorkoutDraft({required this.split}) : startedAt = DateTime.now();

  String split;
  final DateTime startedAt;
  final List<DraftExercise> exercises = [];

  bool get hasContent => exercises.isNotEmpty;

  int get completedSets => exercises.fold(
        0,
        (n, e) => n + e.sets.where((s) => s.done).length,
      );

  int get pendingSets => exercises.fold(
        0,
        (n, e) => n + e.sets.where((s) => !s.done).length,
      );

  /// Apply [change] and notify listeners once.
  void mutate(VoidCallback change) {
    change();
    notifyListeners();
  }

  void addExercise(String name) =>
      mutate(() => exercises.add(DraftExercise(name: _clean(name))));

  void removeExercise(DraftExercise e) => mutate(() => exercises.remove(e));

  /// New set starts from the previous set's weight and reps.
  void addSet(DraftExercise e) => mutate(() {
        final last = e.sets.isEmpty ? null : e.sets.last;
        e.sets.add(
          DraftSet(weightKg: last?.weightKg ?? 0, reps: last?.reps ?? 8),
        );
      });

  void removeSet(DraftExercise e, DraftSet s) => mutate(() => e.sets.remove(s));

  /// Only completed sets are saved; exercises with none are dropped.
  WorkoutSession toSession(DateTime finishedAt) {
    final saved = <ExerciseEntry>[];
    for (final e in exercises) {
      final sets = <SetEntry>[
        for (final s in e.sets)
          if (s.done)
            SetEntry(
              weightKg: s.weightKg,
              reps: s.reps,
              rpe: s.rpe,
              type: s.type,
            ),
      ];
      if (sets.isNotEmpty) {
        saved.add(ExerciseEntry(name: _clean(e.name), sets: sets));
      }
    }

    final name = _clean(split).isEmpty ? 'Workout' : _clean(split);
    final minutes = finishedAt.difference(startedAt).inSeconds / 60;
    final hh = startedAt.hour.toString().padLeft(2, '0');
    final mm = startedAt.minute.toString().padLeft(2, '0');
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final session = WorkoutSession(
      split: name,
      date: DateTime(startedAt.year, startedAt.month, startedAt.day),
      timeStarted: '$hh:$mm',
      durationMin: (minutes < 1 ? 1 : minutes.round()).toDouble(),
      title: '$name Session',
      tags: ['fitness/gym', if (slug.isNotEmpty) 'split/$slug'],
      exercises: saved,
    );
    return session.copyWith(totalVolumeKg: session.computedVolumeKg());
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
