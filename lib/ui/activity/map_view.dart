/// MapLibre GL map for recording and previews.
///
///  * live: native "my location" dot, follow mode, and a polyline that grows
///    as new points arrive (one line per `<trkseg>`, so pauses leave a gap);
///  * ghost: an optional static reference trace (a saved `.gpx`, see
///    `GhostRoute`) drawn beneath the live line, in a different colour;
///  * static: non-interactive route preview fitted to the track, used by the
///    history session card via [ActivityRouteMap].
///
/// The default style is an inline dark background with no tile source, so it
/// works fully offline and sends no location to any tile server. Swap in
/// [kOpenFreeMapStyle] (online) or a local style referencing your offline
/// `.mbtiles` for real base maps.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../services/gpx_service.dart';
import '../app_services.dart';
import '../theme/app_theme.dart';

const String kOfflineDarkStyle = '{"version":8,"name":"ObsidianFit Dark",'
    '"sources":{},"layers":[{"id":"background","type":"background",'
    '"paint":{"background-color":"#0D0D10"}}]}';

/// Online vector basemap (OpenFreeMap). Requests tiles over the network.
const String kOpenFreeMapStyle = 'https://tiles.openfreemap.org/styles/liberty';

class TrackMapView extends StatefulWidget {
  const TrackMapView({
    super.key,
    this.segments = const [],
    this.showUserLocation = false,
    this.followUser = false,
    this.interactive = true,
    this.fitToTrack = false,
    this.initialTarget,
    this.styleString = kOfflineDarkStyle,
    this.lineColor = '#A78BFA',
    this.ghostSegments = const [],
    this.ghostColor = '#60A5FA',
  });

  /// Track to draw, one polyline per segment. The list may be mutated in
  /// place by the caller; changes are detected by per-segment point counts.
  final List<List<TrackPoint>> segments;

  /// Shows the native location dot (needs location permission).
  final bool showUserLocation;

  /// Keeps the camera on the user. Panning the map cancels it natively.
  final bool followUser;

  /// False disables all gestures (route preview).
  final bool interactive;

  /// Fits the camera to the whole track once it is drawn.
  final bool fitToTrack;

  /// Where the camera starts when there is no track yet.
  final LatLng? initialTarget;
  final String styleString;
  final String lineColor;

  /// Reference ("ghost") trace, one polyline per segment. Treated as
  /// immutable: it is redrawn only when a different list instance is passed,
  /// so keep the same list for as long as the same ghost is shown.
  final List<List<TrackPoint>> ghostSegments;
  final String ghostColor;

  @override
  State<TrackMapView> createState() => _TrackMapViewState();
}

class _TrackMapViewState extends State<TrackMapView> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  bool _syncing = false;
  bool _dirty = false;
  bool _fitted = false;

  /// Lines already on the map, aligned with segment index.
  final List<Line?> _lines = [];
  final List<int> _drawnLengths = [];

  /// Ghost lines on the map and the list instance they were drawn from.
  final List<Line> _ghostLines = [];
  List<List<TrackPoint>>? _ghostDrawn;

  /// Longest ghost polyline sent to the map; longer ones are thinned out.
  static const int _maxGhostPoints = 2000;

  LatLng get _initialTarget {
    for (final s in widget.segments) {
      if (s.isNotEmpty) return LatLng(s.first.lat, s.first.lon);
    }
    return widget.initialTarget ?? const LatLng(0, 0);
  }

  @override
  void didUpdateWidget(TrackMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleLoaded) _sync();
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _sync();
  }

  /// Brings the drawn lines in step with [TrackMapView.segments]. Calls that
  /// arrive mid-sync set a dirty flag and trigger exactly one more pass.
  Future<void> _sync() async {
    final controller = _controller;
    if (controller == null) return;
    if (_syncing) {
      _dirty = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _dirty = false;
        await _syncOnce(controller);
      } while (_dirty && mounted);
    } finally {
      _syncing = false;
    }
  }

  /// Draws [TrackMapView.ghostSegments] when they changed. Runs before the
  /// live lines so the ghost sits underneath. If a ghost appears after the
  /// live line exists, the live lines are dropped here and redrawn by the
  /// normal pass so they end up on top again.
  Future<void> _syncGhost(MapLibreMapController controller) async {
    final wanted = widget.ghostSegments;
    if (identical(_ghostDrawn, wanted)) return;

    for (final line in _ghostLines) {
      await controller.removeLine(line);
    }
    _ghostLines.clear();

    for (final segment in wanted) {
      if (segment.length < 2) continue;
      final step = (segment.length / _maxGhostPoints).ceil();
      final geometry = <LatLng>[];
      for (var i = 0; i < segment.length; i += step < 1 ? 1 : step) {
        geometry.add(LatLng(segment[i].lat, segment[i].lon));
      }
      final last = segment.last;
      if (geometry.last.latitude != last.lat ||
          geometry.last.longitude != last.lon) {
        geometry.add(LatLng(last.lat, last.lon));
      }
      _ghostLines.add(
        await controller.addLine(
          LineOptions(
            geometry: geometry,
            lineColor: widget.ghostColor,
            lineWidth: 3,
            lineOpacity: 0.7,
            lineJoin: 'round',
          ),
        ),
      );
    }
    _ghostDrawn = wanted;

    if (_ghostLines.isNotEmpty && _lines.any((l) => l != null)) {
      for (final line in _lines) {
        if (line != null) await controller.removeLine(line);
      }
      _lines.clear();
      _drawnLengths.clear();
    }
  }

  Future<void> _syncOnce(MapLibreMapController controller) async {
    await _syncGhost(controller);
    final segments = widget.segments;

    for (var i = 0; i < segments.length; i++) {
      final points = segments[i];
      if (points.length < 2) continue;
      while (_lines.length <= i) {
        _lines.add(null);
        _drawnLengths.add(0);
      }
      if (_drawnLengths[i] == points.length) continue;

      final geometry = [for (final p in points) LatLng(p.lat, p.lon)];
      final existing = _lines[i];
      if (existing == null) {
        _lines[i] = await controller.addLine(
          LineOptions(
            geometry: geometry,
            lineColor: widget.lineColor,
            lineWidth: 4,
            lineOpacity: 0.95,
            lineJoin: 'round',
          ),
        );
      } else {
        await controller.updateLine(existing, LineOptions(geometry: geometry));
      }
      _drawnLengths[i] = points.length;
    }

    // Segments shrank (recording discarded): drop stale lines.
    while (_lines.length > segments.length) {
      final line = _lines.removeLast();
      _drawnLengths.removeLast();
      if (line != null) await controller.removeLine(line);
    }

    if (widget.fitToTrack && !_fitted) {
      _fitted = await _fit(controller);
    }
  }

  Future<bool> _fit(MapLibreMapController controller) async {
    final points = [for (final s in widget.segments) ...s];
    if (points.isEmpty) return false;
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLon = points.first.lon, maxLon = points.first.lon;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
    if (minLat == maxLat && minLon == maxLon) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLon), 16),
      );
    } else {
      await controller.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLon),
            northeast: LatLng(maxLat, maxLon),
          ),
          left: 28,
          top: 28,
          right: 28,
          bottom: 28,
        ),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.interactive;
    return MapLibreMap(
      styleString: widget.styleString,
      initialCameraPosition: CameraPosition(target: _initialTarget, zoom: 15),
      onMapCreated: (c) => _controller = c,
      onStyleLoadedCallback: _onStyleLoaded,
      myLocationEnabled: widget.showUserLocation,
      myLocationTrackingMode: widget.followUser && widget.showUserLocation
          ? MyLocationTrackingMode.tracking
          : MyLocationTrackingMode.none,
      compassEnabled: interactive,
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      rotateGesturesEnabled: interactive,
      tiltGesturesEnabled: false,
    );
  }
}

/// Static route preview for a saved activity: loads `Tracks/<gpxFileName>`
/// and draws it fitted to the view. Shows a short message if the file is
/// missing (e.g. not yet synced to this device) or empty.
class ActivityRouteMap extends StatefulWidget {
  const ActivityRouteMap({
    super.key,
    required this.gpxFileName,
    this.height = 200,
  });

  final String gpxFileName;
  final double height;

  @override
  State<ActivityRouteMap> createState() => _ActivityRouteMapState();
}

class _ActivityRouteMapState extends State<ActivityRouteMap> {
  Future<GpxTrack?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(AppScope.of(context));
  }

  Future<GpxTrack?> _load(AppServices services) async {
    try {
      final track =
          GpxService.parse(await services.vault.readTrack(widget.gpxFileName));
      return track.isEmpty ? null : track;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: FutureBuilder<GpxTrack?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const ColoredBox(
                color: AppColors.surfaceHigh,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final track = snap.data;
            if (track == null) {
              return const ColoredBox(
                color: AppColors.surfaceHigh,
                child: Center(
                  child: Text(
                    'Route not available',
                    style: TextStyle(color: AppColors.textDim),
                  ),
                ),
              );
            }
            return TrackMapView(
              segments: track.segments,
              interactive: false,
              fitToTrack: true,
            );
          },
        ),
      ),
    );
  }
}
