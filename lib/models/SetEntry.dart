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

/// One logged set. Weights are always stored in kg (see config `units`), box
/// heights in cm. Spec: `schemas/workout_schema.phase5.md`.
///
/// Markdown line grammar (pipe-delimited; the writer always emits this
/// segment order, the reader accepts the optional segments in any order):
///
/// ```text
/// - Set <n>: <load> x <reps> reps [| RPE <r>] [| Box: <cm>cm] [| Contact: <ms>ms] | Type: <W|N|D|F>
/// - Set <n>: <load> | Hold: <s>s [| RPE <r>] [| Box: <cm>cm] [| Contact: <ms>ms] | Type: <W|N|D|F>
/// ```
///
/// `<load>` is `80kg` (external load) or `BW+<n>kg` (bodyweight plus `n` kg;
/// bare `BW` is read as `BW+0kg`, the writer always emits `BW+<n>kg`).
///
/// Modalities:
///  * weighted lift: `80kg x 8 reps`
///  * bodyweight / weighted bodyweight: `BW+0kg x 12 reps`, `BW+10kg x 6 reps`
///  * isometric hold: `BW+0kg | Hold: 60s` ([durationSeconds], no [reps])
///  * plyometric: `BW+0kg x 5 reps | Box: 60cm | Contact: 210ms`
class SetEntry {
  const SetEntry({
    this.weightKg = 0,
    this.reps,
    this.rpe,
    this.type = SetType.normal,
    this.isBodyweight = false,
    this.extraWeightKg,
    this.durationSeconds,
    this.boxHeightCm,
    this.contactTimeMs,
  }) : assert(
          reps == null || durationSeconds == null,
          'A set has either reps or a hold duration, never both.',
        );

  /// External load in kg. Only meaningful when [isBodyweight] is false; it is
  /// `0` (and ignored) for bodyweight sets.
  final double weightKg;

  /// Repetitions (or jump count for plyometrics). Null for isometric holds,
  /// which use [durationSeconds] instead.
  final int? reps;
  final double? rpe;
  final SetType type;

  /// True when the load is the athlete's own bodyweight, optionally plus
  /// [extraWeightKg].
  final bool isBodyweight;

  /// Added load (belt, vest, dumbbell) on a bodyweight set. Null is read as
  /// `0` (pure bodyweight). Ignored when [isBodyweight] is false.
  final double? extraWeightKg;

  /// Isometric hold time in seconds. Exclusive with [reps].
  final int? durationSeconds;

  /// Box / drop height in cm (plyometrics).
  final double? boxHeightCm;

  /// Ground contact time in ms (plyometrics).
  final int? contactTimeMs;

  /// The load that counts toward progressive-overload tonnage: the added
  /// weight for bodyweight sets (bodyweight itself counts as `0`), otherwise
  /// the external weight.
  double get loadKg => isBodyweight ? (extraWeightKg ?? 0.0) : weightKg;

  /// True for an isometric hold (a duration instead of reps).
  bool get isHold => durationSeconds != null;

  /// Tonnage of this set: `loadKg x reps`. Pure bodyweight sets contribute
  /// `0`, and so does any set without reps (holds, including weighted ones).
  /// Whether warmups count is decided by the caller.
  double get computedVolumeKg {
    final r = reps;
    if (r == null) return 0;
    return loadKg * r;
  }

  /// Alias of [computedVolumeKg], kept for existing callers.
  double get volumeKg => computedVolumeKg;

  /// Copy with changes. The nullable fields cannot be set back to null with
  /// `null`; pass the matching `clear*` flag (needed e.g. to turn a rep set
  /// into a hold: `copyWith(durationSeconds: 30, clearReps: true)`).
  SetEntry copyWith({
    double? weightKg,
    int? reps,
    bool clearReps = false,
    double? rpe,
    bool clearRpe = false,
    SetType? type,
    bool? isBodyweight,
    double? extraWeightKg,
    bool clearExtraWeight = false,
    int? durationSeconds,
    bool clearDuration = false,
    double? boxHeightCm,
    bool clearBoxHeight = false,
    int? contactTimeMs,
    bool clearContactTime = false,
  }) {
    return SetEntry(
      weightKg: weightKg ?? this.weightKg,
      reps: clearReps ? null : (reps ?? this.reps),
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      type: type ?? this.type,
      isBodyweight: isBodyweight ?? this.isBodyweight,
      extraWeightKg:
          clearExtraWeight ? null : (extraWeightKg ?? this.extraWeightKg),
      durationSeconds:
          clearDuration ? null : (durationSeconds ?? this.durationSeconds),
      boxHeightCm: clearBoxHeight ? null : (boxHeightCm ?? this.boxHeightCm),
      contactTimeMs:
          clearContactTime ? null : (contactTimeMs ?? this.contactTimeMs),
    );
  }

  // ---- parsing --------------------------------------------------------------

  /// `- Set 3:` prefix; `body` is everything after the colon.
  static final RegExp _prefix =
      RegExp(r'^\s*[-*]\s*Set\s+\d+\s*:\s*(?<body>.*?)\s*$');

  /// First segment: the load, optionally followed by `x <reps> [reps]`.
  /// Case-insensitive (`BW`, `kg`, `x`).
  static final RegExp _main = RegExp(
    r'^(?:(?<w>\d+(?:\.\d+)?)\s*kg|(?<bw>BW)(?:\s*\+\s*(?<x>\d+(?:\.\d+)?)\s*kg)?)'
    r'(?:\s*[x×]\s*(?<r>\d+)\s*(?:reps?)?)?$',
    caseSensitive: false,
  );

  static final RegExp _rpeSegment =
      RegExp(r'^RPE\s*(\d+(?:\.\d+)?)$', caseSensitive: false);
  static final RegExp _typeSegment =
      RegExp(r'^Type\s*:\s*([WNDF])$', caseSensitive: false);
  static final RegExp _holdSegment =
      RegExp(r'^Hold\s*:\s*(\d+)\s*s$', caseSensitive: false);
  static final RegExp _boxSegment =
      RegExp(r'^Box\s*:\s*(\d+(?:\.\d+)?)\s*cm$', caseSensitive: false);
  static final RegExp _contactSegment =
      RegExp(r'^Contact\s*:\s*(\d+)\s*ms$', caseSensitive: false);

  /// Returns null if [line] is not a valid set line (so the caller keeps it as
  /// free-form exercise notes). A set needs exactly one of `x <reps> reps` or
  /// `Hold: <s>s`; unknown or repeated segments make the line invalid.
  static SetEntry? tryParseLine(String line) {
    final head = _prefix.firstMatch(line);
    if (head == null) return null;

    final parts = head
        .namedGroup('body')!
        .split('|')
        .map((s) => s.trim())
        .toList(growable: false);

    final main = _main.firstMatch(parts.first);
    if (main == null) return null;

    final isBodyweight = main.namedGroup('bw') != null;
    final double weightKg =
        isBodyweight ? 0.0 : double.tryParse(main.namedGroup('w')!) ?? 0.0;
    final double? extraWeightKg = isBodyweight
        ? (double.tryParse(main.namedGroup('x') ?? '') ?? 0.0)
        : null;

    int? reps;
    final repsText = main.namedGroup('r');
    if (repsText != null) {
      reps = int.tryParse(repsText);
      if (reps == null) return null;
    }

    double? rpe;
    SetType? type;
    int? hold;
    double? box;
    int? contact;

    for (final segment in parts.skip(1)) {
      final rpeMatch = _rpeSegment.firstMatch(segment);
      if (rpeMatch != null) {
        if (rpe != null) return null;
        rpe = double.tryParse(rpeMatch.group(1)!);
        if (rpe == null) return null;
        continue;
      }
      final typeMatch = _typeSegment.firstMatch(segment);
      if (typeMatch != null) {
        if (type != null) return null;
        type = SetType.fromCode(typeMatch.group(1));
        continue;
      }
      final holdMatch = _holdSegment.firstMatch(segment);
      if (holdMatch != null) {
        if (hold != null) return null;
        hold = int.tryParse(holdMatch.group(1)!);
        if (hold == null) return null;
        continue;
      }
      final boxMatch = _boxSegment.firstMatch(segment);
      if (boxMatch != null) {
        if (box != null) return null;
        box = double.tryParse(boxMatch.group(1)!);
        if (box == null) return null;
        continue;
      }
      final contactMatch = _contactSegment.firstMatch(segment);
      if (contactMatch != null) {
        if (contact != null) return null;
        contact = int.tryParse(contactMatch.group(1)!);
        if (contact == null) return null;
        continue;
      }
      return null; // unknown segment: not a set line
    }

    // Exactly one of reps / hold.
    if ((reps == null) == (hold == null)) return null;

    return SetEntry(
      weightKg: weightKg,
      reps: reps,
      rpe: rpe,
      type: type ?? SetType.normal,
      isBodyweight: isBodyweight,
      extraWeightKg: extraWeightKg,
      durationSeconds: hold,
      boxHeightCm: box,
      contactTimeMs: contact,
    );
  }

  // ---- rendering ------------------------------------------------------------

  /// [index] is the 1-based set number within the exercise.
  ///
  /// Segment order is fixed (load, reps or hold, RPE, Box, Contact, Type) so
  /// the round trip is lossless. `Type` is always written.
  String toMarkdownLine(int index) {
    final b = StringBuffer('- Set $index: ');
    if (isBodyweight) {
      b.write('BW+${formatDecimal(extraWeightKg ?? 0.0)}kg');
    } else {
      b.write('${formatDecimal(weightKg)}kg');
    }

    final hold = durationSeconds;
    if (hold != null) {
      b.write(' | Hold: ${hold}s');
    } else {
      b.write(' x ${reps ?? 0} reps');
    }

    if (rpe != null) b.write(' | RPE ${rpe!.toStringAsFixed(1)}');
    if (boxHeightCm != null) {
      b.write(' | Box: ${formatDecimal(boxHeightCm!)}cm');
    }
    if (contactTimeMs != null) b.write(' | Contact: ${contactTimeMs}ms');
    b.write(' | Type: ${type.code}');
    return b.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is SetEntry &&
      other.isBodyweight == isBodyweight &&
      other.loadKg == loadKg &&
      other.reps == reps &&
      other.durationSeconds == durationSeconds &&
      other.boxHeightCm == boxHeightCm &&
      other.contactTimeMs == contactTimeMs &&
      other.rpe == rpe &&
      other.type == type;

  @override
  int get hashCode => Object.hash(
        isBodyweight,
        loadKg,
        reps,
        durationSeconds,
        boxHeightCm,
        contactTimeMs,
        rpe,
        type,
      );

  @override
  String toString() => 'SetEntry(${toMarkdownLine(0)})';
}
