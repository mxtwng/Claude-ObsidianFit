/// Keeps the Drift index in step with the Markdown vault.
///
/// Scans `Workouts/`, `Activities/` and `Plans/`, compares each file's
/// modified time with the index row's `updatedAt`, re-parses changed notes
/// through [FilePersistenceService], upserts them, and drops rows whose files
/// are gone.
///
/// Call [start] at launch: it creates the vault folders, runs one full scan,
/// then watches the vault (debounced). Also call [reindex] when the app
/// resumes, because directory watching is unreliable for changes made by
/// another process (e.g. Syncthing) on some platforms.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../models/Models.dart';
import 'FilePersistenceService.dart';
import 'app_database.dart';

class ReindexReport {
  const ReindexReport({
    this.scanned = 0,
    this.upserted = 0,
    this.unchanged = 0,
    this.removed = 0,
    this.errors = const [],
  });

  final int scanned;
  final int upserted;
  final int unchanged;
  final int removed;

  /// One entry per file that could not be parsed or indexed.
  final List<String> errors;

  @override
  String toString() => 'ReindexReport(scanned: $scanned, upserted: $upserted, '
      'unchanged: $unchanged, removed: $removed, errors: ${errors.length})';
}

class VaultReindexerService {
  VaultReindexerService({
    required this.vault,
    required this.database,
    this.debounce = const Duration(milliseconds: 500),
  });

  final FilePersistenceService vault;
  final AppDatabase database;
  final Duration debounce;

  StreamSubscription<FileSystemEvent>? _watchSub;
  Timer? _debounceTimer;
  Future<ReindexReport>? _running;
  bool _rerunRequested = false;
  bool _disposed = false;
  final StreamController<ReindexReport> _reports =
      StreamController<ReindexReport>.broadcast();

  /// Emits a report after every completed scan (manual or watcher-triggered).
  Stream<ReindexReport> get reports => _reports.stream;

  /// Creates the vault folders, runs a full scan, then starts watching.
  Future<ReindexReport> start() async {
    await vault.ensureStructure();
    final report = await reindex();
    _startWatching();
    return report;
  }

  /// Stops watching. [reindex] can still be called manually.
  void stop() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _watchSub?.cancel();
    _watchSub = null;
  }

  void dispose() {
    _disposed = true;
    stop();
    _reports.close();
  }

  /// Runs a full scan. Calls made while a scan is in flight share it and cause
  /// exactly one follow-up pass, so a change landing mid-scan is never missed.
  Future<ReindexReport> reindex() {
    final running = _running;
    if (running != null) {
      _rerunRequested = true;
      return running;
    }
    final run = _runLoop();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<ReindexReport> _runLoop() async {
    ReindexReport report;
    do {
      _rerunRequested = false;
      report = await _scan();
      if (!_disposed) _reports.add(report);
    } while (_rerunRequested);
    return report;
  }

  // ---- watching -------------------------------------------------------------

  void _startWatching() {
    if (_watchSub != null || _disposed) return;
    try {
      _watchSub = vault.vaultDir.watch(recursive: true).listen(
        (event) {
          if (_isRelevant(event.path)) _scheduleReindex();
        },
        // Watching is best-effort; launch/resume scans are the safety net.
        onError: (Object _) {},
      );
    } on FileSystemException {
      // Platform cannot watch this directory.
    }
  }

  bool _isRelevant(String path) {
    if (path.endsWith('.tmp')) return false; // our own atomic-write temp file
    final rel = path.startsWith(vault.vaultDir.path)
        ? path.substring(vault.vaultDir.path.length)
        : path;
    // Ignore hidden folders/files (.obsidian, .stfolder, .git, ...).
    return !rel.split(Platform.pathSeparator).any((s) => s.startsWith('.'));
  }

  void _scheduleReindex() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (_disposed) return;
      reindex().catchError((Object _) => const ReindexReport());
    });
  }

  // ---- scan -----------------------------------------------------------------

  Future<ReindexReport> _scan() async {
    if (!await vault.vaultDir.exists()) {
      // Vault unreachable (storage unmounted, folder moved): do NOT wipe the
      // index, or every row would look deleted.
      return ReindexReport(
        errors: ['Vault directory missing: ${vault.vaultDir.path}'],
      );
    }

    final files = await vault.listMarkdownFiles(
      folders: FilePersistenceService.dataFolders,
    );
    final indexed = await database.indexedTimestamps();
    final seen = <String>{};
    final errors = <String>[];
    var upserted = 0;
    var unchanged = 0;

    for (final file in files) {
      final rel = vault.relativePath(file);
      seen.add(rel);
      try {
        // Stat before reading: if the file changes during the read, its
        // mtime differs next scan and it is re-indexed.
        final modified = _truncateToSeconds((await file.stat()).modified);
        final previous = indexed[rel];
        if (previous != null && previous.isAtSameMomentAs(modified)) {
          unchanged++;
          continue;
        }

        final parsed =
            FilePersistenceService.parseAny(await file.readAsString());
        switch (parsed) {
          case WorkoutSession w:
            await database.upsertWorkout(_workoutRow(rel, w, modified));
            upserted++;
          case ActivitySession a:
            await database.upsertActivity(_activityRow(rel, a, modified));
            upserted++;
          case PlanProgram plan:
            await database.upsertPlan(_planRow(rel, plan, modified));
            upserted++;
          default:
            // Not an ObsidianFit note (no/unknown `type`). Treat as absent so
            // a previously indexed row is removed below.
            seen.remove(rel);
        }
      } catch (e) {
        // Unreadable/invalid note: keep any existing row, report the problem.
        errors.add('$rel: $e');
      }
    }

    final stale = indexed.keys.where((path) => !seen.contains(path));
    final removed = await database.removePaths(stale);

    return ReindexReport(
      scanned: files.length,
      upserted: upserted,
      unchanged: unchanged,
      removed: removed,
      errors: errors,
    );
  }

  static DateTime _truncateToSeconds(DateTime d) =>
      DateTime.fromMillisecondsSinceEpoch(
        (d.millisecondsSinceEpoch ~/ 1000) * 1000,
      );

  static WorkoutsIndexCompanion _workoutRow(
    String path,
    WorkoutSession w,
    DateTime modified,
  ) {
    return WorkoutsIndexCompanion.insert(
      filePath: path,
      split: w.split,
      date: w.date,
      timeStarted: w.timeStarted,
      durationMin: w.durationMin,
      totalVolumeKg: Value(w.totalVolumeKg),
      tssScore: Value(w.tssScore),
      readinessScore: Value(w.readinessScore),
      updatedAt: modified,
    );
  }

  static ActivitiesIndexCompanion _activityRow(
    String path,
    ActivitySession a,
    DateTime modified,
  ) {
    return ActivitiesIndexCompanion.insert(
      filePath: path,
      category: a.category,
      date: a.date,
      timeStarted: a.timeStarted,
      durationMin: a.durationMin,
      distanceKm: Value(a.distanceKm),
      elevationGainM: Value(a.elevationGainM),
      avgHr: Value(a.avgHr),
      tssScore: Value(a.tssScore),
      gpxFileName: Value(a.gpxFileName),
      updatedAt: modified,
    );
  }

  static PlansIndexCompanion _planRow(
    String path,
    PlanProgram plan,
    DateTime modified,
  ) {
    return PlansIndexCompanion.insert(
      filePath: path,
      programName: plan.programName,
      durationWeeks: plan.durationWeeks,
      daysPerWeek: Value(plan.daysPerWeek),
      startDate: Value(plan.startDate),
      updatedAt: modified,
    );
  }
}
