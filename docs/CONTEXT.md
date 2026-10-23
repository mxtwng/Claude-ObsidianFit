# SYSTEM CONTEXT & HANDOFF: OBSIDIANFIT MOBILE APP

## Role & System Mission
You are a principal cross-platform mobile engineer (Flutter/Dart) building **ObsidianFit**—a free, open-source, local-first fitness app combining Strava-style GPS logging and Hevy-style gym tracking.

---

## Core Architectural Laws

1. **GUI-Over-Markdown Architecture:**
   - The user interface is a modern, high-contrast dark mode GUI. The user NEVER views or types raw Markdown inside the app.
   - Behind the scenes, all data serializes to flat `.md` notes (with YAML frontmatter) and `.gpx` tracks in local storage (`/Documents/ObsidianFit/`), fully syncable via Syncthing/rsync.

2. **Dual-Layer Storage Engine:**
   - **SQLite (Drift ORM):** In-memory / fast read cache for calendar grids, history lists, and charts.
   - **Flat Files (`.md` / `.gpx`):** Single source of truth.
   - **Directory Re-indexer:** On launch, scan local storage for modified `.md` files and sync changes into SQLite.

3. **Background Services & Hardware:**
   - Persistent Android Foreground Service & iOS Location Background Mode to prevent background kills.
   - Native BLE scanning for Heart Rate monitors (`0x180D`) with auto-reconnect logic.

---

## Development Environment & Storage
- **Local Directory:** `/home/mxtw/Developer/Claude-ObsidianFit/`
- **Active Tools:** Filesystem MCP (direct read/write access) and Git MCP (`main` branch).
- **Reference Schemas Location:** `schemas/` (`workout_schema.md`, `activity_schema.md`, `plan_schema.md`, `config_schema.json`).

---

## Universal Handoff & Discovery Protocol

Whenever a new chat session starts or an account switch occurs, execute these steps immediately using MCP tools:

1. **Inspect Workspace:** Use Filesystem MCP to list files in `/home/mxtw/Developer/Claude-ObsidianFit/` (check `lib/`, `schemas/`, `pubspec.yaml`, `test/`).
2. **Check Git Status:** Inspect recent commits and uncommitted changes using local Git/MCP.
3. **Assess State:** Determine which phase/component is complete, in progress, or missing.
4. **Report & Await Input:** Provide a 3-bullet summary of current codebase state and ask for the next task or automatically resume the active feature.

# CONTEXT UPDATE: ObsidianFit Master Plan & Workspace State

## Workspace Status
- **Repository State:** Clean on `main` branch at commit `155a1b2`.
- **Test Suite:** 51/51 unit tests passing (`flutter test`).
- **Static Analysis:** Clean (`flutter analyze`).
- **Supported Platforms:** Android, iOS, and Linux desktop (`flutter create`).
- **Key Services Active:** Flat Markdown & GPX file persistence, Drift SQLite read-cache, background vault re-indexer, MapLibre GL tracking, BLE heart rate scanner, screen wake-lock (`wakelock_plus`), and Syncthing conflict file filtering (`*.sync-conflict-*.md`).

---

## Expanded Master Roadmap (Phases 1–6)

### Phases 1–4: Core Foundation (Completed)
- **Phase 1:** Flat Markdown note storage, FrontMatter codec, Drift SQLite schema, and background re-indexer.
- **Phase 2:** Obsidian dark theme shell, workout logger, haptic rest timer, plate math modal, calendar, and history.
- **Phase 3:** Lossless GPX 1.1 XML recorder/parser, background GPS location service, GATT BLE heart rate scanner, and MapLibre GL map overlay.
- **Phase 4:** Platform configuration (Android permissions manifest, iOS scaffolding, screen wake lock, and Syncthing conflict file filter).

---

### Phase 5: Multi-Discipline Gym Engine & Manual Retro-Logging (Next Execution)
- **Retroactive Manual Logging:**
  - Date & Time selector allowing backdated entries for missed workouts.
  - Manual Gym Logger (batch set input for past workouts).
  - Manual Outdoor Activity Logger (distance, duration, elevation, and optional HR for runs/rides without GPS traces).
  - Calendar integration: tapping past empty days prompts "+ Log Past Session".
- **Calisthenics & Weighted Bodyweight:**
  - Toggle between Bodyweight (`+0 kg`) and Weighted (`+X kg`) load baselines.
  - Isometric hold sets tracked in duration/seconds (planks, L-sits, handstands).
- **Plyometrics & Explosive Sets:**
  - Metrics for box height (`cm`/`in`), contact time (`ms`), or jump counts.
- **Stretching & Mobility:**
  - Duration-based set rows with auto-advancing stretch/rest timers.
  - Pre-built mobility routine markdown plans under `/Plans/`.

---

### Phase 6: Strava-Grade Outdoor Suite & Analytics
- **Splits & Auto-Laps:** 1 km / 1 mi live lap markers and post-activity split breakdown tables.
- **Pace & Elevation Profiles:** Interactive charts rendered alongside MapLibre GPS polylines.
- **Ghost Route Navigation:** Load any existing `.gpx` file as a ghost overlay trace to follow pre-planned trails.
- **Multi-Sport Dashboard & PRs:** Aggregated weekly stats (volume, distance, stretch time) and all-time record detection.
