/// Resolves which routine a plan schedules on a given day.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/Models.dart';
import '../../services/FilePersistenceService.dart';
import '../app_services.dart';

class ScheduledSession {
  const ScheduledSession({
    required this.label,
    required this.planName,
    required this.isRest,
  });

  /// e.g. `Push Day A` or `Rest / Light Recovery`.
  final String label;
  final String planName;
  final bool isRest;
}

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The routine scheduled on [day], or null if no plan covers it.
/// A plan covers `[startDate, startDate + durationWeeks * 7 days)`.
ScheduledSession? scheduledFor(DateTime day, List<PlanProgram> plans) {
  final d = DateTime(day.year, day.month, day.day);
  for (final plan in plans) {
    final start = plan.startDate;
    if (start == null || plan.durationWeeks <= 0) continue;
    final end = DateTime(
      start.year,
      start.month,
      start.day + plan.durationWeeks * 7,
    );
    if (d.isBefore(start) || !d.isBefore(end)) continue;
    final label = plan.sessionFor(_weekdayNames[d.weekday - 1])?.trim();
    if (label == null || label.isEmpty) continue;
    return ScheduledSession(
      label: label,
      planName: plan.programName,
      isRest: label.toLowerCase().startsWith('rest'),
    );
  }
  return null;
}

/// Plans from the index, parsed from their vault files (the index does not
/// store the weekly rotation). Unreadable plans are skipped.
Stream<List<PlanProgram>> watchParsedPlans(AppServices services) {
  return services.database.watchPlans().asyncMap((rows) async {
    final out = <PlanProgram>[];
    for (final row in rows) {
      try {
        final file = File(p.join(services.vault.vaultDir.path, row.filePath));
        out.add(FilePersistenceService.parsePlan(await file.readAsString()));
      } catch (_) {
        // Deleted or invalid since indexing; the re-indexer will catch up.
      }
    }
    return out;
  });
}
