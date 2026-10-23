/// Pure activity maths (no Flutter, no plugins) so it can be unit tested:
/// Haversine distance, noise-filtered elevation gain, heart-rate TSS estimate,
/// pace formatting, and the BLE Heart Rate Measurement parser.
library;

import 'dart:math' as math;

const double kEarthRadiusM = 6371008.8;

/// Great-circle distance in metres between two WGS84 coordinates.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * kEarthRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Incremental elevation gain with hysteresis. Raw GPS altitude jitters by a
/// few metres, so a change only counts once it moves [thresholdM] away from
/// the last accepted reference altitude.
class ElevationGain {
  ElevationGain({this.thresholdM = 3});

  final double thresholdM;
  double _gain = 0;
  double? _ref;

  double get gainM => _gain;

  void add(double elevationM) {
    final ref = _ref;
    if (ref == null) {
      _ref = elevationM;
      return;
    }
    final diff = elevationM - ref;
    if (diff >= thresholdM) {
      _gain += diff;
      _ref = elevationM;
    } else if (-diff >= thresholdM) {
      _ref = elevationM;
    }
  }
}

/// Heart-rate thresholds. Mirrors `user_profile` in `schemas/config_schema.json`.
/// TODO: load from the vault config once config parsing exists.
class HrProfile {
  const HrProfile({this.lthr = 168, this.maxHr = 192, this.restHr = 58});

  final int lthr;
  final int maxHr;
  final int restHr;

  static const HrProfile defaults = HrProfile();
}

/// Heart-rate based Training Stress Score: `hours x IF^2 x 100`, where
/// IF = avgHr / LTHR. Returns null without HR data. This is an estimate; a
/// full-hour effort at threshold scores 100.
int? estimateTss({
  required Duration duration,
  required int? avgHr,
  HrProfile profile = HrProfile.defaults,
}) {
  if (avgHr == null || avgHr <= 0 || profile.lthr <= 0) return null;
  final hours = duration.inMilliseconds / Duration.millisecondsPerHour;
  final intensity = avgHr / profile.lthr;
  return (hours * intensity * intensity * 100).round();
}

/// Seconds per km -> `m:ss`. Null for non-finite or non-positive input.
String? formatPace(double? secPerKm) {
  if (secPerKm == null || !secPerKm.isFinite || secPerKm <= 0) return null;
  final total = secPerKm.round();
  final s = (total % 60).toString().padLeft(2, '0');
  return '${total ~/ 60}:$s';
}

/// `h:mm:ss` once past an hour, otherwise `m:ss`.
String formatDuration(Duration d) {
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s';
  }
  return '${d.inMinutes}:$s';
}

/// Parses a BLE Heart Rate Measurement characteristic (`0x2A37`).
/// Flags bit 0: 0 = uint8 BPM at byte 1, 1 = uint16 little-endian at bytes 1-2.
/// Returns null for malformed packets.
int? parseHeartRateMeasurement(List<int> data) {
  if (data.length < 2) return null;
  final is16Bit = (data[0] & 0x01) != 0;
  if (is16Bit) {
    if (data.length < 3) return null;
    return data[1] | (data[2] << 8);
  }
  return data[1];
}
