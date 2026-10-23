/// Screen wake-lock helper. Keeps the display on while a workout or GPS
/// activity screen is open.
///
/// Failures are swallowed on purpose: a platform without wake-lock support
/// (or a unit test without plugins) must never break logging.
library;

import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenAwake {
  const ScreenAwake._();

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
