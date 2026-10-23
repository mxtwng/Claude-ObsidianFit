library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'session_entry.dart';

class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.entry, required this.onTap});

  final SessionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWorkout = entry.kind == SessionKind.workout;
    final color = isWorkout ? AppColors.accent : AppColors.activity;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isWorkout ? Icons.fitness_center : Icons.directions_run,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          entry.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${DateFormat('EEE, d MMM').format(entry.date)} · '
          '${entry.timeStarted}\n${entry.summary}',
          style: const TextStyle(color: AppColors.textDim, height: 1.35),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textDim),
      ),
    );
  }
}
