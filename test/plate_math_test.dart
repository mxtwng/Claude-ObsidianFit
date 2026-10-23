import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/ui/workout/plate_math.dart';

void main() {
  group('PlateMath.calculate', () {
    test('empty bar is exact and needs no plates', () {
      final r = PlateMath.calculate(20);
      expect(r.belowBar, isFalse);
      expect(r.platesPerSide, isEmpty);
      expect(r.loadedKg, 20);
      expect(r.isExact, isTrue);
    });

    test('target lighter than the bar is flagged', () {
      final r = PlateMath.calculate(15);
      expect(r.belowBar, isTrue);
      expect(r.platesPerSide, isEmpty);
      expect(r.loadedKg, 20);
      expect(r.isExact, isFalse);
    });

    test('60 kg = one 20 per side', () {
      final r = PlateMath.calculate(60);
      expect(r.platesPerSide, {20.0: 1});
      expect(r.perSideKg, 20);
      expect(r.loadedKg, 60);
      expect(r.isExact, isTrue);
    });

    test('100 kg = two 20s per side', () {
      final r = PlateMath.calculate(100);
      expect(r.platesPerSide, {20.0: 2});
      expect(r.loadedKg, 100);
    });

    test('uses the smallest plate for fractional loads', () {
      final r = PlateMath.calculate(62.5);
      expect(r.platesPerSide, {20.0: 1, 1.25: 1});
      expect(r.loadedKg, 62.5);
      expect(r.isExact, isTrue);
    });

    test('mixes plate sizes greedily', () {
      final r = PlateMath.calculate(72.5);
      expect(r.platesPerSide, {20.0: 1, 5.0: 1, 1.25: 1});
      expect(r.perSideKg, 26.25);
      expect(r.loadedKg, 72.5);
    });

    test('lists plates heaviest first', () {
      final r = PlateMath.calculate(97.5);
      expect(r.platesPerSide.keys.toList(), [20.0, 10.0, 5.0, 2.5, 1.25]);
      expect(r.loadedKg, 97.5);
    });

    test('respects a 15 kg bar', () {
      final r = PlateMath.calculate(100, barKg: 15);
      expect(r.platesPerSide, {20.0: 2, 2.5: 1});
      expect(r.loadedKg, 100);
    });

    test('rounds down when the target is finer than 2.5 kg total', () {
      final r = PlateMath.calculate(61);
      expect(r.platesPerSide, {20.0: 1});
      expect(r.loadedKg, 60);
      expect(r.isExact, isFalse);
      expect(r.shortfallKg, closeTo(1.0, 1e-9));
    });

    test('loaded weight never exceeds the target', () {
      for (var kg = 20.0; kg <= 300; kg += 0.5) {
        final r = PlateMath.calculate(kg);
        expect(r.loadedKg, lessThanOrEqualTo(kg + 1e-9), reason: '$kg kg');
        expect(r.shortfallKg, lessThan(2.5), reason: '$kg kg');
      }
    });
  });
}
