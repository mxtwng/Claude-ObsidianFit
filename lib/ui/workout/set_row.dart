/// One editable set row.
///
/// Top line: set-type badge, load stepper, reps / hold stepper, done checkbox.
/// Second line: input-mode toggles that bind straight to the [DraftSet]:
///  * **Reps | Hold**: weight x reps vs an isometric hold in seconds
///    (planks, L-sits, handstands); binds `isHold` / `durationSeconds`.
///  * **Bodyweight** switch: external weight (`80kg`) vs bodyweight plus added
///    load (`BW+0kg`, `BW+10kg`); binds `isBodyweight` / `extraWeightKg`.
///  * **Plyo** menu: optional box height (cm) and contact time (ms).
///  * **RPE** slider.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/Models.dart';
import '../common/prompt_dialog.dart';
import '../common/set_type_style.dart';
import '../theme/app_theme.dart';
import 'workout_draft.dart';

const double kWeightStepKg = 2.5;
const int kRepStep = 1;
const int kHoldStepSec = 5;

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

  // ---- edits ----------------------------------------------------------------

  Future<void> _editLoad() async {
    final bodyweight = _s.isBodyweight;
    final v = await promptNumber(
      context,
      title: bodyweight ? 'Added weight (kg)' : 'Weight (kg)',
      initial: bodyweight ? _s.extraWeightKg : _s.weightKg,
    );
    if (v == null) return;
    widget.draft.mutate(() {
      if (bodyweight) {
        _s.extraWeightKg = v;
      } else {
        _s.weightKg = v;
      }
    });
  }

  Future<void> _editReps() async {
    final v = await promptNumber(
      context,
      title: 'Reps',
      initial: _s.reps.toDouble(),
      integer: true,
    );
    if (v != null) widget.draft.mutate(() => _s.reps = v.round());
  }

  Future<void> _editHold() async {
    final v = await promptNumber(
      context,
      title: 'Hold time (seconds)',
      initial: _s.durationSeconds.toDouble(),
      integer: true,
      min: 1,
    );
    if (v != null) widget.draft.mutate(() => _s.durationSeconds = v.round());
  }

  Future<void> _editBox() async {
    final v = await promptNumber(
      context,
      title: 'Box height (cm)',
      initial: _s.boxHeightCm ?? 40,
      min: 1,
    );
    if (v != null) widget.draft.mutate(() => _s.boxHeightCm = v);
  }

  Future<void> _editContact() async {
    final v = await promptNumber(
      context,
      title: 'Contact time (ms)',
      initial: (_s.contactTimeMs ?? 200).toDouble(),
      integer: true,
      min: 1,
    );
    if (v != null) widget.draft.mutate(() => _s.contactTimeMs = v.round());
  }

  void _setHold(bool hold) {
    widget.draft.mutate(() {
      _s.isHold = hold;
      // A hold with no external weight is a bodyweight hold (`BW+0kg`).
      if (hold && !_s.isBodyweight && _s.weightKg == 0) {
        _s.isBodyweight = true;
      }
    });
  }

  void _setBodyweight(bool on) =>
      widget.draft.mutate(() => _s.isBodyweight = on);

  void _plyoSelected(String action) {
    switch (action) {
      case 'box':
        _editBox();
      case 'contact':
        _editContact();
      case 'clear':
        widget.draft.mutate(() {
          _s.boxHeightCm = null;
          _s.contactTimeMs = null;
        });
    }
  }

  // ---- steppers -------------------------------------------------------------

  Widget _loadStepper() {
    final s = _s;
    if (s.isBodyweight) {
      return _Stepper(
        value: '+${formatDecimal(s.extraWeightKg)}',
        unit: 'kg · BW',
        minusLabel: '−${formatDecimal(kWeightStepKg)}',
        plusLabel: '+${formatDecimal(kWeightStepKg)}',
        onMinus: () {
          _tick();
          widget.draft.mutate(
            () => s.extraWeightKg =
                math.max(0.0, s.extraWeightKg - kWeightStepKg),
          );
        },
        onPlus: () {
          _tick();
          widget.draft.mutate(() => s.extraWeightKg += kWeightStepKg);
        },
        onTapValue: _editLoad,
      );
    }
    return _Stepper(
      value: formatDecimal(s.weightKg),
      unit: 'kg',
      minusLabel: '−${formatDecimal(kWeightStepKg)}',
      plusLabel: '+${formatDecimal(kWeightStepKg)}',
      onMinus: () {
        _tick();
        widget.draft.mutate(
          () => s.weightKg = math.max(0.0, s.weightKg - kWeightStepKg),
        );
      },
      onPlus: () {
        _tick();
        widget.draft.mutate(() => s.weightKg += kWeightStepKg);
      },
      onTapValue: _editLoad,
      onLongPressValue: () => widget.onPlates(s.weightKg),
    );
  }

  Widget _amountStepper() {
    final s = _s;
    if (s.isHold) {
      return _Stepper(
        value: '${s.durationSeconds}',
        unit: 'sec hold',
        minusLabel: '−$kHoldStepSec',
        plusLabel: '+$kHoldStepSec',
        onMinus: () {
          _tick();
          widget.draft.mutate(
            () => s.durationSeconds =
                math.max(1, s.durationSeconds - kHoldStepSec),
          );
        },
        onPlus: () {
          _tick();
          widget.draft.mutate(() => s.durationSeconds += kHoldStepSec);
        },
        onTapValue: _editHold,
      );
    }
    return _Stepper(
      value: '${s.reps}',
      unit: 'reps',
      minusLabel: '−$kRepStep',
      plusLabel: '+$kRepStep',
      onMinus: () {
        _tick();
        widget.draft.mutate(() => s.reps = math.max(0, s.reps - kRepStep));
      },
      onPlus: () {
        _tick();
        widget.draft.mutate(() => s.reps += kRepStep);
      },
      onTapValue: _editReps,
    );
  }

  // ---- build ----------------------------------------------------------------

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
              Expanded(child: _loadStepper()),
              const SizedBox(width: 6),
              Expanded(child: _amountStepper()),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ModePill(
                    leftLabel: 'Reps',
                    rightLabel: 'Hold',
                    rightSelected: s.isHold,
                    onChanged: _setHold,
                  ),
                  FilterChip(
                    selected: s.isBodyweight,
                    onSelected: _setBodyweight,
                    avatar: Icon(
                      Icons.accessibility_new,
                      size: 16,
                      color:
                          s.isBodyweight ? AppColors.accent : AppColors.textDim,
                    ),
                    label: Text(
                      s.isBodyweight
                          ? 'BW+${formatDecimal(s.extraWeightKg)}kg'
                          : 'Bodyweight',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    showCheckmark: false,
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _rpeOpen = !_rpeOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
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
                  if (s.boxHeightCm != null)
                    InputChip(
                      label: Text(
                        'Box ${formatDecimal(s.boxHeightCm!)}cm',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _editBox,
                      onDeleted: () =>
                          widget.draft.mutate(() => s.boxHeightCm = null),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (s.contactTimeMs != null)
                    InputChip(
                      label: Text(
                        'Contact ${s.contactTimeMs}ms',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: _editContact,
                      onDeleted: () =>
                          widget.draft.mutate(() => s.contactTimeMs = null),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Plyometric details',
                    onSelected: _plyoSelected,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'box',
                        child: Text(
                          s.boxHeightCm == null
                              ? 'Add box height'
                              : 'Edit box height',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'contact',
                        child: Text(
                          s.contactTimeMs == null
                              ? 'Add contact time'
                              : 'Edit contact time',
                        ),
                      ),
                      if (s.boxHeightCm != null || s.contactTimeMs != null)
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text(
                            'Clear plyometric data',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 16, color: AppColors.textDim),
                          SizedBox(width: 2),
                          Text(
                            'Plyo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

/// Two-segment pill: [leftLabel] | [rightLabel].
class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.leftLabel,
    required this.rightLabel,
    required this.rightSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool rightSelected;

  /// Called with `true` when the right segment is tapped.
  final ValueChanged<bool> onChanged;

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: selected ? null : onTap,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.accent : AppColors.textDim,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(leftLabel, !rightSelected, () => onChanged(false)),
          _segment(rightLabel, rightSelected, () => onChanged(true)),
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
