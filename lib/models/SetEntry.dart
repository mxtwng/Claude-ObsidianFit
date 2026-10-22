import 'ModelUtils.dart';

/// Set classification. Serialized as a single letter: `W`, `N`, `D`, `F`.
enum SetType {
  warmup('W'),
  normal('N'),
  drop('D'),
  failure('F');

  const SetType(this.code);

  final String code;

  /// Parses a single-letter code (case-insensitive). Unknown -> [normal].
  static SetType fromCode(String? code) {
    final c = code?.trim().toUpperCase();
    for (final t in SetType.values) {
      if (t.code == c) return t;
    }
    return SetType.normal;
  }
}

/// One logged set. Weights are always stored in kg (see config `units`).
///
/// Markdown line grammar:
/// `- Set 1: 80kg x 8 reps | RPE 7.0 | Type: N`
class SetEntry {
  const SetEntry({
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.type = SetType.normal,
  });

  final double weightKg;
  final int reps;
  final double? rpe;
  final SetType type;

  double get volumeKg => weightKg * reps;

  SetEntry copyWith({
    double? weightKg,
    int? reps,
    double? rpe,
    bool clearRpe = false,
    SetType? type,
  }) {
    return SetEntry(
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      type: type ?? this.type,
    );
  }

  static final RegExp _line = RegExp(
    r'^\s*[-*]\s*Set\s+\d+\s*:\s*'
    r'(?<w>\d+(?:\.\d+)?)\s*kg\s*[x×]\s*(?<r>\d+)\s*(?:reps?)?'
    r'(?:\s*\|\s*RPE\s*(?<rpe>\d+(?:\.\d+)?))?'
    r'(?:\s*\|\s*Type\s*:\s*(?<t>[WNDFwndf]))?'
    r'\s*$',
  );

  /// Returns null if [line] is not a set line.
  static SetEntry? tryParseLine(String line) {
    final m = _line.firstMatch(line);
    if (m == null) return null;
    return SetEntry(
      weightKg: double.parse(m.namedGroup('w')!),
      reps: int.parse(m.namedGroup('r')!),
      rpe: m.namedGroup('rpe') == null
          ? null
          : double.parse(m.namedGroup('rpe')!),
      type: SetType.fromCode(m.namedGroup('t')),
    );
  }

  /// [index] is the 1-based set number within the exercise.
  String toMarkdownLine(int index) {
    final b = StringBuffer(
      '- Set $index: ${formatDecimal(weightKg)}kg x $reps reps',
    );
    if (rpe != null) b.write(' | RPE ${rpe!.toStringAsFixed(1)}');
    b.write(' | Type: ${type.code}');
    return b.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is SetEntry &&
      other.weightKg == weightKg &&
      other.reps == reps &&
      other.rpe == rpe &&
      other.type == type;

  @override
  int get hashCode => Object.hash(weightKg, reps, rpe, type);

  @override
  String toString() => 'SetEntry(${toMarkdownLine(0)})';
}
