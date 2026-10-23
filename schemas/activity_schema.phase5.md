# Activity Schema: Phase 5 Extensions

Companion to `activity_schema.md`. That file is a **test fixture** (parsed by
`test/round_trip_test.dart` and the re-indexer tests), so Phase 5 fields are
specified here instead. Everything in `activity_schema.md` stays valid. GPS
recorded activities are unchanged.

> **Status:** specification. `ActivitySession` does not model `duration_seconds`,
> `rpe`, `start_time` or `date_logged` yet (see [Implementation notes](#implementation-notes)).
> Unknown frontmatter keys already survive a round trip via `extraFrontmatter`.

---

## 1. Manual, non-GPS retro-logging

Runs, rides and walks entered after the fact have **no GPX trace**.

* **`gpx_file` is optional.** For a manual entry it is **omitted** (preferred) or `null`.
* Writers **omit** the key (this matches `ActivitySession.toFrontmatter`, which only emits `gpx_file` when a track exists).
* Readers **must accept** all three forms: key omitted, `gpx_file: null`, and `gpx_file: ""`. All mean "no track".
* An empty value must never be written as `"[[]]"`.
* No file is created in `Tracks/` for a manual activity, and the History screen shows no route map for it.
* When `gpx_file` is present, nothing changes: `"[[<name>.gpx]]"` wikilink, resolved by file name.

## 2. Manual outdoor metrics

Frontmatter keys for a manual outdoor entry:

| Key | Type | Required (manual) | Rules |
|---|---|---|---|
| `type` | string | Yes | `activity` |
| `category` | string | Yes | `run`, `ride`, `walk`, ... |
| `date` | `YYYY-MM-DD` | Yes | Local calendar date of `start_time` (unchanged). |
| `time_started` | `"HH:mm"` | Yes | Local wall-clock time of `start_time` (unchanged). |
| `distance_km` | number > 0 | **Yes** | Kilometres, decimals allowed. |
| `duration_seconds` | integer >= 1 | **Yes** | Moving time in whole seconds. Canonical duration for manual entries. |
| `elevation_gain_m` | number >= 0 | **Yes** | Metres climbed. Write `0` for flat or unknown. |
| `avg_hr` | integer (bpm) | Optional | Omit the key if unknown; never write `0`. |
| `rpe` | number 1-10 | **Yes** | Session RPE, 1 (very easy) to 10 (maximal). Integers or halves (`7.5`). |
| `gpx_file` | wikilink | No | Omit or `null` (see section 1). |
| `max_hr`, `avg_pace_min_km`, `tss_score` | as in `activity_schema.md` | Optional | `avg_pace_min_km` is derived (`duration_seconds / distance_km`, `m:ss`) if written. |
| `start_time`, `date_logged` | ISO 8601 UTC | Optional (written by Phase 5 loggers) | Same semantics as in `workout_schema.phase5.md`. |
| `duration_min` | number | Derived | See next paragraph. |

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

### 3.3 Explicit `null` is also valid on read

```yaml
gpx_file: null
```

---

## Implementation notes

For the Phase 5 implementation (not done yet):

* `ActivitySession`: add `durationSeconds`, `rpe`, `startTime`, `dateLogged` to `knownKeys`, `toFrontmatter` and `fromFrontmatter`. Keep `gpxFileName` nullable, and make sure `extractWikilinkTarget` yields `null` for `null`, `""` and `"[[]]"`.
* The Manual Outdoor Activity Logger must validate: `distance_km > 0`, `duration_seconds >= 1`, `elevation_gain_m >= 0`, `rpe` in 1-10, `avg_hr` positive when given.
* Add round-trip tests with **new fixtures** (for example `test/fixtures/`), and keep `schemas/activity_schema.md` byte-identical so the existing tests stay valid.
* The History and map views must handle activities with no GPX (no route preview).
