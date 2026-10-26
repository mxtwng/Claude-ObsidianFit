# Workout Schema: Phase 5 Extensions

Companion to `workout_schema.md`. That file is a **test fixture** (parsed and
re-rendered byte-for-byte by `test/round_trip_test.dart`), so Phase 5 fields
are specified here instead. Everything in `workout_schema.md` stays valid.
New keys are optional, and notes without them keep parsing as before.

> **Status:** the Phase 5 workout fields described here are implemented in the domain models, Markdown parser/writer, and regression fixtures/tests. Unknown frontmatter keys are preserved through `extraFrontmatter`.

---

## 1. Retroactive timestamps (frontmatter)

Used when a session is logged after the fact (a "+ Log Past Session" entry).

| Key | Type | Required | Meaning |
|---|---|---|---|
| `start_time` | ISO 8601 UTC string, e.g. `"2026-10-18T11:30:00Z"` | Optional (written by Phase 5 loggers) | When the session **actually began**. For a backdated entry this is the historical time the user picked. |
| `date_logged` | ISO 8601 UTC string | Optional (written by Phase 5 loggers) | When the note was **written**. Set once at creation, never edited afterwards. |
| `date` | `YYYY-MM-DD` | Required (unchanged) | Local calendar date of `start_time`. Drives the calendar and the file name. |
| `time_started` | `"HH:mm"` 24h | Required (unchanged) | Local wall-clock time of `start_time`. |

Guidelines:

1. **`start_time` is the truth about the workout; `date_logged` is the truth about the entry.** An entry is retroactive when `date_logged` is clearly later than `start_time`. Live sessions write both with (nearly) the same value.
2. **Always UTC with a `Z` suffix**, to second precision, with no offsets or fractional seconds.
3. **`date` and `time_started` are derived from `start_time` using the device's local timezone at entry time**, then stored as written. They are not recomputed on read, so a note stays on the day the user saw when travelling or changing timezones.
4. **Legacy notes** (neither key present) fall back to `date` + `time_started`.
5. **`start_time` must not be in the future.** `date_logged` must be `>= start_time`.
6. **File name uses the local date/time**, same as live sessions: `Workouts/2026-10-18_1830_Push_Day_A.md`. If a note with that name exists, a retro entry must not overwrite it; append a numeric suffix.
7. **`duration_min` is still required**; for a backdated session the user enters it manually. `tss_score`, `readiness_score` and `total_volume_kg` stay optional.
8. Re-indexing is driven by file modification time, not `date_logged`.

```yaml
---
type: strength
split: "Push Day A"
date: 2026-10-18
time_started: "18:30"
start_time: "2026-10-18T11:30:00Z"
date_logged: "2026-10-22T14:05:12Z"
duration_min: 55
total_volume_kg: 3920
tags:
  - fitness/gym
  - split/push
---
```

(Example: a session done on the 18th at 18:30 local time, UTC+7, entered on the 22nd.)

---

## 2. Set attributes

Sets live in the note body, one per line, under their `## Exercise` heading.
Phase 5 extends the existing pipe-delimited line grammar. The attribute names
below are the canonical model/field names.

| Attribute | Type | Default | Applies to | Meaning |
|---|---|---|---|---|
| `is_bodyweight` | boolean | `false` | all sets | `true` when the load is the athlete's own bodyweight (optionally plus extra weight). |
| `extra_weight_kg` | number >= 0 | `0` | when `is_bodyweight: true` | Added load (belt, vest, dumbbell). `0` = pure bodyweight. |
| `weight_kg` | number > 0 | n/a | when `is_bodyweight: false` | External load (existing field, unchanged). |
| `reps` | integer >= 1 | n/a | dynamic sets | Repetitions, or jump count for plyometrics. |
| `duration_seconds` | integer >= 1 | n/a | isometric holds | Hold time. Used **instead of** `reps`. |
| `box_height_cm` | number > 0 | omitted | plyometrics | Box/drop height. |
| `contact_time_ms` | integer > 0 | omitted | plyometrics | Ground contact time. |
| `rpe` | number 1-10 | omitted | all sets | Unchanged. |
| `type` | `W`/`N`/`D`/`F` | `N` | all sets | Unchanged. |

Rules:

* A set has **either** `reps` **or** `duration_seconds`, never both.
* If `is_bodyweight` is `true`, `weight_kg` is absent. If `false`, `extra_weight_kg` is absent.
* Weights are stored in kg regardless of display units (see `config_schema.json`). Box height is stored in cm.
* **Volume:** `total_volume_kg` sums `load x reps` for non-warmup sets. For bodyweight sets the load is `extra_weight_kg`, so pure bodyweight and hold sets contribute `0`.

### 2.1 Line grammar

```text
- Set <n>: <load> x <reps> reps [| RPE <r>] [| Box: <cm>cm] [| Contact: <ms>ms] [| Type: <W|N|D|F>]
- Set <n>: <load> | Hold: <s>s [| RPE <r>] [| Type: <W|N|D|F>]
```

Segment order is fixed (that is what makes the round trip lossless). Written exactly as follows:

| Modality | `<load>` | Reps / hold segment |
|---|---|---|
| Weighted lift (existing) | `80kg` | `x 8 reps` |
| Bodyweight | `BW+0kg` | `x 12 reps` |
| Weighted bodyweight | `BW+20kg` | `x 6 reps` |
| Isometric hold | `BW+0kg` (or `BW+10kg`) | `Hold: 45s` (replaces `x N reps`) |
| Plyometric | `BW+0kg` | `x 5 reps`, then `Box:` / `Contact:` |

Parsers should also accept bare `BW` as `BW+0kg`. Writers always emit `BW+<n>kg`.
`Box:` and `Contact:` are independent and each optional.

---

## 3. Examples

### 3.1 Calisthenics and weighted bodyweight

```markdown
## Pull-ups
- Set 1: BW+0kg x 10 reps | RPE 7.0 | Type: W
- Set 2: BW+10kg x 6 reps | RPE 8.5 | Type: N
- Set 3: BW+10kg x 5 reps | RPE 9.5 | Type: F

## Weighted Dips
- Set 1: BW+20kg x 8 reps | RPE 8.0 | Type: N
```

Equivalent per-set data for the second pull-up set:

```yaml
is_bodyweight: true
extra_weight_kg: 10
reps: 6
rpe: 8.5
type: N
```

### 3.2 Isometric holds

```markdown
## Plank
- Set 1: BW+0kg | Hold: 60s | RPE 7.0 | Type: N
- Set 2: BW+0kg | Hold: 45s | RPE 8.5 | Type: F

## L-Sit
- Set 1: BW+0kg | Hold: 20s | Type: N

## Weighted Plank
- Set 1: BW+10kg | Hold: 30s | RPE 8.0 | Type: N
```

```yaml
is_bodyweight: true
extra_weight_kg: 0
duration_seconds: 60   # no `reps` key
rpe: 7.0
type: N
```

### 3.3 Plyometrics

```markdown
## Box Jumps
- Set 1: BW+0kg x 5 reps | Box: 60cm | Contact: 210ms | Type: N
- Set 2: BW+0kg x 5 reps | Box: 70cm | Contact: 195ms | RPE 8.0 | Type: N

## Broad Jumps
- Set 1: BW+0kg x 6 reps | Type: N
```

```yaml
is_bodyweight: true
extra_weight_kg: 0
reps: 5
box_height_cm: 70
contact_time_ms: 195
rpe: 8.0
type: N
```

### 3.4 Complete retroactive note

```markdown
---
type: strength
split: "Calisthenics A"
date: 2026-10-18
time_started: "07:15"
start_time: "2026-10-18T00:15:00Z"
date_logged: "2026-10-22T14:05:12Z"
duration_min: 48
total_volume_kg: 110
tags:
  - fitness/gym
  - split/calisthenics
---

# Calisthenics A

## Pull-ups
- Set 1: BW+0kg x 10 reps | Type: W
- Set 2: BW+10kg x 6 reps | RPE 8.5 | Type: N
- Set 3: BW+10kg x 5 reps | RPE 9.5 | Type: F

## Plank
- Set 1: BW+0kg | Hold: 60s | RPE 7.0 | Type: N

## Box Jumps
- Set 1: BW+0kg x 5 reps | Box: 60cm | Contact: 210ms | Type: N
```

---

## Implementation status and compatibility notes

The Phase 5 workout extensions described above are implemented. Relevant code and tests:

* Set data and Markdown line grammar: `lib/models/SetEntry.dart` and `lib/models/ExerciseEntry.dart`.
* Session timestamps/frontmatter: `lib/models/WorkoutSession.dart`.
* Parse/render and persistence: `lib/services/FilePersistenceService.dart`.
* Drift cache/index: `lib/services/app_database.dart` and `lib/services/vault_reindexer_service.dart`.
* Round-trip fixtures: `test/fixtures/phase5/`, covered by `test/phase5_round_trip_test.dart`; baseline fixture behavior is covered by `test/round_trip_test.dart`.

Keep `schemas/workout_schema.md` as the baseline round-trip fixture unless intentionally changing its contract. Use sidecar docs and new fixtures for extensions. Any future schema or cache change must preserve legacy-note compatibility and include regression tests.
