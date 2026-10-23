import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_fit/services/gpx_service.dart';
import 'package:xml/xml.dart';

const String _gpxNs = 'http://www.topografix.com/GPX/1/1';
const String _tpxNs = 'http://www.garmin.com/xmlschemas/TrackPointExtension/v1';

TrackPoint _pt(
  double lat,
  double lon, {
  int minute = 0,
  int second = 0,
  double? ele,
  int? hr,
}) {
  return TrackPoint(
    lat: lat,
    lon: lon,
    time: DateTime.utc(2026, 10, 22, 10, minute, second),
    ele: ele,
    hr: hr,
  );
}

List<String> _childNames(XmlElement e) =>
    [for (final c in e.childElements) c.name.local];

void main() {
  group('GpxService.render: GPX 1.1 structure', () {
    final segments = [
      [
        _pt(10.7769, 106.7009, second: 0, ele: 12.5, hr: 120),
        _pt(10.7771, 106.7012, second: 5, ele: 13.0, hr: 124),
      ],
    ];

    test('starts with an XML declaration and parses as well-formed XML', () {
      final xml = GpxService.render(segments);
      expect(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), isTrue);
      expect(() => XmlDocument.parse(xml), returnsNormally);
    });

    test('root is <gpx version="1.1"> in the GPX and Garmin namespaces', () {
      final root = XmlDocument.parse(GpxService.render(segments)).rootElement;
      expect(root.name.local, 'gpx');
      expect(root.getAttribute('version'), '1.1');
      expect(root.getAttribute('creator'), 'ObsidianFit');
      expect(root.namespaceUriUri, _gpxNs);
      expect(root.getAttribute('xmlns:gpxtpx'), _tpxNs);
    });

    test('creator can be overridden', () {
      final root = XmlDocument.parse(
        GpxService.render(segments, creator: 'Test & Co'),
      ).rootElement;
      expect(root.getAttribute('creator'), 'Test & Co');
    });

    test('<metadata> precedes <trk> and carries name and first point time', () {
      final root = XmlDocument.parse(
        GpxService.render(segments, name: 'Morning Run'),
      ).rootElement;
      expect(_childNames(root), ['metadata', 'trk']);
      final meta = root.getElement('metadata')!;
      expect(meta.getElement('name')!.innerText, 'Morning Run');
      expect(meta.getElement('time')!.innerText, '2026-10-22T10:00:00.000Z');
      expect(
          root.getElement('trk')!.getElement('name')!.innerText, 'Morning Run');
    });

    test('metadata has no <time> when there are no points', () {
      final root = XmlDocument.parse(GpxService.render(const [])).rootElement;
      expect(root.getElement('metadata')!.getElement('time'), isNull);
      expect(root.findAllElements('trkseg'), isEmpty);
    });

    test('writes one <trkpt> with lat/lon attributes per point', () {
      final doc = XmlDocument.parse(GpxService.render(segments));
      final pts = doc.findAllElements('trkpt').toList();
      expect(pts, hasLength(2));
      expect(pts.first.getAttribute('lat'), '10.7769');
      expect(pts.first.getAttribute('lon'), '106.7009');
      expect(pts.last.getAttribute('lat'), '10.7771');
    });

    test('trkpt children follow the GPX 1.1 order: ele, time, extensions', () {
      final pt = XmlDocument.parse(GpxService.render(segments))
          .findAllElements('trkpt')
          .first;
      expect(_childNames(pt), ['ele', 'time', 'extensions']);
      expect(pt.getElement('ele')!.innerText, '12.5');
      expect(pt.getElement('time')!.innerText, '2026-10-22T10:00:00.000Z');
    });

    test('times are always written in UTC (Z suffix)', () {
      final local = TrackPoint(
        lat: 1,
        lon: 2,
        time: DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal(),
      );
      final xml = GpxService.render([
        [local],
      ]);
      final time = XmlDocument.parse(xml)
          .findAllElements('time')
          .map((e) => e.innerText)
          .toList();
      expect(time, everyElement(endsWith('Z')));
    });
  });

  group('GpxService.render: TrackPointExtension', () {
    test('heart rate is <gpxtpx:hr> inside TrackPointExtension', () {
      final doc = XmlDocument.parse(
        GpxService.render([
          [_pt(1, 2, hr: 151)],
        ]),
      );
      final hr = doc.findAllElements('hr', namespace: _tpxNs).single;
      expect(hr.innerText, '151');
      expect(hr.name.prefix, 'gpxtpx');
      expect(hr.parentElement!.name.local, 'TrackPointExtension');
      expect(hr.parentElement!.namespaceUriUri, _tpxNs);
      expect(hr.parentElement!.parentElement!.name.local, 'extensions');
    });

    test('points without hr or ele omit those tags entirely', () {
      final pt = XmlDocument.parse(
        GpxService.render([
          [_pt(1, 2)],
        ]),
      ).findAllElements('trkpt').single;
      expect(_childNames(pt), ['time']);
    });

    test('hr is per point: only points that have it get an extension', () {
      final doc = XmlDocument.parse(
        GpxService.render([
          [_pt(1, 2, hr: 100), _pt(1, 2.1, second: 1), _pt(1, 2.2, hr: 102)],
        ]),
      );
      final pts = doc.findAllElements('trkpt').toList();
      expect(pts[0].getElement('extensions'), isNotNull);
      expect(pts[1].getElement('extensions'), isNull);
      expect(pts[2].getElement('extensions'), isNotNull);
    });
  });

  group('GpxService.render: segments', () {
    test('each non-empty segment becomes its own <trkseg>', () {
      final doc = XmlDocument.parse(
        GpxService.render([
          [_pt(1, 2), _pt(1, 2.1, second: 1)],
          [_pt(3, 4, minute: 5)],
        ]),
      );
      final segs = doc.findAllElements('trkseg').toList();
      expect(segs, hasLength(2));
      expect(segs[0].findElements('trkpt'), hasLength(2));
      expect(segs[1].findElements('trkpt'), hasLength(1));
    });

    test('empty segments are skipped', () {
      final doc = XmlDocument.parse(
        GpxService.render([
          <TrackPoint>[],
          [_pt(1, 2)],
          <TrackPoint>[],
        ]),
      );
      expect(doc.findAllElements('trkseg'), hasLength(1));
    });

    test('metadata time comes from the first non-empty segment', () {
      final doc = XmlDocument.parse(
        GpxService.render([
          <TrackPoint>[],
          [_pt(1, 2, minute: 7)],
        ]),
      );
      expect(
        doc.rootElement.getElement('metadata')!.getElement('time')!.innerText,
        '2026-10-22T10:07:00.000Z',
      );
    });
  });

  group('GpxService.render: escaping and number format', () {
    test('XML special characters in the name are escaped and survive', () {
      const name = 'Tom & Jerry <fast> "run"';
      final xml = GpxService.render(
        [
          [_pt(1, 2)],
        ],
        name: name,
      );
      expect(xml, contains('Tom &amp; Jerry &lt;fast&gt; &quot;run&quot;'));
      expect(GpxService.parse(xml).name, name);
    });

    test('tiny values never use exponent notation (invalid XSD decimal)', () {
      final xml = GpxService.render([
        [_pt(1e-7, -2e-8, ele: 5e-9)],
      ]);
      expect(xml, isNot(contains('e-')));
      final pt = XmlDocument.parse(xml).findAllElements('trkpt').single;
      expect(double.parse(pt.getAttribute('lat')!), closeTo(1e-7, 1e-12));
      expect(double.parse(pt.getAttribute('lon')!), closeTo(-2e-8, 1e-12));
    });
  });

  group('GpxService.parse', () {
    test('round trip: parse(render(x)) preserves every point exactly', () {
      final original = [
        [
          _pt(10.776889, 106.700806, second: 0, ele: 8.2, hr: 118),
          _pt(10.777012, 106.700911, second: 4, ele: 8.9, hr: 121),
          _pt(10.777150, 106.701020, second: 9),
        ],
        [
          _pt(10.78, 106.71, minute: 20, ele: -3.5, hr: 140),
        ],
      ];
      final track = GpxService.parse(
        GpxService.render(original, name: 'Round trip'),
      );
      expect(track.name, 'Round trip');
      expect(track.segments, original);
      expect(track.pointCount, 4);
      expect(track.isEmpty, isFalse);
    });

    test('reads heart rate by local name, so any namespace prefix works', () {
      const source = '''<?xml version="1.0"?>
<gpx version="1.1" creator="Garmin"
  xmlns="http://www.topografix.com/GPX/1/1"
  xmlns:ns3="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">
  <trk><name>Garmin Run</name><trkseg>
    <trkpt lat="1.5" lon="2.5"><ele>10</ele>
      <time>2026-10-22T10:00:00Z</time>
      <extensions><ns3:TrackPointExtension><ns3:hr>133</ns3:hr><ns3:cad>80</ns3:cad></ns3:TrackPointExtension></extensions>
    </trkpt>
  </trkseg></trk>
</gpx>''';
      final track = GpxService.parse(source);
      expect(track.name, 'Garmin Run');
      final p = track.segments.single.single;
      expect(p.lat, 1.5);
      expect(p.lon, 2.5);
      expect(p.ele, 10);
      expect(p.hr, 133);
      expect(p.time, DateTime.utc(2026, 10, 22, 10));
    });

    test('converts offset timestamps to UTC', () {
      const source =
          '''<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
<trk><trkseg><trkpt lat="1" lon="2"><time>2026-10-22T17:30:00+07:00</time></trkpt></trkseg></trk>
</gpx>''';
      final p = GpxService.parse(source).segments.single.single;
      expect(p.time.isUtc, isTrue);
      expect(p.time, DateTime.utc(2026, 10, 22, 10, 30));
    });

    test('missing time falls back to the Unix epoch; ele and hr stay null', () {
      const source =
          '''<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
<trk><trkseg><trkpt lat="1" lon="2"/></trkseg></trk></gpx>''';
      final p = GpxService.parse(source).segments.single.single;
      expect(p.time, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
      expect(p.ele, isNull);
      expect(p.hr, isNull);
    });

    test('skips points with missing or non-numeric coordinates', () {
      const source =
          '''<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
<trk><trkseg>
  <trkpt lat="abc" lon="2"/>
  <trkpt lon="2"/>
  <trkpt lat="1" lon="2"/>
</trkseg></trk></gpx>''';
      expect(GpxService.parse(source).pointCount, 1);
    });

    test('drops segments that end up with no points', () {
      const source =
          '''<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
<trk><trkseg/><trkseg><trkpt lat="1" lon="2"/></trkseg></trk></gpx>''';
      expect(GpxService.parse(source).segments, hasLength(1));
    });

    test('name falls back to <metadata><name> when <trk> has none', () {
      const source =
          '''<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
<metadata><name>From metadata</name></metadata>
<trk><trkseg><trkpt lat="1" lon="2"/></trkseg></trk></gpx>''';
      expect(GpxService.parse(source).name, 'From metadata');
    });

    test('a GPX with no track yields an empty GpxTrack', () {
      const source =
          '<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1"/>';
      final track = GpxService.parse(source);
      expect(track.isEmpty, isTrue);
      expect(track.name, '');
      expect(track.segments, isEmpty);
    });

    test('malformed XML throws XmlException', () {
      expect(
        () => GpxService.parse('<gpx><trk></gpx>'),
        throwsA(isA<XmlException>()),
      );
    });
  });

  group('GpxTrack', () {
    test('polylines gives [lat, lon] pairs per segment', () {
      final track = GpxTrack(
        segments: [
          [_pt(1, 2), _pt(3, 4, second: 1)],
          [_pt(5, 6, minute: 1)],
        ],
      );
      expect(track.polylines, [
        [
          [1.0, 2.0],
          [3.0, 4.0],
        ],
        [
          [5.0, 6.0],
        ],
      ]);
      expect(track.pointCount, 3);
    });

    test('default track is empty', () {
      const track = GpxTrack();
      expect(track.isEmpty, isTrue);
      expect(track.pointCount, 0);
      expect(track.polylines, isEmpty);
    });
  });

  group('GpxService.fileNameFor', () {
    test('matches the vault naming used by gpx_file wikilinks', () {
      expect(
        GpxService.fileNameFor(DateTime(2026, 10, 22, 17, 30)),
        '2026-10-22_1730_Route.gpx',
      );
    });

    test('zero-pads month, day, hour and minute', () {
      expect(
        GpxService.fileNameFor(DateTime(2026, 1, 2, 3, 4)),
        '2026-01-02_0304_Route.gpx',
      );
    });
  });

  group('TrackPoint', () {
    test('value equality and hashCode cover every field', () {
      final a = _pt(1, 2, ele: 3, hr: 4);
      final b = _pt(1, 2, ele: 3, hr: 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_pt(1, 2, ele: 3, hr: 5)));
      expect(a, isNot(_pt(1, 2, ele: 9, hr: 4)));
      expect(a, isNot(_pt(1, 2.5, ele: 3, hr: 4)));
    });
  });
}
