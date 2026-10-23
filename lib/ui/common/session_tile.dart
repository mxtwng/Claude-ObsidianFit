library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/pr_service.dart';
import '../theme/app_theme.dart';
import 'pr_badge.dart';
import 'session_entry.dart';

class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.records = const [],
  });

  final SessionEntry entry;
  final VoidCallback onTap;

  /// All-time records this session currently holds; shown as trophy chips.
  final List<PrKind> records;

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('EEE, d MMM').format(entry.date)} · '
              '${entry.timeStarted}\n${entry.summary}',
              style: const TextStyle(color: AppColors.textDim, height: 1.35),
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [for (final k in records) PrChip(kind: k)],
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: AppColors.textDim),
      ),
    );
  }
}
