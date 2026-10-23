/// "Start" chooser shared by the shell's floating button: a gym workout or an
/// outdoor GPS activity.
library;

import 'package:flutter/material.dart';

import '../activity/activity_session_page.dart';
import '../theme/app_theme.dart';
import '../workout/workout_session_page.dart';

/// Lets the user pick what to record, then opens that screen.
/// Returns true if a session was saved.
Future<bool> showStartSessionSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<_StartChoice>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.fitness_center, color: AppColors.accent),
              title: const Text(
                'Gym workout',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Log sets, reps and weight'),
              onTap: () => Navigator.of(sheetContext).pop(_StartChoice.workout),
            ),
            ListTile(
              leading:
                  const Icon(Icons.directions_run, color: AppColors.activity),
              title: const Text(
                'Outdoor activity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Record a run, ride or walk with GPS'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_StartChoice.activity),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  return switch (choice) {
    _StartChoice.workout => startWorkoutSession(context),
    _StartChoice.activity => startOutdoorActivity(context),
  };
}

enum _StartChoice { workout, activity }
