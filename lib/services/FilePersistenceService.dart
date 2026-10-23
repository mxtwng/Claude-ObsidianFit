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
///  * [PlanProgram] has no body-extras field yet, so sections other than
///    "Weekly Rotation" and "Daily Habit Checklist" are not preserved.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/Models.dart';
import 'FrontMatterCodec.dart';

class FilePersistenceService {
  FilePersistenceService(this.vaultDir);

  /// Opens `<app documents>/ObsidianFit`, creating it if needed.
  ///
  /// NOTE: on Android `getApplicationDocumentsDirectory()` is app-private, so
  /// Syncthing cannot see it. A shared-storage vault path must be chosen
  /// before sync works on Android; construct the service with that directory.
  static Future<FilePersistenceService> openDefault() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ObsidianFit'));
    await dir.create(recursive: true);
    return FilePersistenceService(dir);
  }

  final Directory vaultDir;

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
          name: name!,
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

    for (final line in lines) {
      final h2 = _h2.firstMatch(line);
      if (h2 != null) {
        final t = h2.group(1)!.toLowerCase();
        section = t.contains('rotation')
            ? _PlanSection.rotation
            : t.contains('habit')
                ? _PlanSection.habits
                : _PlanSection.other;
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
          if (r != null) rotation.add(r);
        case _PlanSection.habits:
          final h = HabitItem.tryParseLine(line);
          if (h != null) habits.add(h);
        case _PlanSection.none:
        case _PlanSection.other:
          break;
      }
    }

    return PlanProgram.fromFrontmatter(
      doc.frontmatter,
      title: title,
      weeklyRotation: rotation,
      dailyHabits: habits,
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
    return FrontMatterCodec.encode(plan.toFrontmatter(), b.toString());
  }

  // ===========================================================================
  // File IO
  // ===========================================================================

  /// Saves a workout. Pass [fileName] to overwrite an existing note; otherwise
  /// a unique `yyyy-MM-dd_HHmm_<split>.md` name is generated.
  Future<File> saveWorkout(WorkoutSession s, {String? fileName}) {
    final name = fileName ??
        _uniqueName(_stem(s.date, s.timeStarted, s.split, 'Workout'), 'md');
    return _writeAtomic(name, renderWorkout(s));
  }

  Future<File> saveActivity(ActivitySession a, {String? fileName}) {
    final name = fileName ??
        _uniqueName(_stem(a.date, a.timeStarted, a.category, 'Activity'), 'md');
    return _writeAtomic(name, renderActivity(a));
  }

  Future<File> savePlan(PlanProgram plan, {String? fileName}) {
    final name =
        fileName ?? _uniqueName('Plan_${_slug(plan.programName, 'Plan')}', 'md');
    return _writeAtomic(name, renderPlan(plan));
  }

  /// Reads and parses one note. See [parseAny] for return types.
  Future<Object?> readParsed(File file) async =>
      parseAny(await file.readAsString());

  /// All `.md` files under the vault, skipping hidden folders such as
  /// `.obsidian` and `.stfolder`. Input for the directory re-indexer.
  Future<List<File>> listMarkdownFiles() async {
    if (!await vaultDir.exists()) return const [];
    final out = <File>[];
    await for (final entity in vaultDir.list(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.md')) continue;
      final rel = p.relative(entity.path, from: vaultDir.path);
      if (p.split(rel).any((seg) => seg.startsWith('.'))) continue;
      out.add(entity);
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  // ---- internals ------------------------------------------------------------

  /// Write to a temp file in the same directory, then rename, so a sync tool
  /// or a crash never sees a half-written note.
  Future<File> _writeAtomic(String fileName, String content) async {
    await vaultDir.create(recursive: true);
    final target = File(p.join(vaultDir.path, fileName));
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    return tmp.rename(target.path);
  }

  String _uniqueName(String stem, String ext) {
    var name = '$stem.$ext';
    var n = 2;
    while (File(p.join(vaultDir.path, name)).existsSync()) {
      name = '${stem}_$n.$ext';
      n++;
    }
    return name;
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
