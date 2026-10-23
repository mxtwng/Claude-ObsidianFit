/// "+ Log Past Session" chooser opened from a past calendar day: a gym workout
/// or an outdoor activity without GPS, both pre-filled with the selected date.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../activity/manual_activity_page.dart';
import '../theme/app_theme.dart';
import '../workout/workout_session_page.dart';

enum _PastChoice { workout, activity }

/// Shows the sheet for [day], then opens the matching backdated logger.
/// [scheduledText] (e.g. `Push Day A · 4-Week Strength Block`) is shown as a
/// reminder of what the plan had for that day; [suggestedSplit] pre-fills the
/// workout name. Does nothing for a day in the future. Returns true if a
/// session was saved.
Future<bool> showLogPastSessionSheet(
  BuildContext context, {
  required DateTime day,
  String? scheduledText,
  String? suggestedSplit,
}) async {
  final now = DateTime.now();
  final target = DateTime(day.year, day.month, day.day);
  if (target.isAfter(DateTime(now.year, now.month, now.day))) return false;

  final choice = await showModalBottomSheet<_PastChoice>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '+ Log Past Session',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMMM y').format(target),
                    style: const TextStyle(color: AppColors.textDim),
                  ),
                  if (scheduledText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Scheduled: $scheduledText',
                        style: const TextStyle(color: AppColors.textDim),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.fitness_center, color: AppColors.accent),
              title: const Text(
                'Gym workout',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Add sets, reps, holds and weight'),
              onTap: () => Navigator.of(sheetContext).pop(_PastChoice.workout),
            ),
            ListTile(
              leading:
                  const Icon(Icons.directions_run, color: AppColors.activity),
              title: const Text(
                'Outdoor activity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Enter a run, ride or walk without GPS'),
              onTap: () => Navigator.of(sheetContext).pop(_PastChoice.activity),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  return switch (choice) {
    _PastChoice.workout => startRetroWorkoutSession(
        context,
        day: target,
        suggestedSplit: suggestedSplit,
      ),
    _PastChoice.activity => startManualActivity(context, day: target),
  };
}
