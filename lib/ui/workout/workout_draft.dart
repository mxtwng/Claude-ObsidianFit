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

  /// A row for a manual (historical) entry with nothing entered yet: no load,
  /// no reps, no hold time. [problems] reports it until the user fills it in,
  /// so the logger's usual defaults (0 kg x 8 reps, 30 s) are never saved as
  /// if they were recorded results.
  factory DraftSet.blank() => DraftSet(reps: 0, durationSeconds: 0);

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

  /// Why this set cannot be saved as a recorded result; empty when it can.
  ///
  /// The rules follow the set's modality
  /// (`schemas/workout_schema.phase5.md`, section 2), not one rule for all:
  ///
  ///  * **hold**: [durationSeconds] >= 1 (a hold has no reps);
  ///  * **every other set**: [reps] >= 1 (jump count for plyometrics);
  ///  * **external load** ([isBodyweight] false): [weightKg] > 0;
  ///  * **bodyweight**: added load >= 0, so `BW+0kg` (pure bodyweight) is valid;
  ///  * optional box height / contact time must be > 0 when present;
  ///  * optional RPE must be within 1-10 when present.
  List<String> problems() {
    final out = <String>[];
    if (isHold) {
      if (durationSeconds < 1) {
        out.add('enter a hold time of at least 1 second');
      }
    } else if (reps < 1) {
      out.add('enter at least 1 rep');
    }
    if (isBodyweight) {
      if (extraWeightKg < 0) out.add('added weight cannot be negative');
    } else if (weightKg <= 0) {
      out.add('enter the weight, or turn on Bodyweight for no external load');
    }
    final box = boxHeightCm;
    if (box != null && box <= 0) out.add('box height must be above 0 cm');
    final contact = contactTimeMs;
    if (contact != null && contact <= 0) {
      out.add('contact time must be above 0 ms');
    }
    final r = rpe;
    if (r != null && (r < 1 || r > 10)) out.add('RPE must be between 1 and 10');
    return out;
  }

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

/// A set that blocks saving a manual workout, with where to find it.
class DraftSetIssue {
  const DraftSetIssue({
    required this.exercise,
    required this.setNumber,
    required this.message,
  });

  final String exercise;

  /// 1-based, as shown on the set row.
  final int setNumber;
  final String message;

  @override
  String toString() => '$exercise · Set $setNumber: $message';
}

class WorkoutDraft extends ChangeNotifier {
  /// [startedAt] defaults to now (a live session). Pass it together with
  /// [manual] to log a session after the fact.
  ///
  /// A draft created with [manual] records every row as a set that happened
  /// ([recordsAllSets]); a live draft saves only the sets ticked off.
  ///
  /// [clock] supplies "now" (default: the system clock). Tests pass a fixed
  /// one so elapsed time is exact.
  WorkoutDraft({
    required this.split,
    DateTime? startedAt,
    bool manual = false,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        startedAt = startedAt ?? (clock ?? DateTime.now)(),
        isManual = manual,
        recordsAllSets = manual;

  final DateTime Function() _clock;

  String split;

  /// Local start time. Live sessions use "now"; a backdated session uses the
  /// time the user picked.
  DateTime startedAt;

  /// True for a session logged after the fact (backdated). Its duration is
  /// typed in ([manualDurationMin]) instead of measured.
  bool isManual;
  int manualDurationMin = kDefaultManualDurationMin;

  /// True when every row is a recorded set and no completion checkbox is
  /// used (a session that was *opened* as a manual entry). Fixed at creation:
  /// a live draft that is later backdated via [setStart] keeps its
  /// checkboxes, so sets it never ticked are not promoted to results.
  final bool recordsAllSets;

  /// Whether [s] is written to the note.
  bool includes(DraftSet s) => recordsAllSets || s.done;

  final List<DraftExercise> exercises = [];

  bool get hasContent => exercises.isNotEmpty;

  /// Sets that will be saved (every row for a manual entry, else the ticked
  /// ones).
  int get completedSets => exercises.fold(
        0,
        (n, e) => n + e.sets.where(includes).length,
      );

  /// Sets that will be left out (always 0 for a manual entry).
  int get pendingSets => exercises.fold(
        0,
        (n, e) => n + e.sets.where((s) => !includes(s)).length,
      );

  /// Problems that must be fixed (or the set deleted) before a manual entry
  /// can be saved. Empty for a live draft, whose ticked sets are the user's
  /// confirmation.
  List<DraftSetIssue> validateForSave() {
    if (!recordsAllSets) return const [];
    return [
      for (final e in exercises)
        for (var i = 0; i < e.sets.length; i++)
          for (final message in e.sets[i].problems())
            DraftSetIssue(
              exercise: _clean(e.name),
              setNumber: i + 1,
              message: message,
            ),
    ];
  }

  /// Apply [change] and notify listeners once.
  void mutate(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// Sets the session start; returns whether it was applied.
  ///
  /// A live session can only be moved *earlier*: a start at or after its real
  /// one is refused (returns false, nothing changes), so it can never become a
  /// backdated session that starts after the workout actually began.
  ///
  /// Moving a live session earlier turns it into a backdated one (the elapsed
  /// clock no longer applies). The time the clock had measured up to that
  /// moment becomes [manualDurationMin] rather than the 60 min default, and
  /// stays editable. Once backdated, the start can be moved freely.
  bool setStart(DateTime start) {
    if (!isManual && !start.isBefore(startedAt)) return false;
    mutate(() {
      if (!isManual) {
        manualDurationMin = _elapsedMinutes(startedAt, _clock());
      }
      startedAt = start;
      isManual = true;
    });
    return true;
  }

  void setManualDuration(int minutes) =>
      mutate(() => manualDurationMin = minutes < 1 ? 1 : minutes);

  void addExercise(String name) => mutate(
        () => exercises.add(
          DraftExercise(
            name: _clean(name),
            sets: recordsAllSets ? [DraftSet.blank()] : null,
          ),
        ),
      );

  void removeExercise(DraftExercise e) => mutate(() => exercises.remove(e));

  /// New set starts from the previous set's load, reps / hold and modality.
  void addSet(DraftExercise e) => mutate(() {
        e.sets.add(
          e.sets.isEmpty
              ? (recordsAllSets ? DraftSet.blank() : DraftSet())
              : DraftSet.startingFrom(e.sets.last),
        );
      });

  void removeSet(DraftExercise e, DraftSet s) => mutate(() => e.sets.remove(s));

  /// Saves the sets [includes] selects (ticked sets for a live draft, every
  /// row for a manual one, which the caller validates with [validateForSave]
  /// first); exercises with none are dropped.
  ///
  /// Timestamps: `start_time` is the session start in UTC. For a backdated
  /// session `date_logged` is [finishedAt] (when the note is written); for a
  /// live session both carry the start, per the schema ("live sessions write
  /// both with (nearly) the same value"). A live session backdated with
  /// [setStart] counts as backdated: its `date_logged` is [finishedAt], never
  /// the picked start.
  WorkoutSession toSession(DateTime finishedAt) {
    final saved = <ExerciseEntry>[];
    for (final e in exercises) {
      final sets = <SetEntry>[
        for (final s in e.sets)
          if (includes(s)) s.toEntry(),
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
        : _elapsedMinutes(started, finishedAt).toDouble();
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

  /// Whole minutes from [from] to [to], rounded, never below 1 (the same
  /// rule a live session's saved duration uses).
  static int _elapsedMinutes(DateTime from, DateTime to) {
    final m = to.difference(from).inSeconds / 60;
    return m < 1 ? 1 : m.round();
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
