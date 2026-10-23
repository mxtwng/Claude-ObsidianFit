import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/services/gpx_service.dart';
import 'package:obsidian_fit/services/track_profile.dart';

import 'support/track_fixtures.dart';

/// Phase 6: chart-ready pace and elevation series.
///
/// The fixtures run due north in 10 m steps, 3 s per step (a 5:00 /km pace),
/// so every distance and pace below can be derived by hand.
void main() {
  group('degenerate input gives an empty profile', () {
    test('no segments', () {
      final profile = TrackProfile.build(const []);
      expect(profile.isEmpty, isTrue);
      expect(profile.samples, isEmpty);
      expect(profile.totalDistanceM, 0);
      expect(profile.totalTimeS, 0);
      expect(profile.avgPaceSecPerKm, isNull);
      expect(profile.hasElevation, isFalse);
      expect(profile.hasPace, isFalse);
      expect(profile.elevationRange, isNull);
      expect(profile.paceRange, isNull);
    });

    test('a single point', () {
      final profile = TrackProfile.build([steadySegment(steps: 0)]);
      expect(profile.isEmpty, isTrue);
    });

    test('points that never moved (zero distance)', () {
      final a = TrackPoint(lat: 10, lon: 106, time: kTrackStart);
      final b = TrackPoint(
        lat: 10,
        lon: 106,
        time: kTrackStart.add(const Duration(seconds: 30)),
      );
      expect(
          TrackProfile.build([
            [a, b]
          ]).isEmpty,
          isTrue);
    });

    test('fewer than two samples requested', () {
      final profile = TrackProfile.build(
        [steadySegment(steps: 100)],
        maxSamples: 1,
      );
      expect(profile.isEmpty, isTrue);
    });

    test('the shared empty constant is empty', () {
      expect(TrackProfile.empty.isEmpty, isTrue);
    });
  });

  group('steady 1 km at 5:00 /km', () {
    final profile = TrackProfile.build([steadySegment(steps: 100)]);

    test('keeps every point of a short track', () {
      expect(profile.samples, hasLength(101));
      expect(profile.isEmpty, isFalse);
    });

    test('totals', () {
      expect(profile.totalDistanceM, closeTo(1000, 0.01));
      expect(profile.totalTimeS, closeTo(300, 1e-6));
      expect(profile.avgPaceSecPerKm, closeTo(300, 0.01));
    });

    test('distance and time never go backwards', () {
      for (var i = 1; i < profile.samples.length; i++) {
        expect(
          profile.samples[i].distanceM,
          greaterThan(profile.samples[i - 1].distanceM),
        );
        expect(
          profile.samples[i].timeS,
          greaterThan(profile.samples[i - 1].timeS),
        );
      }
    });

    test('the first samples have no pace yet (under 30 m covered)', () {
      expect(profile.samples[0].distanceM, 0);
      expect(profile.samples[0].timeS, 0);
      expect(profile.samples[0].paceSecPerKm, isNull);
      expect(profile.samples[1].paceSecPerKm, isNull);
    });

    test('once there is a window, the rolling pace is 300 s/km', () {
      for (var i = 4; i < profile.samples.length; i++) {
        expect(
          profile.samples[i].paceSecPerKm,
          closeTo(300, 0.01),
          reason: 'sample $i',
        );
      }
    });

    test('has pace but no elevation', () {
      expect(profile.hasPace, isTrue);
      expect(profile.hasElevation, isFalse);
      expect(profile.elevationRange, isNull);
    });

    test('a flat pace gets the minimum 30 s tall chart range', () {
      final range = profile.paceRange!;
      expect(range.fast, closeTo(285, 0.01));
      expect(range.slow, closeTo(315, 0.01));
    });
  });

  group('elevation', () {
    test('a steady climb is reported with a smoothed range', () {
      // +1 m per 10 m step: 100 m up over 1 km.
      final profile = TrackProfile.build([
        steadySegment(steps: 100, ele: (i) => 100.0 + i),
      ]);
      expect(profile.hasElevation, isTrue);

      final range = profile.elevationRange!;
      // The smoothing window is clipped at both ends, so the extremes sit a
      // little inside the raw 100..200 m.
      expect(range.min, inInclusiveRange(100, 103));
      expect(range.max, inInclusiveRange(197, 200));
      // Mid-track the symmetric window averages back to the raw value.
      expect(profile.samples[50].eleM, closeTo(150, 1.0));
    });

    test('a flat track still gets a 10 m tall chart range', () {
      final profile = TrackProfile.build([
        steadySegment(steps: 100, ele: (_) => 120.0),
      ]);
      final range = profile.elevationRange!;
      expect(range.min, closeTo(115, 1e-9));
      expect(range.max, closeTo(125, 1e-9));
    });

    test('GPS altitude jitter is smoothed out', () {
      // Raw altitude flips between 100 and 106 m every point.
      final profile = TrackProfile.build([
        steadySegment(steps: 100, ele: (i) => i.isEven ? 100.0 : 106.0),
      ]);
      for (var i = 5; i <= 95; i++) {
        expect(
          profile.samples[i].eleM,
          inInclusiveRange(102, 104),
          reason: 'sample $i',
        );
      }
    });

    test('samples with no altitude nearby stay null', () {
      final profile = TrackProfile.build([
        steadySegment(steps: 100, ele: (i) => i < 50 ? null : 100.0),
      ]);
      expect(profile.hasElevation, isTrue);
      expect(profile.samples.first.eleM, isNull);
      expect(profile.samples.last.eleM, closeTo(100, 1e-9));
    });

    test('a track without any altitude has no elevation series', () {
      final profile = TrackProfile.build([
        steadySegment(steps: 100, ele: (_) => null),
      ]);
      expect(profile.hasElevation, isFalse);
      expect(profile.elevationRange, isNull);
      expect(profile.samples.every((s) => s.eleM == null), isTrue);
    });
  });

  group('pauses', () {
    final profile = TrackProfile.build([
      steadySegment(steps: 50),
      // Resumed an hour later and half a degree (about 55 km) away.
      steadySegment(
        steps: 50,
        startLat: 10.5,
        start: kTrackStart.add(const Duration(hours: 1)),
      ),
    ]);

    test('the gap adds no distance and no time', () {
      expect(profile.samples, hasLength(102));
      expect(profile.totalDistanceM, closeTo(1000, 0.5));
      expect(profile.totalTimeS, closeTo(300, 1e-6));
      expect(profile.avgPaceSecPerKm, closeTo(300, 0.5));
    });

    test('the first point after the pause continues where the last ended', () {
      final before = profile.samples[50];
      final after = profile.samples[51];
      expect(after.distanceM, closeTo(before.distanceM, 1e-6));
      expect(after.timeS, before.timeS);
    });

    test('the rolling pace does not spike across the pause', () {
      for (var i = 4; i < profile.samples.length; i++) {
        expect(
          profile.samples[i].paceSecPerKm,
          closeTo(300, 0.5),
          reason: 'sample $i',
        );
      }
    });
  });

  group('down-sampling', () {
    // 2001 points, 5 m apart: a 10 km track at 5:00 /km.
    final longTrack = [
      steadySegment(steps: 2000, secPerStep: 1.5, stepM: 5),
    ];

    test('a long track is cut to about maxSamples', () {
      final profile = TrackProfile.build(longTrack);
      expect(profile.samples.length, inInclusiveRange(300, 401));
    });

    test('keeps the first and the last point', () {
      final profile = TrackProfile.build(longTrack);
      expect(profile.samples.first.distanceM, 0);
      expect(profile.samples.last.distanceM, closeTo(10000, 0.1));
      expect(profile.samples.last.timeS, closeTo(3000, 1e-6));
      expect(profile.avgPaceSecPerKm, closeTo(300, 0.01));
    });

    test('samples stay strictly ordered by distance', () {
      final profile = TrackProfile.build(longTrack);
      for (var i = 1; i < profile.samples.length; i++) {
        expect(
          profile.samples[i].distanceM,
          greaterThan(profile.samples[i - 1].distanceM),
        );
      }
    });

    test('maxSamples is respected', () {
      final profile = TrackProfile.build(longTrack, maxSamples: 50);
      expect(profile.samples.length, inInclusiveRange(40, 51));
    });
  });

  group('paceRange ignores stops', () {
    test('two stationary points do not stretch the chart', () {
      final moving = steadySegment(steps: 100);
      final last = moving.last;
      final withStop = [
        ...moving,
        // Standing still for a minute, then another minute.
        TrackPoint(
          lat: last.lat,
          lon: last.lon,
          time: last.time.add(const Duration(seconds: 60)),
        ),
        TrackPoint(
          lat: last.lat,
          lon: last.lon,
          time: last.time.add(const Duration(seconds: 120)),
        ),
      ];
      final profile = TrackProfile.build([withStop]);

      // The stop itself is visible in the series...
      expect(profile.samples.last.paceSecPerKm, greaterThan(600));
      // ...but the 97th percentile keeps it out of the vertical range.
      final range = profile.paceRange!;
      expect(range.fast, closeTo(285, 0.01));
      expect(range.slow, closeTo(315, 0.01));
    });

    test('a varying pace uses the spread of the data', () {
      // 500 m at 4:00 /km, then 500 m at 6:00 /km.
      final profile = TrackProfile.build([
        buildSegment([(50, 2.4), (50, 3.6)]),
      ]);
      final range = profile.paceRange!;
      expect(range.fast, closeTo(240, 5));
      expect(range.slow, closeTo(360, 5));
      expect(range.slow - range.fast, greaterThanOrEqualTo(30));
    });
  });

  group('indexAtDistance', () {
    final profile = TrackProfile.build([steadySegment(steps: 100)]);

    test('exact distances map to their sample', () {
      expect(profile.indexAtDistance(0), 0);
      expect(profile.indexAtDistance(500), 50);
      expect(profile.indexAtDistance(1000), 100);
    });

    test('out-of-range distances clamp to the ends', () {
      expect(profile.indexAtDistance(-50), 0);
      expect(profile.indexAtDistance(5000), 100);
    });

    test('picks the nearest sample between two', () {
      expect(profile.indexAtDistance(254), 25);
      expect(profile.indexAtDistance(256), 26);
    });
  });
}
