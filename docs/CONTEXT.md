# ObsidianFit Repository Context

_Last reviewed: 2026-10-26. This is an engineering checkpoint, not a substitute for source inspection._

## Repository checkpoint
- Repository: https://github.com/mxtwng/Claude-ObsidianFit
- Reviewed baseline: `main` at `2f4d6fd76544adece0afd1eb4effa52ba6887991` — merge commit for PR #4, Refresh repository context and Claude implementation guidance.
- The repository-context refresh has been merged into `main`; its source branch was deleted. This checkpoint is being refreshed on `docs/audit-followups-and-current-state`.
- Current baseline supports gym logging, GPS-recorded outdoor activities, and manual/non-GPS activity logging.
- A live elapsed timer for non-GPS activities is the next agreed feature; it is not present in the current start chooser.
- The private full product masterplan is intentionally not duplicated in this repository.

## Product direction
V2 is a refinement of workflows and domain semantics, not a claim that the current UI is final.
- Activity-first, not gym-only: strength, calisthenics, running, walking, cycling, hiking, martial arts, yoga, stretching/mobility, recreation, and custom categories.
- Plans guide a day; they must not overwrite what actually happened. Simple activities should not require reusable workout templates.
- Planning, live tracking, and manual logging of completed sessions are distinct.
- Markdown/GPX are user-owned durable records; SQLite is a rebuildable cache.

## Architecture and main flows
See `docs/REPO_MAP.md` for module and test navigation, and `docs/AUDIT_FOLLOWUPS.md` for audit findings, failsafe tasks, and Android/Linux validation.

1. UI gets services from `AppScope` / `AppServices`.
2. `FilePersistenceService` parses/renders models and writes Markdown/GPX.
3. `VaultReindexerService` scans `Workouts/`, `Activities/`, and `Plans/`, updating Drift.
4. Calendar/history query the index; richer stats and PRs parse vault notes through `VaultStatsLoader`.
5. The index can be rebuilt from the vault. Never treat SQLite as the only copy of a session.

Vault folders: `Workouts/`, `Activities/`, `Tracks/`, `Plans/`. Android prefers `/storage/emulated/0/Documents/ObsidianFit` when all-files access is available, then an external app directory, then app documents. Other platforms use the application documents directory.

## Current entry points
- `lib/ui/common/start_session_sheet.dart`: global Start chooser currently offers Gym workout and Outdoor activity only.
- `lib/ui/common/log_past_session_sheet.dart`: past-date chooser; gym goes to the retro workout logger and other activity goes to manual non-GPS logging. Future dates are rejected.
- `lib/ui/activity/manual_activity_page.dart`: typed duration and optional metrics/notes; no live timer or GPX.
- `lib/ui/activity/activity_session_page.dart`: GPS-specific live recorder with location/track lifecycle, optional BLE HR, metrics/splits, optional GPX, note save, and re-index.
- `lib/ui/workout/workout_session_page.dart` + `workout_draft.dart`: live and retro/manual gym logging. Historical/manual set changes must not start the live rest timer.
- `lib/ui/common/schedule.dart`: reads free-text weekly rotation entries. Current calendar start treats a scheduled label as a suggested gym split; generalized activity scheduling is a product goal, not a shipped claim.
- `lib/ui/app_services.dart`: shared service bundle.

## Data and time semantics
- `ActivitySession` supports `durationSeconds` (canonical whole seconds for manual entries), `durationMin` (compatibility/index field), UTC `startTime` and `dateLogged`, optional metrics/GPX, and unknown-frontmatter preservation.
- `WorkoutSession` supports start/date-logged timestamps and exercise entries. `SetEntry` supports external or bodyweight-plus-added load, reps or hold duration, RPE, plyometric values, and legacy W/N/D/F markers.
- `PlanProgram` stores plan metadata, free-text weekly rotation, habit checklist, and preserved extra content.
- `start_time` and `date_logged` are UTC instants. Live GPS/gym sessions currently write both from session start. Retro/manual entries use the historical start and actual save time.
- Manual activities write canonical `duration_seconds` plus derived `duration_min` rounded to one decimal. GPS/legacy activity notes may only have `duration_min`.
- Blank optional fields mean unknown/not entered. An explicit elevation gain of zero is meaningful.
- No GPX is valid for non-GPS activities; there must be no track file or route map.

## Recent implementation checkpoint
The baseline includes flexible manual non-GPS activity logging for categories such as Run, Ride, Walking, Hike, Taekwondo, Boxing, Yoga, and Stretching. Duration is required; distance, elevation, average HR, RPE, and notes are optional; pace is derived only when distance is supplied.

The manual/live rest-timer boundary is covered by `test/rest_timer_boundary_test.dart`: historical/manual set toggles must not start rest, while live set completion still does.

### Validation provenance
Owner-reported local validation after the manual activity logging change: `flutter analyze` reported no issues and `flutter test` passed all 382 tests. This GitHub documentation session did not run those commands. Do not describe them as freshly verified; there is no claim of complete real-device validation or automated CI coverage.

## Next agreed task: live timed activity without GPS
Add a third global Start choice, separate from the existing flows:
- Gym workout: existing set/rep logger and live-only rest behavior.
- Outdoor activity: existing GPS recorder.
- Timed activity: free-text category prompt, then a lightweight elapsed timer for TKD, boxing, yoga, stretching, walking, or another user-defined activity.

Expected behavior:
- Capture start time automatically; display elapsed active time.
- Pause/resume excludes paused intervals.
- Compute elapsed duration from timestamps plus accumulated paused time, never from timer tick count; ticks only refresh the UI.
- Finish saves exactly one `ActivitySession` through the existing vault route, with exact `durationSeconds`, compatible `durationMin`, start/date metadata, `fitness/<category>` tag, and no GPX.
- Discard saves nothing.
- No GPS permission, GPX, sets/reps, or rest timer.
- Manual/past activity logging remains a typed-duration flow.
- Request re-indexing after a successful save; re-index failure must not undo the note.
- Do not change the model/schema unless inspection proves a real gap.

## Open gaps; do not silently decide
- The grey `1` in a workout set row is the set number. Its color/type styling is intentional; do not change it without a new, specific design request.
- Do not turn legacy W/N/D/F markers into a universal set taxonomy.
- Generalized activity planning/scheduling needs its own audit/design; the current weekly rotation is mostly free text.
- Current user testing targets are Android and Linux only. GPS/background service, BLE, permissions, notifications, and wake-lock behavior require Android device verification; Linux should receive normal desktop build/run and regression checks. iOS testing is explicitly deferred for later.
- Static audit follow-ups are tracked in `docs/AUDIT_FOLLOWUPS.md`; they are tasks to validate/fix, not claims that defects have been reproduced.
