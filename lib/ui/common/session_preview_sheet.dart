/// Bottom sheet that shows a parsed session note as a normal GUI card
/// (never raw Markdown).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/Models.dart';
import '../../services/FilePersistenceService.dart';
import '../activity/map_view.dart';
import '../app_services.dart';
import '../theme/app_theme.dart';
import 'session_entry.dart';
import 'set_type_style.dart';

Future<void> showSessionPreview(
  BuildContext context,
  List<SessionEntry> entries, {
  required String heading,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (listContext, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              heading,
              style: Theme.of(listContext)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PreviewCard(entry: e),
            ),
        ],
      ),
    ),
  );
}

class _PreviewCard extends StatefulWidget {
  const _PreviewCard({required this.entry});

  final SessionEntry entry;

  @override
  State<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<_PreviewCard> {
  Future<Object>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(AppScope.of(context));
  }

  Future<Object> _load(AppServices services) async {
    final file =
        File(p.join(services.vault.vaultDir.path, widget.entry.filePath));
    final source = await file.readAsString();
    return widget.entry.kind == SessionKind.workout
        ? FilePersistenceService.parseWorkout(source)
        : FilePersistenceService.parseActivity(source);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Frame(
            child: Text(
              'Could not read ${widget.entry.filePath}\n${snap.error}',
              style: const TextStyle(color: AppColors.danger),
            ),
          );
        }
        final data = snap.data;
        if (data is WorkoutSession) return _WorkoutView(session: data);
        if (data is ActivitySession) return _ActivityView(activity: data);
        return const _Frame(
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _WorkoutView extends StatelessWidget {
  const _WorkoutView({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final volume = session.totalVolumeKg ?? session.computedVolumeKg();
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.split.isEmpty ? 'Workout' : session.split,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          Text(
            '${formatIsoDate(session.date)} · ${session.timeStarted}',
            style: const TextStyle(color: AppColors.textDim),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _Metric('Duration', '${session.durationMin.round()} min'),
              _Metric('Volume', '${formatDecimal(volume.roundToDouble())} kg'),
              _Metric('Sets', '${session.totalSets}'),
              if (session.tssScore != null)
                _Metric('TSS', '${session.tssScore}'),
              if (session.readinessScore != null)
                _Metric('Readiness', '${session.readinessScore}/10'),
            ],
          ),
          for (final e in session.exercises) ...[
            const SizedBox(height: 16),
            Text(
              e.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < e.sets.length; i++)
              _SetLine(number: i + 1, set: e.sets[i]),
            if (e.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _stripBullets(e.notes),
                  style: const TextStyle(color: AppColors.textDim),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SetLine extends StatelessWidget {
  const _SetLine({required this.number, required this.set});

  final int number;
  final SetEntry set;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$number',
              style: const TextStyle(color: AppColors.textDim),
            ),
          ),
          Expanded(
            child: Text(
              '${formatDecimal(set.weightKg)} kg × ${set.reps}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (set.rpe != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                'RPE ${set.rpe!.toStringAsFixed(1)}',
                style: const TextStyle(color: AppColors.textDim),
              ),
            ),
          if (set.type != SetType.normal)
            Text(
              setTypeName(set.type),
              style: TextStyle(
                color: setTypeColor(set.type),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView({required this.activity});

  final ActivitySession activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final c = a.category;
    final pace = a.avgPaceMinKm ?? a.computedPaceMinKm;
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.title.isNotEmpty
                ? a.title
                : (c.isEmpty
                    ? 'Activity'
                    : '${c[0].toUpperCase()}${c.substring(1)}'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.activity,
            ),
          ),
          Text(
            '${formatIsoDate(a.date)} · ${a.timeStarted}',
            style: const TextStyle(color: AppColors.textDim),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              if (a.distanceKm != null)
                _Metric('Distance', '${a.distanceKm!.toStringAsFixed(2)} km'),
              _Metric('Duration', '${a.durationMin.toStringAsFixed(0)} min'),
              if (pace != null) _Metric('Pace', '$pace /km'),
              if (a.elevationGainM != null)
                _Metric('Elevation', '${a.elevationGainM!.round()} m'),
              if (a.avgHr != null) _Metric('Avg HR', '${a.avgHr}'),
              if (a.maxHr != null) _Metric('Max HR', '${a.maxHr}'),
              if (a.tssScore != null) _Metric('TSS', '${a.tssScore}'),
            ],
          ),
          if (a.gpxFileName != null) ...[
            const SizedBox(height: 12),
            ActivityRouteMap(gpxFileName: a.gpxFileName!),
          ],
          if (a.bodyText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_stripBullets(a.bodyText),
                style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Turns Markdown list markers into plain bullets so no raw Markdown shows.
String _stripBullets(String text) =>
    text.replaceAllMapped(RegExp(r'^\s*[-*]\s+', multiLine: true), (_) => '• ');
