# ObsidianFit Repository Context

_Last updated: 2026-10-25. This file is an engineering checkpoint, not a substitute for reading relevant code or running checks._

## Current direction

ObsidianFit is moving from the Demo 1 maintenance checkpoint into V2 refinement. The core six-phase feature roadmap was previously implemented, but that does not mean the existing UX or every workflow is final. Follow [`docs/IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) for the agreed direction and priorities.

- Repository: https://github.com/mxtwng/Claude-ObsidianFit
- Main branch: `main`.
- The private, full product masterplan is intentionally not stored in this repository. This file and the implementation plan contain the information needed for implementation work.
- The last reported local validation at the Demo 1 checkpoint (2026-10-24) was `flutter analyze` with no issues and `flutter test` with 288 tests passing. These are historical reported results, not tests run during this documentation update.
- V2 application-code work has not yet been implemented as of this context update. Documentation changes do not imply that any V2 requirement is already satisfied.

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

## Important implementation facts to verify before changing

- The codebase contains a backdated/manual workout session path (`startRetroWorkoutSession()`) and a `WorkoutDraft` manual mode. This does not by itself prove the flow is discoverable or works end-to-end.
- In the previously inspected `workout_session_page.dart`, `_toggleDone(DraftSet set)` started the rest timer when a set became checked without an evident manual-session guard. Re-read the current code and add a regression test before fixing; do not rely on this note instead of checking the current branch.
- Calendar past-date entry has been an entry point for backdated gym logging; inspect the actual UI before asserting that manual logging is unavailable.
- Existing set markers include W/N/D/F, but V2 does not mandate this taxonomy. Dropsets, supersets, and circuits are grouping/technique concepts and should not be collapsed into a universal set-type enum without a deliberate design decision.
- An unexplained grey `1` indicator was reported. Investigate its source and intended semantics before changing it.
- Existing tests cover manual draft serialization, but prior inspection did not establish complete UI-level coverage of the manual/live timer boundary.

These are leads from prior inspection, not a substitute for current code evidence.

## Validation baseline and caveats

At the Demo 1 checkpoint, the developer reported:
- `flutter analyze`: no issues found.
- `flutter test`: 288 tests passed.

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
