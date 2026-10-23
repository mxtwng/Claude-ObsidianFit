# Platform setup (Phase 3 / 4)

Everything the recording stack needs outside Dart code: Android and iOS
permissions, the Syncthing vault layout, and how to test on a device.

> **First-time setup.** This repo does not contain `android/` or `ios/` yet.
> Generate them once; `flutter create` never overwrites existing files such as
> `lib/` or `pubspec.yaml`:
>
> ```bash
> flutter create --platforms=android,ios --project-name obsidian_fit .
> flutter pub get
> git status   # confirm lib/ and pubspec.yaml are untouched
> ```
>
> Then apply the Android manifest and iOS plist entries below.

## 1. Android

Apply the ready-made manifest:

```bash
cp docs/platform/AndroidManifest.reference.xml \
   android/app/src/main/AndroidManifest.xml
```

It is commented line by line. Summary of what it declares and why:

| Permission | Why |
|---|---|
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | GPS track (`geolocator`). |
| `ACCESS_BACKGROUND_LOCATION` | Requested per the project brief. Usually unnecessary: a location foreground service started while the app is visible keeps getting fixes. Drop it if you target Google Play. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Keeps the process alive while recording. |
| `FOREGROUND_SERVICE_CONNECTED_DEVICE` | **Not in the original list, but required.** `BackgroundKeepAlive` declares `AndroidForegroundType.connectedDevice`; on Android 14+ a type without its permission makes `startForeground()` throw. |
| `POST_NOTIFICATIONS` | Android 13+: shows the ongoing "Recording" notification. |
| `BLUETOOTH`, `BLUETOOTH_ADMIN` (`maxSdkVersion=30`) | Legacy BLE for Android 11 and lower. |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT` | BLE heart-rate strap on Android 12+. |
| `MANAGE_EXTERNAL_STORAGE` | Writing the vault to `/storage/emulated/0/Documents/ObsidianFit` with `dart:io`. |
| `READ/WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=32`) | Older Android versions. |
| `INTERNET` | Only for an online map style. The default style is offline. |

### Android 14+ foreground service types

The type declared in three places must agree:

1. `AndroidConfiguration.foregroundServiceTypes` in
   `lib/services/location_ble_service.dart`: `location`, `connectedDevice`.
2. The `<service ... android:foregroundServiceType="location|connectedDevice">`
   entry in the manifest.
3. One `FOREGROUND_SERVICE_<TYPE>` permission per type.

If you add a type in one place, add it in the other two.

### Runtime prompts

The app asks for these at runtime; the manifest only makes them possible:

* Location (precise), then notifications, when an activity screen opens.
* Nearby devices (Bluetooth) when the heart-rate sheet scans.
* "All files access" on first launch (opens a system settings page). If
  denied, the vault falls back to `<external app dir>/ObsidianFit`, which
  **Syncthing cannot see**.

Some vendors (Xiaomi, Huawei, Samsung, OnePlus) also kill foreground
services aggressively. Disable battery optimisation for ObsidianFit and see
https://dontkillmyapp.com for device-specific steps.

### Build requirements

`wakelock_plus` and the map/BLE plugins need a recent toolchain (Java 17,
current Android Gradle Plugin and Kotlin). If Gradle reports a higher NDK
version, set it in `android/app/build.gradle(.kts)` as the error message says.
`wakelock_plus` itself needs no permissions.

## 2. iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ObsidianFit records your route while you exercise.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ObsidianFit keeps recording your route when the screen is locked.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>ObsidianFit connects to your heart rate monitor.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>bluetooth-central</string>
</array>
<!-- Optional: show Documents/ObsidianFit in the Files app -->
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

Notes:

* iOS keeps the app alive through the `location` background mode (set in code
  via `AppleSettings`) and `bluetooth-central`; the Dart background service is
  not what keeps iOS running.
* The vault lives in the app's Documents directory, not a shared folder. Use
  the Files app or a desktop copy to move it; Syncthing is Android-first.
* Run `cd ios && pod install` after `flutter pub get` if CocoaPods complains.

## 3. Vault layout and Syncthing

```
/storage/emulated/0/Documents/ObsidianFit/
├── Workouts/     2026-10-22_1800_Push_Day_A.md
├── Activities/   2026-10-22_1730_run.md
├── Plans/        Plan_4_Week_Strength_Block.md
└── Tracks/       2026-10-22_1730_Route.gpx
```

* Markdown notes and GPX tracks are the source of truth. SQLite is a
  disposable cache rebuilt on launch and on app resume.
* An activity note links its track with `gpx_file: "[[2026-10-22_1730_Route.gpx]]"`.
  Obsidian resolves that by file name, so the `Tracks/` folder can stay put.
* Share the whole `ObsidianFit` folder with Syncthing and open the same folder
  as an Obsidian vault on desktop.
* Writes are atomic (`<name>.tmp`, then rename). Add a `.stignore` to the
  Syncthing folder so a temp file is never synced mid-write:

  ```
  *.tmp
  ```
* Hidden folders (`.obsidian`, `.stfolder`) are skipped by the re-indexer.
* **Known gap:** Syncthing conflict copies
  (`name.sync-conflict-<date>-<id>.md`) are ordinary `.md` files with valid
  frontmatter, so the re-indexer currently indexes them as extra sessions.
  Resolve or delete conflicts in Syncthing, or add a filter in
  `FilePersistenceService.listMarkdownFiles`.

## 4. Testing

### Automated

```bash
flutter pub get
flutter analyze
flutter test
```

All of these are plain-Dart tests (GPX, round trip, re-indexer, plate math).
The recording UI, BLE, background service and wake lock are not covered by
them and need a real device.

### On a device (Android)

1. `flutter run --release` (debug builds can behave differently with
   background services).
2. Grant location, notifications, Bluetooth and "All files access" when asked.
   To grant storage access from a terminal:
   `adb shell appops set <your.package.id> MANAGE_EXTERNAL_STORAGE allow`
3. **Outdoor activity:** start a run, lock the screen, walk for 10 minutes.
   Check that the "Recording" notification stays, the map follows you, and
   distance keeps counting.
4. **Foreground service type:** while recording, run
   `adb shell dumpsys activity services <your.package.id>` and confirm the
   service is foreground with types `location|connectedDevice`.
5. **Pause / resume:** pause, walk 50 m, resume. The saved GPX should contain
   two `<trkseg>` blocks and the gap must not count as distance.
6. **Heart rate:** connect a strap, then move it out of range and back. The
   sheet should show "reconnecting" and recover on its own.
7. **Wake lock:** the screen must stay on during a workout and from Start to
   Stop in an activity, and sleep normally on the review screen and after
   leaving.
8. **Offline map:** turn on airplane mode (keep GPS on). The dark offline map
   and route line should still draw.
9. **Vault:** after saving, confirm `Tracks/*.gpx` and `Activities/*.md` exist
   and appear on your desktop through Syncthing, and that the session shows up
   in History with its route map.
10. No GPS in an emulator? Use Developer options, then "Select mock location
    app", or the emulator's route playback in Extended controls.
