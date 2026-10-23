/// Mutable, in-progress workout that the logger UI edits. Converted to an
/// immutable [WorkoutSession] when the user finishes.
library;

import 'package:flutter/foundation.dart';

import '../../models/Models.dart';

/// Duration pre-filled when a session is logged after the fact.
const int kDefaultManualDurationMin = 60;

/// One set being edited. Covers every Phase 5 modality:
///
///  * weighted lift: [isBodyweight] false, [weightKg] x [reps];
///  * bodyweight / weighted bodyweight: [isBodyweight] true, load is
///    [extraWeightKg] (`BW+0kg`, `BW+10kg`) x [reps];
///  * isometric hold: [isHold] true, [durationSeconds] instead of [reps];
///  * plyometrics: any rep set with [boxHeightCm] / [contactTimeMs].
///
/// The inactive mode's value is kept (e.g. [weightKg] while bodyweight is on)
/// so toggling back and forth never loses what was typed.
class DraftSet {
  DraftSet({
    this.weightKg = 0,
    this.reps = 8,
    this.rpe,
    this.type = SetType.normal,
    this.done = false,
    this.isBodyweight = false,
    this.extraWeightKg = 0,
    this.isHold = false,
    this.durationSeconds = 30,
    this.boxHeightCm,
    this.contactTimeMs,
  });

  /// A new set that starts from [previous]'s load, reps / hold and modality.
  /// RPE, set type and the done flag start fresh.
  factory DraftSet.startingFrom(DraftSet previous) => DraftSet(
        weightKg: previous.weightKg,
        reps: previous.reps,
        isBodyweight: previous.isBodyweight,
        extraWeightKg: previous.extraWeightKg,
        isHold: previous.isHold,
        durationSeconds: previous.durationSeconds,
        boxHeightCm: previous.boxHeightCm,
        contactTimeMs: previous.contactTimeMs,
      );

  /// External load in kg (used when [isBodyweight] is false).
  double weightKg;
  int reps;

  /// Null until the user touches the RPE slider.
  double? rpe;
  SetType type;
  bool done;

  /// True when the load is the athlete's own bodyweight (`BW+<extra>kg`).
  bool isBodyweight;

  /// Added load on a bodyweight set; `0` is pure bodyweight.
  double extraWeightKg;

  /// True for an isometric hold: [durationSeconds] replaces [reps].
  bool isHold;
  int durationSeconds;

  /// Plyometric metadata, null when not recorded.
  double? boxHeightCm;
  int? contactTimeMs;

  /// The load that counts toward tonnage (added weight for bodyweight sets).
  double get loadKg => isBodyweight ? extraWeightKg : weightKg;

  /// Tonnage of this set; holds contribute `0`.
  double get volumeKg => isHold ? 0 : loadKg * reps;

  /// The immutable entry written to the note. A hold carries no reps, and a
  /// bodyweight set carries no external weight, as the schema requires.
  SetEntry toEntry() => SetEntry(
        weightKg: isBodyweight ? 0 : weightKg,
        reps: isHold ? null : reps,
        rpe: rpe,
        type: type,
        isBodyweight: isBodyweight,
        extraWeightKg: isBodyweight ? extraWeightKg : null,
        durationSeconds: isHold ? durationSeconds : null,
        boxHeightCm: boxHeightCm,
        contactTimeMs: contactTimeMs,
      );
}

class DraftExercise {
  DraftExercise({required this.name, List<DraftSet>? sets})
      : sets = sets ?? [DraftSet()];

  String name;
  final List<DraftSet> sets;
}

class WorkoutDraft extends ChangeNotifier {
  /// [startedAt] defaults to now (a live session). Pass it together with
  /// [manual] to log a session after the fact.
  WorkoutDraft({
    required this.split,
    DateTime? startedAt,
    bool manual = false,
  })  : startedAt = startedAt ?? DateTime.now(),
        isManual = manual;

  String split;

  /// Local start time. Live sessions use "now"; a backdated session uses the
  /// time the user picked.
  DateTime startedAt;

  /// True for a session logged after the fact (backdated). Its duration is
  /// typed in ([manualDurationMin]) instead of measured.
  bool isManual;
  int manualDurationMin = kDefaultManualDurationMin;

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

  /// Sets the session start. Picking a different start on a live session
  /// turns it into a backdated one (the elapsed clock no longer applies).
  void setStart(DateTime start) => mutate(() {
        startedAt = start;
        isManual = true;
      });

  void setManualDuration(int minutes) =>
      mutate(() => manualDurationMin = minutes < 1 ? 1 : minutes);

  void addExercise(String name) =>
      mutate(() => exercises.add(DraftExercise(name: _clean(name))));

  void removeExercise(DraftExercise e) => mutate(() => exercises.remove(e));

  /// New set starts from the previous set's load, reps / hold and modality.
  void addSet(DraftExercise e) => mutate(() {
        e.sets.add(
          e.sets.isEmpty ? DraftSet() : DraftSet.startingFrom(e.sets.last),
        );
      });

  void removeSet(DraftExercise e, DraftSet s) => mutate(() => e.sets.remove(s));

  /// Only completed sets are saved; exercises with none are dropped.
  ///
  /// Timestamps: `start_time` is the session start in UTC. For a backdated
  /// session `date_logged` is [finishedAt] (when the note is written); for a
  /// live session both carry the start, per the schema ("live sessions write
  /// both with (nearly) the same value").
  WorkoutSession toSession(DateTime finishedAt) {
    final saved = <ExerciseEntry>[];
    for (final e in exercises) {
      final sets = <SetEntry>[
        for (final s in e.sets)
          if (s.done) s.toEntry(),
      ];
      if (sets.isNotEmpty) {
        saved.add(ExerciseEntry(name: _clean(e.name), sets: sets));
      }
    }

    // A session never starts in the future (the pickers clamp, this is the
    // belt-and-braces check).
    final started = startedAt.isAfter(finishedAt) ? finishedAt : startedAt;

    final name = _clean(split).isEmpty ? 'Workout' : _clean(split);
    final minutes = isManual
        ? manualDurationMin.toDouble()
        : (() {
            final m = finishedAt.difference(started).inSeconds / 60;
            return (m < 1 ? 1 : m.round()).toDouble();
          })();
    final hh = started.hour.toString().padLeft(2, '0');
    final mm = started.minute.toString().padLeft(2, '0');
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final startUtc = started.toUtc();
    final loggedUtc = isManual ? finishedAt.toUtc() : startUtc;

    final session = WorkoutSession(
      split: name,
      date: DateTime(started.year, started.month, started.day),
      timeStarted: '$hh:$mm',
      startTime: startUtc,
      dateLogged: loggedUtc,
      durationMin: minutes,
      title: '$name Session',
      tags: ['fitness/gym', if (slug.isNotEmpty) 'split/$slug'],
      exercises: saved,
    );
    return session.copyWith(totalVolumeKg: session.computedVolumeKg());
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
