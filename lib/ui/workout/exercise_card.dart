library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'set_row.dart';
import 'workout_draft.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.draft,
    required this.onToggleDone,
    required this.onPlates,
  });

  final DraftExercise exercise;
  final WorkoutDraft draft;
  final void Function(DraftSet set) onToggleDone;
  final void Function(double kg) onPlates;

  @override
  Widget build(BuildContext context) {
    final sets = exercise.sets;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    exercise.name,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Plate calculator',
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () {
                  final weight = sets.isEmpty ? 0.0 : sets.last.loadKg;
                  onPlates(weight > 0 ? weight : 60);
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options',
                onSelected: (_) => draft.removeExercise(exercise),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove exercise',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
          for (var i = 0; i < sets.length; i++)
            SetRow(
              key: ObjectKey(sets[i]),
              set: sets[i],
              number: i + 1,
              draft: draft,
              exercise: exercise,
              onToggleDone: () => onToggleDone(sets[i]),
              onPlates: onPlates,
            ),
          TextButton.icon(
            onPressed: () => draft.addSet(exercise),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add set'),
          ),
        ],
      ),
    );
  }
}
