/// Reads and writes ObsidianFit notes (`.md`) in the vault directory.
///
/// Two layers:
///  * pure, static `parse*` / `render*` functions (Markdown <-> models),
///    testable without touching the filesystem;
///  * instance methods that do atomic file IO against [vaultDir].
///
/// Known round-trip limits (by design, see model docs):
///  * set lines are renumbered 1..n on render;
///  * numbers are re-emitted via `formatDecimal` (`7.50` -> `7.5`);
///  * exercise notes keep their text but not their position relative to sets;
///  * [PlanProgram] keeps everything outside the H1, the weekly rotation and
///    the habit checklist in `extraBody`, rendered after those sections (its
///    original position in the note is not kept).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/Models.dart';
import 'FrontMatterCodec.dart';
import 'gpx_service.dart';

class FilePersistenceService {
  FilePersistenceService(this.vaultDir);

  /// Shared-storage vault on Android, readable by Syncthing/FolderSync.
  static const String androidSharedVaultPath =
      '/storage/emulated/0/Documents/ObsidianFit';

  /// Opens the default vault, creating it if needed.
  ///
  /// Android: `/storage/emulated/0/Documents/ObsidianFit` when "All files
  /// access" is granted (needed for plain `dart:io` writes to shared storage
  /// on Android 11+), else `<external app dir>/ObsidianFit`, else the
  /// app-private documents directory. Only the first location is visible to
  /// Syncthing. Other platforms: `<app documents>/ObsidianFit`.
  static Future<FilePersistenceService> openDefault() async {
    final dir = await resolveDefaultVaultDir();
    await dir.create(recursive: true);
    return FilePersistenceService(dir);
  }

  static Future<Directory> resolveDefaultVaultDir() async {
    if (Platform.isAndroid) {
      final shared = Directory(androidSharedVaultPath);
      if (await _hasAllFilesAccess() && await _canCreate(shared)) return shared;

      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir = Directory(p.join(external.path, 'ObsidianFit'));
        if (await _canCreate(dir)) return dir;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'ObsidianFit'));
  }

  static Future<bool> _hasAllFilesAccess() async {
    try {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _canCreate(Directory dir) async {
    try {
      await dir.create(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  final Directory vaultDir;

  /// Vault sub-folders, relative to [vaultDir].
  static const String workoutsFolder = 'Workouts';
  static const String activitiesFolder = 'Activities';
  static const String plansFolder = 'Plans';

  /// GPX tracks. Not in [dataFolders]: the re-indexer only reads `.md` notes.
  static const String tracksFolder = 'Tracks';
  static const List<String> dataFolders = [
    workoutsFolder,
    activitiesFolder,
    plansFolder,
  ];

  /// Creates the vault root and the three data folders if missing.
  Future<void> ensureStructure() async {
    for (final f in [...dataFolders, tracksFolder]) {
      await Directory(p.join(vaultDir.path, f)).create(recursive: true);
    }
  }

  /// Vault-relative path with forward slashes (stable across devices),
  /// e.g. `Workouts/2026-10-22_1800_Push_Day_A.md`.
  String relativePath(File file) =>
      p.split(p.relative(file.path, from: vaultDir.path)).join('/');

  // ===========================================================================
  // Parsing
  // ===========================================================================

  static final RegExp _h1 = RegExp(r'^#\s+(.*?)\s*$');
  static final RegExp _h2 = RegExp(r'^##\s+(.*?)\s*$');

  static WorkoutSession parseWorkout(String source) {
    final doc = FrontMatterCodec.parse(source);
    final lines = doc.body.split('\n');

    var title = '';
    var seenH1 = false;
    final preamble = <String>[];
    final exercises = <ExerciseEntry>[];

    String? name;
    var sets = <SetEntry>[];
    var notes = <String>[];

    void flush() {
      if (name == null) return;
      exercises.add(
        ExerciseEntry(
          name: name,
          sets: List.unmodifiable(sets),
          notes: _trimBlankLines(notes),
        ),
      );
      sets = <SetEntry>[];
      notes = <String>[];
    }

    for (final line in lines) {
      final h2 = _h2.firstMatch(line);
      if (h2 != null) {
        flush();
        name = h2.group(1)!;
        continue;
      }
      if (name == null) {
        final h1 = _h1.firstMatch(line);
        if (!seenH1 && h1 != null) {
          title = h1.group(1)!;
          seenH1 = true;
        } else {
          preamble.add(line);
        }
        continue;
      }
      final set = SetEntry.tryParseLine(line);
      if (set != null) {
        sets.add(set);
      } else {
        notes.add(line);
      }
    }
    flush();

    return WorkoutSession.fromFrontmatter(
      doc.frontmatter,
      title: title,
      preamble: _trimBlankLines(preamble),
      exercises: exercises,
    );
  }

  static ActivitySession parseActivity(String source) {
    final doc = FrontMatterCodec.parse(source);
    final lines = doc.body.split('\n');

    var title = '';
    var start = 0;
    while (start < lines.length && lines[start].trim().isEmpty) {
      start++;
    }
    if (start < lines.length) {
      final h1 = _h1.firstMatch(lines[start]);
      if (h1 != null) {
        title = h1.group(1)!;
        start++;
      } else {
        start = 0;
      }
    }

    return ActivitySession.fromFrontmatter(
      doc.frontmatter,
      title: title,
      bodyText: _trimBlankLines(lines.sublist(start)),
    );
  }

  static PlanProgram parsePlan(String source) {
    final doc = FrontMatterCodec.parse(source);
    final lines = doc.body.split('\n');

    var title = '';
    var seenH1 = false;
    final rotation = <RotationDay>[];
    final habits = <HabitItem>[];
    var section = _PlanSection.none;
    final extra = <String>[];

    for (final line in lines) {
      final h2 = _h2.firstMatch(line);
      if (h2 != null) {
        final t = h2.group(1)!.toLowerCase();
        section = t.contains('rotation')
            ? _PlanSection.rotation
            : t.contains('habit')
                ? _PlanSection.habits
                : _PlanSection.other;
        if (section == _PlanSection.other) extra.add(line);
        continue;
      }
      if (!seenH1 && section == _PlanSection.none) {
        final h1 = _h1.firstMatch(line);
        if (h1 != null) {
          title = h1.group(1)!;
          seenH1 = true;
          continue;
        }
      }
      switch (section) {
        case _PlanSection.rotation:
          final r = RotationDay.tryParseLine(line);
          if (r != null) {
            rotation.add(r);
          } else if (line.trim().isNotEmpty) {
            extra.add(line);
          }
        case _PlanSection.habits:
          final h = HabitItem.tryParseLine(line);
          if (h != null) {
            habits.add(h);
          } else if (line.trim().isNotEmpty) {
            extra.add(line);
          }
        case _PlanSection.none:
        case _PlanSection.other:
          extra.add(line);
      }
    }

    return PlanProgram.fromFrontmatter(
      doc.frontmatter,
      title: title,
      weeklyRotation: rotation,
      dailyHabits: habits,
      extraBody: _trimBlankLines(extra),
    );
  }

  /// Parses any ObsidianFit note, dispatching on frontmatter `type`.
  /// Returns a [WorkoutSession], [ActivitySession], [PlanProgram], or null
  /// for notes that are not ObsidianFit data (no/unknown `type`).
  static Object? parseAny(String source) {
    final type = FrontMatterCodec.parse(source).frontmatter['type']?.toString();
    switch (type) {
      case 'strength':
        return parseWorkout(source);
      case 'activity':
        return parseActivity(source);
      case 'program_plan':
        return parsePlan(source);
      default:
        return null;
    }
  }

  // ===========================================================================
  // Rendering
  // ===========================================================================

  static String renderWorkout(WorkoutSession s) {
    final b = StringBuffer();
    if (s.title.isNotEmpty) b.writeln('# ${s.title}');
    if (s.preamble.isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.writeln(s.preamble);
    }
    for (final e in s.exercises) {
      if (b.isNotEmpty) b.writeln();
      b.writeln('## ${e.name}');
      for (var i = 0; i < e.sets.length; i++) {
        b.writeln(e.sets[i].toMarkdownLine(i + 1));
      }
      if (e.notes.isNotEmpty) {
        b.writeln();
        b.writeln(e.notes);
      }
    }
    return FrontMatterCodec.encode(s.toFrontmatter(), b.toString());
  }

  static String renderActivity(ActivitySession a) {
    final b = StringBuffer();
    if (a.title.isNotEmpty) b.writeln('# ${a.title}');
    if (a.bodyText.isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.writeln(a.bodyText);
    }
    return FrontMatterCodec.encode(a.toFrontmatter(), b.toString());
  }

  static String renderPlan(PlanProgram plan) {
    final b = StringBuffer();
    if (plan.title.isNotEmpty) b.writeln('# ${plan.title}');
    if (plan.weeklyRotation.isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.writeln('## Weekly Rotation');
      for (final r in plan.weeklyRotation) {
        b.writeln(r.toMarkdownLine());
      }
    }
    if (plan.dailyHabits.isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.writeln('## Daily Habit Checklist');
      for (final h in plan.dailyHabits) {
        b.writeln(h.toMarkdownLine());
      }
    }
    if (plan.extraBody.isNotEmpty) {
      if (b.isNotEmpty) b.writeln();
      b.writeln(plan.extraBody);
    }
    return FrontMatterCodec.encode(plan.toFrontmatter(), b.toString());
  }

  // ===========================================================================
  // File IO
  // ===========================================================================

  /// Saves a workout into `Workouts/`. Pass [relativePath] (as returned by
  /// [FilePersistenceService.relativePath]) to overwrite an existing note;
  /// otherwise a unique `yyyy-MM-dd_HHmm_<split>.md` name is generated.
  Future<File> saveWorkout(WorkoutSession s, {String? relativePath}) {
    final path = relativePath ??
        _uniquePath(
          workoutsFolder,
          _stem(s.date, s.timeStarted, s.split, 'Workout'),
        );
    return _writeAtomic(path, renderWorkout(s));
  }

  /// Saves an activity into `Activities/`.
  Future<File> saveActivity(ActivitySession a, {String? relativePath}) {
    final path = relativePath ??
        _uniquePath(
          activitiesFolder,
          _stem(a.date, a.timeStarted, a.category, 'Activity'),
        );
    return _writeAtomic(path, renderActivity(a));
  }

  /// Saves a plan into `Plans/`.
  Future<File> savePlan(PlanProgram plan, {String? relativePath}) {
    final path = relativePath ??
        _uniquePath(plansFolder, 'Plan_${_slug(plan.programName, 'Plan')}');
    return _writeAtomic(path, renderPlan(plan));
  }

  /// Saves GPX text as `Tracks/YYYY-MM-DD_HHMM_Route.gpx` (`_2`, `_3`, ...
  /// if taken). The returned file's basename is what a note's `gpx_file`
  /// wikilink should reference.
  Future<File> saveGpx(DateTime startedAt, String gpxXml) {
    final fileName = GpxService.fileNameFor(startedAt);
    final stem = p.basenameWithoutExtension(fileName);
    var path = '$tracksFolder/$stem.gpx';
    var n = 2;
    while (File(p.join(vaultDir.path, path)).existsSync()) {
      path = '$tracksFolder/${stem}_$n.gpx';
      n++;
    }
    return _writeAtomic(path, gpxXml);
  }

  /// Reads a track by bare file name (as stored in `ActivitySession.gpxFileName`).
  Future<String> readTrack(String fileName) =>
      File(p.join(vaultDir.path, tracksFolder, fileName)).readAsString();

  /// Deletes a track by bare file name; ignores a missing file.
  Future<void> deleteTrack(String fileName) async {
    final f = File(p.join(vaultDir.path, tracksFolder, fileName));
    if (await f.exists()) await f.delete();
  }

  /// Reads and parses one note. See [parseAny] for return types.
  Future<Object?> readParsed(File file) async =>
      parseAny(await file.readAsString());

  /// All `.md` files under the vault, skipping hidden folders such as
  /// `.obsidian` and `.stfolder`. Input for the directory re-indexer.
  ///
  /// Pass [folders] (vault-relative) to scan only those; missing ones are
  /// skipped. Defaults to the whole vault.
  Future<List<File>> listMarkdownFiles({List<String>? folders}) async {
    if (!await vaultDir.exists()) return const [];
    final roots = folders == null
        ? [vaultDir]
        : [for (final f in folders) Directory(p.join(vaultDir.path, f))];
    final out = <File>[];
    for (final root in roots) {
      if (!await root.exists()) continue;
      await for (final entity in root.list(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.md')) continue;
        final rel = p.relative(entity.path, from: vaultDir.path);
        if (p.split(rel).any((seg) => seg.startsWith('.'))) continue;
        out.add(entity);
      }
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  // ---- internals ------------------------------------------------------------

  /// Write to a temp file in the same directory, then rename, so a sync tool
  /// or a crash never sees a half-written note.
  Future<File> _writeAtomic(String fileName, String content) async {
    final target = File(p.join(vaultDir.path, fileName));
    await target.parent.create(recursive: true);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    return tmp.rename(target.path);
  }

  /// `<folder>/<stem>.md`, or `<folder>/<stem>_2.md`, `_3`, ... if taken.
  String _uniquePath(String folder, String stem) {
    var path = '$folder/$stem.md';
    var n = 2;
    while (File(p.join(vaultDir.path, path)).existsSync()) {
      path = '$folder/${stem}_$n.md';
      n++;
    }
    return path;
  }

  static String _stem(
    DateTime date,
    String timeStarted,
    String label,
    String fallback,
  ) {
    final hhmm = timeStarted.replaceAll(':', '');
    return '${formatIsoDate(date)}_${hhmm}_${_slug(label, fallback)}';
  }

  static String _slug(String s, String fallback) {
    final slug = s
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? fallback : slug;
  }

  /// Joins [lines], dropping leading/trailing blank lines but keeping inner
  /// formatting and indentation untouched.
  static String _trimBlankLines(List<String> lines) {
    var start = 0;
    var end = lines.length;
    while (start < end && lines[start].trim().isEmpty) {
      start++;
    }
    while (end > start && lines[end - 1].trim().isEmpty) {
      end--;
    }
    return lines.sublist(start, end).join('\n');
  }
}

enum _PlanSection { none, rotation, habits, other }
