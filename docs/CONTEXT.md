# ObsidianFit: Technical Master Plan and Session Context

_Last updated: 2026-10-23. This file records the project checkpoint reported by the developer. Always treat current local disk and Git state as authoritative._

## 1. Project status

ObsidianFit is a local-first Flutter fitness app. **All six planned feature phases have been implemented.** Work has moved from roadmap implementation into maintenance, verification, repository cleanup, documentation, and iterative bug fixing. Do not restart Phase 5 or Phase 6 or describe them as planned work.

- Repository: https://github.com/mxtwng/Claude-ObsidianFit
- Package name: `obsidian_fit` (from `pubspec.yaml`).
- Primary branch: `main`.
- Feature milestone commit reported by the developer: `4d5ccaf` (`feat(phase6): complete phase 6 outdoor suite, PR engine, and tests`). A later `.gitignore` update was discussed and reportedly committed/pushed, but its commit hash was not provided; check `git log -1` for actual HEAD.
- Latest standalone test result reported by the developer: `flutter test` passed with `+200: All tests passed!`.
- Latest analyzer result reported by the developer: a deprecation info in `test/gpx_service_test.dart` concerning the XML `namespace` parameter. `flutter analyze` exited non-zero, so do **not** describe static analysis as clean until this is resolved and rechecked.
- `test/phase6_edge_cases_test.dart` exists on public `main` and contains test groups for PRs, splits, track profiles, weekly statistics, and vault-stat controller behavior. It previously had 37 issues because an earlier generated version guessed imports. The import paths were subsequently corrected.

Do not use a static test-count badge as a substitute for fresh verification. The `200+` result is a reported local test result, not a continuously refreshed CI status.

## 2. Architecture

### GUI-over-Markdown

- Flutter provides the native user interface; users do not need to edit Markdown manually.
- Markdown notes with YAML frontmatter and GPX 1.1 XML track files are the durable source of truth.
- Drift/SQLite is a rebuildable read-cache used by calendar, history, and analytics views.
- `VaultReindexerService` scans and parses files to refresh the cache. Hidden folders and Syncthing conflict copies such as `*.sync-conflict-*.md` should not be indexed as normal records.
- Syncthing and rsync are optional file-sync approaches. The app does not require a proprietary fitness-data cloud.

### Vault layout

```text
/Documents/ObsidianFit/
├── Workouts/      # Gym workout Markdown notes
├── Activities/    # GPS or manually logged activity Markdown notes
├── Tracks/        # GPX 1.1 route files
└── Plans/         # Workout and mobility templates
```

### Important domain/API names

Use exact names and import casing from the repository. Common entry points include:

- Models: `WorkoutSession`, `ActivitySession`, `ExerciseEntry`, `SetEntry`, and `PlanProgram` in `lib/models/Models.dart`.
- Persistence: `FilePersistenceService` in `lib/services/FilePersistenceService.dart` and the frontmatter codec.
- GPX: `GpxService` and track point/segment models under `lib/services/gpx_service.dart`.
- Phase 6 calculations: `PrService`, `SplitCalculator`, `TrackProfile`, and `WeeklyStatsService` under `lib/services/`.
- Vault/index/cache: `VaultReindexerService`, `VaultStatsLoader`, database services under `lib/services/`, and `VaultStatsController` in `lib/ui/common/vault_stats_controller.dart`.
- Shared UI services: `AppServices` in `lib/ui/app_services.dart`.

These are entry points, not a complete API specification. If a change depends on a constructor or method signature, read only the relevant file before writing code. Never invent an API to avoid a read.

## 3. Completed feature phases

### Phase 1 — Storage foundation
- Domain models for workout sessions, activity sessions, plans, exercises, and sets.
- Markdown/YAML frontmatter persistence and GPX persistence.
- Drift SQLite read-cache and vault re-indexing.
- Round-trip and persistence tests.

### Phase 2 — Gym UI and calendar
- High-contrast dark UI, workout logger, set-type markers (`W`, `N`, `D`, `F`), haptic rest timer, plate calculator, calendar, and session-history review.

### Phase 3 — GPS and BLE
- GPX 1.1 recording/parsing, location tracking and platform background-service support, MapLibre route rendering, and BLE heart-rate monitors via Heart Rate Service `0x180D`.

### Phase 4 — Platform resilience
- Android/iOS configuration and permissions, screen wake-lock, and Syncthing conflict-copy filtering in vault indexing.

### Phase 5 — Multi-discipline logging and retroactive entry
- Weighted-bodyweight syntax `BW+Xkg`; baseline bodyweight contributes `0 kg` to tonnage, with only external added load counted.
- Isometric holds such as `Hold: 60s`.
- Plyometric measurements such as `Box: 60cm | Contact: 210ms`.
- Backdated gym sessions, manual non-GPS activities, past-calendar entry, and mobility/routine support.

### Phase 6 — Outdoor analytics and PRs
- Live 1 km / 1 mi splits and split tables.
- Custom pace/elevation profile charts.
- Ghost-route overlays from saved GPX tracks.
- Personal-record engine, including estimated 1RM bench, max plank, longest run, and fastest 5K.
- Weekly multi-sport dashboard and edge-case tests.

## 4. Known maintenance items

### A. Fix the XML namespace deprecation precisely

The latest reported analyzer message was similar to:

```text
'namespace' is deprecated and shouldn't be used. Use 'namespaceUri' instead.
test/gpx_service_test.dart
```

The query uses a named argument like `namespace: _tpxNs`. The earlier suggested command

```bash
sed -i 's/\.namespace\b/\.namespaceUri/g' test/gpx_service_test.dart
```

does **not** match `namespace:` (there is no dot before the argument), so it would not fix that occurrence. Inspect only the exact line and confirm the installed `xml` package API before changing to `namespaceUri:`. Then run `flutter analyze` and `flutter test` separately. Record both results.

### B. Check whether generated build files are tracked

The public repository root has listed `.dart_tool/` and `build/`, even though `.gitignore` includes ignore rules. Ignore rules do not untrack files already committed.

First check:

```bash
git ls-files .dart_tool build
```

If this prints tracked paths, review the output, then untrack the generated directories without deleting local copies:

```bash
git rm -r --cached .dart_tool build
```

Review `git status` and the staged diff before committing. Do not run `git rm` if no tracked paths were reported. Do not routinely use `git restore .` because that can discard unrelated developer changes.

### C. Documentation status

The earlier README showed a stale `51 passing` test badge and left Phases 5 and 6 unchecked. It has now been updated to describe the completed six-phase feature set, use the actual clone URL, and avoid a fixed test-count badge. Keep validation claims honest: the last reported standalone test run passed 200+ tests, while analysis still had the namespace deprecation info.

### D. CI workflow

A `.github/workflows/flutter.yml` workflow was not found at the checked path. GitHub Actions running `flutter analyze` and `flutter test` on pushes and pull requests is a reasonable next improvement after local checks are clean; it is not a prerequisite for saying the six feature phases are implemented.

## 5. Multi-instance workflow and read-budget rules

The developer coordinates several Claude sessions/accounts through Gemini. Your job is to preserve continuity and give Claude small, executable tasks, not to restart the roadmap or perform broad speculative audits.

1. **Read narrowly.** Begin with this context and current Git status. Do not perform a full workspace scan or read every service/UI file by default.
2. **Do not guess APIs.** If a change requires an actual constructor, class, path, or method signature, inspect only the relevant file. Accurate targeted reads are better than an unbuildable guess.
3. **Name the exact files.** Keep a task scoped to 1–3 named files where practical. State what must not change.
4. **Write directly to disk.** Use workspace file tools for code/docs edits. Avoid dumping full source files into chat or using long shell heredocs for Markdown; this repeatedly caused formatting/truncation problems.
5. **Avoid costly tool loops.** “Inspect everything” prompts triggered 10–15 sequential reads and consumed quota before a change was written.
6. **Do not claim validation you did not run.** The developer normally runs local checks and shares output:

```bash
cd ~/Developer/Claude-ObsidianFit
dart format lib test
flutter analyze
flutter test
```

Run analyzer and tests as separate commands during diagnosis so an analyzer's non-zero exit does not skip tests.
7. **Protect working changes.** Check `git status` before editing. Do not recommend `git restore .` as routine cleanup; review and revert only a specific confirmed-disposable path.
8. **No premature commits.** Do not stage guessed tests or commit before tests pass and the diff has been reviewed.
9. **Update this context after meaningful milestones.** Record files changed, actual validation performed, failures remaining, and commit hash when known.

### Efficient startup protocol

1. Read `docs/CONTEXT.md`.
2. Check `git status --short --branch` and `git log -1 --oneline`.
3. Inspect only the file(s) relevant to the user's current request.
4. Briefly report the actual repository state, then proceed with the specific task.

## 6. Immediate priorities

1. Resolve the XML namespace deprecation in `test/gpx_service_test.dart` and independently rerun analysis and tests.
2. Check whether `.dart_tool/` and `build/` are tracked; if so, untrack them in a focused housekeeping commit.
3. Consider adding the GitHub Actions workflow after the current state is green.
4. Continue with the user's reported app/UX bugs one issue at a time. **Do not reopen Phases 1–6 as unfinished roadmap work.**
