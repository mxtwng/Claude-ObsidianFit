library;

import 'package:flutter/material.dart';

import '../../services/app_database.dart';
import '../app_services.dart';
import 'session_entry.dart';

/// Merges the workout and activity index streams into one list of
/// [SessionEntry], newest first, and rebuilds whenever either changes.
class SessionEntriesBuilder extends StatefulWidget {
  const SessionEntriesBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, List<SessionEntry> entries)
      builder;

  @override
  State<SessionEntriesBuilder> createState() => _SessionEntriesBuilderState();
}

class _SessionEntriesBuilderState extends State<SessionEntriesBuilder> {
  Stream<List<WorkoutIndexRow>>? _workouts;
  Stream<List<ActivityIndexRow>>? _activities;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).database;
    _workouts ??= db.watchWorkouts();
    _activities ??= db.watchActivities();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkoutIndexRow>>(
      stream: _workouts,
      builder: (context, workouts) {
        return StreamBuilder<List<ActivityIndexRow>>(
          stream: _activities,
          builder: (context, activities) {
            final entries = <SessionEntry>[
              for (final r in workouts.data ?? const <WorkoutIndexRow>[])
                SessionEntry.fromWorkout(r),
              for (final r in activities.data ?? const <ActivityIndexRow>[])
                SessionEntry.fromActivity(r),
            ]..sort((a, b) {
                // Newest first by when the session physically happened
                // (start_time), falling back to date + time for legacy notes.
                final byInstant = b.sortInstant.compareTo(a.sortInstant);
                return byInstant != 0
                    ? byInstant
                    : b.filePath.compareTo(a.filePath);
              });
            return widget.builder(context, entries);
          },
        );
      },
    );
  }
}
