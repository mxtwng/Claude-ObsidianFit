# Repository Map

Navigation aid for implementation work. Confirm behavior in source and tests before editing.

## Entry points

| User action | Entry point | Current route |
|---|---|---|
| Global Start | `lib/ui/common/start_session_sheet.dart` | Gym workout or GPS outdoor activity. Live non-GPS timer is planned, not present in the reviewed baseline. |
| Start gym workout | `lib/ui/workout/workout_session_page.dart` | `startWorkoutSession` prompts for a split and opens the live workout page. |
| Log a past session | `lib/ui/common/log_past_session_sheet.dart` | Past date -> retro gym logger or manual non-GPS activity logger; future dates are rejected. |
| Record GPS activity | `lib/ui/activity/activity_session_page.dart` | GPS, optional BLE HR, metrics/splits, optional GPX, activity note, re-index. |
| Log past non-GPS activity | `lib/ui/activity/manual_activity_page.dart` | Free-text category, typed duration and optional metrics/notes; no timer or GPX. |
| Calendar | `lib/ui/calendar/calendar_page.dart` | Calendar, day previews, plan text, start and past-session sheet. |
| History | `lib/ui/history/history_page.dart` | Indexed session list and previews. |
| Dashboard | `lib/ui/dashboard/dashboard_page.dart` | Weekly totals and PRs via the stats controller. |
| App shell | `lib/ui/shell/app_shell.dart` | Top-level navigation and shared Start entry point. |

## Domain models

| File | Responsibility |
|---|---|
| `lib/models/ActivitySession.dart` | Activity fields, optional GPX, duration seconds/minutes, UTC timestamps, metrics, unknown-frontmatter preservation. |
| `lib/models/WorkoutSession.dart` | Gym workout frontmatter and aggregate metadata. |
| `lib/models/ExerciseEntry.dart` | Exercise grouping, sets, exercise notes. |
| `lib/models/SetEntry.dart` | External/bodyweight load, reps or hold duration, RPE, plyometric values, legacy W/N/D/F type. |
| `lib/models/PlanProgram.dart` | Plan metadata, free-text weekly rotation, habit checklist, preserved extra content. |
| `lib/models/ModelUtils.dart` | Shared parsing/formatting and numeric/string helpers. |

## Persistence and services

| File | Responsibility |
|---|---|
| `lib/services/FilePersistenceService.dart` | Markdown parse/render and vault IO; filename collision handling, atomic writes, GPX path confinement, folder creation. |
| `lib/services/FrontMatterCodec.dart` | YAML frontmatter parse/encode. |
| `lib/services/app_database.dart` | Drift schema and queries for rebuildable read cache. |
| `lib/services/vault_reindexer_service.dart` | Scans Markdown folders, updates cache, watches changes, supports explicit re-index. |
| `lib/services/vault_stats_loader.dart` | Loads vault notes for derived stats/records. |
| `lib/services/weekly_stats.dart` | Weekly volume, distance, activity count, mobility calculations. |
| `lib/services/pr_service.dart` | Personal records and source attribution. |
| `lib/services/gpx_service.dart` | GPX parsing/rendering and track calculations. |
| `lib/services/location_ble_service.dart` | Location recording and BLE heart-rate integration. |
| `lib/services/track_math.dart`, `splits_service.dart`, `track_profile.dart` | Track geometry, splits, pace/elevation profile. |
| `lib/services/screen_awake.dart` | Screen wake-lock. |
| `lib/services/session_time.dart` | Start instant: UTC `start_time` wins; legacy falls back to local date/time. |
| `lib/services/splits_markdown.dart` | Adds split details to activity note body. |

UI gets services from `AppScope.of(context)` in `lib/ui/app_services.dart`. After a successful save, request re-index asynchronously; re-index failure must not undo a durable note.

## UI modules

- Workout: `workout_draft.dart` holds editable draft/live-vs-manual mode; `workout_session_page.dart` owns session flow/save/rest boundary; `exercise_card.dart` and `set_row.dart` edit entries; `rest_timer.dart` owns rest timing; `plate_math.dart` and `plate_calculator_sheet.dart` implement plate math/UI.
- Activity: `activity_session_page.dart` is GPS-specific; `manual_activity_page.dart` is typed-duration retro/manual logging; `map_view.dart`, `track_charts.dart`, and `splits_table.dart` show track analytics; `hr_sheet.dart` handles HR UI; `ghost_route_sheet.dart` selects saved routes.
- Shared UI: `prompt_dialog.dart` provides free-text/numeric prompts; `schedule.dart` resolves free-text weekly rotation; `session_entry.dart`, `session_entries_builder.dart`, `session_tile.dart`, and `session_preview_sheet.dart` assemble/display history entries.

## Schemas and compatibility

- `schemas/workout_schema.md` and `schemas/activity_schema.md` are baseline round-trip fixtures. Avoid casual edits; tests expect canonical render/parse behavior.
- `schemas/workout_schema.phase5.md` and `schemas/activity_schema.phase5.md` describe extended fields.
- `schemas/plan_schema.md` describes the current plan note shape.
- `schemas/config_schema.json` is an example config shape; do not assume each key is wired to runtime settings without tracing it.
- Unknown frontmatter survives through `extraFrontmatter`.
- Markdown/GPX are authoritative; Drift is a rebuildable index.

## Tests by concern

| Test file | Main coverage |
|---|---|
| `test/round_trip_test.dart` | Baseline schema parse/render round trips. |
| `test/phase5_round_trip_test.dart` | Phase 5 fixtures: timestamps, bodyweight, holds, plyometrics, manual activity fields. |
| `test/manual_activity_logging_test.dart` | Manual activity validation/building, UI save, no-GPX behavior. |
| `test/manual_workout_logging_test.dart` | Manual gym logging, input/corrections and save behavior. |
| `test/rest_timer_boundary_test.dart` | Manual/backdated set toggles do not start rest; live completion still does. |
| `test/zero_load_warning_test.dart` | Zero external load warning in live workouts. |
| `test/reindexer_test.dart` | Parsing and index refresh. |
| `test/file_persistence_track_path_test.dart` | GPX path confinement and filesystem safety. |
| `test/gpx_service_test.dart` | GPX parsing/rendering/track calculations. |
| `test/splits_markdown_test.dart`, `test/track_profile_test.dart` | Split notes and track profiles. |
| `test/weekly_stats_test.dart`, `test/phase6_edge_cases_test.dart` | Weekly totals, PRs, and edge cases. |
| `test/plate_math_test.dart` | Plate-loading calculations. |

## Local validation

```bash
flutter pub get
dart format <touched Dart files>
flutter test <focused test file>
flutter analyze
flutter test
```

Do not claim a command passed unless actually run. Widget tests with active periodic clocks should pump fixed frames; `pumpAndSettle()` may never settle while a timer is ticking.
