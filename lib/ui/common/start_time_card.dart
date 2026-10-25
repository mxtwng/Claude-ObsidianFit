/// Date + time pickers for retroactive logging, shared by the workout and the
/// manual outdoor activity screens.
///
/// Rules (see `schemas/workout_schema.phase5.md`, section 1):
///  * a session cannot start in the future, so picks are clamped to "now";
///  * a live session can only be moved *earlier*: it passes its real start as
///    `latest`, so a later pick is clamped back to that start (a no-op)
///    instead of silently becoming a backdated session that starts after the
///    workout really began;
///  * values have minute precision (the note stores `time_started` as
///    `HH:mm`; `start_time` is written to the second but a picked time has
///    zero seconds);
///  * the picked value is a device-local [DateTime]; the model layer converts
///    it to a UTC `...Z` timestamp when the note is written.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// [d] without seconds and below.
DateTime truncateToMinute(DateTime d) =>
    DateTime(d.year, d.month, d.day, d.hour, d.minute);

/// Pre-filled start for "+ Log Past Session": the selected [day] at the
/// current time of day, never later than now.
DateTime defaultRetroStart(DateTime day) {
  final now = DateTime.now();
  final candidate =
      DateTime(day.year, day.month, day.day, now.hour, now.minute);
  return candidate.isAfter(now) ? truncateToMinute(now) : candidate;
}

/// A start pick after [clampStartPick] has limited it.
class ClampedStart {
  const ClampedStart(this.value, {required this.wasClamped});

  /// Minute-precision local start.
  final DateTime value;

  /// True when the pick was later than allowed and [value] is the limit.
  final bool wasClamped;
}

/// Limits a picked start to the latest allowed one, at minute precision.
///
/// The limit is [now] or, when given and earlier, [latest]. A live session
/// passes its real start as [latest]: clamping its picks to [now] instead
/// would give a start *later* than the one the workout really had.
ClampedStart clampStartPick({
  required DateTime picked,
  required DateTime now,
  DateTime? latest,
}) {
  var limit = truncateToMinute(now);
  if (latest != null) {
    final cap = truncateToMinute(latest);
    if (cap.isBefore(limit)) limit = cap;
  }
  final value = truncateToMinute(picked);
  return value.isAfter(limit)
      ? ClampedStart(limit, wasClamped: true)
      : ClampedStart(value, wasClamped: false);
}

/// Card with a date button and a time button. [onChanged] receives the new
/// local start (minute precision, never in the future, never after [latest])
/// and is not called when the pick leaves the minute unchanged.
class StartTimeCard extends StatelessWidget {
  const StartTimeCard({
    super.key,
    required this.start,
    required this.onChanged,
    this.title = 'Started',
    this.hint,
    this.footer,
    this.enabled = true,
    this.latest,
  });

  final DateTime start;
  final ValueChanged<DateTime> onChanged;
  final String title;

  /// Small dim caption under the buttons.
  final String? hint;

  /// Extra row under the buttons (e.g. the manual duration control).
  final Widget? footer;
  final bool enabled;

  /// Latest start a pick may produce, when earlier than now. Pass a live
  /// session's real start so it can only be moved earlier. Null: now.
  final DateTime? latest;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final cap = latest;
    final limit = cap != null && cap.isBefore(now) ? cap : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: start.isAfter(limit) ? limit : start,
      firstDate: DateTime(2000),
      lastDate: limit,
      helpText: 'Session date',
    );
    if (picked == null || !context.mounted) return;
    _emit(
      context,
      DateTime(picked.year, picked.month, picked.day, start.hour, start.minute),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
      helpText: 'Start time',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null || !context.mounted) return;
    _emit(
      context,
      DateTime(start.year, start.month, start.day, picked.hour, picked.minute),
    );
  }

  void _emit(BuildContext context, DateTime next) {
    final pick = clampStartPick(
      picked: next,
      now: DateTime.now(),
      latest: latest,
    );
    if (pick.wasClamped) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            latest == null
                ? "A session can't start in the future. Set to now."
                : "A live session can't start later than it did. "
                    'Pick an earlier time to backdate it.',
          ),
        ),
      );
    }
    if (pick.value == truncateToMinute(start)) return;
    onChanged(pick.value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: enabled ? () => _pickDate(context) : null,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(DateFormat('EEE, d MMM y').format(start)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: enabled ? () => _pickTime(context) : null,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(DateFormat('HH:mm').format(start)),
                ),
              ),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                hint!,
                style: const TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ),
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer!,
          ],
        ],
      ),
    );
  }
}
