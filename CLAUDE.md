# Claude Repository Instructions

## Source of truth
- Follow `docs/IMPLEMENTATION_PLAN.md` for agreed product direction and implementation priorities.
- Use `docs/CONTEXT.md` for the current repository/architecture checkpoint; inspect the code and tests for actual behavior.
- `README.md` describes the project to users, not a complete specification.
- The private product masterplan and planning conversations are not in this repository. Do not assume hidden context or invent requirements. If a necessary product decision is unresolved in the implementation plan, ask before making a consequential choice.

## Working style
1. Start with `git status --short --branch` and `git log -1 --oneline`. Preserve the user's existing changes.
2. Read only the files relevant to the current task. Do not scan the whole repository unless asked.
3. Implement one narrowly scoped task at a time. Prefer 1–3 named files where practical; explain before expanding scope.
4. Prioritize correctness, data integrity, and regression prevention. Make the functional, data-model, and logger-interface changes required by the agreed design; preserve existing behavior that remains compatible. Do not initiate unrelated redesigns.
5. Treat existing UI and data models as implementation evidence, not as proof that every existing behavior is desirable. Conversely, do not replace working behavior without a requirement or demonstrated defect.
6. Do not invent APIs. Read the relevant class/method signatures before using them.
7. Add focused regression tests for behavior changes, especially persistence, date/time handling, manual vs live logging, and timer side effects.
8. Keep user data safe. Markdown and GPX files are the durable source of truth; SQLite/Drift is a rebuildable cache. Do not introduce cloud storage, telemetry, destructive migrations, or data deletion without explicit approval.
9. Do not infer results from targets, silently rewrite historical records when templates change, or create duplicate session records.
10. Do not commit or push unless explicitly requested. Never claim a command/test passed unless it was actually run; distinguish code inspection from executed verification.

## Validation
For Dart/Flutter changes, run the narrowest relevant tests first, then as appropriate:

```bash
dart format <touched Dart files>
flutter analyze
flutter test
```

Report changed files, behavior changed, tests/commands actually run, results, and anything the user still needs to verify on-device. Keep manual real-device checks distinct from automated test results.
