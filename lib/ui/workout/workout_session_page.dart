/// Live workout screen: set rows, rest timer, plate calculator, dynamic
/// "add exercise", and save-to-vault on finish.
///
/// The screen only ever edits a [WorkoutDraft]. Finishing converts it to an
/// immutable `WorkoutSession` and writes it through `FilePersistenceService`
/// (the `.md` file is the source of truth); the Drift index is then refreshed
/// by the re-indexer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/Models.dart';
import '../../services/screen_awake.dart';
import '../../services/vault_reindexer_service.dart';
import '../app_services.dart';
import '../common/prompt_dialog.dart';
import '../theme/app_theme.dart';
import 'exercise_card.dart';
import 'plate_calculator_sheet.dart';
import 'rest_timer.dart';
import 'workout_draft.dart';

const List<String> _splitSuggestions = [
  'Push Day',
  'Pull Day',
  'Leg Day',
  'Upper Body',
  'Full Body',
];

const List<String> _exerciseSuggestions = [
  'Barbell Bench Press',
  'Overhead Press',
  'Barbell Squat',
  'Deadlift',
  'Barbell Row',
  'Pull-Up',
  'Incline Dumbbell Press',
  'Romanian Deadlift',
];

/// Asks for a session name, then opens the live workout screen.
///
/// [suggestedSplit] pre-fills the prompt (e.g. today's scheduled routine).
/// Returns true if a workout was saved.
Future<bool> startWorkoutSession(
  BuildContext context, {
  String? suggestedSplit,
}) async {
  final split = await promptText(
    context,
    title: 'Start session',
    initial: suggestedSplit ?? '',
    hint: 'e.g. Push Day A',
    suggestions: _splitSuggestions,
  );
  if (split == null || !context.mounted) return false;
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => WorkoutSessionPage(split: split)),
  );
  return saved ?? false;
}

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({super.key, required this.split});

  final String split;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  late final WorkoutDraft _draft;
  final RestTimerController _rest = RestTimerController();
  bool _restExpanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = WorkoutDraft(split: widget.split);
    unawaited(ScreenAwake.enable());
  }

  @override
  void dispose() {
    unawaited(ScreenAwake.disable());
    _rest.dispose();
    _draft.dispose();
    super.dispose();
  }

  // ---- actions --------------------------------------------------------------

  void _toggleDone(DraftSet set) {
    _draft.mutate(() => set.done = !set.done);
    if (set.done) {
      HapticFeedback.mediumImpact();
      _rest.start(RestDefaults.forSet(set.type, set.rpe));
    }
  }

  Future<void> _showPlates(double kg) =>
      showPlateCalculator(context, initialKg: kg);

  Future<void> _addExercise() async {
    final name = await promptText(
      context,
      title: 'Add exercise',
      hint: 'Exercise name',
      suggestions: _exerciseSuggestions,
    );
    if (name == null) return;
    _draft.addExercise(name);
  }

  Future<void> _rename() async {
    final name = await promptText(
      context,
      title: 'Session name',
      initial: _draft.split,
      suggestions: _splitSuggestions,
    );
    if (name == null) return;
    _draft.mutate(() => _draft.split = name);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.black,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmLeave() async {
    final leave = await _confirm(
      title: 'Discard workout?',
      message: 'Your logged sets have not been saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _finish() async {
    if (_saving) return;

    if (_draft.completedSets == 0) {
      final discard = await _confirm(
        title: 'No sets completed',
        message: 'Only checked-off sets are saved. Discard this workout?',
        confirmLabel: 'Discard',
        destructive: true,
      );
      if (discard && mounted) Navigator.of(context).pop(false);
      return;
    }

    final pending = _draft.pendingSets;
    if (pending > 0) {
      final go = await _confirm(
        title: 'Finish workout?',
        message: '$pending set${pending == 1 ? '' : 's'} not checked off '
            'will not be saved.',
        confirmLabel: 'Finish',
      );
      if (!go || !mounted) return;
    }

    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final session = _draft.toSession(DateTime.now());
      await services.vault.saveWorkout(session);
      // The file watcher would catch this too; reindex now so the calendar
      // and history update immediately. A failed reindex must not fail a save.
      unawaited(
        services.reindexer
            .reindex()
            .catchError((Object _) => const ReindexReport()),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Saved ${session.split} · ${session.totalSets} sets'),
        ),
      );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save workout: $e')),
      );
    }
  }

  // ---- derived --------------------------------------------------------------

  /// Live volume of checked-off, non-warmup sets (matches the saved value).
  double _liveVolumeKg() {
    var total = 0.0;
    for (final e in _draft.exercises) {
      for (final s in e.sets) {
        if (s.done && s.type != SetType.warmup) total += s.weightKg * s.reps;
      }
    }
    return total;
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        return PopScope(
          canPop: !_draft.hasContent,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _rename,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _draft.split.isEmpty ? 'Workout' : _draft.split,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.edit,
                            size: 14,
                            color: AppColors.textDim,
                          ),
                        ],
                      ),
                      _ElapsedText(
                        startedAt: _draft.startedAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton(
                    onPressed: _saving ? null : _finish,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Finish'),
                  ),
                ),
              ],
            ),
            body: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _StatsBar(
                  startedAt: _draft.startedAt,
                  volumeKg: _liveVolumeKg(),
                  done: _draft.completedSets,
                  total: _draft.completedSets + _draft.pendingSets,
                ),
                const SizedBox(height: 14),
                if (_draft.exercises.isEmpty) const _EmptyState(),
                for (final e in _draft.exercises)
                  ExerciseCard(
                    key: ObjectKey(e),
                    exercise: e,
                    draft: _draft,
                    onToggleDone: _toggleDone,
                    onPlates: _showPlates,
                  ),
                OutlinedButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _buildRestBar(),
          ),
        );
      },
    );
  }

  Widget _buildRestBar() {
    return ListenableBuilder(
      listenable: _rest,
      builder: (context, _) {
        if (!_rest.running && !_rest.finished) return const SizedBox.shrink();

        if (_restExpanded) {
          return RestTimerSheet(
            controller: _rest,
            onClose: () => setState(() => _restExpanded = false),
          );
        }

        final finished = _rest.finished;
        final color = finished ? AppColors.done : AppColors.accent;
        return Material(
          color: AppColors.surfaceHigh,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => setState(() => _restExpanded = true),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: color),
                    const SizedBox(width: 10),
                    Text(
                      finished
                          ? 'Rest over — go!'
                          : 'Rest  ${formatClock(_rest.remainingSec)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Skip rest',
                      icon: const Icon(Icons.close),
                      onPressed: _rest.skip,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Small widgets
// =============================================================================

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.startedAt,
    required this.volumeKg,
    required this.done,
    required this.total,
  });

  final DateTime startedAt;
  final double volumeKg;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.w800);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(
            label: 'Time',
            child: _ElapsedText(startedAt: startedAt, style: valueStyle),
          ),
          _Stat(
            label: 'Volume',
            child: Text(
              '${formatDecimal(volumeKg.roundToDouble())} kg',
              style: valueStyle,
            ),
          ),
          _Stat(
            label: 'Sets',
            child: Text('$done/$total', style: valueStyle),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 40, color: AppColors.textDim),
          SizedBox(height: 12),
          Text(
            'Add your first exercise to start logging.',
            style: TextStyle(color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

/// Ticking elapsed time since [startedAt]. Owns its own timer so only this
/// text rebuilds each second.
class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.startedAt, this.style});

  final DateTime startedAt;
  final TextStyle? style;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _format(Duration d) {
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final m = (d.inMinutes % 60).toString().padLeft(2, '0');
      return '${d.inHours}:$m:$s';
    }
    return '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    return Text(
      _format(elapsed.isNegative ? Duration.zero : elapsed),
      style: widget.style,
    );
  }
}
