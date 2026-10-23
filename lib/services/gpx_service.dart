/// GPX 1.1 reading and writing (pure Dart, no IO).
///
/// Writes `<trkpt>` with `<ele>`, `<time>` and a Garmin TrackPointExtension
/// `<gpxtpx:hr>` per point. A pause starts a new `<trkseg>`, so the gap between
/// segments is never counted as distance. Numbers are written with Dart's
/// shortest round-trip representation, so parse(render(x)) == x.
library;

import 'package:xml/xml.dart';

class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lon,
    required this.time,
    this.ele,
    this.hr,
  });

  final double lat;
  final double lon;

  /// Stored in UTC.
  final DateTime time;
  final double? ele;
  final int? hr;

  @override
  bool operator ==(Object other) =>
      other is TrackPoint &&
      other.lat == lat &&
      other.lon == lon &&
      other.time == time &&
      other.ele == ele &&
      other.hr == hr;

  @override
  int get hashCode => Object.hash(lat, lon, time, ele, hr);

  @override
  String toString() => 'TrackPoint($lat, $lon, ele: $ele, hr: $hr)';
}

class GpxTrack {
  const GpxTrack({this.name = '', this.segments = const []});

  final String name;

  /// One list per `<trkseg>`; each is a polyline.
  final List<List<TrackPoint>> segments;

  int get pointCount => segments.fold(0, (n, s) => n + s.length);
  bool get isEmpty => pointCount == 0;

  /// `[lat, lon]` pairs per segment, ready for a map polyline.
  List<List<List<double>>> get polylines => [
        for (final seg in segments)
          [
            for (final p in seg) [p.lat, p.lon],
          ],
      ];
}

class GpxService {
  const GpxService._();

  static const String _gpxNs = 'http://www.topografix.com/GPX/1/1';
  static const String _tpxNs =
      'http://www.garmin.com/xmlschemas/TrackPointExtension/v1';

  /// Vault file name for a track: `YYYY-MM-DD_HHMM_Route.gpx`.
  static String fileNameFor(DateTime startedAt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = '${startedAt.year.toString().padLeft(4, '0')}-'
        '${two(startedAt.month)}-${two(startedAt.day)}';
    return '${d}_${two(startedAt.hour)}${two(startedAt.minute)}_Route.gpx';
  }

  // ---- writing --------------------------------------------------------------

  static String render(
    List<List<TrackPoint>> segments, {
    String name = 'Route',
    String creator = 'ObsidianFit',
  }) {
    DateTime? first;
    for (final s in segments) {
      if (s.isNotEmpty) {
        first = s.first.time;
        break;
      }
    }

    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="${_esc(creator)}" '
        'xmlns="$_gpxNs" xmlns:gpxtpx="$_tpxNs">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <name>${_esc(name)}</name>');
    if (first != null) {
      b.writeln('    <time>${first.toUtc().toIso8601String()}</time>');
    }
    b
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>${_esc(name)}</name>');
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      b.writeln('    <trkseg>');
      for (final p in seg) {
        b.write('      <trkpt lat="${_num(p.lat)}" lon="${_num(p.lon)}">');
        if (p.ele != null) b.write('<ele>${_num(p.ele!)}</ele>');
        b.write('<time>${p.time.toUtc().toIso8601String()}</time>');
        if (p.hr != null) {
          b.write(
            '<extensions><gpxtpx:TrackPointExtension>'
            '<gpxtpx:hr>${p.hr}</gpxtpx:hr>'
            '</gpxtpx:TrackPointExtension></extensions>',
          );
        }
        b.writeln('</trkpt>');
      }
      b.writeln('    </trkseg>');
    }
    b
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return b.toString();
  }

  // ---- reading --------------------------------------------------------------

  /// Parses any GPX 1.x document. Heart rate is found by element local name,
  /// so other namespace prefixes (`ns3:hr`) work. Points with missing or bad
  /// coordinates are skipped. Throws [XmlException] for malformed XML.
  static GpxTrack parse(String source) {
    final doc = XmlDocument.parse(source);
    final trk = doc.findAllElements('trk').firstOrNull;
    final name = trk?.getElement('name')?.innerText.trim() ??
        doc.findAllElements('name').firstOrNull?.innerText.trim() ??
        '';

    final segments = <List<TrackPoint>>[];
    for (final seg in doc.findAllElements('trkseg')) {
      final points = <TrackPoint>[];
      for (final pt in seg.findElements('trkpt')) {
        final lat = double.tryParse(pt.getAttribute('lat') ?? '');
        final lon = double.tryParse(pt.getAttribute('lon') ?? '');
        if (lat == null || lon == null) continue;
        final time = DateTime.tryParse(
          pt.getElement('time')?.innerText.trim() ?? '',
        )?.toUtc();
        final ele = double.tryParse(
          pt.getElement('ele')?.innerText.trim() ?? '',
        );
        final hrText = pt.descendantElements
            .where((e) => e.name.local == 'hr')
            .firstOrNull
            ?.innerText
            .trim();
        points.add(
          TrackPoint(
            lat: lat,
            lon: lon,
            time: time ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            ele: ele,
            hr: hrText == null ? null : int.tryParse(hrText),
          ),
        );
      }
      if (points.isNotEmpty) segments.add(points);
    }
    return GpxTrack(name: name, segments: segments);
  }

  // ---- helpers --------------------------------------------------------------

  /// XSD decimals cannot use exponent notation, which `double.toString` emits
  /// for very small values.
  static String _num(double v) {
    final s = v.toString();
    return s.contains('e') || s.contains('E') ? v.toStringAsFixed(10) : s;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
