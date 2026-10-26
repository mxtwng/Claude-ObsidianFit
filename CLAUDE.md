# Claude Repository Instructions

## Source of truth
1. Current source and tests define what the checked-out code actually does.
2. **docs/IMPLEMENTATION_PLAN.md** records agreed product direction and priorities; it is intent, not proof of implementation.
3. **docs/CONTEXT.md** is the current engineering checkpoint.
4. **docs/REPO_MAP.md** is the module/test navigation guide.
5. **schemas/** defines Markdown/frontmatter contracts and compatibility expectations.
6. **README.md** is the user-facing overview, not a complete specification.

The private product masterplan is not stored here. Do not invent missing requirements. Ask before consequential unresolved product decisions.

## Working agreement
- Begin with `git status --short --branch` and `git log -1 --oneline`; preserve user changes.
- Read the relevant call path and tests. Do not scan the entire repository by default, but when asked for a repository audit, do it thoroughly and update the docs that the audit exposes as stale.
- Trace visible UI through navigation, model, persistence, re-indexing, and tests before saying a feature is absent or broken.
- Existing UI/models are evidence of current behavior, not proof every legacy behavior is desirable. Read actual signatures before using APIs.
- Keep changes scoped to the goal, but include every layer the agreed behavior actually needs.
- Add regression tests for parsing/round trips, timestamps, manual-vs-live behavior, timers, persistence, indexing, and discard/error paths.
- Never delete user records, silently rewrite history, add destructive migrations, or change durable formats without a clear need and compatibility tests.
- No cloud sync, telemetry, uploaded analytics, or enabled-by-default reminders/notifications without explicit approval.
- Do not commit, push, merge, reset, clean, or rewrite history unless explicitly authorized. Repository-edit permission is not permission to merge into `main`.
- Separate code inspection from commands actually run. Never claim a test/build/device check passed without evidence.

## Domain invariants
- **Plan is not reality.** Editing a template must not mutate historical sessions or already-created plans; targets are not achieved results.
- One actual session must produce one record.
- Activity-first, not gym-only: support strength, calisthenics, cardio, walking, cycling, hiking, martial arts, yoga, stretching/mobility, recreation, and user-defined categories.
- Activity category is separate from tracking method; planned activity is separate from actual session.
- Past/manual entry is not live recording. A historical set toggle must not start live rest; manual activity entry must not start a live clock or GPS recorder.
- Only real-time set completion in a live workout may start rest, according to timer behavior/context. Rest targets, elapsed rest, and interval timers are separate concepts.
- Ordinary sets are the default. W/N/D/F markers are legacy classification, not a universal technique taxonomy. Do not infer dropsets/supersets/circuits from order or values.
- Blank optional metrics mean unknown/not entered, not zero. Preserve unknown frontmatter fields.

## Storage invariants
- Markdown notes and GPX 1.1 files are durable source of truth; Drift/SQLite is a disposable read cache rebuildable from the vault.
- UI services come from `AppScope.of(context)` / `AppServices`: database, `FilePersistenceService` vault, and `VaultReindexerService`.
- Use persistence service APIs for atomic writes, collision handling, and GPX path confinement; do not bypass them.
- After a successful note save, request re-indexing so views refresh. A re-index failure must not undo a durable save.
- No GPX is valid for non-GPS activity; do not create empty tracks.
- Baseline schema files are round-trip fixtures. Put extensions in phase sidecar schemas and fixtures unless a deliberate compatibility change is required.

## Validation
Run focused tests first, then broader checks as appropriate:

```bash
dart format <touched Dart files>
flutter test <focused test file>
flutter analyze
flutter test
```

Run analyzer/tests separately during diagnosis. For widget tests with periodic clocks, pump fixed frames rather than relying on `pumpAndSettle()`. Use mocked/recording vaults for fake-time UI tests and temporary directories for real persistence/re-index tests. Clearly list remaining Android/iOS device checks for GPS, background lifecycle, BLE, permissions, notifications, and wake lock.

## Current handoff
Read `docs/CONTEXT.md`. The next agreed feature is a **live timed activity without GPS**: a third global start option beside Gym workout and Outdoor activity. It needs a lightweight elapsed timer with pause/resume and save/discard, using the existing activity model/persistence route. It is not implemented on the reviewed baseline. Keep it separate from the GPS recorder and the manual/past logger.
