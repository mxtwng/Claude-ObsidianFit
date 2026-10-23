/// One row in the calendar / history, unified across workouts and activities.
library;

import '../../models/Models.dart';
import '../../services/app_database.dart';

enum SessionKind { workout, activity }

class SessionEntry {
  const SessionEntry({
    required this.kind,
    required this.filePath,
    required this.date,
    required this.timeStarted,
    required this.title,
    required this.summary,
  });

  final SessionKind kind;

  /// Vault-relative path, e.g. `Workouts/2026-10-22_1800_Push_Day_A.md`.
  final String filePath;
  final DateTime date;
  final String timeStarted;
  final String title;
  final String summary;

  factory SessionEntry.fromWorkout(WorkoutIndexRow r) {
    final parts = <String>['${r.durationMin.round()} min'];
    final volume = r.totalVolumeKg;
    if (volume != null && volume > 0) {
      parts.add('${formatDecimal(volume.roundToDouble())} kg');
    }
    return SessionEntry(
      kind: SessionKind.workout,
      filePath: r.filePath,
      date: r.date,
      timeStarted: r.timeStarted,
      title: r.split.isEmpty ? 'Workout' : r.split,
      summary: parts.join(' · '),
    );
  }

  factory SessionEntry.fromActivity(ActivityIndexRow r) {
    final parts = <String>[];
    final km = r.distanceKm;
    if (km != null) parts.add('${km.toStringAsFixed(2)} km');
    parts.add('${r.durationMin.round()} min');
    final c = r.category;
    return SessionEntry(
      kind: SessionKind.activity,
      filePath: r.filePath,
      date: r.date,
      timeStarted: r.timeStarted,
      title: c.isEmpty ? 'Activity' : '${c[0].toUpperCase()}${c.substring(1)}',
      summary: parts.join(' · '),
    );
  }
}
