import 'SetEntry.dart';

/// One exercise block (`## Barbell Bench Press`) and its ordered sets.
class ExerciseEntry {
  const ExerciseEntry({
    required this.name,
    this.sets = const [],
    this.notes = '',
  });

  final String name;
  final List<SetEntry> sets;

  /// Any non-set free text found under the exercise heading, preserved
  /// verbatim so hand-edited notes survive a round trip.
  final String notes;

  /// Tonnage of the exercise (sum of each set's `loadKg x reps`). Bodyweight
  /// and hold sets add only their extra weight x reps, so they often add `0`.
  double volumeKg({bool includeWarmups = false}) => sets
      .where((s) => includeWarmups || s.type != SetType.warmup)
      .fold(0.0, (sum, s) => sum + s.computedVolumeKg);

  ExerciseEntry copyWith({String? name, List<SetEntry>? sets, String? notes}) {
    return ExerciseEntry(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'ExerciseEntry($name, ${sets.length} sets)';
}
