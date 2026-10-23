/// Outdoor activity screen: Start / Pause / Resume / Stop controls, live
/// metrics, a MapLibre view that follows the user, and a heart-rate monitor
/// sheet.
///
/// Flow: idle -> recording <-> paused -> stopped (summary) -> saved.
/// "Save Session" writes two files through `FilePersistenceService`:
///  * `Tracks/YYYY-MM-DD_HHMM_Route.gpx`  (GPX 1.1, one `<trkseg>` per pause)
///  * `Activities/YYYY-MM-DD_HHMM_<category>.md`  (frontmatter + notes, with
///    `gpx_file: "[[...gpx]]"` pointing at the track)
/// The Drift index is then refreshed by the re-indexer. The user never sees
/// or types Markdown here: notes are plain text and are turned into bullets
/// on save.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:path/path.dart' as p;

import '../../models/Models.dart';
import '../../services/activity_metrics.dart' as metrics;
import '../../services/gpx_service.dart';
import '../../services/location_ble_service.dart';
import '../../services/screen_awake.dart';
import '../../services/vault_reindexer_service.dart';
import '../app_services.dart';
import '../common/prompt_dialog.dart';
import '../theme/app_theme.dart';
import 'hr_sheet.dart';
import 'map_view.dart';

const List<String> _categorySuggestions = ['Run', 'Ride', 'Walk', 'Hike'];

/// Asks which kind of activity to record, then opens the recording screen.
/// Returns true if an activity was saved.
Future<bool> startOutdoorActivity(BuildContext context) async {
  final label = await promptText(
    context,
    title: 'Start activity',
    initial: 'Run',
    hint: 'e.g. Run',
    suggestions: _categorySuggestions,
  );
  if (label == null || !context.mounted) return false;
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ActivitySessionPage(category: label),
    ),
  );
  return saved ?? false;
}

class ActivitySessionPage extends StatefulWidget {
  const ActivitySessionPage({super.key, required this.category});

  /// Free-text label from the start prompt (`Run`, `Trail run`, ...).
  final String category;

  @override
  State<ActivitySessionPage> createState() => _ActivitySessionPageState();
}

class _ActivitySessionPageState extends State<ActivitySessionPage> {
  late final HeartRateMonitor _hr;
  late final ActivityRecorder _recorder;
  final TextEditingController _notes = TextEditingController();

  /// Frontmatter `category` and tag suffix: lowercase, `[a-z0-9_]` only.
  late final String _category;

  bool _locationReady = false;
  String? _locationError;
  LatLng? _initialTarget;

  RecordedActivity? _result;
  bool _saving = false;

  /// Set once the GPX is on disk, so a retry after a failed note write does
  /// not create a second track file.
  String? _savedGpxName;

  @override
  void initState() {
    super.initState();
    final slug = widget.category
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    _category = slug.isEmpty ? 'run' : slug;
    _hr = HeartRateMonitor();
    _recorder = ActivityRecorder(heartRate: _hr);
    unawaited(_prepareLocation());
  }

  @override
  void dispose() {
    unawaited(ScreenAwake.disable());
    _recorder.dispose();
    _hr.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ---- setup ----------------------------------------------------------------

  /// Asks for permissions up front so the map can show the user's location
  /// dot before the recording starts.
  Future<void> _prepareLocation() async {
    final error = await ActivityRecorder.requestPermissions();
    LatLng? target;
    if (error == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) target = LatLng(last.latitude, last.longitude);
      } catch (_) {
        // Not available on every platform; the map recentres on the first fix.
      }
    }
    if (!mounted) return;
    setState(() {
      _locationError = error;
      _locationReady = error == null;
      _initialTarget = target;
    });
  }

  // ---- actions --------------------------------------------------------------

  Future<void> _start() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await _recorder.start();
    if (!mounted) return;
    if (error != null) {
      setState(() => _locationError = error);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    HapticFeedback.mediumImpact();
    unawaited(ScreenAwake.enable());
    if (!_locationReady) {
      setState(() {
        _locationError = null;
        _locationReady = true;
      });
    }
  }

  void _pause() {
    HapticFeedback.selectionClick();
    _recorder.pause();
  }

  void _resume() {
    HapticFeedback.selectionClick();
    _recorder.resume();
  }

  Future<void> _stop() async {
    final go = await _confirm(
      title: 'Finish activity?',
      message: 'Recording stops and you can review the session before '
          'saving it.',
      confirmLabel: 'Finish',
    );
    if (!go || !mounted) return;
    final result = await _recorder.stop();
    if (!mounted || result == null) return;
    unawaited(ScreenAwake.disable());
    HapticFeedback.mediumImpact();
    setState(() => _result = result);
  }

  Future<void> _discard() async {
    final go = await _confirm(
      title: 'Discard activity?',
      message: 'This recording has not been saved and will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!go || !mounted) return;
    await _recorder.discard();
    unawaited(ScreenAwake.disable());
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _confirmLeave() => _discard();

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving) return;

    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final started = result.startedAt;
      final label = _label;
      final title = result.hasTrack && result.distanceM >= 10
          ? '${result.distanceKm.toStringAsFixed(1)} km $label'
          : label;

      // 1. GPX track (only if GPS produced points).
      if (result.hasTrack && _savedGpxName == null) {
        final xml = GpxService.render(result.segments, name: title);
        final file = await services.vault.saveGpx(started, xml);
        _savedGpxName = p.basename(file.path);
      }

      // 2. Activity note.
      final activity = ActivitySession(
        category: _category,
        date: DateTime(started.year, started.month, started.day),
        timeStarted: DateFormat('HH:mm').format(started),
        durationMin: (result.activeDuration.inSeconds / 60 * 10).round() / 10,
        distanceKm: result.hasTrack
            ? double.parse(result.distanceKm.toStringAsFixed(2))
            : null,
        elevationGainM:
            result.hasTrack ? result.elevationGainM.roundToDouble() : null,
        avgHr: result.avgHr,
        maxHr: result.maxHr,
        avgPaceMinKm: result.avgPaceMinKm,
        tssScore: result.tss,
        gpxFileName: _savedGpxName,
        tags: ['fitness/$_category'],
        title: title,
        bodyText: _notesAsBullets(_notes.text),
      );
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

  // ---- derived --------------------------------------------------------------

  String get _label {
    final c = widget.category.trim();
    if (c.isEmpty) return 'Activity';
    return '${c[0].toUpperCase()}${c.substring(1)}';
  }

  /// Plain text lines -> Markdown bullets, matching `activity_schema.md`.
  static String _notesAsBullets(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .where((l) => l.isNotEmpty);
    return lines.map((l) => '- $l').join('\n');
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _recorder,
      builder: (context, _) {
        final state = _recorder.state;
        final stopped = state == RecorderState.stopped;
        return PopScope(
          canPop: state == RecorderState.idle,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed:
                    _saving ? null : () => Navigator.of(context).maybePop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    switch (state) {
                      RecorderState.idle => 'Ready',
                      RecorderState.recording => 'Recording',
                      RecorderState.paused => 'Paused',
                      RecorderState.stopped => 'Review',
                    },
                    style: TextStyle(
                      fontSize: 12,
                      color: state == RecorderState.paused
                          ? AppColors.warmup
                          : state == RecorderState.recording
                              ? AppColors.done
                              : AppColors.textDim,
                    ),
                  ),
                ],
              ),
              actions: [
                if (!stopped) _hrButton(),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                Expanded(child: _mapArea(state)),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SafeArea(
                      top: false,
                      child: stopped ? _summaryPanel() : _livePanel(state),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hrButton() {
    return ListenableBuilder(
      listenable: _hr,
      builder: (context, _) {
        final linked = _hr.state != HrConnectionState.disconnected;
        final bpm = _hr.freshBpm;
        return TextButton.icon(
          onPressed: _saving ? null : () => showHeartRateSheet(context, _hr),
          icon: Icon(
            Icons.favorite,
            size: 20,
            color: linked ? AppColors.danger : AppColors.textDim,
          ),
          label: Text(
            bpm != null ? '$bpm' : (linked ? '--' : 'HR'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: linked ? AppColors.text : AppColors.textDim,
            ),
          ),
        );
      },
    );
  }

  // ---- map --------------------------------------------------------------------

  Widget _mapArea(RecorderState state) {
    if (state == RecorderState.stopped) {
      final result = _result;
      return TrackMapView(
        // New key: a fresh map that fits the finished route once.
        key: const ValueKey('review-map'),
        segments: result?.segments ?? const [],
        fitToTrack: true,
      );
    }

    if (!_locationReady) {
      return ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_locationError == null)
                  const CircularProgressIndicator()
                else ...[
                  const Icon(
                    Icons.location_off,
                    size: 40,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _locationError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _prepareLocation,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final live =
        state == RecorderState.recording || state == RecorderState.paused;
    return Stack(
      children: [
        Positioned.fill(
          child: TrackMapView(
            key: const ValueKey('live-map'),
            segments: _recorder.segments,
            showUserLocation: true,
            followUser: true,
            initialTarget: _initialTarget,
          ),
        ),
        if (live && _recorder.lastPosition == null)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: _Pill('Waiting for GPS…')),
          ),
      ],
    );
  }

  // ---- panels -----------------------------------------------------------------

  Widget _livePanel(RecorderState state) {
    final r = _recorder;
    final pace = metrics.formatPace(r.avgPaceSecPerKm);
    final hr = r.currentHr;
    final avg = r.avgHr;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Tile('Time', metrics.formatDuration(r.elapsed), large: true),
            _Tile('Distance', '${(r.distanceM / 1000).toStringAsFixed(2)} km',
                large: true),
            _Tile('Avg pace', pace == null ? '--' : '$pace /km', large: true),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Tile('Elevation', '${r.elevationGainM.round()} m'),
            _Tile(
              'Heart rate',
              hr == null ? '--' : '$hr bpm',
              color: hr == null ? null : AppColors.danger,
              onTap: () => showHeartRateSheet(context, _hr),
            ),
            _Tile('Avg HR', avg == null ? '--' : '$avg bpm'),
          ],
        ),
        const SizedBox(height: 16),
        _controls(state),
      ],
    );
  }

  Widget _controls(RecorderState state) {
    switch (state) {
      case RecorderState.idle:
        return FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        );
      case RecorderState.recording:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _stopButton()),
          ],
        );
      case RecorderState.paused:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _resume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _stopButton()),
          ],
        );
      case RecorderState.stopped:
        return const SizedBox.shrink();
    }
  }

  Widget _stopButton() {
    return FilledButton.icon(
      onPressed: _stop,
      icon: const Icon(Icons.stop),
      label: const Text('Stop'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
      ),
    );
  }

  Widget _summaryPanel() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();
    final pace = r.avgPaceMinKm;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Tile('Time', metrics.formatDuration(r.activeDuration),
                large: true),
            _Tile('Distance', '${r.distanceKm.toStringAsFixed(2)} km',
                large: true),
            _Tile('Avg pace', pace == null ? '--' : '$pace /km', large: true),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Tile('Elevation', '${r.elevationGainM.round()} m'),
            _Tile('Avg HR', r.avgHr == null ? '--' : '${r.avgHr} bpm'),
            _Tile('TSS', r.tss == null ? '--' : '${r.tss}'),
          ],
        ),
        if (!r.hasTrack)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No GPS points were recorded, so no route will be saved.',
              style: TextStyle(color: AppColors.warmup),
            ),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _notes,
          enabled: !_saving,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes (one per line)',
            hintText: 'How did it feel?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _saving ? null : _discard,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Discard'),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Small widgets
// =============================================================================

class _Tile extends StatelessWidget {
  const _Tile(
    this.label,
    this.value, {
    this.large = false,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final bool large;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 24 : 18,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ],
      ),
    );
    return Expanded(
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: child,
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textDim),
        ),
      ),
    );
  }
}
