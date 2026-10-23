/// Monthly calendar: completed-day dots from the workout and activity index
/// streams, a day preview sheet, and a quick "Start Session" button.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/Models.dart';
import '../app_services.dart';
import '../common/log_past_session_sheet.dart';
import '../common/schedule.dart';
import '../common/session_entries_builder.dart';
import '../common/session_entry.dart';
import '../common/session_preview_sheet.dart';
import '../common/session_tile.dart';
import '../theme/app_theme.dart';
import '../workout/workout_session_page.dart';

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Stream<List<PlanProgram>>? _plans;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _plans ??= watchParsedPlans(AppScope.of(context));
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  void _goToday() {
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month));
  }

  /// Start a session, pre-filling the plan's routine unless it is a rest day.
  void _start(ScheduledSession? scheduled) {
    final suggestion =
        (scheduled != null && !scheduled.isRest) ? scheduled.label : null;
    startWorkoutSession(context, suggestedSplit: suggestion);
  }

  bool _isPast(DateTime day) => _dayOf(day).isBefore(_dayOf(DateTime.now()));

  /// "+ Log Past Session" for [day], pre-filled with that date and, unless it
  /// was a rest day, the plan's routine for it.
  Future<void> _logPast(DateTime day, ScheduledSession? scheduled) async {
    if (!mounted) return;
    final routine =
        (scheduled != null && !scheduled.isRest) ? scheduled.label : null;
    await showLogPastSessionSheet(
      context,
      day: day,
      scheduledText: scheduled == null
          ? null
          : '${scheduled.label} · ${scheduled.planName}',
      suggestedSplit: routine,
    );
  }

  void _openDay(
    DateTime day,
    List<SessionEntry> entries,
    ScheduledSession? scheduled,
  ) {
    // An empty past day goes straight to "+ Log Past Session".
    if (entries.isEmpty && _isPast(day)) {
      _logPast(day, scheduled);
      return;
    }
    final pageContext = context;
    showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _DaySheet(
        day: day,
        // Index order is newest first; show the day chronologically.
        entries: entries.reversed.toList(),
        scheduled: scheduled,
        onOpenEntry: (entry) {
          Navigator.of(sheetContext).pop();
          showSessionPreview(
            pageContext,
            [entry],
            heading: DateFormat('EEEE, d MMMM').format(entry.date),
          );
        },
        onStart: () {
          Navigator.of(sheetContext).pop();
          _start(scheduled);
        },
        onLogPast: () {
          Navigator.of(sheetContext).pop();
          _logPast(day, scheduled);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(onPressed: _goToday, child: const Text('Today')),
          const SizedBox(width: 8),
        ],
      ),
      body: SessionEntriesBuilder(
        builder: (context, entries) {
          return StreamBuilder<List<PlanProgram>>(
            stream: _plans,
            builder: (context, plansSnap) {
              final plans = plansSnap.data ?? const <PlanProgram>[];
              final today = DateTime.now();

              final byDay = <DateTime, List<SessionEntry>>{};
              for (final e in entries) {
                byDay.putIfAbsent(_dayOf(e.date), () => []).add(e);
              }

              final inMonth = entries.where(
                (e) =>
                    e.date.year == _month.year && e.date.month == _month.month,
              );
              final workouts =
                  inMonth.where((e) => e.kind == SessionKind.workout).length;
              final activities = inMonth.length - workouts;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _MonthHeader(
                    month: _month,
                    onPrev: () => _shift(-1),
                    onNext: () => _shift(1),
                  ),
                  const SizedBox(height: 8),
                  _MonthGrid(
                    month: _month,
                    today: today,
                    byDay: byDay,
                    onTapDay: (day) => _openDay(
                      day,
                      byDay[day] ?? const [],
                      scheduledFor(day, plans),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MonthStats(workouts: workouts, activities: activities),
                  const SizedBox(height: 14),
                  _TodayCard(
                    scheduled: scheduledFor(today, plans),
                    doneToday: byDay[_dayOf(today)]?.length ?? 0,
                    onStart: () => _start(scheduledFor(today, plans)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// Month header + grid
// =============================================================================

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y').format(month),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.byDay,
    required this.onTapDay,
  });

  final DateTime month;
  final DateTime today;
  final Map<DateTime, List<SessionEntry>> byDay;
  final void Function(DateTime day) onTapDay;

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    // Weeks start on Monday (matches plan rotations in schedule.dart).
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((leading + daysInMonth) / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < weeks; w++)
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(child: _cell(w * 7 + d - leading + 1, daysInMonth)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: _DayCell.height);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final entries = byDay[day] ?? const <SessionEntry>[];
    return _DayCell(
      day: day,
      isToday: _sameDay(day, today),
      hasWorkout: entries.any((e) => e.kind == SessionKind.workout),
      hasActivity: entries.any((e) => e.kind == SessionKind.activity),
      onTap: () => onTapDay(day),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.hasWorkout,
    required this.hasActivity,
    required this.onTap,
  });

  static const double height = 54;

  final DateTime day;
  final bool isToday;
  final bool hasWorkout;
  final bool hasActivity;
  final VoidCallback onTap;

  static Widget _dot(Color color) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? AppColors.accent : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isToday ? Colors.black : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasWorkout) _dot(AppColors.done),
                  if (hasWorkout && hasActivity) const SizedBox(width: 4),
                  if (hasActivity) _dot(AppColors.activity),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Summary cards
// =============================================================================

class _MonthStats extends StatelessWidget {
  const _MonthStats({required this.workouts, required this.activities});

  final int workouts;
  final int activities;

  @override
  Widget build(BuildContext context) {
    Widget legend(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        legend(
          AppColors.done,
          '$workouts workout${workouts == 1 ? '' : 's'}',
        ),
        const SizedBox(width: 24),
        legend(
          AppColors.activity,
          '$activities activit${activities == 1 ? 'y' : 'ies'}',
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.scheduled,
    required this.doneToday,
    required this.onStart,
  });

  final ScheduledSession? scheduled;
  final int doneToday;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = scheduled;
    final subtitle =
        s == null ? 'No routine scheduled' : '${s.label} · ${s.planName}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today',
            style: TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (doneToday > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$doneToday session${doneToday == 1 ? '' : 's'} logged',
                style: const TextStyle(color: AppColors.done),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Day preview sheet
// =============================================================================

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.day,
    required this.entries,
    required this.scheduled,
    required this.onOpenEntry,
    required this.onStart,
    required this.onLogPast,
  });

  final DateTime day;
  final List<SessionEntry> entries;
  final ScheduledSession? scheduled;
  final void Function(SessionEntry entry) onOpenEntry;
  final VoidCallback onStart;

  /// Opens the "+ Log Past Session" chooser for this day (past days only).
  final VoidCallback onLogPast;

  @override
  Widget build(BuildContext context) {
    final s = scheduled;
    // "Start Session" logs live ("now"), so it is only offered for today;
    // earlier days offer "+ Log Past Session" instead.
    final isToday = _sameDay(day, DateTime.now());
    final isPast = _dayOf(day).isBefore(_dayOf(DateTime.now()));
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(day),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (s != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Scheduled: ${s.label} · ${s.planName}',
              style: const TextStyle(color: AppColors.textDim),
            ),
          ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Nothing logged on this day.',
                style: TextStyle(color: AppColors.textDim),
              ),
            ),
          )
        else
          for (final e in entries)
            SessionTile(entry: e, onTap: () => onOpenEntry(e)),
        if (isToday) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Session'),
          ),
        ],
        if (isPast) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onLogPast,
            icon: const Icon(Icons.add),
            label: const Text('+ Log Past Session'),
          ),
        ],
      ],
    );
  }
}
