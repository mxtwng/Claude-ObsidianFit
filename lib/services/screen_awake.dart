/// Screen wake-lock helper. Keeps the display on while a workout or GPS
/// activity screen is open.
///
/// Failures are swallowed on purpose: a platform without wake-lock support
/// (or a unit test without plugins) must never break logging.
library;

import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenAwake {
  const ScreenAwake._();

  static bool _requested = false;

  /// Whether the last call asked for the display to stay on. This is the
  /// requested state, not a read-back from the platform (which may be
  /// unsupported); it lets tests check that a screen releases the lock.
  static bool get isRequested => _requested;

  static Future<void> enable() async {
    _requested = true;
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  static Future<void> disable() async {
    _requested = false;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
