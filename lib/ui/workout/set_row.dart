library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/Models.dart';
import '../common/set_type_style.dart';
import '../theme/app_theme.dart';
import 'workout_draft.dart';

const double kWeightStepKg = 2.5;
const int kRepStep = 1;

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.draft,
    required this.exercise,
    required this.onToggleDone,
    required this.onPlates,
  });

  final DraftSet set;

  /// 1-based position within the exercise.
  final int number;
  final WorkoutDraft draft;
  final DraftExercise exercise;
  final VoidCallback onToggleDone;
  final void Function(double kg) onPlates;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  bool _rpeOpen = false;

  DraftSet get _s => widget.set;

  void _tick() => HapticFeedback.selectionClick();

  Future<void> _editWeight() async {
    final v = await _editNumber(
      context,
      title: 'Weight (kg)',
      initial: _s.weightKg,
      integer: false,
    );
    if (v != null) widget.draft.mutate(() => _s.weightKg = v);
  }

  Future<void> _editReps() async {
    final v = await _editNumber(
      context,
      title: 'Reps',
      initial: _s.reps.toDouble(),
      integer: true,
    );
    if (v != null) widget.draft.mutate(() => _s.reps = v.round());
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final done = s.done;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
      decoration: BoxDecoration(
        color: done ? AppColors.done.withAlpha(28) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? AppColors.done.withAlpha(90) : AppColors.outline,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PopupMenuButton<Object>(
                tooltip: 'Set type',
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value is SetType) {
                    widget.draft.mutate(() => s.type = value);
                  } else {
                    widget.draft.removeSet(widget.exercise, s);
                  }
                },
                itemBuilder: (_) => [
                  for (final t in SetType.values)
                    PopupMenuItem<Object>(
                      value: t,
                      child: Row(
                        children: [
                          SetTypeBadge(type: t, number: widget.number),
                          const SizedBox(width: 12),
                          Text('${setTypeName(t)} (${t.code})'),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<Object>(
                    value: 'delete',
                    child: Text(
                      'Delete set',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
                child: SetTypeBadge(type: s.type, number: widget.number),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Stepper(
                  value: formatDecimal(s.weightKg),
                  unit: 'kg',
                  minusLabel: '−${formatDecimal(kWeightStepKg)}',
                  plusLabel: '+${formatDecimal(kWeightStepKg)}',
                  onMinus: () {
                    _tick();
                    widget.draft.mutate(
                      () => s.weightKg =
                          math.max(0.0, s.weightKg - kWeightStepKg),
                    );
                  },
                  onPlus: () {
                    _tick();
                    widget.draft.mutate(() => s.weightKg += kWeightStepKg);
                  },
                  onTapValue: _editWeight,
                  onLongPressValue: () => widget.onPlates(s.weightKg),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Stepper(
                  value: '${s.reps}',
                  unit: 'reps',
                  minusLabel: '−$kRepStep',
                  plusLabel: '+$kRepStep',
                  onMinus: () {
                    _tick();
                    widget.draft.mutate(
                      () => s.reps = math.max(0, s.reps - kRepStep),
                    );
                  },
                  onPlus: () {
                    _tick();
                    widget.draft.mutate(() => s.reps += kRepStep);
                  },
                  onTapValue: _editReps,
                ),
              ),
              Checkbox(
                value: done,
                activeColor: AppColors.done,
                checkColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (_) => widget.onToggleDone(),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _rpeOpen = !_rpeOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.rpe == null
                          ? 'RPE  –'
                          : 'RPE  ${s.rpe!.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: s.rpe == null
                            ? AppColors.textDim
                            : AppColors.accent,
                      ),
                    ),
                    Icon(
                      _rpeOpen ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.textDim,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_rpeOpen)
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 10,
                    divisions: 18,
                    value: (s.rpe ?? 8.0).clamp(1.0, 10.0).toDouble(),
                    label: (s.rpe ?? 8.0).toStringAsFixed(1),
                    onChanged: (v) {
                      if (s.rpe != v) _tick();
                      widget.draft.mutate(() => s.rpe = v);
                    },
                  ),
                ),
                TextButton(
                  onPressed: s.rpe == null
                      ? null
                      : () => widget.draft.mutate(() => s.rpe = null),
                  child: const Text('Clear'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.unit,
    required this.minusLabel,
    required this.plusLabel,
    required this.onMinus,
    required this.onPlus,
    required this.onTapValue,
    this.onLongPressValue,
  });

  final String value;
  final String unit;
  final String minusLabel;
  final String plusLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTapValue;
  final VoidCallback? onLongPressValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(label: minusLabel, onTap: onMinus),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTapValue,
            onLongPress: onLongPressValue,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    unit,
                    style:
                        const TextStyle(fontSize: 10, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StepButton(label: plusLabel, onTap: onPlus),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 40,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

Future<double?> _editNumber(
  BuildContext context, {
  required String title,
  required double initial,
  required bool integer,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) =>
        _NumberDialog(title: title, initial: initial, integer: integer),
  );
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.integer,
  });

  final String title;
  final double initial;
  final bool integer;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.integer
        ? '${widget.initial.round()}'
        : formatDecimal(widget.initial),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    Navigator.of(context).pop(v == null || v < 0 ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: !widget.integer),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Set')),
      ],
    );
  }
}
