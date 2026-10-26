# ObsidianFit Implementation Plan

_Last reviewed: 2026-10-26. This document records product intent and priorities; inspect source/tests before claiming a feature is implemented._

## Product direction
ObsidianFit is a free, open-source, local-first fitness app built around user-owned Markdown and GPX files. V2 is a meaningful refinement, not merely a maintenance pass.

- **Simple, fast, effective, customizable.** Keep common actions quick; expose advanced options when useful.
- **Activity-first, not gym-only.** Support strength, calisthenics, running, walking, cycling, hiking, martial arts (TKD/boxing), yoga, stretching/mobility, dance, recreation, and custom activities.
- **Plan is not reality.** Templates guide; they must not rewrite actual sessions or silently mutate already-created plans. Targets are not achieved results.
- **Manual and live are different.** Completed activities can be logged afterwards without pretending they were tracked live.
- **Offline-first and user-owned.** Markdown is authoritative, GPX stores tracks, and Drift/SQLite is a disposable cache.
- No cloud sync, telemetry, or enabled-by-default reminders/notifications without explicit approval.

## Domain distinctions
Keep separate: activity category vs tracking method; planned activity vs actual session; reusable template vs historical session; exercise vs set/effort; technique/grouping vs category; rest target vs elapsed rest vs interval timer; live vs historical/manual logging.

Do not infer technique from set order or values. Ordinary sets are the default. Dropsets are linked efforts, supersets group exercises, circuits group sequences/rounds. Legacy W/N/D/F markers are not a universal taxonomy; investigate visible indicators before changing them.

## Activity entry and tracking
- One actual session is one record.
- Support manual/backdated logging without a live timer or tracker.
- Preserve GPS recording, GPX track handling, and manual non-GPS activity logging.
- **Next agreed feature:** add a third global Start choice for a live non-GPS timed activity, distinct from Gym workout, GPS Outdoor activity, and manual/past logging. Use elapsed time based on timestamps minus paused intervals; save through the existing activity-note path without GPX.
- Planning/scheduling should support activity types beyond gym workouts.
- Simple activities should not require reusable workout templates.
- Make live start, past-session logging, and daily metrics discoverable; never force a live session for manual entry.
- Notifications/reminders stay off by default.

## Gym logging
- Manual gym logging is first-class: enter exercises, sets, reps, load, holds/duration, and optional metrics directly. It must not require a live session, completion checkbox, or plate calculator.
- Historical/manual/batch entry must never start or increment live rest.
- Only real-time completion of a set in an active live session may trigger rest, subject to the configured behavior/context.
- Support set-by-set and exercise-by-exercise live workflows, including corrections, added sets, and exercise edits.
- Rest target, elapsed rest, and timer behavior are distinct. Desired default: non-blocking count-up that continues past target; timer can be disabled and never blocks logging. Interval/round timers are separate.
- Preserve useful optional features (plate calculator, RPE, weighted-bodyweight/assistance/added-load context, timed holds) without making every optional control dominate the logger.

## Data and compatibility constraints
- Markdown/GPX remain durable source of truth; the index must be rebuildable.
- Preserve round trips, legacy note compatibility, unknown frontmatter, and user data.
- Do not create duplicate records, silently mutate history, infer values from targets, or replace missing optional metrics with zero.
- Schema changes require explicit compatibility rules and regression tests.
- No network-dependent core behavior, telemetry, or cloud service without approval.

## Priorities

### P0 — Immediate feature and regression safety
1. Implement live timed activity without GPS as a third global Start choice.
2. Test elapsed duration from timestamps, pause/resume exclusion, finish/save, discard/no-save, category slugging, UTC timestamps, and re-index behavior.
3. Preserve the manual/live rest-timer boundary and its tests.
4. Verify one finish produces one Markdown note and no GPX file.

### P1 — Logger usability and semantics
5. Trace the reported grey `1` indicator to its source and intended meaning before changing it.
6. Inspect current workout draft/logger/timer before implementing set-by-set and exercise-by-exercise workflows or changing rest behavior.
7. Keep manual logging free of live-only controls while retaining useful optional tools.

### P2 — Activity-first planning and broader V2 alignment
8. Audit add/start entry points and daily-metric flow for discoverability.
9. Design generalized activity scheduling without assuming every planned item is a gym split or reusable workout.
10. Compare implementation against template/history separation, activity types, search/filtering, and correction requirements; prioritize evidenced gaps over speculative rewrites.

## Recommended workflow
1. Read `CLAUDE.md`, this plan, `docs/CONTEXT.md`; check git status and latest commit.
2. Trace the real UI path through model, persistence, re-indexing, and tests.
3. Implement one coherent feature slice, including all layers required by the agreed behavior.
4. Add focused regression tests; preserve baseline schema fixtures.
5. Run formatting, focused tests, analyzer, and full tests as appropriate. Separate automated results from device checks.
6. Update context after meaningful milestones and keep schema/README claims synchronized with implementation.

## Task handoff contract
State the goal/evidence, expected behavior and edge cases, files likely to change, behavior that must remain unchanged, tests, validation, and owner-run/device checks.

This plan describes requirements and priorities, not proof that the code already satisfies them. When requirements and current behavior differ, explain the discrepancy rather than silently redefining either.
