/// Manual activity logger: any activity (a run, ride, walk, Taekwondo, boxing,
/// yoga, stretching, ...) entered after the fact with no GPS trace.
///
/// Writes one note, `Activities/YYYY-MM-DD_HHMM_<category>.md`, and no GPX
/// file: `gpxFileName` is null, so the key is omitted from the frontmatter and
/// the History screen shows no route map. Spec:
/// `schemas/activity_schema.phase5.md`, sections 1 and 2.
///
/// Required: duration (>= 1 s). Optional, and left out of the note when blank
/// (never written as `0`): distance (> 0 km when given), elevation gain
/// (>= 0 m when given), session RPE (1-10, halves allowed) and average heart
/// rate. Pace is derived only when a distance is given. Timestamps:
/// `start_time` is the picked start and `date_logged` is the save time, both
/// UTC with a trailing `Z`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/Models.dart';
import '../../services/vault_reindexer_service.dart';
import '../app_services.dart';
import '../common/prompt_dialog.dart';
import '../common/start_time_card.dart';
import '../theme/app_theme.dart';

/// Quick picks in the "Log activity" prompt. Any text can still be typed.
const List<String> manualCategorySuggestions = [
  'Run',
  'Ride',
  'Walking',
  'Hike',
  'Taekwondo',
  'Boxing',
  'Yoga',
  'Stretching',
];

/// Per-field problems of one manual entry; a null field is valid.
class ManualActivityErrors {
  const ManualActivityErrors({
    this.distance,
    this.duration,
    this.elevation,
    this.avgHr,
    this.rpe,
  });

  final String? distance;
  final String? duration;
  final String? elevation;
  final String? avgHr;
  final String? rpe;

  bool get isValid =>
      distance == null &&
      duration == null &&
      elevation == null &&
      avgHr == null &&
      rpe == null;
}

double? _parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Validates a manual entry's raw field values.
///
/// Only [durationSeconds] is required (>= 1). A blank [distanceText],
/// [elevationText] or [avgHrText], or a null [rpe], means "not entered" and is
/// valid. When something is entered it must be usable: distance > 0 km,
/// elevation >= 0 m, heart rate 1-300 bpm, RPE 1-10.
ManualActivityErrors validateManualActivity({
  required String distanceText,
  required int durationSeconds,
  required String elevationText,
  required String avgHrText,
  required double? rpe,
}) {
  String? distance;
  final d = distanceText.trim().isEmpty ? null : _parseNumber(distanceText);
  if (distanceText.trim().isNotEmpty && (d == null || !d.isFinite || d <= 0)) {
    distance = 'Enter a distance above 0 km, or leave it empty';
  }

  String? elevation;
  final e = elevationText.trim().isEmpty ? null : _parseNumber(elevationText);
  if (elevationText.trim().isNotEmpty && (e == null || !e.isFinite || e < 0)) {
    elevation = 'Enter the elevation gain in metres (0 or more), '
        'or leave it empty';
  }

  String? avgHr;
  final hrTrimmed = avgHrText.trim();
  final hr = hrTrimmed.isEmpty ? null : int.tryParse(hrTrimmed);
  if (hrTrimmed.isNotEmpty && (hr == null || hr <= 0 || hr > 300)) {
    avgHr = 'Enter a heart rate from 1 to 300, or leave empty';
  }

  String? rpeError;
  if (rpe != null && !(rpe >= 1 && rpe <= 10)) {
    rpeError = 'RPE must be between 1 and 10';
  }

  return ManualActivityErrors(
    distance: distance,
    duration:
        durationSeconds < 1 ? 'Enter a duration of at least 1 second' : null,
    elevation: elevation,
    avgHr: avgHr,
    rpe: rpeError,
  );
}

/// Builds the note for a manual entry that passed [validateManualActivity].
///
/// Only what was entered is written: a blank distance, elevation, heart rate
/// or RPE leaves its key out, and `avg_pace_min_km` is derived only when a
/// distance is given (duration is always present). The title is
/// `<km> km <label>` for a distance entry and just `<label>` otherwise.
/// [category] is the slugged frontmatter value, [label] the display text, and
/// [start] the (already clamped) local start; [now] becomes `date_logged`.
ActivitySession buildManualActivity({
  required String category,
  required String label,
  required DateTime start,
  required DateTime now,
  required int durationSeconds,
  String distanceText = '',
  String elevationText = '',
  String avgHrText = '',
  double? rpe,
  String notes = '',
}) {
  final distance =
      distanceText.trim().isEmpty ? null : _parseNumber(distanceText);
  final distanceKm =
      distance == null ? null : double.parse(distance.toStringAsFixed(2));
  final elevation =
      elevationText.trim().isEmpty ? null : _parseNumber(elevationText);
  final hrTrimmed = avgHrText.trim();
  final title =
      distanceKm == null ? label : '${distanceKm.toStringAsFixed(1)} km $label';

  final draft = ActivitySession(
    category: category,
    date: DateTime(start.year, start.month, start.day),
    timeStarted: DateFormat('HH:mm').format(start),
    startTime: start.toUtc(),
    dateLogged: now.toUtc(),
    // Canonical duration, plus the derived minutes the parser still needs.
    durationSeconds: durationSeconds,
    durationMin: (durationSeconds / 60 * 10).round() / 10,
    distanceKm: distanceKm,
    elevationGainM: elevation,
    avgHr: hrTrimmed.isEmpty ? null : int.parse(hrTrimmed),
    rpe: rpe,
    gpxFileName: null,
    tags: ['fitness/$category'],
    title: title,
    bodyText: _notesAsBullets(notes),
  );
  // computedPaceMinKm is null without a distance, which keeps the key out.
  return draft.copyWith(avgPaceMinKm: draft.computedPaceMinKm);
}

/// Plain text lines -> Markdown bullets, matching `activity_schema.md`.
String _notesAsBullets(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s+'), ''))
      .where((l) => l.isNotEmpty);
  return lines.map((l) => '- $l').join('\n');
}

/// Opens the manual logger for [day] (the current time of day on that date,
/// never in the future). Asks for the activity kind first unless [category]
/// is given. Returns true if an activity was saved.
Future<bool> startManualActivity(
  BuildContext context, {
  DateTime? day,
  String? category,
}) async {
  var label = category;
  if (label == null) {
    label = await promptText(
      context,
      title: 'Log activity',
      initial: 'Run',
      hint: 'e.g. Taekwondo',
      suggestions: manualCategorySuggestions,
    );
    if (label == null || !context.mounted) return false;
  }
  final chosen = label;
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ManualActivityPage(
        category: chosen,
        initialStart: defaultRetroStart(day ?? DateTime.now()),
      ),
    ),
  );
  return saved ?? false;
}

class ManualActivityPage extends StatefulWidget {
  const ManualActivityPage({
    super.key,
    required this.category,
    required this.initialStart,
  });

  /// Free-text label (`Run`, `Trail run`, ...).
  final String category;

  /// Local start time the pickers open on.
  final DateTime initialStart;

  @override
  State<ManualActivityPage> createState() => _ManualActivityPageState();
}

class _ManualActivityPageState extends State<ManualActivityPage> {
  final TextEditingController _distance = TextEditingController();
  final TextEditingController _hours = TextEditingController();
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _seconds = TextEditingController();
  // Blank = not entered (no `elevation_gain_m` key), never an implied 0.
  final TextEditingController _elevation = TextEditingController();
  final TextEditingController _avgHr = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  /// Frontmatter `category` and tag suffix: lowercase, `[a-z0-9_]` only.
  late final String _category;
  late DateTime _start = truncateToMinute(widget.initialStart);

  double? _rpe;
  bool _touched = false;
  bool _saving = false;

  String? _distanceError;
  String? _durationError;
  String? _elevationError;
  String? _hrError;
  String? _rpeError;

  @override
  void initState() {
    super.initState();
    final slug = widget.category
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    _category = slug.isEmpty ? 'run' : slug;
  }

  @override
  void dispose() {
    _distance.dispose();
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    _elevation.dispose();
    _avgHr.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ---- parsing / validation ---------------------------------------------------

  static int _whole(String text) => int.tryParse(text.trim()) ?? 0;

  int get _durationSeconds =>
      _whole(_hours.text) * 3600 +
      _whole(_minutes.text) * 60 +
      _whole(_seconds.text);

  String get _label {
    final c = widget.category.trim();
    if (c.isEmpty) return 'Activity';
    return '${c[0].toUpperCase()}${c.substring(1)}';
  }

  /// Live pace preview (`m:ss /km`), or null until a valid distance and
  /// duration are both entered (a blank distance has no pace).
  String? get _pacePreview {
    final d = _parseNumber(_distance.text);
    final secs = _durationSeconds;
    if (d == null || !d.isFinite || d <= 0 || secs < 1) return null;
    final perKm = (secs / d).round();
    return '${perKm ~/ 60}:${(perKm % 60).toString().padLeft(2, '0')}';
  }

  /// Validates every field, showing inline errors. True when all pass.
  bool _validate() {
    final errors = validateManualActivity(
      distanceText: _distance.text,
      durationSeconds: _durationSeconds,
      elevationText: _elevation.text,
      avgHrText: _avgHr.text,
      rpe: _rpe,
    );
    setState(() {
      _distanceError = errors.distance;
      _durationError = errors.duration;
      _elevationError = errors.elevation;
      _hrError = errors.avgHr;
      _rpeError = errors.rpe;
    });
    return errors.isValid;
  }

  // ---- actions ----------------------------------------------------------------

  Future<void> _save() async {
    if (_saving) return;
    if (!_validate()) return;

    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      // Never in the future (the pickers clamp; this is the final check).
      final start = _start.isAfter(now) ? truncateToMinute(now) : _start;

      final activity = buildManualActivity(
        category: _category,
        label: _label,
        start: start,
        now: now,
        durationSeconds: _durationSeconds,
        distanceText: _distance.text,
        elevationText: _elevation.text,
        avgHrText: _avgHr.text,
        rpe: _rpe,
        notes: _notes.text,
      );
      final title = activity.title;

      await services.vault.saveActivity(activity);

      // The watcher would catch this too; reindex now so the calendar and
      // history update immediately. A failed reindex must not fail a save.
      unawaited(
        services.reindexer
            .reindex()
            .catchError((Object _) => const ReindexReport()),
      );
      messenger.showSnackBar(SnackBar(content: Text('Saved $title')));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save activity: $e')),
      );
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard activity?'),
        content: const Text('What you entered has not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) Navigator.of(context).pop(false);
  }

  void _markTouched() {
    if (!_touched) _touched = true;
  }

  // ---- build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pace = _pacePreview;
    return PopScope(
      canPop: !_touched || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Log $_label',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Without GPS',
                style: TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ],
          ),
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            StartTimeCard(
              start: _start,
              enabled: !_saving,
              title: 'Started',
              onChanged: (v) => setState(() {
                _markTouched();
                _start = v;
              }),
            ),
            _field(
              controller: _distance,
              label: 'Distance (km, optional)',
              error: _distanceError,
              decimal: true,
              onChanged: () => setState(() => _distanceError = null),
            ),
            const SizedBox(height: 12),
            _durationFields(),
            if (pace != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Text(
                  'Average pace  $pace /km',
                  style: const TextStyle(color: AppColors.textDim),
                ),
              ),
            const SizedBox(height: 12),
            _field(
              controller: _elevation,
              label: 'Elevation gain (m, optional)',
              error: _elevationError,
              decimal: true,
              onChanged: () => setState(() => _elevationError = null),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _avgHr,
              label: 'Average heart rate (bpm, optional)',
              error: _hrError,
              decimal: false,
              onChanged: () => setState(() => _hrError = null),
            ),
            const SizedBox(height: 16),
            _rpeSection(),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                // Rebuild once so the leave-confirmation guard turns on.
                if (!_touched) setState(() => _touched = true);
              },
              decoration: const InputDecoration(
                labelText: 'Notes (one per line)',
                hintText: 'How did it feel?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save Session'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? error,
    required bool decimal,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) {
        _markTouched();
        onChanged();
      },
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _durationFields() {
    Widget part(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) {
              _markTouched();
              setState(() => _durationError = null);
            },
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              errorText: _durationError == null ? null : '',
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            part(_hours, 'h'),
            const SizedBox(width: 8),
            part(_minutes, 'min'),
            const SizedBox(width: 8),
            part(_seconds, 'sec'),
          ],
        ),
        Padding(
          padding:
              EdgeInsets.only(top: _durationError == null ? 4 : 0, left: 12),
          child: Text(
            _durationError ?? 'Moving time',
            style: TextStyle(
              fontSize: 12,
              color:
                  _durationError == null ? AppColors.textDim : AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }

  Widget _rpeSection() {
    final rpe = _rpe;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _rpeError == null ? AppColors.outline : AppColors.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Session RPE (optional)',
                style: TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
              const Spacer(),
              if (rpe != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _rpe = null;
                            _rpeError = null;
                          }),
                  child: const Text('Clear'),
                ),
              Text(
                rpe == null ? '\u2013' : formatDecimal(rpe),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: rpe == null ? AppColors.textDim : AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            min: 1,
            max: 10,
            divisions: 18,
            value: (rpe ?? 5.0).clamp(1.0, 10.0).toDouble(),
            label: rpe == null ? null : formatDecimal(rpe),
            onChanged: _saving
                ? null
                : (v) => setState(() {
                      _markTouched();
                      _rpe = v;
                      _rpeError = null;
                    }),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              _rpeError ?? '1 very easy \u00b7 10 maximal',
              style: TextStyle(
                fontSize: 12,
                color: _rpeError == null ? AppColors.textDim : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
