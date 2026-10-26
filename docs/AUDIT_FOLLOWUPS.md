# Repository audit follow-ups

_Last reviewed: 2026-10-26 against `main` commit `7dba1371a9a44f69a1f5368af8a4b5adc80f8bac`._

This is an actionable handoff, not a claim that every item has been implemented or reproduced. Current user validation targets are **Android and Linux**. iOS is explicitly deferred.

## Closed during this documentation refresh

- [x] Update `docs/CONTEXT.md` after PR #5 was merged; remove branch-specific checkpoint wording.
- [x] Correct `ActivitySession.startTime` documentation: live GPS sessions already write it.
- [x] Correct the platform guide: Syncthing conflict copies are filtered by `FilePersistenceService.listMarkdownFiles()`; consolidate platform guidance under `docs/platform/README.md`.
- [x] Record that iOS permission/background setup is incomplete and deferred, not current acceptance scope.
- [x] Clarify the grey `1` in workout rows: it is the set number; the styling/type indicator is intentional. Do not change it.
- [x] State Android/Linux-only current validation scope in the engineering instructions.

## P0 — Feature already agreed

### Live non-GPS timed activity

**Goal:** Add a third global Start choice alongside Gym workout and Outdoor activity.

- Ask for an activity category (suggestions plus custom text).
- Start/pause/resume/finish/discard; no GPS, GPX, sets/reps, or rest timer.
- Compute active duration from timestamps and accumulated paused intervals; UI timer ticks only refresh the display.
- Save one `ActivitySession` through `AppScope` → `AppServices` → `FilePersistenceService.saveActivity()`, then request reindexing.
- Store exact whole `durationSeconds`, compatible `durationMin`, UTC `startTime` and `dateLogged` based on the original start instant, a `fitness/<category>` tag, and no GPX.
- A durable note save must not be reported as failed because reindexing failed. If note persistence itself fails, show an error and allow retry. Discard must save nothing.
- Keep historical/manual activity logging as a typed-duration flow.

**Likely files:** `lib/ui/common/start_session_sheet.dart`, a new focused non-GPS timer screen/state helper, `lib/ui/activity/manual_activity_page.dart` for category suggestions only if a shared helper is appropriate, and new tests. Avoid reusing the GPS-heavy `ActivitySessionPage`.

**Regression tests:** elapsed duration; multiple pause/resume intervals; background/resume recalculation from timestamps; finish exactly once; discard no-save; persistence failure/retry; reindex failure after durable save; UTC metadata; category tag slugging; no GPX; no rest timer/GPS side effects; manual flow remains unchanged.

## P1 — Persistence and tracking failsafes

### 1. Confine generic note writes to the vault

**Observation:** GPX read/delete paths have explicit path checks. The generic note save path accepts `relativePath` and should be audited for equivalent confinement before writing.

**Task:** Inspect all callers of `FilePersistenceService` save APIs. Normalize/validate relative paths and reject absolute paths, parent traversal, unexpected roots, and symlink escapes where applicable. Preserve legitimate paths under the configured vault. Do not break existing filenames or silently rename records.

**Tests:** valid relative paths; `../` traversal; absolute path; nested traversal; symlink escape if supported by the test platform; atomic-write failure does not truncate the original note.

### 2. Reset elevation reference at GPS segment boundaries

**Observation to verify:** pause/resume splits GPX track segments, but the elevation accumulator may retain its previous altitude reference. If so, the first point after resume can count elevation change that occurred while paused.

**Task:** Trace `ActivityRecorder`, `ElevationGain`, and segment creation. Preserve already accumulated gain, but reset only the last-altitude reference at pause/resume boundaries so the inter-segment altitude delta is not counted.

**Tests:** elevation before pause remains; altitude difference during pause is excluded; elevation after resume accumulates normally; normal continuous-track behavior is unchanged.

### 3. Preserve the save/reindex failure boundary

For every session type, ensure the UI distinguishes a failed durable write from a successful write followed by failed indexing. Do not duplicate a session when retrying a reindex, and do not make a user repeat a successful save because the cache is stale.

Add or retain a regression test around the service boundary. Keep Markdown/GPX as the durable source of truth and Drift/SQLite rebuildable.

## P1 — Android and Linux validation

### Android device checklist

- Live GPS recording with screen locked; ongoing notification and foreground service remain active.
- Pause/resume creates distinct GPX segments and excludes paused distance/time.
- BLE heart-rate connect, disconnect and reconnect.
- Permission denial and subsequent grant paths.
- All-files-access denied fallback is clear and does not claim the fallback folder is Syncthing-shared.
- Wake lock starts/stops on the intended screens and is released on finish, discard, errors and navigation.
- Finish saves one Markdown note and, for a GPS session, one GPX file; history/index updates.
- New non-GPS timed activity works without requesting location/Bluetooth permissions.

### Linux desktop checklist

- `flutter pub get`, `flutter analyze`, `flutter test`.
- Build and launch the Linux desktop target.
- Confirm vault selection, save/reindex, history/calendar and manual logging.
- Confirm unsupported mobile-only features fail gracefully or remain unavailable without blocking core logging.

Do not claim Android/Linux checks passed until they are actually run. Add CI later if desired, but do not make an external service or network dependency part of normal app behavior.

## P2 — Model extensibility and planning

### Can existing data be expanded into the broader product?

Mostly yes for **actual activity records**. `ActivitySession` already stores free-text categories, duration, optional metrics, tags, body text, unknown frontmatter and nullable GPX. The live non-GPS timer should fit the existing model without a schema migration.

The larger design gap is **planning**, not activity storage. `PlanProgram` and the weekly rotation are still largely gym/free-text oriented. Do not force every planned activity into a workout template or equate a plan with an actual session.

Before implementing generalized scheduling, design explicit distinctions for:

- activity category vs tracking method;
- planned item vs completed session;
- reusable workout/template vs one-off activity;
- planned target vs measured result;
- optional modality-specific fields vs universal fields.

Keep the first iteration backward-compatible with existing Markdown plans. Prefer an extensible planned-item representation and adapters for legacy free-text rotations over a destructive rewrite. Add round-trip fixtures and migration/compatibility tests before changing durable schemas.

## Deferred

- iOS permission, background location/Bluetooth, signing and real-device testing. The current user explicitly wants Android/Linux first.
- Broad redesign of set techniques. The grey `1` is the set number; legacy W/N/D/F markers must not be reinterpreted as a universal technique taxonomy.
- Generalized activity scheduling until its model and migration path are designed.
- Release signing/app identifiers and store-readiness work.

## Claude handoff contract

For each task: inspect current source and callers first; make a focused change; add regression tests; run formatter, focused tests, analyzer and full tests as appropriate; report exact commands/results and unrun device checks. Do not merge, delete data, rewrite history, or claim device validation without evidence.
