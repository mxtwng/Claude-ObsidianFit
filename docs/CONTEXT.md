# ObsidianFit Repository Context

_Last updated: 2026-10-25. This file is an engineering checkpoint, not a substitute for reading relevant code or running checks._

## Current direction

ObsidianFit is moving from the Demo 1 maintenance checkpoint into V2 refinement. The core six-phase feature roadmap was previously implemented, but that does not mean the existing UX or every workflow is final. Follow [`docs/IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) for the agreed direction and priorities.

- Repository: https://github.com/mxtwng/Claude-ObsidianFit
- Main branch: `main`.
- The private, full product masterplan is intentionally not stored in this repository. This file and the implementation plan contain the information needed for implementation work.
- V2 refinement is just beginning. The latest application-code change fixes the manual/live rest-timer boundary; broader logger and UX requirements remain to be investigated against the current code.
- PR #2 (merged): https://github.com/mxtwng/Claude-ObsidianFit/pull/2 — “Fix rest timer boundary for manual workouts”.

## Architecture and data integrity

- Flutter provides the user interface.
- Markdown notes with YAML frontmatter and GPX 1.1 XML files are the durable source of truth.
- Drift/SQLite is a rebuildable read-cache for calendar, history, and analytics.
- The vault re-indexer scans files to rebuild/refresh the cache. Hidden folders and Syncthing conflict copies should not be indexed as normal records.
- Optional sync can be performed by the user with tools such as Syncthing or rsync; the app does not require a proprietary fitness-data cloud.
- Typical vault layout:

```text
/Documents/ObsidianFit/
├── Workouts/      # Gym session Markdown notes
├── Activities/    # GPS or manually logged activity notes
├── Tracks/        # GPX 1.1 route files
└── Plans/         # Workout and mobility templates
```

Do not break Markdown/GPX round-tripping, silently rewrite historical sessions when templates change, infer results from targets, or introduce destructive migration without explicit approval.

## Recent implementation checkpoint

### Manual/live rest-timer boundary — merged

The previous bug was in `lib/ui/workout/workout_session_page.dart`: checking a completed set could start the rest timer even for a historical/manual workout.

The merged fix checks `_draft.isManual` after toggling a set. Historical/manual set completion returns without starting live rest; active live set completion retains the rest-timer behavior. The check reads the current draft state on every toggle, so backdating a session changes behavior immediately.

Regression coverage in `test/rest_timer_boundary_test.dart` covers:
- Checking, unchecking, and rechecking a set in a manual/backdated workout does not start rest.
- Checking a set in a live workout still starts rest.
- Calling `setStart()` changes the draft to manual mode.

Owner-run validation on the PR branch before merge:
- `dart format lib/ui/workout/workout_session_page.dart test/rest_timer_boundary_test.dart` — 2 files checked, 0 changes.
- `flutter analyze` — no issues found.
- `flutter test` — all 291 tests passed, including the new regression tests.

The owner then fast-forwarded local `main` from `origin/main`; the merge included the fix and test file. These are reported command results from the PR branch, not a claim that the commands were rerun after merging.

## Important implementation facts to verify before changing

- The codebase contains a backdated/manual workout session path (`startRetroWorkoutSession()`) and a `WorkoutDraft` manual mode. This does not by itself prove the flow is discoverable or works end-to-end.
- **Next priority:** inspect manual gym logging from its actual UI entry point through saving a session. Report concrete findings with file/line references before changing code; do not assume the flow is absent or broken without evidence.
- Calendar past-date entry has been an entry point for backdated gym logging; inspect the actual UI before asserting that manual logging is unavailable.
- Existing set markers include W/N/D/F, but V2 does not mandate this taxonomy. Dropsets, supersets, and circuits are grouping/technique concepts and should not be collapsed into a universal set-type enum without a deliberate design decision.
- An unexplained grey `1` indicator was reported. Investigate its source and intended semantics before changing it.
- The timer-boundary regression now has UI-level tests. Continue to add focused tests for future behavior changes, especially persistence, date/time handling, and manual versus live logging.

These are leads from prior inspection, not a substitute for current code evidence.

## Validation baseline and caveats

The latest owner-reported validation for the current implementation, on the PR branch immediately before merge:
- `dart format` on the two touched Dart files: 0 changes.
- `flutter analyze`: no issues found.
- `flutter test`: 291 tests passed.

Do not claim these were rerun unless you actually run them. Automated tests do not replace Android/iOS real-device checks for GPS, background service lifecycle, BLE, notifications, permissions, or wake-lock behavior.

For Dart/Flutter changes, run the relevant tests, then as appropriate:

```bash
dart format <touched Dart files>
flutter analyze
flutter test
```

Run analyzer and tests separately during diagnosis so one failing command does not prevent the other from running.

## Multi-agent development workflow

- This repository is Claude's implementation context. Do not ask for, recreate, or store the full private product masterplan here.
- Read `CLAUDE.md` for working rules and `docs/IMPLEMENTATION_PLAN.md` for requirements.
- Read narrowly: start with `git status --short --branch` and `git log -1 --oneline`, then inspect only relevant files.
- Implement one scoped task at a time. Do not launch broad redesigns or audits without a specific task.
- Preserve user changes and data. Never recommend broad destructive cleanup as routine.
- Report exact files changed, actual validation performed, failures remaining, and commit hash when known.
- Update this context after meaningful implementation milestones, not after every trivial edit.
