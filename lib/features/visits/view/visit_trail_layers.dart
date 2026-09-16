import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/design/app_colors.dart';
import '../../../app/design/app_dimens.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit_location_log.dart';

/// The drawn GPS trail: the thread itself plus the pins that cap it.
///
/// Both the compact card on the visit detail page and the full-screen trail
/// page render the same path, so the drawing lives here once. Everything is
/// returned as `flutter_map` layer widgets, to be dropped into a map's layers
/// in the usual order — line first, pins on top.
class TrailLayers {
  const TrailLayers._();

  /// The thread's width on the compact card; the full-screen map passes
  /// [strokeWidthFull].
  static const double strokeWidth = 4.5;
  static const double strokeWidthFull = 5;

  /// The white casing drawn on each side of the thread.
  static const double _casingWidth = 2;

  /// Above this many points the vertex dots merge into a band that hides the
  /// line, and their markers cost layout on every pan.
  static const int _maxDots = 60;

  /// Diameter of one vertex dot, and the white ring around it.
  static const double _dotSize = 9;
  static const double _dotRing = CompSz.outlineWidth;

  /// Endpoint pin sizes on the full-screen map and on the compact card.
  static const double pinSize = 34;
  static const double pinSizeCompact = 28;

  /// Extra room a marker box needs beyond its pin: the pin's ring and shadow,
  /// and — for the live pin — the pulse that grows past it.
  static const double _pinPadding = 6;
  static const double _livePinPadding = 18;

  static List<LatLng> points(VisitTrack track) => [
    for (final l in track.logs) LatLng(l.latitude, l.longitude),
  ];

  /// The thread.
  ///
  /// Drawn as two stacked lines: a wide white casing under a coloured core.
  /// A single-colour line disappears over pale roads and river polygons on the
  /// OSM raster tiles — the casing is what keeps it readable over any of them,
  /// and is the same trick the route map uses.
  ///
  /// [path] replaces the straight joins between the recorded fixes with a
  /// derived line — the road-matched geometry of the same trail.
  static Widget polyline(
    BuildContext context,
    VisitTrack track, {
    double width = strokeWidth,
    List<LatLng>? path,
  }) {
    final pts = path ?? points(track);
    if (pts.length < 2) return const SizedBox.shrink();
    return PolylineLayer(
      polylines: [
        Polyline(
          points: pts,
          strokeWidth: width,
          color: context.colors.primary,
          borderStrokeWidth: _casingWidth,
          borderColor: AppColors.onMap,
        ),
      ],
    );
  }

  /// A dot on every intermediate fix, so it is visible where the device
  /// actually sampled rather than just the line interpolated between them.
  static Widget vertexDots(BuildContext context, VisitTrack track) {
    final logs = track.logs;
    if (logs.length < 3 || logs.length > _maxDots) {
      return const SizedBox.shrink();
    }
    final color = context.colors.primary;
    return MarkerLayer(
      markers: [
        for (final l in logs)
          if (!l.isStart && !l.isEnd)
            Marker(
              point: LatLng(l.latitude, l.longitude),
              width: _dotSize,
              height: _dotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: AppColors.onMap, width: _dotRing),
                ),
              ),
            ),
      ],
    );
  }

  /// The pins at the two ends of the thread.
  ///
  /// [live] marks the newest fix as "where they are now" (a pulsing dot) rather
  /// than as the end of a finished path — on a running visit the last point is
  /// the employee's current position, not their destination.
  static Widget endpoints(
    BuildContext context,
    VisitTrack track, {
    bool live = false,
    double size = pinSize,
  }) {
    final logs = track.logs;
    if (logs.isEmpty) return const SizedBox.shrink();
    // The server tags the points the Start and End actions wrote (`source`),
    // so those pins mark the real check-in and check-out even if a fix ever
    // sorts before the Start or after the End. A trail without them (a visit
    // started with no coordinates) falls back to its first and last points.
    // On a live visit the far pin is the newest fix — where the rep is now.
    final first = logs.firstWhere((l) => l.isStart, orElse: () => logs.first);
    final last = live
        ? logs.last
        : logs.lastWhere((l) => l.isEnd, orElse: () => logs.last);
    final s = context.s;

    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(first.latitude, first.longitude),
          width: size + _pinPadding,
          height: size + _pinPadding,
          child: MapPin.icon(
            icon: Symbols.trip_origin,
            color: AppColors.routeStart,
            size: size,
            tooltip: s.trailPointStart,
          ),
        ),
        if (logs.length > 1 && !identical(first, last))
          Marker(
            point: LatLng(last.latitude, last.longitude),
            width: size + _livePinPadding,
            height: size + _livePinPadding,
            child: live
                ? _LivePin(size: size, tooltip: s.trailLive)
                : MapPin.icon(
                    icon: Symbols.flag,
                    color: AppColors.routeEnd,
                    size: size,
                    tooltip: s.trailPointEnd,
                  ),
          ),
      ],
    );
  }
}

/// The employee's current position on a running visit: a solid dot inside a
/// ring that breathes outward, so a manager watching the map can tell a live
/// position from the frozen end of a finished route at a glance.
class _LivePin extends StatelessWidget {
  final double size;
  final String tooltip;
  const _LivePin({required this.size, required this.tooltip});

  /// One breath, and the pause after it.
  static const _beat = Duration(milliseconds: 1600);
  static const _rest = Duration(milliseconds: 900);

  /// The ring grows from [_ringFrom] to `_ringFrom + _ringGrowth` times the
  /// pin, fading out from [Alphas.halo].
  static const double _ringFrom = 0.7;
  static const double _ringGrowth = 0.9;

  /// The pin inside the ring, relative to [size].
  static const double _pinScale = 0.8;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    // AmbientPulse rather than a free-running controller: it rests between
    // beats instead of rebuilding this subtree every frame for as long as the
    // screen stays open. The same reasoning as the geofence ring on the visit
    // map card.
    return AmbientPulse(
      period: _beat,
      rest: _rest,
      curve: Curves.easeOut,
      builder: (_, beat) => AnimatedBuilder(
        animation: beat,
        builder: (_, __) {
          final t = beat.value;
          final ring = size * (_ringFrom + t * _ringGrowth);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: (1 - t) * Alphas.halo),
                ),
              ),
              MapPin.icon(
                icon: Symbols.navigation,
                color: color,
                size: size * _pinScale,
                tooltip: tooltip,
              ),
            ],
          );
        },
      ),
    );
  }
}
