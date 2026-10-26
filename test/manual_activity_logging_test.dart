// Manual activity logging for activities with no distance or elevation
// (Taekwondo, boxing, yoga, stretching, a simple walk), while a run or ride
// with distance keeps its behavior.
//
// Pure rules (`validateManualActivity`, `buildManualActivity`) are plain-Dart
// tests. The logger screen is driven with a vault that records saves instead
// of writing files (real file IO cannot complete under the widget tester's
// fake clock). Parsing and re-indexing use a real temp vault in plain tests,
// as `reindexer_test.dart` does.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/models/Models.dart';
import 'package:obsidian_fit/services/FilePersistenceService.dart';
import 'package:obsidian_fit/services/FrontMatterCodec.dart';
import 'package:obsidian_fit/services/app_database.dart';
import 'package:obsidian_fit/services/vault_reindexer_service.dart';
import 'package:obsidian_fit/services/weekly_stats.dart';
import 'package:obsidian_fit/ui/activity/manual_activity_page.dart';
import 'package:obsidian_fit/ui/app_services.dart';
import 'package:obsidian_fit/ui/common/log_past_session_sheet.dart';
import 'package:obsidian_fit/ui/common/session_entry.dart';

const String _distanceError = 'Enter a distance above 0 km, or leave it empty';
const String _elevationError =
    'Enter the elevation gain in metres (0 or more), or leave it empty';
const String _durationError = 'Enter a duration of at least 1 second';
const String _rpeError = 'RPE must be between 1 and 10';

/// Keys that must only appear when the user entered the value.
const List<String> _optionalKeys = [
  'distance_km',
  'elevation_gain_m',
  'rpe',
  'avg_pace_min_km',
  'avg_hr',
];

final DateTime _start = DateTime(2026, 10, 24, 18, 0);
final DateTime _now = DateTime(2026, 10, 24, 20, 5, 12);

/// A Taekwondo entry with only a duration entered.
ActivitySession _taekwondo({String notes = ''}) => buildManualActivity(
      category: 'taekwondo',
      label: 'Taekwondo',
      start: _start,
      now: _now,
      durationSeconds: 4500,
      notes: notes,
    );

Map<String, Object?> _frontmatter(String md) =>
    FrontMatterCodec.parse(md).frontmatter;

/// A vault that records saved activities instead of touching the disk.
class _RecordingVault extends FilePersistenceService {
  _RecordingVault(super.vaultDir);

  final List<ActivitySession> saved = [];

  @override
  Future<File> saveActivity(ActivitySession a, {String? relativePath}) async {
    saved.add(a);
    return File('${vaultDir.path}/Activities/recorded.md');
  }
}

/// Counts re-index requests without scanning anything.
class _CountingReindexer extends VaultReindexerService {
  _CountingReindexer({required super.vault, required super.database});

  int calls = 0;

  @override
  Future<ReindexReport> reindex() async {
    calls++;
    return const ReindexReport();
  }
}

/// Opens the manual logger for [category] the way a caller does and reports
/// what the route returns (true = saved).
class _LoggerLauncher extends StatelessWidget {
  const _LoggerLauncher({required this.category, required this.onResult});

  final String category;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => ManualActivityPage(
                  category: category,
                  initialStart: DateTime(2026, 10, 18, 18, 30),
                ),
              ),
            );
            onResult(saved);
          },
          child: const Text('Open logger'),
        ),
      ),
    );
  }
}

/// Opens the "+ Log Past Session" chooser for a past day.
class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () =>
              showLogPastSessionSheet(context, day: DateTime(2026, 10, 18)),
          child: const Text('Open sheet'),
        ),
      ),
    );
  }
}

void main() {
  group('validateManualActivity', () {
    ManualActivityErrors check({
      String distance = '',
      int seconds = 1800,
      String elevation = '',
      String hr = '',
      double? rpe,
    }) =>
        validateManualActivity(
          distanceText: distance,
          durationSeconds: seconds,
          elevationText: elevation,
          avgHrText: hr,
          rpe: rpe,
        );

    test('only a duration is required: everything else may be blank', () {
      expect(check().isValid, isTrue);
      // Whitespace counts as blank.
      expect(check(distance: '  ', elevation: ' ', hr: ' ').isValid, isTrue);
    });

    test('duration must be at least 1 second', () {
      expect(check(seconds: 0).duration, _durationError);
      expect(check(seconds: -5).duration, _durationError);
      expect(check(seconds: 1).duration, isNull);
      expect(check(seconds: 0).isValid, isFalse);
    });

    test('a supplied distance must be above 0 km', () {
      for (final bad in ['0', '0.0', '-1', 'abc', 'NaN', 'Infinity']) {
        expect(check(distance: bad).distance, _distanceError, reason: bad);
      }
      for (final good in ['0.01', '7.5', '7,5', ' 10 ']) {
        expect(check(distance: good).distance, isNull, reason: good);
      }
    });

    test('a supplied elevation must be 0 m or more', () {
      for (final bad in ['-1', '-0.5', 'abc', 'NaN']) {
        expect(check(elevation: bad).elevation, _elevationError, reason: bad);
      }
      for (final good in ['0', '85', '12.5', '12,5']) {
        expect(check(elevation: good).elevation, isNull, reason: good);
      }
    });

    test('a supplied RPE must be within 1-10, halves allowed', () {
      for (final bad in [0.0, 0.5, 10.5, 11.0, -1.0]) {
        expect(check(rpe: bad).rpe, _rpeError, reason: '$bad');
      }
      for (final good in [1.0, 5.5, 7.5, 10.0]) {
        expect(check(rpe: good).rpe, isNull, reason: '$good');
      }
      expect(check(rpe: null).rpe, isNull);
    });

    test('a supplied heart rate must be 1-300 (existing rule)', () {
      for (final bad in ['0', '301', 'abc', '-5']) {
        expect(check(hr: bad).avgHr, isNotNull, reason: bad);
      }
      expect(check(hr: '152').avgHr, isNull);
    });

    test('each problem is reported on its own field', () {
      final e = check(
        distance: '0',
        seconds: 0,
        elevation: '-3',
        hr: '999',
        rpe: 12,
      );
      expect(e.distance, _distanceError);
      expect(e.duration, _durationError);
      expect(e.elevation, _elevationError);
      expect(e.avgHr, isNotNull);
      expect(e.rpe, _rpeError);
      expect(e.isValid, isFalse);
    });
  });

  group('buildManualActivity: a session with no distance', () {
    test('uses the category as the title, not "0.0 km ..."', () {
      final a = _taekwondo();
      expect(a.title, 'Taekwondo');
      expect(a.title, isNot(contains('km')));
      expect(a.category, 'taekwondo');
      expect(a.tags, ['fitness/taekwondo']);
    });

    test('keeps blank distance, elevation, RPE, heart rate and pace null', () {
      final a = _taekwondo();
      expect(a.distanceKm, isNull);
      expect(a.elevationGainM, isNull);
      expect(a.rpe, isNull);
      expect(a.avgHr, isNull);
      expect(a.avgPaceMinKm, isNull);
      expect(a.computedPaceMinKm, isNull);
    });

    test('still records the required duration and timestamps', () {
      final a = _taekwondo();
      expect(a.durationSeconds, 4500);
      expect(a.durationMin, 75);
      expect(a.date, DateTime(2026, 10, 24));
      expect(a.timeStarted, '18:00');
      expect(a.startTime, _start.toUtc());
      expect(a.dateLogged, _now.toUtc());
      expect(a.gpxFileName, isNull);
    });

    test('the saved note has no fabricated optional keys', () {
      final md = FilePersistenceService.renderActivity(_taekwondo());
      final fm = _frontmatter(md);
      for (final key in _optionalKeys) {
        expect(fm.containsKey(key), isFalse, reason: key);
        expect(md, isNot(contains('$key:')), reason: key);
      }
      expect(md, isNot(contains('gpx_file')));
      expect(fm['type'], 'activity');
      expect(fm['category'], 'taekwondo');
      expect(fm['duration_seconds'], 4500);
      expect(md, contains('# Taekwondo\n'));
    });

    test('notes become bullets', () {
      final a = _taekwondo(notes: 'Sparring and forms.\n- Kicks\n\n');
      expect(a.bodyText, '- Sparring and forms.\n- Kicks');
    });

    test('an entered elevation of 0 is kept, a blank one is not', () {
      final entered = buildManualActivity(
        category: 'hike',
        label: 'Hike',
        start: _start,
        now: _now,
        durationSeconds: 3600,
        elevationText: '0',
      );
      expect(entered.elevationGainM, 0);
      expect(
        FilePersistenceService.renderActivity(entered),
        contains('elevation_gain_m: 0\n'),
      );
      expect(_taekwondo().elevationGainM, isNull);
    });

    test('RPE and heart rate are written only when entered', () {
      final a = buildManualActivity(
        category: 'boxing',
        label: 'Boxing',
        start: _start,
        now: _now,
        durationSeconds: 3000,
        avgHrText: '140',
        rpe: 7.5,
      );
      final md = FilePersistenceService.renderActivity(a);
      expect(md, contains('avg_hr: 140\n'));
      expect(md, contains('rpe: 7.5\n'));
      expect(md, isNot(contains('distance_km')));
      expect(md, isNot(contains('avg_pace_min_km')));
      expect(a.title, 'Boxing');
    });
  });

  group('buildManualActivity: a distance entry keeps its behavior', () {
    ActivitySession run({
      String distance = '7.5',
      int seconds = 2712,
    }) =>
        buildManualActivity(
          category: 'run',
          label: 'Run',
          start: _start,
          now: _now,
          durationSeconds: seconds,
          distanceText: distance,
          elevationText: '85',
          avgHrText: '152',
          rpe: 7,
        );

    test('title is "<km> km <Label>" with one decimal', () {
      expect(run().title, '7.5 km Run');
      // The distance is stored to 2 decimals; the title shows 1.
      final precise = run(distance: '7.456');
      expect(precise.distanceKm, 7.46);
      expect(precise.title, '7.5 km Run');
      expect(run(distance: '7,5').distanceKm, 7.5);
    });

    test('pace is derived from distance and duration', () {
      final a = run();
      expect(a.avgPaceMinKm, '6:02');
      expect(a.durationMin, 45.2);
      expect(a.durationSeconds, 2712);
    });

    test('writes every entered field', () {
      final md = FilePersistenceService.renderActivity(run());
      expect(md, contains('distance_km: 7.5\n'));
      expect(md, contains('elevation_gain_m: 85\n'));
      expect(md, contains('avg_hr: 152\n'));
      expect(md, contains('rpe: 7\n'));
      expect(md, contains('avg_pace_min_km: "6:02"\n'));
      expect(md, contains('duration_seconds: 2712\n'));
      expect(md, contains('# 7.5 km Run\n'));
    });

    test('a walk with a distance but no elevation or RPE omits those two', () {
      final a = buildManualActivity(
        category: 'walking',
        label: 'Walking',
        start: _start,
        now: _now,
        durationSeconds: 1800,
        distanceText: '3',
      );
      expect(a.title, '3.0 km Walking');
      expect(a.avgPaceMinKm, '10:00');
      final fm = _frontmatter(FilePersistenceService.renderActivity(a));
      expect(fm['distance_km'], 3);
      expect(fm.containsKey('elevation_gain_m'), isFalse);
      expect(fm.containsKey('rpe'), isFalse);
    });
  });

  group('suggestions', () {
    test('cover non-distance activities and keep the old ones', () {
      expect(
        manualCategorySuggestions,
        containsAll([
          'Taekwondo',
          'Boxing',
          'Yoga',
          'Stretching',
          'Walking',
          'Run',
          'Ride',
        ]),
      );
    });
  });

  group('manual activity note: parse, re-index, summaries', () {
    late Directory tmp;
    late FilePersistenceService vault;
    late AppDatabase db;
    late VaultReindexerService reindexer;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('obsidianfit_manual_');
      vault = FilePersistenceService(tmp);
      await vault.ensureStructure();
      db = AppDatabase(NativeDatabase.memory());
      reindexer = VaultReindexerService(vault: vault, database: db);
    });

    tearDown(() async {
      reindexer.dispose();
      await db.close();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('parses with every optional metric null and round-trips', () {
      final md = FilePersistenceService.renderActivity(
        _taekwondo(notes: 'Sparring and forms.'),
      );
      final a = FilePersistenceService.parseActivity(md);
      expect(a.category, 'taekwondo');
      expect(a.title, 'Taekwondo');
      expect(a.durationSeconds, 4500);
      expect(a.durationMin, 75);
      expect(a.distanceKm, isNull);
      expect(a.elevationGainM, isNull);
      expect(a.rpe, isNull);
      expect(a.avgHr, isNull);
      expect(a.avgPaceMinKm, isNull);
      expect(a.computedPaceMinKm, isNull);
      expect(a.gpxFileName, isNull);
      expect(a.bodyText, '- Sparring and forms.');
      expect(a.extraFrontmatter, isEmpty);
      expect(FilePersistenceService.parseAny(md), isA<ActivitySession>());
      // Byte-stable: re-rendering adds no keys.
      expect(FilePersistenceService.renderActivity(a), md);
    });

    test('is indexed with null metrics and a duration-only summary', () async {
      await vault.saveActivity(_taekwondo());
      final report = await reindexer.reindex();
      expect(report.errors, isEmpty);
      expect(report.upserted, 1);

      final rows = await db.select(db.activitiesIndex).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.category, 'taekwondo');
      expect(row.distanceKm, isNull);
      expect(row.elevationGainM, isNull);
      expect(row.rpe, isNull);
      expect(row.avgHr, isNull);
      expect(row.gpxFileName, isNull);
      expect(row.durationSeconds, 4500);
      expect(row.durationMin, 75);
      expect(row.filePath, startsWith('Activities/'));
      expect(row.filePath, contains('taekwondo'));

      final entry = SessionEntry.fromActivity(row);
      expect(entry.kind, SessionKind.activity);
      expect(entry.title, 'Taekwondo');
      // Duration only: no "0.00 km".
      expect(entry.summary, '75 min');
    });

    test('a run still shows distance and duration in its summary', () async {
      await vault.saveActivity(
        buildManualActivity(
          category: 'run',
          label: 'Run',
          start: _start,
          now: _now,
          durationSeconds: 2712,
          distanceText: '7.5',
        ),
      );
      await reindexer.reindex();
      final row = (await db.select(db.activitiesIndex).get()).single;
      expect(row.distanceKm, 7.5);
      expect(SessionEntry.fromActivity(row).summary, '7.50 km · 45 min');
    });

    test('weekly stats count distance-less activities, with 0 km', () async {
      final taekwondo = _taekwondo(); // Sat 24 Oct, 75 min
      final walk = buildManualActivity(
        category: 'walking',
        label: 'Walking',
        start: DateTime(2026, 10, 23, 7, 0),
        now: _now,
        durationSeconds: 1800,
      );
      final stretching = buildManualActivity(
        category: 'stretching',
        label: 'Stretching',
        start: DateTime(2026, 10, 22, 21, 0),
        now: _now,
        durationSeconds: 900,
      );
      final run = buildManualActivity(
        category: 'run',
        label: 'Run',
        start: DateTime(2026, 10, 21, 6, 0),
        now: _now,
        durationSeconds: 1800,
        distanceText: '5',
      );
      // Go through the files, as the dashboard does.
      final parsed = [
        for (final a in [taekwondo, walk, stretching, run])
          FilePersistenceService.parseActivity(
            FilePersistenceService.renderActivity(a),
          ),
      ];

      // Sunday 25 Oct: the week of Mon 19 Oct holds all four.
      final result = WeeklyStatsService.compute(
        activities: parsed,
        now: DateTime(2026, 10, 25),
        weeks: 2,
      );
      final week = result.last;
      expect(week.weekStart, DateTime(2026, 10, 19));
      expect(week.activityCount, 4);
      // Only the run has a distance; the others add nothing, not NaN.
      expect(week.distanceKm, closeTo(5, 1e-9));
      // Stretching counts as mobility time; Taekwondo and walking do not.
      expect(week.mobilityMinutes, closeTo(15, 1e-9));
      expect(result.first.activityCount, 0);
    });
  });

  group('manual logger screen', () {
    late _RecordingVault vault;
    late AppDatabase db;
    late _CountingReindexer reindexer;
    bool? result;

    setUp(() {
      result = null;
      // Never touched: _RecordingVault does no IO, and the counting
      // reindexer scans nothing.
      vault = _RecordingVault(Directory('unused-vault'));
      db = AppDatabase(NativeDatabase.memory());
      reindexer = _CountingReindexer(vault: vault, database: db);
    });

    tearDown(() async {
      reindexer.dispose();
      await db.close();
    });

    Future<void> pumpFrames(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> openLogger(
      WidgetTester tester, {
      String category = 'Taekwondo',
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        AppScope(
          services: AppServices(
            database: db,
            vault: vault,
            reindexer: reindexer,
          ),
          child: MaterialApp(
            home: _LoggerLauncher(
              category: category,
              onResult: (saved) => result = saved,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open logger'));
      await pumpFrames(tester);
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    Future<void> type(WidgetTester tester, String label, String text) async {
      final f = field(label);
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
      await tester.pump();
    }

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.text('Save Session');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await pumpFrames(tester);
    }

    /// Lets the route finish popping and the snackbar run out.
    Future<void> pumpUntilClosed(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('copy no longer implies an outdoor run or ride',
        (tester) async {
      await openLogger(tester);
      expect(find.text('Log Taekwondo'), findsOneWidget);
      expect(find.text('Without GPS'), findsOneWidget);
      expect(find.text('Distance (km, optional)'), findsOneWidget);
      expect(find.text('Elevation gain (m, optional)'), findsOneWidget);
      expect(find.text('Session RPE (optional)'), findsOneWidget);
      // Elevation is not pre-filled with an implied 0.
      expect(
        tester
            .widget<TextField>(field('Elevation gain (m, optional)'))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets(
        'saves a Taekwondo session with only a duration, once, '
        'and writes no distance, elevation, RPE or pace', (tester) async {
      await openLogger(tester);
      await type(tester, 'min', '75');
      expect(find.textContaining('Average pace'), findsNothing);

      await tapSave(tester);
      await pumpUntilClosed(tester);

      expect(result, isTrue);
      expect(find.byType(ManualActivityPage), findsNothing);
      expect(reindexer.calls, 1);
      expect(vault.saved, hasLength(1));

      final a = vault.saved.single;
      expect(a.title, 'Taekwondo');
      expect(a.category, 'taekwondo');
      expect(a.durationSeconds, 4500);
      expect(a.distanceKm, isNull);
      expect(a.elevationGainM, isNull);
      expect(a.rpe, isNull);
      expect(a.avgPaceMinKm, isNull);

      final md = FilePersistenceService.renderActivity(a);
      for (final key in _optionalKeys) {
        expect(md, isNot(contains('$key:')), reason: key);
      }
    });

    testWidgets('a distance entry keeps its title, pace and elevation',
        (tester) async {
      await openLogger(tester, category: 'Run');
      await type(tester, 'Distance (km, optional)', '7.5');
      await type(tester, 'min', '45');
      expect(find.textContaining('6:00 /km'), findsOneWidget);
      await type(tester, 'Elevation gain (m, optional)', '85');

      await tapSave(tester);
      await pumpUntilClosed(tester);

      expect(vault.saved, hasLength(1));
      final a = vault.saved.single;
      expect(a.title, '7.5 km Run');
      expect(a.distanceKm, 7.5);
      expect(a.avgPaceMinKm, '6:00');
      expect(a.elevationGainM, 85);
      // RPE is optional now: left alone, it is not written.
      expect(a.rpe, isNull);
      expect(
        FilePersistenceService.renderActivity(a),
        isNot(contains('rpe:')),
      );
    });

    testWidgets('invalid distance and elevation block saving with messages',
        (tester) async {
      await openLogger(tester);
      await type(tester, 'min', '30');
      await type(tester, 'Distance (km, optional)', '0');
      await type(tester, 'Elevation gain (m, optional)', '-5');

      await tapSave(tester);

      expect(find.text(_distanceError), findsOneWidget);
      expect(find.text(_elevationError), findsOneWidget);
      expect(find.byType(ManualActivityPage), findsOneWidget);
      expect(vault.saved, isEmpty);
      expect(reindexer.calls, 0);

      // Clearing both fields makes the entry valid again.
      await type(tester, 'Distance (km, optional)', '');
      await type(tester, 'Elevation gain (m, optional)', '');
      await tapSave(tester);
      await pumpUntilClosed(tester);
      expect(vault.saved, hasLength(1));
      expect(vault.saved.single.distanceKm, isNull);
      expect(vault.saved.single.elevationGainM, isNull);
    });

    testWidgets('a missing duration still blocks saving', (tester) async {
      await openLogger(tester);

      await tapSave(tester);

      expect(find.text(_durationError), findsOneWidget);
      expect(find.byType(ManualActivityPage), findsOneWidget);
      expect(vault.saved, isEmpty);
    });

    testWidgets('an RPE can be set and cleared back to not entered',
        (tester) async {
      await openLogger(tester);
      await type(tester, 'min', '40');
      expect(find.text('Clear'), findsNothing);

      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.tap(slider);
      await tester.pump();
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(find.text('Clear'), findsNothing);

      await tapSave(tester);
      await pumpUntilClosed(tester);
      expect(vault.saved, hasLength(1));
      expect(vault.saved.single.rpe, isNull);
    });

    testWidgets('a set RPE is saved', (tester) async {
      await openLogger(tester);
      await type(tester, 'min', '40');
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.tap(slider);
      await tester.pump();

      await tapSave(tester);
      await pumpUntilClosed(tester);

      expect(vault.saved, hasLength(1));
      final rpe = vault.saved.single.rpe;
      expect(rpe, isNotNull);
      expect(rpe! >= 1 && rpe <= 10, isTrue);
    });
  });

  group('"+ Log Past Session" chooser', () {
    testWidgets('no longer calls every non-gym activity outdoor',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _SheetLauncher()));
      await tester.tap(find.text('Open sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Gym workout'), findsOneWidget);
      expect(find.text('Other activity'), findsOneWidget);
      expect(find.text('Outdoor activity'), findsNothing);
      expect(find.textContaining('martial arts'), findsOneWidget);
    });
  });
}
