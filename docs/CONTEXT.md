# ObsidianFit: Technical Master Plan and Session Context

_Last updated: 2026-10-24. This file records the latest developer-reported checkpoint. Treat current local disk and Git state as authoritative; test results below are the latest results reported for the local checkout, not CI results._

## 1. Project status

ObsidianFit is a local-first Flutter fitness app. **All six planned feature phases are implemented, and Demo 1's core functionality, persistence/cache architecture, and primary UI are in place.** The project is now at a maintenance and refinement checkpoint—not at the start of the feature roadmap. Treat the app as a working first demo, not as fully production-validated software.

- Repository: https://github.com/mxtwng/Claude-ObsidianFit
- Package name: `obsidian_fit` (from `pubspec.yaml`).
- Primary branch: `main`.
- Latest reported repository HEAD: `f185a96` (`docs: sync reference Android manifest with security export restrictions`).
- Latest reported Git state: `main` is clean and synchronized with `origin/main`.
- Latest developer-run validation (2026-10-24): `flutter analyze` reported **No issues found**; `flutter test` reported **288 tests passed**. These are local results and do not establish CI coverage or real-device correctness.
- Recent maintenance commits reported on `main`: `257a3c6` (XML namespace API and missing-GPX-time fallback), `2599024` (GPX path confinement), `9803cae` (stop tracking generated Flutter build files), `049a98b` (restrict background-service component exports/remove boot receiver), and `f185a96` (sync reference Android manifest).
- Repository cleanup removed generated `.dart_tool/` and `build/` files from Git's index while preserving local copies.
- Future commits should use the GitHub-provided noreply email configured in the local repository. Historical commit metadata may still contain an older email; changing the local setting does not rewrite old commits.

**Security checkpoint:** a focused static-review/maintenance pass addressed the reported GPX track path-confinement issue and Android background-service component exposure. This is not a full penetration test or a guarantee that every platform/plugin interaction is secure. GitHub security scanning is enabled according to the developer; review new alerts in GitHub and revoke any genuine exposed credential at its issuing service.

**Release caveat:** platform-specific behavior still needs real-device verification. Before public release, review Android permission policy/necessity, foreground/background tracking and BLE behavior, and release signing. Do not describe Demo 1 as release-ready solely because analysis and unit tests pass.

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

## 4. Current maintenance and release-readiness checkpoint

The following previously open maintenance items are reported complete and were committed to `main`:

### A. XML namespace API and missing GPX timestamps — completed

- Updated the deprecated XML namespace argument in `test/gpx_service_test.dart` to the current API.
- Fixed track-math handling for GPX files without `<time>` tags so missing timestamps do not produce an extreme epoch-based duration.
- Latest local validation: `flutter analyze` reported no issues; `flutter test` passed all 288 tests.

### B. GPX track path confinement — completed

- `FilePersistenceService` now validates GPX track filenames and confines read/delete operations to the intended tracks directory, including traversal/absolute-path and outside-directory symlink cases.
- Added regression coverage in `test/file_persistence_track_path_test.dart`.
- Treat Markdown and synced files as untrusted input; maintain the confinement checks in future persistence changes.

### C. Generated build artifacts — completed

- Generated `.dart_tool/` and `build/` files were removed from Git's index without deleting the local generated files.
- Keep ignore rules in place; do not commit generated build output.

### D. Android background components — updated, device validation still required

- `BackgroundService` and `WatchdogReceiver` are declared non-exported in `android/app/src/main/AndroidManifest.xml`.
- The plugin's `BootReceiver` is removed from the merged manifest using the manifest-merger removal directive.
- `docs/platform/AndroidManifest.reference.xml` is synchronized with the app manifest.
- The manifest change has passed the reported repository checks, but confirm the merged manifest and test tracking/service startup and shutdown on a real Android device. Removing boot-start behavior is intentional in the current configuration.

### E. Git identity privacy — current setting updated

- Local Git email is configured to use the GitHub noreply address for future commits.
- This does not remove an email from already-created commit objects. Consider history rewriting only if the user explicitly decides it is necessary; it disrupts collaborators and is not required for routine development.

### F. Suggested next engineering tasks (not blockers to Demo 1)

1. Perform a focused real-device acceptance pass for Android: fresh install/permissions, GPS start-pause-resume-stop, screen-off/background tracking, notification behavior, BLE heart-rate connection/reconnection, and app/service lifecycle.
2. Exercise data integrity end-to-end: create/edit/delete workout and activity notes, restart the app, rebuild the Drift cache from Markdown/GPX, and verify synced/conflict copies do not become duplicate records.
3. Add a lightweight GitHub Actions workflow for `flutter analyze` and `flutter test` on pushes and pull requests if desired. This was a recommendation, not a currently verified repository feature.
4. Before release, review Android permission scope and store-policy implications, signing configuration, dependency updates, and the exact supported platform matrix.
5. After these checks, prioritize refinement from observed bugs/usability friction rather than speculative rewrites. Keep the scope small and preserve the flat-file source-of-truth model.

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

1. **Real-device acceptance testing**, especially Android background GPS/service lifecycle and BLE; unit tests do not cover all OS/vendor behavior.
2. **End-to-end data-integrity testing** across Markdown/GPX persistence, cache rebuild, app restart, and optional file sync.
3. **Release-readiness review** for permissions, signing, dependency/security alerts, and supported platforms before distribution.
4. Optionally add CI for `flutter analyze` and `flutter test`, then focus on concrete UI/UX and functionality feedback from Demo 1.

Do not reopen Phases 1–6 as unfinished roadmap work. Keep changes incremental, preserve user data, and update this file after meaningful milestones with the exact changed files, validation actually run, remaining issues, and commit hash when known.
