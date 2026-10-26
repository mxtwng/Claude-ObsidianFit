# Documentation index

This directory is organized by purpose. Keep each document focused; link to it rather than copying the same instructions into several files.

## Working on the app

- [Engineering context](CONTEXT.md) — current baseline, architecture, known boundaries, and next agreed task. Refresh after meaningful code milestones.
- [Implementation plan](IMPLEMENTATION_PLAN.md) — product intent, domain rules, priorities, and task workflow. Requirements here are not proof of implementation.
- [Repository map](REPO_MAP.md) — source-file navigation, service boundaries, and test locations.
- [Audit follow-ups](AUDIT_FOLLOWUPS.md) — outstanding reliability checks, platform validation, and broader planning-model work.

## Platform setup

- [Platform setup and device validation](platform/README.md) — Android manifest guidance, runtime permissions, vault/Syncthing behavior, Android/Linux checks, and deferred iOS notes.
- The actual Android manifest lives at `android/app/src/main/AndroidManifest.xml`. Do not maintain a second copy of the manifest in documentation.

## Durable data contracts

- [Baseline activity example](../schemas/activity_schema.md) and [baseline workout example](../schemas/workout_schema.md) are round-trip fixtures; avoid editing them casually.
- [Activity extensions](../schemas/activity_schema.phase5.md) and [workout extensions](../schemas/workout_schema.phase5.md) describe implemented additions without changing baseline fixtures.
- [Plan schema example](../schemas/plan_schema.md) documents the current plan note shape.
- [Config example](../schemas/config_schema.json) is illustrative; it is not a general runtime configuration system. Check source comments for settings that remain hardcoded.

## Quick rules

- Source and tests establish current behavior.
- Markdown/GPX are durable user data; SQLite is a rebuildable cache.
- Keep manual/past logging separate from live tracking.
- Current validation scope is Android and Linux; iOS is deferred.
- Record exact commands and results. Do not claim device validation without actually testing hardware.
