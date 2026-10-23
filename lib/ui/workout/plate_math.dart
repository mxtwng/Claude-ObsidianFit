/// Pure plate-loading maths (no Flutter), so it can be unit tested.
library;

class PlateResult {
  const PlateResult({
    required this.targetKg,
    required this.barKg,
    required this.platesPerSide,
    required this.loadedKg,
    required this.belowBar,
  });

  final double targetKg;
  final double barKg;

  /// Plate weight -> count for ONE side, heaviest first.
  final Map<double, int> platesPerSide;

  /// Actual total weight with these plates (bar + both sides).
  final double loadedKg;

  /// True when the target is lighter than the empty bar.
  final bool belowBar;

  double get perSideKg =>
      platesPerSide.entries.fold(0.0, (sum, e) => sum + e.key * e.value);

  /// How far the loadable weight falls short of the target (0 if exact).
  double get shortfallKg => belowBar ? 0 : targetKg - loadedKg;

  bool get isExact => !belowBar && shortfallKg.abs() < 1e-6;
}

class PlateMath {
  const PlateMath._();

  /// Available plates, heaviest first.
  static const List<double> plates = [20, 10, 5, 2.5, 1.25];

  static const double _smallest = 1.25;

  /// Greedy per-side plate set for [targetKg]. Every plate is a multiple of
  /// 1.25 kg, so greedy is optimal; if the target needs a finer step than
  /// 2.5 kg total, the result rounds DOWN and [PlateResult.shortfallKg]
  /// reports the difference.
  static PlateResult calculate(double targetKg, {double barKg = 20}) {
    if (targetKg < barKg) {
      return PlateResult(
        targetKg: targetKg,
        barKg: barKg,
        platesPerSide: const {},
        loadedKg: barKg,
        belowBar: true,
      );
    }
    // Work in integer units of 1.25 kg to avoid floating-point drift.
    var units = (((targetKg - barKg) / 2) / _smallest + 1e-9).floor();
    final counts = <double, int>{};
    for (final plate in plates) {
      final plateUnits = (plate / _smallest).round();
      final n = units ~/ plateUnits;
      if (n > 0) {
        counts[plate] = n;
        units -= n * plateUnits;
      }
    }
    final perSide = counts.entries.fold(0.0, (s, e) => s + e.key * e.value);
    return PlateResult(
      targetKg: targetKg,
      barKg: barKg,
      platesPerSide: counts,
      loadedKg: barKg + 2 * perSide,
      belowBar: false,
    );
  }
}
