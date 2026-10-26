# Activity Schema: Phase 5 Extensions

Companion to `activity_schema.md`. That file is a **test fixture** (parsed by
`test/round_trip_test.dart` and the re-indexer tests), so Phase 5 fields are
specified here instead. Everything in `activity_schema.md` stays valid. GPS
recorded activities are unchanged.

> **Status:** the Phase 5 activity fields described here are implemented in `ActivitySession`, `manual_activity_page.dart`, persistence, indexing, and tests. The live non-GPS timed activity flow is a separate planned feature; do not confuse it with manual/past logging.
> Unknown frontmatter keys are preserved through `extraFrontmatter`.

---

## 1. Manual, non-GPS retro-logging

Runs, rides and walks entered after the fact have **no GPX trace**.

* **`gpx_file` is optional.** For a manual entry it is **omitted** (preferred) or `null`.
* Writers **omit** the key (this matches `ActivitySession.toFrontmatter`, which only emits `gpx_file` when a track exists).
* Readers **must accept** all three forms: key omitted, `gpx_file: null`, and `gpx_file: ""`. All mean "no track".
* An empty value must never be written as `"[[]]"`.
* No file is created in `Tracks/` for a manual activity, and the History screen shows no route map for it.
* When `gpx_file` is present, nothing changes: `"[[<name>.gpx]]"` wikilink, resolved by file name.

## 2. Manual activity metrics

Manual entries cover **any** activity, not only distance sports: a run, ride or
walk, but also Taekwondo, boxing, yoga, stretching and similar sessions that
have no distance or elevation. `category` is a free-text label slugged to
`[a-z0-9_]` (`taekwondo`, `trail_run`).

Frontmatter keys for a manual entry:

| Key | Type | Required (manual) | Rules |
|---|---|---|---|
| `type` | string | Yes | `activity` |
| `category` | string | Yes | `run`, `ride`, `walking`, `taekwondo`, `boxing`, `yoga`, `stretching`, ... |
| `date` | `YYYY-MM-DD` | Yes | Local calendar date of `start_time` (unchanged). |
| `time_started` | `"HH:mm"` | Yes | Local wall-clock time of `start_time` (unchanged). |
| `duration_seconds` | integer >= 1 | **Yes** | Moving time in whole seconds. Canonical duration for manual entries. |
| `distance_km` | number > 0 | Optional | Kilometres, decimals allowed. **Omit the key when no distance was entered**; never write `0`. |
| `elevation_gain_m` | number >= 0 | Optional | Metres climbed. **Omit the key when not entered** (unknown or not applicable). `0` means "entered, flat". |
| `avg_hr` | integer (bpm) | Optional | Omit the key if unknown; never write `0`. |
| `rpe` | number 1-10 | Optional | Session RPE, 1 (very easy) to 10 (maximal). Integers or halves (`7.5`). **Omit the key when not entered.** |
| `gpx_file` | wikilink | No | Omit or `null` (see section 1). |
| `max_hr`, `avg_pace_min_km`, `tss_score` | as in `activity_schema.md` | Optional | `avg_pace_min_km` is derived (`duration_seconds / distance_km`, `m:ss`) and **only written when `distance_km` is present**. |
| `start_time`, `date_logged` | ISO 8601 UTC | Optional (written by Phase 5 loggers) | Same semantics as in `workout_schema.phase5.md`. |
| `duration_min` | number | Derived | See next paragraph. |

**Blank means unknown, not zero.** A writer never substitutes `0` for a value
the user did not enter. When a distance, elevation, RPE or heart rate is
supplied it must be valid (distance > 0, elevation >= 0, RPE 1-10, heart rate
1-300); otherwise the entry is rejected rather than saved without it.

**Title.** An entry with a distance is titled `<km> km <Label>`
(`7.5 km Run`); an entry without one is titled with the label alone
(`Taekwondo`).

**Backward compatibility.** Readers already treat all of these keys as
optional, so existing notes (including ones with `elevation_gain_m: 0` or an
`rpe`) stay valid and are never rewritten. Without a distance, History and the
calendar show duration only, and the weekly distance total counts `0 km` for
the entry while it still counts as one activity.

**Duration compatibility.** `duration_min` is still a required key in today's
parser. Until the model migrates, manual entries write **both**:
`duration_seconds` (canonical) and `duration_min = duration_seconds / 60`
(derived, rounded to 1 decimal). On a mismatch, `duration_seconds` wins. GPS
activities keep using `duration_min` only.

**Retroactive timestamps** follow the workout rules (`workout_schema.phase5.md`, section 1):

* `start_time`: when the activity actually began, ISO 8601 UTC with `Z`, not in the future.
* `date_logged`: when the note was written, UTC, `>= start_time`, never edited later.
* `date` and `time_started` are the local rendering of `start_time` at entry time and drive the file name (`Activities/2026-10-19_0615_run.md`).
* No timestamps present means fall back to `date` + `time_started`.

---

## 3. Examples

### 3.1 Manual run, no GPS

```yaml
---
type: activity
category: run
date: 2026-10-19
time_started: "06:15"
start_time: "2026-10-18T23:15:00Z"
date_logged: "2026-10-22T14:20:41Z"
duration_seconds: 2712
duration_min: 45.2
distance_km: 7.5
elevation_gain_m: 85
avg_hr: 152
rpe: 7
avg_pace_min_km: "6:02"
tags:
  - fitness/run
---
```

Complete note:

```markdown
---
type: activity
category: run
date: 2026-10-19
time_started: "06:15"
start_time: "2026-10-18T23:15:00Z"
date_logged: "2026-10-22T14:20:41Z"
duration_seconds: 2712
duration_min: 45.2
distance_km: 7.5
elevation_gain_m: 85
avg_hr: 152
rpe: 7
tags:
  - fitness/run
---

# 7.5km Easy Run (logged afterwards)

- Treadmill was broken, ran the river loop. No watch, so no GPS trace.
```

### 3.2 Manual ride, minimal (no heart rate)

```yaml
---
type: activity
category: ride
date: 2026-10-20
time_started: "17:00"
start_time: "2026-10-20T10:00:00Z"
date_logged: "2026-10-22T14:22:03Z"
duration_seconds: 5400
duration_min: 90
distance_km: 32
elevation_gain_m: 0
rpe: 6
tags:
  - fitness/ride
---
```

### 3.3 Manual Taekwondo session, no distance, elevation or RPE

```yaml
---
type: activity
category: taekwondo
date: 2026-10-24
time_started: "18:00"
start_time: "2026-10-24T11:00:00Z"
date_logged: "2026-10-24T13:05:12Z"
duration_seconds: 4500
duration_min: 75
tags:
  - fitness/taekwondo
---
```

```markdown
# Taekwondo

- Sparring and forms.
```

No `distance_km`, `elevation_gain_m`, `rpe` or `avg_pace_min_km` key is
written, because none was entered.

### 3.4 Explicit `null` is also valid on read

```yaml
gpx_file: null
```

---

## Implementation status and compatibility notes

The Phase 5 activity fields described above are implemented. Relevant code and tests:

* Model/frontmatter: `lib/models/ActivitySession.dart`.
* Manual logger and validation: `lib/ui/activity/manual_activity_page.dart`.
* Markdown/GPX persistence: `lib/services/FilePersistenceService.dart`.
* Read-cache indexing: `lib/services/vault_reindexer_service.dart` and `lib/services/app_database.dart`.
* Regression and round-trip coverage: `test/manual_activity_logging_test.dart`, `test/phase5_round_trip_test.dart`, `test/round_trip_test.dart`, and `test/reindexer_test.dart`.

Keep `schemas/activity_schema.md` as the baseline round-trip fixture unless intentionally changing its contract. Use new fixtures for additional cases. The next planned addition is a live non-GPS timer; it should reuse the activity model and save route unless inspection identifies a real schema gap. It must save no GPX and remain separate from the manual logger.
