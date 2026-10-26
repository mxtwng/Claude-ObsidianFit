<div align="center">

# ObsidianFit

**Your fitness, your files.**

A local-first fitness tracker that brings a friendly interface to your own Markdown and GPX files—so your workout and activity history stays readable, portable, and under your control.

![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![Current test targets](https://img.shields.io/badge/Test%20targets-Android%20%7C%20Linux-lightgrey)

</div>

## What is ObsidianFit?

ObsidianFit helps you log workouts and activities without locking your history inside a proprietary fitness platform. Your records are stored as ordinary files that you can inspect, back up, sync, and use with tools such as [Obsidian](https://obsidian.md).

The app uses a local database to make calendars, history, and summaries faster. That database is a rebuildable index: your Markdown and GPX files are the durable records.

## What you can track

### Strength training
- Log workouts as exercises and sets.
- Record reps, external or bodyweight-based load, and timed holds.
- Track optional effort ratings and selected plyometric details.
- Use a rest timer and plate-loading calculator.
- Enter a workout after the fact without triggering the live rest timer.

### Outdoor activities
- Record GPS routes and save them as GPX files.
- Review routes, distance, pace/splits, and elevation profiles.
- Connect a compatible Bluetooth Low Energy heart-rate monitor.
- Pause and resume a recording, with route segments preserved.
- Use background recording where the platform and device permit it.

### Other activities
- Manually log activities such as walking, running, Taekwondo, boxing, yoga, stretching, and mobility work.
- Add duration and optionally include distance, elevation, heart rate, effort, or notes.
- Record past activities without starting GPS tracking.

*Note: a live elapsed timer for non-GPS activities is planned but is not yet available in the current baseline.*

### Review your progress
- Browse sessions in a calendar and history list.
- Review monthly totals and weekly multi-sport summaries.
- Track selected personal records, including strength and running milestones.

## Your data stays portable

ObsidianFit is designed around files you own:

- **Markdown** stores workout and activity records.
- **GPX** stores GPS tracks.
- **SQLite** is only a local, rebuildable index for faster browsing.
- **Sync is your choice.** Use your preferred backup or file-sync tool, such as Syncthing. Avoid editing the same note in multiple places simultaneously to reduce sync conflicts.

A typical vault looks like this:

```text
ObsidianFit/
├── Workouts/
├── Activities/
├── Tracks/
└── Plans/
```

You can open the vault in a text editor or Obsidian. The app is not a cloud service, and it does not require a proprietary account to store your fitness history.

## Screenshots

Screenshots will be added as the user interface settles. The current interface and product direction are still being refined.

## Getting started

### Current test targets

- **Android** — the primary mobile target; GPS, background recording, Bluetooth, and permissions should be checked on a real device.
- **Linux desktop** — available for desktop use and development.
- **iOS** — not currently validated; configuration and device testing are deferred.

### Requirements

Install a compatible [Flutter SDK](https://docs.flutter.dev/get-started/install) and the platform tools for the device or desktop you want to run.

Clone the repository and fetch dependencies:

```bash
git clone https://github.com/mxtwng/Claude-ObsidianFit.git
cd Claude-ObsidianFit
flutter pub get
```

Run on Linux desktop:

```bash
flutter run -d linux
```

Run on a connected Android device:

```bash
flutter run
```

This project is actively being refined. Features that depend on GPS, Bluetooth, background execution, or device permissions may behave differently across devices; automated tests alone do not guarantee that hardware behavior has been verified.

## Project status

ObsidianFit has working foundations for strength workouts, manual activity logging, GPS activity recording, calendar/history, and summaries. The product is still evolving, especially around activity-first navigation and planning that works across different kinds of exercise.

## For contributors

If you want to work on the code, start with the [contributor and repository instructions](CLAUDE.md), then use the [documentation index](docs/README.md) to find the engineering context, implementation plan, platform guidance, and outstanding audit tasks.

## License

MIT. See [LICENSE](LICENSE).
