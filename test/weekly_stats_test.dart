import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/weekly_stats.dart';

/// Phase 6: weekly aggregates for the dashboard (lifted volume, distance and
/// mobility time per Monday-to-Sunday week).
///
/// "Now" is Friday 23 Oct 2026, so the current week is Mon 19 Oct to Sun 25
/// Oct and the previous ones start on 12 Oct, 5 Oct and 28 Sep.
void main() {
  final now = DateTime(2026, 10, 23);

  WorkoutSession workout(
    DateTime date, {
    double? volume,
    String split = 'Push Day A',
    String title = 'Push Day Session',
    List<String> tags = const ['fitness/gym', 'split/push'],
    List<ExerciseEntry> exercises = const [],
  }) {
    return WorkoutSession(
      split: split,
      title: title,
      date: date,
      timeStarted: '18:00',
      durationMin: 50,
      totalVolumeKg: volume,
      tags: tags,
      exercises: exercises,
    );
  }

  ActivitySession activity(
    DateTime date, {
    String category = 'run',
    double? km,
    double minutes = 30,
  }) {
    return ActivitySession(
      category: category,
      date: date,
      timeStarted: '07:00',
      durationMin: minutes,
      distanceKm: km,
    );
  }

  ExerciseEntry holds(String name, List<int> seconds) => ExerciseEntry(
        name: name,
        sets: [
          for (final s in seconds)
            SetEntry(isBodyweight: true, durationSeconds: s),
        ],
      );

  group('weekStartOf', () {
    test('every day of a week maps to its Monday', () {
      for (var day = 19; day <= 25; day++) {
        expect(
          WeeklyStatsService.weekStartOf(DateTime(2026, 10, day, 15, 30)),
          DateTime(2026, 10, 19),
          reason: '$day Oct',
        );
      }
    });

    test('the next Monday starts a new week', () {
      expect(
        WeeklyStatsService.weekStartOf(DateTime(2026, 10, 26)),
        DateTime(2026, 10, 26),
      );
    });

    test('the week can start in the previous month', () {
      // Sunday 1 Nov 2026 belongs to the week of Monday 26 Oct.
      expect(
        WeeklyStatsService.weekStartOf(DateTime(2026, 11, 1)),
        DateTime(2026, 10, 26),
      );
    });

    test('the time of day is dropped', () {
      final start =
          WeeklyStatsService.weekStartOf(DateTime(2026, 10, 21, 23, 59));
      expect(start.hour, 0);
      expect(start.minute, 0);
    });
  });

  group('workoutVolumeKg', () {
    final sets = [
      const SetEntry(weightKg: 40, reps: 10, type: SetType.warmup),
      const SetEntry(weightKg: 80, reps: 8),
      const SetEntry(weightKg: 80, reps: 8),
      const SetEntry(weightKg: 85, reps: 6, type: SetType.failure),
    ];

    test('uses the note\'s total_volume_kg when it has one', () {
      final w = workout(
        DateTime(2026, 10, 22),
        volume: 4850,
        exercises: [ExerciseEntry(name: 'Barbell Bench Press', sets: sets)],
      );
      expect(WeeklyStatsService.workoutVolumeKg(w), 4850);
    });

    test('otherwise sums the sets, warmups excluded', () {
      final w = workout(
        DateTime(2026, 10, 22),
        exercises: [ExerciseEntry(name: 'Barbell Bench Press', sets: sets)],
      );
      // 80x8 + 80x8 + 85x6 = 640 + 640 + 510
      expect(WeeklyStatsService.workoutVolumeKg(w), 1790);
    });

    test('a session with no sets has no volume', () {
      expect(
          WeeklyStatsService.workoutVolumeKg(workout(DateTime(2026, 10, 22))),
          0);
    });
  });

  group('mobilitySeconds', () {
    test('every hold counts in a session that is mobility work', () {
      final w = workout(
        DateTime(2026, 10, 20),
        split: 'Mobility Flow',
        title: 'Morning routine',
        tags: const ['fitness/mobility'],
        exercises: [
          holds('Hip opener', [30, 45]),
          holds('Plank', [60]),
        ],
      );
      expect(WeeklyStatsService.mobilitySeconds(w), 135);
    });

    test('the session tags alone can mark it as mobility work', () {
      final w = workout(
        DateTime(2026, 10, 20),
        split: 'Flow',
        title: 'Evening',
        tags: const ['fitness/yoga'],
        exercises: [
          holds('Warrior pose', [40, 40])
        ],
      );
      expect(WeeklyStatsService.mobilitySeconds(w), 80);
    });

    test('in a strength session only stretch-like exercises count', () {
      final w = workout(
        DateTime(2026, 10, 22),
        exercises: [
          holds('Hamstring Stretch', [60, 60]),
          holds('Plank', [90]),
          holds('Foam Rolling', [30]),
        ],
      );
      expect(WeeklyStatsService.mobilitySeconds(w), 150);
    });

    test('sets with reps instead of a hold add nothing', () {
      final w = workout(
        DateTime(2026, 10, 22),
        split: 'Mobility',
        exercises: const [
          ExerciseEntry(
            name: 'Cat-Cow',
            sets: [SetEntry(isBodyweight: true, reps: 10)],
          ),
        ],
      );
      expect(WeeklyStatsService.mobilitySeconds(w), 0);
    });

    test('a plain strength session has none', () {
      final w = workout(
        DateTime(2026, 10, 22),
        exercises: [
          holds('Plank', [60])
        ],
      );
      expect(WeeklyStatsService.mobilitySeconds(w), 0);
    });
  });

  group('compute', () {
    test('returns one entry per week, oldest first, ending this week', () {
      final result = WeeklyStatsService.compute(now: now, weeks: 4);
      expect(result.map((w) => w.weekStart), [
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 19),
      ]);
    });

    test('no sessions gives all-zero weeks', () {
      final result = WeeklyStatsService.compute(now: now, weeks: 3);
      expect(result, hasLength(3));
      for (final w in result) {
        expect(w.volumeKg, 0);
        expect(w.distanceKm, 0);
        expect(w.mobilityMinutes, 0);
        expect(w.workoutCount, 0);
        expect(w.activityCount, 0);
      }
    });

    test('zero or negative weeks gives an empty list', () {
      expect(WeeklyStatsService.compute(now: now, weeks: 0), isEmpty);
      expect(WeeklyStatsService.compute(now: now, weeks: -2), isEmpty);
    });

    test('sums every discipline into the right week', () {
      final workouts = [
        // This week (19-25 Oct).
        workout(DateTime(2026, 10, 19), volume: 1000),
        workout(DateTime(2026, 10, 22), volume: 2000),
        workout(
          DateTime(2026, 10, 20),
          split: 'Mobility',
          title: 'Hips',
          tags: const ['fitness/mobility'],
          exercises: [
            holds('Hip opener', [60, 60]),
          ],
        ),
        // Previous week (12-18 Oct).
        workout(DateTime(2026, 10, 13), volume: 500),
        // Older than the four weeks shown: ignored.
        workout(DateTime(2026, 9, 1), volume: 9999),
      ];
      final activities = [
        activity(DateTime(2026, 10, 20), km: 5.0),
        activity(DateTime(2026, 10, 21), category: 'ride', km: 20.5),
        // A yoga class has no distance; its duration is mobility time.
        activity(DateTime(2026, 10, 22), category: 'yoga', minutes: 30),
        activity(DateTime(2026, 10, 14), km: 10),
      ];

      final result = WeeklyStatsService.compute(
        workouts: workouts,
        activities: activities,
        now: now,
        weeks: 4,
      );
      expect(result, hasLength(4));

      final current = result[3];
      expect(current.volumeKg, 3000);
      expect(current.distanceKm, closeTo(25.5, 1e-9));
      // 120 s of holds + 30 min of yoga.
      expect(current.mobilityMinutes, closeTo(32, 1e-9));
      expect(current.workoutCount, 3);
      expect(current.activityCount, 3);

      final previous = result[2];
      expect(previous.volumeKg, 500);
      expect(previous.distanceKm, 10);
      expect(previous.mobilityMinutes, 0);
      expect(previous.workoutCount, 1);
      expect(previous.activityCount, 1);

      for (final w in result.take(2)) {
        expect(w.volumeKg, 0);
        expect(w.distanceKm, 0);
        expect(w.workoutCount, 0);
        expect(w.activityCount, 0);
      }
    });

    test('a week runs Monday to Sunday', () {
      final result = WeeklyStatsService.compute(
        workouts: [
          workout(DateTime(2026, 10, 18), volume: 100), // Sun, last week
          workout(DateTime(2026, 10, 19), volume: 200), // Mon, this week
          workout(DateTime(2026, 10, 25), volume: 400), // Sun, this week
          workout(DateTime(2026, 10, 26), volume: 800), // Mon, next week
        ],
        now: now,
        weeks: 2,
      );
      expect(result[0].volumeKg, 100);
      expect(result[1].volumeKg, 600);
      expect(result[1].workoutCount, 2);
    });

    test('a ride or run is not mobility time, a stretch class is', () {
      final result = WeeklyStatsService.compute(
        activities: [
          activity(DateTime(2026, 10, 20), category: 'run', minutes: 40),
          activity(DateTime(2026, 10, 21), category: 'stretching', minutes: 15),
          activity(DateTime(2026, 10, 22), category: 'mobility', minutes: 10),
        ],
        now: now,
        weeks: 1,
      );
      expect(result.single.mobilityMinutes, closeTo(25, 1e-9));
      expect(result.single.activityCount, 3);
    });

    test('an activity without a distance adds zero kilometres', () {
      final result = WeeklyStatsService.compute(
        activities: [
          activity(DateTime(2026, 10, 20), km: null),
          activity(DateTime(2026, 10, 21), km: 3.5),
        ],
        now: now,
        weeks: 1,
      );
      expect(result.single.distanceKm, 3.5);
      expect(result.single.activityCount, 2);
    });

    test('a manual activity uses its duration in seconds for mobility', () {
      final a = ActivitySession(
        category: 'yoga',
        date: DateTime(2026, 10, 21),
        timeStarted: '06:00',
        durationMin: 0, // derived field, ignored when seconds are given
        durationSeconds: 2700,
      );
      final result = WeeklyStatsService.compute(
        activities: [a],
        now: now,
        weeks: 1,
      );
      expect(result.single.mobilityMinutes, closeTo(45, 1e-9));
    });
  });
}
