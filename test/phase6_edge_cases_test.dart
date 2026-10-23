// Phase 6 edge-case unit tests, aligned with the real Phase 6 APIs:
//   PrService (static compute / recordsBrokenBy, PrWorkoutSource, PrActivitySource)
//   SplitCalculator.compute + TrackProfile.build over parsed GPX tracks
//   WeeklyStatsService.compute / VaultStatsLoader (empty vault)
//   VaultStatsController(AppServices) with an in-memory Drift database

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:obsidian_fit/services/activity_metrics.dart';
import 'package:obsidian_fit/services/app_database.dart';
import 'package:obsidian_fit/services/gpx_service.dart';
import 'package:obsidian_fit/services/pr_service.dart';
import 'package:obsidian_fit/services/splits_service.dart';
import 'package:obsidian_fit/services/track_math.dart';
import 'package:obsidian_fit/services/track_profile.dart';
import 'package:obsidian_fit/services/vault_reindexer_service.dart';
import 'package:obsidian_fit/services/vault_stats_loader.dart';
import 'package:obsidian_fit/services/weekly_stats.dart';
import 'package:obsidian_fit/ui/app_services.dart';
import 'package:obsidian_fit/ui/common/vault_stats_controller.dart';
import 'package:path/path.dart' as p;

void main() {
  // ---------------------------------------------------------------------------
  // 1. PrService
  // ---------------------------------------------------------------------------
  group('PrService edge cases', () {
    test('no workouts and no activities yields an empty snapshot', () {
      final snapshot = PrService.compute();

      expect(snapshot.isEmpty, isTrue);
      for (final kind in PrKind.values) {
        expect(snapshot[kind], isNull);
      }
    });

    test('workout with no exercises produces no records', () {
      final snapshot = PrService.compute(
        workouts: [_ws(_workout(exercises: const []))],
      );

      expect(snapshot.isEmpty, isTrue);
    });

    test('exercise with zero sets produces no records', () {
      final snapshot = PrService.compute(
        workouts: [
          _ws(_workout(exercises: const [
            ExerciseEntry(name: 'Barbell Bench Press', sets: []),
            ExerciseEntry(name: 'Plank', sets: []),
          ])),
        ],
      );

      expect(snapshot.isEmpty, isTrue);
    });

    test('zero total volume: 0 kg bench sets and bodyweight bench set no 1RM',
        () {
      final snapshot = PrService.compute(
        workouts: [
          _ws(_workout(totalVolumeKg: 0, exercises: const [
            ExerciseEntry(name: 'Barbell Bench Press', sets: [
              SetEntry(weightKg: 0, reps: 8),
              SetEntry(isBodyweight: true, extraWeightKg: 20, reps: 8),
            ]),
          ])),
        ],
      );

      expect(snapshot[PrKind.bench1rm], isNull);
    });

    test('zero total volume does not stop a plank hold from being a record',
        () {
      final workout = _workout(totalVolumeKg: 0, exercises: const [
        ExerciseEntry(name: 'Plank', sets: [
          SetEntry(isBodyweight: true, extraWeightKg: 0, durationSeconds: 60),
        ]),
        ExerciseEntry(name: 'Pull-ups', sets: [
          SetEntry(isBodyweight: true, extraWeightKg: 0, reps: 10),
        ]),
      ]);
      expect(workout.computedVolumeKg(), 0);

      final snapshot = PrService.compute(workouts: [_ws(workout)]);

      expect(snapshot[PrKind.maxPlank]?.value, 60);
      expect(snapshot[PrKind.bench1rm], isNull);
    });

    test('warmup-only bench sets never count', () {
      final snapshot = PrService.compute(
        workouts: [
          _ws(_workout(exercises: const [
            ExerciseEntry(name: 'Barbell Bench Press', sets: [
              SetEntry(weightKg: 140, reps: 1, type: SetType.warmup),
            ]),
          ])),
        ],
      );

      expect(snapshot[PrKind.bench1rm], isNull);
    });

    test('bench sets above 12 reps are skipped (Epley is unreliable)', () {
      final snapshot = PrService.compute(
        workouts: [
          _ws(_workout(exercises: const [
            ExerciseEntry(name: 'Barbell Bench Press', sets: [
              SetEntry(weightKg: 40, reps: 20),
            ]),
          ])),
        ],
      );

      expect(snapshot[PrKind.bench1rm], isNull);
    });

    test('run without a GPX file counts for longest run but not as a 5K', () {
      final snapshot = PrService.compute(
        activities: [
          _as(_activity(distanceKm: 7.5, durationSeconds: 2712)),
        ],
      );

      expect(snapshot[PrKind.longestRun]?.value, 7.5);
      expect(snapshot[PrKind.fastest5k], isNull,
          reason: '7.5 km is outside the 5.00-5.25 km manual 5K window');
    });

    test('manual exact 5K run is an exact (not estimated) fastest 5K', () {
      final snapshot = PrService.compute(
        activities: [
          _as(_activity(distanceKm: 5.0, durationSeconds: 1500)),
        ],
      );

      final record = snapshot[PrKind.fastest5k]!;
      expect(record.value, closeTo(1500, 1e-6));
      expect(record.estimated, isFalse);
    });

    test('manual 5.2 km run is scaled to 5 km and flagged as estimated', () {
      final snapshot = PrService.compute(
        activities: [
          _as(_activity(distanceKm: 5.2, durationSeconds: 1560)),
        ],
      );

      final record = snapshot[PrKind.fastest5k]!;
      expect(record.value, closeTo(1500, 1e-6));
      expect(record.estimated, isTrue);
    });

    test('run with a track whose 5K could not be read gets no fastest 5K', () {
      final snapshot = PrService.compute(
        activities: [
          _as(
            _activity(
              distanceKm: 5.0,
              durationSeconds: 1500,
              gpxFileName: 'missing.gpx',
            ),
            hasTrack: true,
            fastest5k: null,
          ),
        ],
      );

      expect(snapshot[PrKind.longestRun]?.value, 5.0);
      expect(snapshot[PrKind.fastest5k], isNull,
          reason: 'A run with a track is never scored from summary numbers');
    });

    test('zero or missing distance never produces run records', () {
      final snapshot = PrService.compute(
        activities: [
          _as(_activity(distanceKm: 0, durationSeconds: 600)),
          _as(_activity(distanceKm: null, durationSeconds: 600)),
        ],
      );

      expect(snapshot[PrKind.longestRun], isNull);
      expect(snapshot[PrKind.fastest5k], isNull);
    });

    test('5K-length run with zero duration yields no fastest 5K', () {
      final snapshot = PrService.compute(
        activities: [_as(_activity(distanceKm: 5.0, durationMin: 0))],
      );

      expect(snapshot[PrKind.fastest5k], isNull);
    });

    test('non-run activities (ride) are ignored', () {
      final snapshot = PrService.compute(
        activities: [
          _as(_activity(
              category: 'ride', distanceKm: 32, durationSeconds: 5400)),
        ],
      );

      expect(snapshot.isEmpty, isTrue);
    });

    test('PrActivitySource.fromSegments with an empty track has no track', () {
      final source = PrActivitySource.fromSegments(
        path: 'Activities/x.md',
        session: _activity(distanceKm: 3, durationSeconds: 900),
        segments: const [],
      );

      expect(source.hasTrack, isFalse);
      expect(source.trackFastest5kSeconds, isNull);
    });

    test('recordsBrokenBy with nothing new reports nothing', () {
      expect(PrService.recordsBrokenBy(PrSnapshot.empty), isEmpty);
    });

    test('an equal result does not break an existing record', () {
      final run = _as(_activity(distanceKm: 10, durationSeconds: 3000));
      final current = PrService.compute(activities: [run]);

      final broken = PrService.recordsBrokenBy(current, activities: [run]);

      expect(broken, isEmpty);
    });

    test('ties go to the earliest holder', () {
      final earlier = _as(
        _activity(date: DateTime(2026, 10, 1), distanceKm: 10),
        path: 'Activities/earlier.md',
      );
      final later = _as(
        _activity(date: DateTime(2026, 10, 20), distanceKm: 10),
        path: 'Activities/later.md',
      );

      final snapshot = PrService.compute(activities: [later, earlier]);

      expect(snapshot[PrKind.longestRun]?.sourcePath, 'Activities/earlier.md');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. SplitCalculator / TrackProfile
  // ---------------------------------------------------------------------------
  group('SplitCalculator edge cases', () {
    test('no segments, an empty segment and a single point give no splits', () {
      expect(SplitCalculator.compute(const []), isEmpty);
      expect(SplitCalculator.compute(const [<TrackPoint>[]]), isEmpty);
      expect(SplitCalculator.compute(_track([_line(count: 1)])), isEmpty);
    });

    test('a remainder under 50 m is dropped, over 50 m is a partial split', () {
      final tiny = SplitCalculator.compute(_track([_line(count: 3)]));
      expect(tiny, isEmpty, reason: '~44 m is below kMinPartialSplitM');

      final short = SplitCalculator.compute(_track([_line(count: 5)]));
      expect(short, hasLength(1));
      expect(short.single.partial, isTrue);
      expect(short.single.distanceM, greaterThan(kMinPartialSplitM));
      expect(short.single.distanceM, lessThan(1000));
    });

    test('regular track: full km splits plus one partial, sane pace', () {
      final segments = _track([_line(count: 120)]);
      final totalM = CumulativeTrack.from(segments).totalDistanceM;
      final fullCount = (totalM / 1000).floor();

      final splits = SplitCalculator.compute(segments);

      expect(splits, hasLength(fullCount + 1));
      expect([for (final s in splits) s.index],
          [for (var i = 1; i <= splits.length; i++) i]);
      for (final s in splits.take(fullCount)) {
        expect(s.partial, isFalse);
        expect(s.distanceM, 1000);
        expect(s.paceSecPer(SplitUnit.km), closeTo(359.7, 1.0));
      }
      expect(splits.last.partial, isTrue);
    });

    test('stationary track (no distance covered) gives no splits', () {
      final splits = SplitCalculator.compute(
        _track([_line(count: 60, dLat: 0)]),
      );

      expect(splits, isEmpty);
    });

    test('missing <time> tags: splits exist, duration is zero, no pace shown',
        () {
      final segments = _track([_line(count: 120, withTime: false)]);

      final splits = SplitCalculator.compute(segments);

      expect(splits, isNotEmpty);
      for (final s in splits) {
        expect(s.duration, Duration.zero);
        final pace = s.paceSecPer(SplitUnit.km);
        expect(pace, isNotNull);
        expect(pace!.isNaN, isFalse);
        expect(pace.isFinite, isTrue);
        expect(formatPace(pace), isNull,
            reason: 'A zero pace must render as "no pace", not 0:00');
      }
    });

    test('timestamps missing on part of the track do not inflate durations',
        () {
      // Parsed points without <time> fall back to the Unix epoch, so a stretch
      // of them sits between two real timestamps. The elapsed time of every
      // split must still be bounded by the real recording time (~16 min).
      final segments = _track([
        _line(count: 120, dropTime: (i) => i >= 30 && i < 50),
      ]);

      final splits = SplitCalculator.compute(segments);

      expect(splits, isNotEmpty);
      for (final s in splits) {
        expect(s.duration, lessThanOrEqualTo(const Duration(minutes: 20)),
            reason: 'split ${s.index} duration blew up: ${s.duration}');
      }
    });

    test('flat track: zero gain and zero net elevation change per split', () {
      final splits = SplitCalculator.compute(
        _track([_line(count: 120, ele: (_) => 12.0)]),
      );

      expect(splits, isNotEmpty);
      for (final s in splits) {
        expect(s.elevationGainM, 0);
        expect(s.elevationDeltaM, 0);
      }
    });

    test('track without <ele> tags: zero gain and null elevation delta', () {
      final splits = SplitCalculator.compute(_track([_line(count: 120)]));

      expect(splits, isNotEmpty);
      for (final s in splits) {
        expect(s.elevationGainM, 0);
        expect(s.elevationDeltaM, isNull);
      }
    });

    test('GPS altitude jitter under 3 m is not counted as climbing', () {
      final splits = SplitCalculator.compute(
        _track([_line(count: 120, ele: (i) => 10.0 + (i.isEven ? 0.0 : 1.5))]),
      );

      expect(splits, isNotEmpty);
      for (final s in splits) {
        expect(s.elevationGainM, 0);
      }
    });

    test('a pause between segments adds no distance and no moving time', () {
      final seg1 = _line(count: 30);
      final seg2 = _line(
        count: 30,
        startLat: 10.5, // ~55 km away: must never be bridged
        t0: _t0.add(const Duration(hours: 1)),
      );

      final splits = SplitCalculator.compute(_track([seg1, seg2]));

      final fullSplits = splits.where((s) => !s.partial).toList();
      expect(fullSplits, hasLength(1));
      expect(fullSplits.single.duration, lessThan(const Duration(minutes: 7)));
      final total = splits.fold<double>(0, (sum, s) => sum + s.distanceM);
      expect(total, lessThan(1500));
    });

    test('LiveLapDetector reports nothing before the first boundary', () {
      final detector = LiveLapDetector();

      final events = detector.update(
        distanceM: 0,
        elapsed: Duration.zero,
      );

      expect(events, isEmpty);
      expect(detector.lapsCompleted, 0);
    });
  });

  group('TrackProfile with degraded tracks', () {
    test('empty and single-point tracks give an empty profile', () {
      expect(TrackProfile.build(const []).isEmpty, isTrue);
      expect(TrackProfile.build(_track([_line(count: 1)])).isEmpty, isTrue);
    });

    test('missing timestamps: no pace samples, no NaN', () {
      final profile = TrackProfile.build(
        _track([_line(count: 120, withTime: false)]),
      );

      expect(profile.isEmpty, isFalse);
      for (final s in profile.samples) {
        expect(s.paceSecPerKm, isNull);
        expect(s.distanceM.isNaN, isFalse);
      }
    });

    test('no <ele> tags: elevation samples are null, not 0', () {
      final profile = TrackProfile.build(_track([_line(count: 120)]));

      expect(profile.isEmpty, isFalse);
      for (final s in profile.samples) {
        expect(s.eleM, isNull);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 3. WeeklyStatsService
  // ---------------------------------------------------------------------------
  group('WeeklyStatsService edge cases', () {
    final now = DateTime(2026, 10, 23); // a Friday; its week starts 2026-10-19

    test('no notes: eight zeroed weeks, oldest first, current week last', () {
      final weeks = WeeklyStatsService.compute(now: now);

      expect(weeks, hasLength(8));
      expect(weeks.first.weekStart, DateTime(2026, 8, 31));
      expect(weeks.last.weekStart, DateTime(2026, 10, 19));
      for (final w in weeks) {
        expect(w.volumeKg, 0);
        expect(w.distanceKm, 0);
        expect(w.mobilityMinutes, 0);
        expect(w.workoutCount, 0);
        expect(w.activityCount, 0);
      }
    });

    test('weeks <= 0 returns an empty list', () {
      expect(WeeklyStatsService.compute(now: now, weeks: 0), isEmpty);
      expect(WeeklyStatsService.compute(now: now, weeks: -3), isEmpty);
    });

    test('weekStartOf maps a Sunday to the previous Monday', () {
      expect(WeeklyStatsService.weekStartOf(DateTime(2026, 10, 25, 23, 59)),
          DateTime(2026, 10, 19));
      expect(WeeklyStatsService.weekStartOf(DateTime(2026, 10, 26)),
          DateTime(2026, 10, 26));
    });

    test('empty vault on disk: loader yields no notes and zeroed weeks',
        () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);

      final stats = await VaultStatsLoader(h.vault).load();

      expect(stats.workouts, isEmpty);
      expect(stats.activities, isEmpty);
      expect(stats.records.isEmpty, isTrue);
      final weekly = stats.weekly(now: now);
      expect(weekly, hasLength(8));
      expect(
          weekly.every((w) => w.workoutCount + w.activityCount == 0), isTrue);
    });

    test('an unreadable note in the vault is skipped, not fatal', () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      await h.writeNote('Workouts', 'garbage.md', 'this is not a workout');

      final stats = await VaultStatsLoader(h.vault).load();

      expect(stats.workouts, isEmpty);
      expect(stats.activities, isEmpty);
    });

    test('workouts outside the 8-week range are ignored', () {
      final weeks = WeeklyStatsService.compute(
        now: now,
        workouts: [
          _workout(date: DateTime(2026, 6, 1), totalVolumeKg: 9999),
          _workout(date: DateTime(2026, 11, 30), totalVolumeKg: 8888),
        ],
      );

      expect(weeks.fold<double>(0, (s, w) => s + w.volumeKg), 0);
      expect(weeks.fold<int>(0, (s, w) => s + w.workoutCount), 0);
    });

    test('Sunday 23:59 belongs to the week; next Monday 00:00 does not', () {
      final weeks = WeeklyStatsService.compute(
        now: now,
        workouts: [
          _workout(date: DateTime(2026, 10, 25, 23, 59), totalVolumeKg: 100),
          _workout(date: DateTime(2026, 10, 26), totalVolumeKg: 500),
        ],
      );

      expect(weeks.last.workoutCount, 1);
      expect(weeks.last.volumeKg, 100);
    });

    test('zero-volume sessions count as workouts with 0 kg', () {
      final weeks = WeeklyStatsService.compute(
        now: now,
        workouts: [
          _workout(date: DateTime(2026, 10, 21), exercises: const [
            ExerciseEntry(name: 'Pull-ups', sets: [
              SetEntry(isBodyweight: true, extraWeightKg: 0, reps: 10),
            ]),
            ExerciseEntry(name: 'Plank', sets: [
              SetEntry(
                  isBodyweight: true, extraWeightKg: 0, durationSeconds: 60),
            ]),
          ]),
        ],
      );

      expect(weeks.last.workoutCount, 1);
      expect(weeks.last.volumeKg, 0);
    });

    test('activities without distance add 0 km and still count', () {
      final weeks = WeeklyStatsService.compute(
        now: now,
        activities: [
          _activity(date: DateTime(2026, 10, 20), distanceKm: null),
        ],
      );

      expect(weeks.last.activityCount, 1);
      expect(weeks.last.distanceKm, 0);
      expect(weeks.last.distanceKm.isNaN, isFalse);
    });

    test('mobility time comes from holds in mobility sessions', () {
      final weeks = WeeklyStatsService.compute(
        now: now,
        workouts: [
          _workout(
            split: 'Mobility Flow',
            date: DateTime(2026, 10, 22),
            exercises: const [
              ExerciseEntry(name: 'Pigeon', sets: [
                SetEntry(isBodyweight: true, durationSeconds: 60),
              ]),
              ExerciseEntry(name: 'Cat Cow', sets: [
                SetEntry(isBodyweight: true, durationSeconds: 30),
              ]),
            ],
          ),
        ],
      );

      expect(weeks.last.mobilityMinutes, closeTo(1.5, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. VaultStatsController
  // ---------------------------------------------------------------------------
  group('VaultStatsController listener notifications', () {
    late _Harness h;

    setUp(() async => h = await _Harness.create());
    tearDown(() => h.dispose());

    test('first load on an empty vault notifies and clears loading', () async {
      final c = h.makeController();
      expect(c.loading, isTrue);
      expect(c.stats, isNull);

      await _waitFor(c, () => !c.loading);

      expect(c.error, isNull);
      expect(c.stats, isNotNull);
      expect(c.stats!.workouts, isEmpty);
      expect(c.stats!.activities, isEmpty);
      expect(c.stats!.records.isEmpty, isTrue);
      expect(c.recordsByPath, isEmpty);
    });

    test('refresh() on an empty vault notifies listeners', () async {
      final c = h.makeController();
      await _waitFor(c, () => !c.loading);

      var notifications = 0;
      c.addListener(() => notifications++);
      await c.refresh();
      await _waitFor(c, () => notifications >= 1);

      expect(c.error, isNull);
      expect(c.stats!.workouts, isEmpty);
    });

    test('re-indexing a new workout notifies listeners with fresh stats',
        () async {
      final c = h.makeController();
      await _waitFor(c, () => !c.loading);
      var notifications = 0;
      c.addListener(() => notifications++);

      await h.writeNote('Workouts', _pushName, _pushNote);
      await h.reindexer.reindex();
      await _waitFor(c, () => c.stats?.workouts.length == 1);

      expect(notifications, greaterThanOrEqualTo(1));
      expect(c.error, isNull);
      expect(c.stats!.records[PrKind.bench1rm]?.value,
          closeTo(80 * (1 + 8 / 30), 1e-9));
    });

    test('recordsByPath maps a record to its vault-relative note path',
        () async {
      final c = h.makeController();
      await _waitFor(c, () => !c.loading);

      await h.writeNote('Workouts', _plankName, _plankNote);
      await h.reindexer.reindex();
      await _waitFor(c, () => c.recordsByPath.isNotEmpty);

      expect(c.recordsByPath['Workouts/$_plankName'], [PrKind.maxPlank]);
    });

    test('a burst of new notes settles on one consistent state', () async {
      final c = h.makeController();
      await _waitFor(c, () => !c.loading);

      await h.writeNote('Workouts', _pushName, _pushNote);
      await h.writeNote('Workouts', _plankName, _plankNote);
      await h.writeNote('Activities', _runName, _runNote);
      await h.reindexer.reindex();
      await _waitFor(
        c,
        () => c.stats?.workouts.length == 2 && c.stats?.activities.length == 1,
      );

      expect(c.stats!.records[PrKind.longestRun]?.value, 7.5);
      expect(c.stats!.records[PrKind.bench1rm], isNotNull);
      expect(c.stats!.records[PrKind.maxPlank], isNotNull);
    });

    test('deleting a note and re-indexing clears its records', () async {
      final c = h.makeController();
      await _waitFor(c, () => !c.loading);
      final file = await h.writeNote('Workouts', _plankName, _plankNote);
      await h.reindexer.reindex();
      await _waitFor(c, () => c.recordsByPath.isNotEmpty);

      await file.delete();
      await h.reindexer.reindex();
      await _waitFor(c, () => c.stats?.workouts.isEmpty ?? false);

      expect(c.recordsByPath, isEmpty);
      expect(c.stats!.records.isEmpty, isTrue);
    });

    test('Syncthing conflict copies are never counted', () async {
      final c = h.makeController();
      await _waitFor(c, () => !c.loading);

      await h.writeNote('Workouts', _pushName, _pushNote);
      await h.writeNote(
        'Workouts',
        '2026-10-22_1800_Push_Day_A.sync-conflict-20261023-101500-ABCD123.md',
        _pushNote,
      );
      await h.reindexer.reindex();
      await _waitFor(c, () => c.stats?.workouts.length == 1);
      // Let any trailing debounced reload land, then check it did not grow.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(c.stats!.workouts, hasLength(1));
    });

    test('a disposed controller stays silent when the vault re-indexes',
        () async {
      // Not created through makeController: disposed here, not in tearDown.
      final c = VaultStatsController(h.services);
      await _waitFor(c, () => !c.loading);
      var notifications = 0;
      c.addListener(() => notifications++);

      c.dispose();
      await h.writeNote('Workouts', _pushName, _pushNote);
      await h.reindexer.reindex();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(notifications, 0);
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

final DateTime _t0 = DateTime.utc(2026, 10, 22, 10);

// ---- model factories --------------------------------------------------------

WorkoutSession _workout({
  String split = 'Push Day A',
  DateTime? date,
  String timeStarted = '18:00',
  double? totalVolumeKg,
  List<ExerciseEntry> exercises = const [],
}) =>
    WorkoutSession(
      split: split,
      date: date ?? DateTime(2026, 10, 22),
      timeStarted: timeStarted,
      durationMin: 52,
      totalVolumeKg: totalVolumeKg,
      exercises: exercises,
    );

ActivitySession _activity({
  String category = 'run',
  DateTime? date,
  double? distanceKm,
  double durationMin = 25,
  int? durationSeconds,
  String? gpxFileName,
}) =>
    ActivitySession(
      category: category,
      date: date ?? DateTime(2026, 10, 22),
      timeStarted: '17:30',
      durationMin: durationSeconds != null ? durationSeconds / 60 : durationMin,
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      gpxFileName: gpxFileName,
    );

PrWorkoutSource _ws(WorkoutSession s, {String path = 'Workouts/w.md'}) =>
    PrWorkoutSource(path: path, session: s);

PrActivitySource _as(
  ActivitySession a, {
  String path = 'Activities/a.md',
  bool hasTrack = false,
  double? fastest5k,
}) =>
    PrActivitySource(
      path: path,
      session: a,
      hasTrack: hasTrack,
      trackFastest5kSeconds: fastest5k,
    );

// ---- GPX fixtures (built as XML and parsed, like real vault tracks) ---------

class _Pt {
  const _Pt(this.lat, this.lon, {this.ele, this.time});
  final double lat;
  final double lon;
  final double? ele;
  final DateTime? time;
}

/// A straight north-south line. 0.0002 degrees of latitude is ~22.24 m, and
/// each point is [stepSeconds] after the previous one (~360 s/km by default).
List<_Pt> _line({
  required int count,
  double startLat = 10.0,
  double dLat = 0.0002,
  double lon = 106.0,
  double? Function(int i)? ele,
  bool withTime = true,
  bool Function(int i)? dropTime,
  DateTime? t0,
  int stepSeconds = 8,
}) =>
    [
      for (var i = 0; i < count; i++)
        _Pt(
          startLat + i * dLat,
          lon,
          ele: ele?.call(i),
          time: (withTime && !(dropTime?.call(i) ?? false))
              ? (t0 ?? _t0).add(Duration(seconds: i * stepSeconds))
              : null,
        ),
    ];

String _gpxXml(List<List<_Pt>> segments) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="test" '
        'xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('<trk><name>t</name>');
  for (final seg in segments) {
    b.writeln('<trkseg>');
    for (final pt in seg) {
      b.write('<trkpt lat="${pt.lat}" lon="${pt.lon}">');
      if (pt.ele != null) b.write('<ele>${pt.ele}</ele>');
      if (pt.time != null) {
        b.write('<time>${pt.time!.toUtc().toIso8601String()}</time>');
      }
      b.writeln('</trkpt>');
    }
    b.writeln('</trkseg>');
  }
  b
    ..writeln('</trk>')
    ..writeln('</gpx>');
  return b.toString();
}

/// Round-trips through [GpxService.parse], so points with no `<time>` get the
/// parser's epoch fallback exactly as they would from a real file.
List<List<TrackPoint>> _track(List<List<_Pt>> segments) =>
    GpxService.parse(_gpxXml(segments)).segments;

// ---- vault notes -------------------------------------------------------------

const String _pushName = '2026-10-22_1800_Push_Day_A.md';
const String _pushNote = '''---
type: strength
split: "Push Day A"
date: 2026-10-22
time_started: "18:00"
duration_min: 52
tags:
  - fitness/gym
---

# Push Day Session

## Barbell Bench Press
- Set 1: 80kg x 8 reps | RPE 7.0 | Type: N
''';

const String _plankName = '2026-10-21_0700_Core.md';
const String _plankNote = '''---
type: strength
split: "Core"
date: 2026-10-21
time_started: "07:00"
duration_min: 20
total_volume_kg: 0
tags:
  - fitness/gym
---

# Core

## Plank
- Set 1: BW+0kg | Hold: 60s | Type: N
''';

const String _runName = '2026-10-22_1730_run.md';
const String _runNote = '''---
type: activity
category: run
date: 2026-10-22
time_started: "17:30"
duration_min: 45.2
distance_km: 7.5
elevation_gain_m: 85
avg_hr: 152
tags:
  - fitness/run
---

# 7.5km Run
''';

// ---- vault + controller harness ----------------------------------------------

class _Harness {
  _Harness._(this.root, this.vault, this.database, this.reindexer);

  final Directory root;
  final FilePersistenceService vault;
  final AppDatabase database;
  final VaultReindexerService reindexer;
  final List<VaultStatsController> _controllers = [];

  AppServices get services => AppServices(
        database: database,
        vault: vault,
        reindexer: reindexer,
      );

  static Future<_Harness> create() async {
    final root = await Directory.systemTemp.createTemp('obsidianfit_p6_');
    final vault = FilePersistenceService(Directory(p.join(root.path, 'vault')));
    await vault.ensureStructure();
    final database = AppDatabase(NativeDatabase.memory());
    final reindexer = VaultReindexerService(
      vault: vault,
      database: database,
      debounce: const Duration(milliseconds: 50),
    );
    return _Harness._(root, vault, database, reindexer);
  }

  /// A controller that this harness disposes first on teardown.
  VaultStatsController makeController() {
    final c = VaultStatsController(services);
    _controllers.add(c);
    return c;
  }

  Future<File> writeNote(String folder, String name, String content) async {
    final file = File(p.join(vault.vaultDir.path, folder, name));
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  Future<void> dispose() async {
    for (final c in _controllers) {
      c.dispose();
    }
    reindexer.dispose();
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

/// Completes once [condition] holds, checked now and after every notification
/// of [notifier]. Fails the test on timeout instead of hanging.
Future<void> _waitFor(
  ChangeNotifierLike notifier,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) {
  if (condition()) return Future<void>.value();
  final done = Completer<void>();
  void listener() {
    if (!done.isCompleted && condition()) done.complete();
  }

  notifier.addListener(listener);
  return done.future
      .timeout(timeout)
      .whenComplete(() => notifier.removeListener(listener));
}

/// The two Listenable methods [_waitFor] needs (a [VaultStatsController] fits).
typedef ChangeNotifierLike = VaultStatsController;
