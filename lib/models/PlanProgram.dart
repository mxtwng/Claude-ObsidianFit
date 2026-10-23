import 'ModelUtils.dart';

/// One line of the weekly rotation: `- **Monday:** Push Day A`.
class RotationDay {
  const RotationDay({required this.day, required this.session});

  final String day;
  final String session;

  static final RegExp _line =
      RegExp(r'^\s*[-*]\s*\*\*(?<d>[^*:]+?):\*\*\s*(?<s>.*?)\s*$');

  static RotationDay? tryParseLine(String line) {
    final m = _line.firstMatch(line);
    if (m == null) return null;
    return RotationDay(day: m.namedGroup('d')!, session: m.namedGroup('s')!);
  }

  String toMarkdownLine() => '- **$day:** $session';

  @override
  bool operator ==(Object other) =>
      other is RotationDay && other.day == day && other.session == session;

  @override
  int get hashCode => Object.hash(day, session);
}

/// One checklist line: `- [ ] 3L Water Intake` / `- [x] ...`.
class HabitItem {
  const HabitItem({required this.label, this.done = false});

  final String label;
  final bool done;

  static final RegExp _line =
      RegExp(r'^\s*[-*]\s*\[(?<c>[ xX])\]\s*(?<l>.*?)\s*$');

  static HabitItem? tryParseLine(String line) {
    final m = _line.firstMatch(line);
    if (m == null) return null;
    return HabitItem(
      label: m.namedGroup('l')!,
      done: m.namedGroup('c')!.trim().isNotEmpty,
    );
  }

  String toMarkdownLine() => '- [${done ? 'x' : ' '}] $label';

  HabitItem copyWith({String? label, bool? done}) =>
      HabitItem(label: label ?? this.label, done: done ?? this.done);

  @override
  bool operator ==(Object other) =>
      other is HabitItem && other.label == label && other.done == done;

  @override
  int get hashCode => Object.hash(label, done);
}

/// A multi-week training program. Mirrors `schemas/plan_schema.md`.
class PlanProgram {
  const PlanProgram({
    this.type = 'program_plan',
    required this.programName,
    required this.durationWeeks,
    this.daysPerWeek,
    this.startDate,
    this.tags = const [],
    this.title = '',
    this.weeklyRotation = const [],
    this.dailyHabits = const [],
    this.extraBody = '',
    this.extraFrontmatter = const {},
  });

  /// Frontmatter `type` (`program_plan`).
  final String type;
  final String programName;
  final int durationWeeks;
  final int? daysPerWeek;
  final DateTime? startDate;
  final List<String> tags;

  /// The `# H1` heading text.
  final String title;

  /// Ordered Monday..Sunday entries under `## Weekly Rotation`.
  final List<RotationDay> weeklyRotation;

  /// Checklist items under `## Daily Habit Checklist`.
  final List<HabitItem> dailyHabits;

  /// Free-form Markdown found outside the H1, the weekly rotation, and the
  /// habit checklist (extra `## Sections`, intro text, stray lines). Kept
  /// verbatim and rendered after the structured sections.
  final String extraBody;

  /// Unknown frontmatter keys, preserved verbatim.
  final Map<String, Object?> extraFrontmatter;

  static const Set<String> knownKeys = {
    'type',
    'program_name',
    'duration_weeks',
    'days_per_week',
    'start_date',
    'tags',
  };

  /// Session label for a weekday name (case-insensitive), or null.
  String? sessionFor(String day) {
    final d = day.toLowerCase();
    for (final r in weeklyRotation) {
      if (r.day.toLowerCase() == d) return r.session;
    }
    return null;
  }

  PlanProgram copyWith({
    String? type,
    String? programName,
    int? durationWeeks,
    int? daysPerWeek,
    DateTime? startDate,
    List<String>? tags,
    String? title,
    List<RotationDay>? weeklyRotation,
    List<HabitItem>? dailyHabits,
    String? extraBody,
    Map<String, Object?>? extraFrontmatter,
  }) {
    return PlanProgram(
      type: type ?? this.type,
      programName: programName ?? this.programName,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      startDate: startDate ?? this.startDate,
      tags: tags ?? this.tags,
      title: title ?? this.title,
      weeklyRotation: weeklyRotation ?? this.weeklyRotation,
      dailyHabits: dailyHabits ?? this.dailyHabits,
      extraBody: extraBody ?? this.extraBody,
      extraFrontmatter: extraFrontmatter ?? this.extraFrontmatter,
    );
  }

  /// Ordered map matching schema key order; `start_date` stays a [DateTime]
  /// so the codec can emit it unquoted.
  Map<String, Object?> toFrontmatter() {
    return <String, Object?>{
      'type': type,
      'program_name': programName,
      'duration_weeks': durationWeeks,
      if (daysPerWeek != null) 'days_per_week': daysPerWeek,
      if (startDate != null) 'start_date': startDate,
      if (tags.isNotEmpty) 'tags': tags,
      ...extraFrontmatter,
    };
  }

  factory PlanProgram.fromFrontmatter(
    Map<String, Object?> fm, {
    String title = '',
    List<RotationDay> weeklyRotation = const [],
    List<HabitItem> dailyHabits = const [],
    String extraBody = '',
  }) {
    return PlanProgram(
      type: coerceString(fm['type']) ?? 'program_plan',
      programName: coerceString(fm['program_name']) ?? '',
      durationWeeks: coerceInt(fm['duration_weeks']) ?? 0,
      daysPerWeek: coerceInt(fm['days_per_week']),
      startDate: coerceDate(fm['start_date']),
      tags: coerceStringList(fm['tags']),
      title: title,
      weeklyRotation: weeklyRotation,
      dailyHabits: dailyHabits,
      extraBody: extraBody,
      extraFrontmatter: extractExtras(fm, knownKeys),
    );
  }

  @override
  String toString() => 'PlanProgram($programName, $durationWeeks wks)';
}
