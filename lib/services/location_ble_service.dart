/// Outdoor recording stack: background keep-alive, BLE heart-rate monitor,
/// and the GPS recorder that turns position + HR samples into session metrics.
///
/// Background strategy
///  * Android: `flutter_background_service` runs a foreground service
///    (location + connectedDevice types) with an ongoing notification. That
///    keeps the whole app process alive, so GPS and BLE keep running in the
///    main isolate while the screen is locked. The service isolate itself only
///    mirrors stats into the notification; it does no tracking.
///  * iOS: the `location` background mode (via `AppleSettings`) and the
///    `bluetooth-central` mode keep the app running; the Dart background
///    service is not what keeps iOS alive.
///
/// See `docs/platform/README.md` for platform manifest / Info.plist guidance.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'activity_metrics.dart';
import 'gpx_service.dart';

// =============================================================================
// Background keep-alive
// =============================================================================

@pragma('vm:entry-point')
void backgroundServiceOnStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  service.on('stop').listen((_) => service.stopSelf());
  service.on('update').listen((event) {
    if (service is AndroidServiceInstance && event != null) {
      service.setForegroundNotificationInfo(
        title: (event['title'] as String?) ?? 'ObsidianFit',
        content: (event['content'] as String?) ?? '',
      );
    }
  });
}

@pragma('vm:entry-point')
Future<bool> backgroundServiceOnIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

class BackgroundKeepAlive {
  const BackgroundKeepAlive._();

  static const String channelId = 'obsidianfit_recording';
  static const int notificationId = 4242;
  static bool _configured = false;

  /// Creates the notification channel and configures the service. Idempotent;
  /// call once before the first recording (does not start the service).
  static Future<void> initialize() async {
    if (_configured) return;
    if (Platform.isAndroid) {
      // The channel must exist before the foreground service posts to it.
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              'Activity recording',
              description: 'Shown while an activity is being recorded.',
              importance: Importance.low,
            ),
          );
    }
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'ObsidianFit',
        initialNotificationContent: 'Recording activity',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [
          AndroidForegroundType.location,
          AndroidForegroundType.connectedDevice,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceOnStart,
        onBackground: backgroundServiceOnIosBackground,
      ),
    );
    _configured = true;
  }

  static Future<void> start() async {
    await initialize();
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) await service.startService();
  }

  static void update({required String title, required String content}) {
    FlutterBackgroundService()
        .invoke('update', {'title': title, 'content': content});
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) service.invoke('stop');
  }
}

// =============================================================================
// BLE heart-rate monitor (GATT Heart Rate Service 0x180D)
// =============================================================================

enum HrConnectionState { disconnected, connecting, connected, reconnecting }

class HeartRateMonitor extends ChangeNotifier {
  static final Guid heartRateService = Guid('180D');
  static final Guid heartRateMeasurement = Guid('2A37');

  /// A reading older than this is treated as "no signal".
  static const Duration staleAfter = Duration(seconds: 5);

  HrConnectionState _state = HrConnectionState.disconnected;
  BluetoothDevice? _device;
  bool _wanted = false;
  int _attempt = 0;
  Timer? _reconnectTimer;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _valueSub;
  final StreamController<int> _bpm = StreamController<int>.broadcast();
  int? _latestBpm;
  DateTime? _latestAt;
  bool _disposed = false;

  HrConnectionState get state => _state;
  BluetoothDevice? get device => _device;

  String get deviceName {
    final n = _device?.platformName ?? '';
    return n.isEmpty ? 'Heart rate monitor' : n;
  }

  /// Live BPM readings (broadcast).
  Stream<int> get bpm => _bpm.stream;

  /// Last reading if it is recent enough, else null.
  int? get freshBpm {
    final at = _latestAt;
    if (at == null || DateTime.now().difference(at) > staleAfter) return null;
    return _latestBpm;
  }

  // ---- scanning -------------------------------------------------------------

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  /// Scans for devices advertising 0x180D. Returns an error message, or null.
  Future<String?> startScan({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (Platform.isAndroid) {
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      if (!scan.isGranted || !connect.isGranted) {
        return 'Bluetooth permission is required to find heart rate monitors.';
      }
    }
    if (!await FlutterBluePlus.isSupported) {
      return 'Bluetooth LE is not supported on this device.';
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {
          return 'Turn Bluetooth on to find heart rate monitors.';
        }
      } else {
        return 'Turn Bluetooth on to find heart rate monitors.';
      }
    }
    await FlutterBluePlus.startScan(
      withServices: [heartRateService],
      timeout: timeout,
    );
    return null;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // ---- connection (with auto-reconnect) --------------------------------------

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;
    _wanted = true;
    _attempt = 0;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _connSub = device.connectionState.listen(_onConnectionState);
    await _connectOnce();
  }

  /// Stops reconnecting and drops the link.
  Future<void> disconnect() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _valueSub?.cancel();
    _valueSub = null;
    await _connSub?.cancel();
    _connSub = null;
    final device = _device;
    _device = null;
    _latestBpm = null;
    _latestAt = null;
    try {
      await device?.disconnect();
    } catch (_) {}
    _setState(HrConnectionState.disconnected);
  }

  Future<void> _connectOnce() async {
    final device = _device;
    if (device == null || !_wanted) return;
    _setState(
      _attempt == 0
          ? HrConnectionState.connecting
          : HrConnectionState.reconnecting,
    );
    try {
      // flutter_blue_plus 2.x requires an explicit license. `free` covers
      // individuals, non-profits and small orgs; ObsidianFit is free and
      // open source. Revisit if the project is ever used commercially.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      await _subscribe(device);
      _attempt = 0;
    } on _NotAHeartRateMonitor {
      // Wrong kind of device: do not retry.
      await disconnect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> _subscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    BluetoothCharacteristic? characteristic;
    for (final s in services) {
      if (s.uuid != heartRateService) continue;
      for (final c in s.characteristics) {
        if (c.uuid == heartRateMeasurement) characteristic = c;
      }
    }
    if (characteristic == null) throw _NotAHeartRateMonitor();

    await _valueSub?.cancel();
    final sub = characteristic.onValueReceived.listen(_onData);
    _valueSub = sub;
    device.cancelWhenDisconnected(sub);
    await characteristic.setNotifyValue(true);
    _setState(HrConnectionState.connected);
  }

  void _onData(List<int> data) {
    final value = parseHeartRateMeasurement(data);
    if (value == null || value <= 0) return;
    _latestBpm = value;
    _latestAt = DateTime.now();
    if (!_bpm.isClosed) _bpm.add(value);
    if (!_disposed) notifyListeners();
  }

  void _onConnectionState(BluetoothConnectionState s) {
    if (s == BluetoothConnectionState.disconnected && _wanted) {
      _scheduleReconnect();
    }
  }

  /// Exponential backoff: 2, 4, 8, then every 15 s, until [disconnect].
  void _scheduleReconnect() {
    if (!_wanted || _disposed) return;
    _reconnectTimer?.cancel();
    _setState(HrConnectionState.reconnecting);
    final seconds = math.min(1 << (_attempt + 1), 15);
    _attempt = math.min(_attempt + 1, 10);
    _reconnectTimer = Timer(Duration(seconds: seconds), _connectOnce);
  }

  void _setState(HrConnectionState s) {
    if (_state == s) return;
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    _bpm.close();
    super.dispose();
  }
}

class _NotAHeartRateMonitor implements Exception {}

// =============================================================================
// Activity recorder
// =============================================================================

enum RecorderState { idle, recording, paused, stopped }

/// Final result of a recording, ready to be written to the vault.
class RecordedActivity {
  const RecordedActivity({
    required this.startedAt,
    required this.endedAt,
    required this.activeDuration,
    required this.segments,
    required this.distanceM,
    required this.elevationGainM,
    required this.avgHr,
    required this.maxHr,
    required this.tss,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  /// Time spent recording, excluding pauses.
  final Duration activeDuration;
  final List<List<TrackPoint>> segments;
  final double distanceM;
  final double elevationGainM;
  final int? avgHr;
  final int? maxHr;
  final int? tss;

  double get distanceKm => distanceM / 1000;
  int get pointCount => segments.fold(0, (n, s) => n + s.length);
  bool get hasTrack => pointCount > 0;

  String? get avgPaceMinKm =>
      formatPace(distanceM > 0 ? activeDuration.inSeconds / distanceKm : null);
}

class ActivityRecorder extends ChangeNotifier {
  ActivityRecorder({
    required this.heartRate,
    this.profile = HrProfile.defaults,
  });

  final HeartRateMonitor heartRate;
  final HrProfile profile;

  /// Fixes worse than this (metres) are ignored.
  static const double maxAccuracyM = 30;

  /// Steps shorter than this (metres) are treated as GPS jitter.
  static const double minStepM = 1;

  RecorderState _state = RecorderState.idle;
  final List<List<TrackPoint>> _segments = [];
  final ElevationGain _gain = ElevationGain();
  DateTime? _startedAt;
  Duration _accum = Duration.zero;
  DateTime? _clockStart;
  double _distanceM = 0;
  int _hrSum = 0;
  int _hrCount = 0;
  int _hrMax = 0;
  Position? _lastPosition;
  StreamSubscription<Position>? _posSub;
  Timer? _ticker;
  int _tickCount = 0;
  bool _disposed = false;

  // ---- read-only state --------------------------------------------------------

  RecorderState get state => _state;
  List<List<TrackPoint>> get segments => _segments;
  Position? get lastPosition => _lastPosition;
  double get distanceM => _distanceM;
  double get elevationGainM => _gain.gainM;
  int? get currentHr => heartRate.freshBpm;
  int? get avgHr => _hrCount == 0 ? null : (_hrSum / _hrCount).round();
  int? get maxHr => _hrCount == 0 ? null : _hrMax;
  int get pointCount => _segments.fold(0, (n, s) => n + s.length);

  Duration get elapsed =>
      _accum +
      (_state == RecorderState.recording && _clockStart != null
          ? DateTime.now().difference(_clockStart!)
          : Duration.zero);

  /// Average pace over the whole recording, seconds per km.
  double? get avgPaceSecPerKm =>
      _distanceM < 10 ? null : elapsed.inSeconds / (_distanceM / 1000);

  // ---- permissions ------------------------------------------------------------

  /// Asks for location (and notification, which Android 13+ needs for the
  /// foreground-service notification). Returns an error message, or null.
  static Future<String?> requestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location services are turned off.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Location permission is required to record an activity.';
    }
    if (Platform.isAndroid) {
      // Not fatal: recording still works, only the notification is hidden.
      await Permission.notification.request();
    }
    return null;
  }

  // ---- controls ---------------------------------------------------------------

  /// Starts recording. Returns an error message, or null on success.
  Future<String?> start() async {
    if (_state != RecorderState.idle) return null;
    final error = await requestPermissions();
    if (error != null) return error;

    await BackgroundKeepAlive.start();
    _startedAt = DateTime.now();
    _segments.add(<TrackPoint>[]);
    _clockStart = DateTime.now();
    _state = RecorderState.recording;
    _posSub = Geolocator.getPositionStream(locationSettings: _settings())
        .listen(_onPosition, onError: (Object _) {});
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _publishNotification();
    _notify();
    return null;
  }

  void pause() {
    if (_state != RecorderState.recording) return;
    _accum = elapsed;
    _clockStart = null;
    _state = RecorderState.paused;
    _publishNotification();
    _notify();
  }

  void resume() {
    if (_state != RecorderState.paused) return;
    // New segment: the gap while paused is never counted as distance.
    _segments.add(<TrackPoint>[]);
    _clockStart = DateTime.now();
    _state = RecorderState.recording;
    _publishNotification();
    _notify();
  }

  /// Ends the recording and returns the result. Safe from recording or paused.
  Future<RecordedActivity?> stop() async {
    if (_state != RecorderState.recording && _state != RecorderState.paused) {
      return null;
    }
    final active = elapsed;
    _clockStart = null;
    _accum = active;
    _state = RecorderState.stopped;
    await _teardown();

    final segments = [
      for (final s in _segments)
        if (s.isNotEmpty) List<TrackPoint>.unmodifiable(s),
    ];
    final average = avgHr;
    _notify();
    return RecordedActivity(
      startedAt: _startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      activeDuration: active,
      segments: segments,
      distanceM: _distanceM,
      elevationGainM: _gain.gainM,
      avgHr: average,
      maxHr: maxHr,
      tss: estimateTss(duration: active, avgHr: average, profile: profile),
    );
  }

  /// Abandons the recording without producing a result.
  Future<void> discard() async {
    await _teardown();
    _state = RecorderState.idle;
    _segments.clear();
    _accum = Duration.zero;
    _clockStart = null;
    _distanceM = 0;
    _hrSum = _hrCount = _hrMax = 0;
    _notify();
  }

  // ---- internals ----------------------------------------------------------------

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      // No foregroundNotificationConfig: flutter_background_service already
      // owns the foreground-service notification.
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    );
  }

  void _onPosition(Position pos) {
    _lastPosition = pos; // drives the map even while paused
    if (_state == RecorderState.recording && pos.accuracy <= maxAccuracyM) {
      final segment = _segments.last;
      final point = TrackPoint(
        lat: pos.latitude,
        lon: pos.longitude,
        ele: pos.altitude,
        time: DateTime.now().toUtc(),
        hr: heartRate.freshBpm,
      );
      var accept = true;
      if (segment.isNotEmpty) {
        final prev = segment.last;
        final step = haversineMeters(prev.lat, prev.lon, point.lat, point.lon);
        if (step < minStepM) {
          accept = false;
        } else {
          _distanceM += step;
        }
      }
      if (accept) {
        segment.add(point);
        _gain.add(pos.altitude);
      }
    }
    _notify();
  }

  void _tick() {
    _tickCount++;
    if (_state == RecorderState.recording) {
      // 1 Hz HR sampling gives a time-weighted average, independent of GPS.
      final hr = heartRate.freshBpm;
      if (hr != null) {
        _hrSum += hr;
        _hrCount++;
        if (hr > _hrMax) _hrMax = hr;
      }
      if (_tickCount % 5 == 0) _publishNotification();
    }
    _notify();
  }

  void _publishNotification() {
    final km = (_distanceM / 1000).toStringAsFixed(2);
    final hr = currentHr;
    final stateLabel = _state == RecorderState.paused ? 'Paused' : 'Recording';
    BackgroundKeepAlive.update(
      title: '$stateLabel · ${formatDuration(elapsed)}',
      content: '$km km${hr == null ? '' : ' · $hr bpm'}',
    );
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    await _posSub?.cancel();
    _posSub = null;
    await BackgroundKeepAlive.stop();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    super.dispose();
  }
}
