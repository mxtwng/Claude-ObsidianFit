# ObsidianFit Implementation Plan

_Last updated: 2026-10-25. This is the public implementation-facing summary of agreed product direction. It is not a claim that these requirements are already implemented._

## Product direction

ObsidianFit is a free, open-source, local-first fitness app built around user-owned Markdown and GPX files. V2 is a meaningful refinement of the product, not merely a maintenance-only pass. Preserve working behavior where it remains compatible with this direction; do not treat the existing UI as automatically final.

Guiding principles:
- **Simple, fast, effective, customizable.** Keep common actions quick; make advanced options available without forcing them into every flow.
- **Activity-first, not gym-only.** Support strength training, bodyweight/weighted exercise, running, walking, cycling, hiking, martial arts (including TKD/boxing), yoga, stretching/mobility, dance, recreation, and custom activities.
- **Plan is not reality.** Plans and templates are guidance/starting points, not molds. Editing a template must not rewrite past plans or actual sessions. Targets must not be presented as achieved results.
- **Manual and live flows are different.** Users must be able to record completed activities without pretending to be tracking them live.
- **Offline-first and user-owned.** Markdown is authoritative and human-readable; GPX stores tracks. SQLite/Drift is a disposable/rebuildable cache if retained. Use stable identifiers and recoverable Trash where deletion is supported.
- No cloud sync service, telemetry, or notifications/reminders enabled by default without explicit approval.

## Domain distinctions

Keep these concepts separate in code and UI:
- Activity type vs tracking method.
- Planned activity vs actual session.
- Workout template vs historical plan/session.
- Exercise vs individual set/effort.
- Technique/grouping (e.g. dropset, superset, circuit) vs section/category.
- Rest target vs elapsed rest vs timer behavior.
- Live logging vs historical/manual entry.

Do not infer a technique from set order or values. Ordinary sets should be the default. Dropsets are linked efforts; supersets group exercises; circuits group sequences/rounds. The legacy warmup/normal/drop/failure markers are not mandatory as a universal classification system; investigate existing indicators before deciding what they mean or whether to retain them.

## Activity entry and scheduling

- A single actual activity/session is one record.
- Support manual logging of already completed activities, including backdated activities, without requiring a live tracker.
- Preserve manual historical GPS activity logging and GPX import/track handling where already supported.
- Scheduling/planning must accommodate different activity types, not only gym workouts.
- Simple activities should not require creation of a reusable workout template.
- The global add/start entry point should make the main actions discoverable: start tracking, manually log an activity, and enter daily metrics. Do not force a live session for manual entry.
- Notifications and reminders are off by default.

## Gym logging requirements

- Manual gym logging is first-class: users can enter actual exercises, sets, reps, load, holds/duration, and relevant optional metrics directly. It must not require a live workout, a set-completion checkbox, or a plate calculator.
- Historical/manual/batch entry must **never start or increment a live rest timer** when a set is checked or recorded.
- Only real-time completion of a set in an active live session may trigger rest, and only when the configured timer behavior/context calls for it.
- Support two live workflows: **set-by-set** and **exercise-by-exercise**. Both must allow corrections, added sets, and exercise edits. Exercise-by-exercise can quickly confirm prescribed values or batch-correct them.
- Rest target, elapsed rest, and timer behavior are distinct. Default rest behavior is a non-blocking count-up that continues after the target; the timer can be disabled and must never block logging. Round/interval timers are a separate concept.
- Preserve useful optional features such as the plate calculator, RPE, weighted-bodyweight/assistance/added-load context, and timed holds. Do not let optional controls dominate every logger screen. Reassess always-visible plyometric controls based on relevance.
- Do not commit to a broad UI redesign before inspecting the current implementation and tests. Make substantive logger refinements where the requirements or observed friction justify them.

## Data and compatibility constraints

- Markdown/GPX remain the durable, human-readable source of truth; any SQLite/Drift cache must be rebuildable.
- Preserve round-trip behavior and existing user data. Prefer stable IDs and explicit, recoverable deletion.
- One actual session must not become multiple records.
- Template edits must not mutate historical actual sessions or silently rewrite already-created plans.
- Do not invent values, fill missing results from targets, or silently reinterpret legacy data. If migration is necessary, define and test it explicitly.
- No network-dependent core functionality, telemetry, or cloud service without explicit approval.

## Prioritized work

### P0 — Correctness and access
1. Inspect the current manual gym entry path and determine whether it is discoverable and usable end-to-end. Restore/fix it if broken; do not assume it is absent just because its entry point is narrow.
2. Fix the rest-timer event boundary so historical/manual set completion never starts live rest.
3. Add regression tests that distinguish live set completion from historical/manual entry and cover corrections/serialization as applicable.

### P1 — Logger behavior
4. Confirm the meaning and origin of the unexplained grey `1` indicator before changing it; do not blindly restore the legacy W/N/D/F taxonomy.
5. Inspect current logger UI, draft/session model, and timer service. Implement the two live logging styles and configurable, non-blocking rest behavior in small, testable increments.
6. Keep manual logging free of controls that only make sense during live tracking; retain optional tools where useful.

### P2 — Broader V2 alignment
7. Compare the implemented app with the requirements in this document: activity types, planning/scheduling, manual entry, template/history separation, discoverability, and search/filtering.
8. Prioritize concrete gaps and regression risks over speculative rewrites. Keep each implementation handoff narrow and testable.

## Recommended implementation sequence

1. Inspect the current relevant code and tests against P0; report findings with file/line references.
2. Fix manual/live timer boundary and add regression tests.
3. Verify manual gym logging from the actual user entry points; fix access/flow defects.
4. Confirm the data-model semantics and legacy indicator before changing them.
5. Refine live logging styles and rest behavior.
6. Audit broader V2 gaps and propose small tasks in priority order.
7. Run validation and document remaining real-device checks.

## Task handoff contract

Each task should state:
- Goal and observed evidence.
- Exact expected behavior and important edge cases.
- Files likely to change and files/behavior that must not change.
- Regression tests to add/update.
- Validation required and what needs owner-run/device verification.

Treat this document as requirements and priorities, not proof of implementation. When a requirement conflicts with the current code, inspect and explain the discrepancy instead of silently redefining the requirement. Do not invent new scenarios or reopen settled decisions without concrete evidence.
