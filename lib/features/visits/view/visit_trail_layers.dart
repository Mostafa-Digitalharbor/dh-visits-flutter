import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/models/visit_location_log.dart';

/// The drawn GPS trail: the thread itself plus the pins that cap it.
///
/// Both the compact card on the visit detail page and the full-screen trail
/// page render the same path, so the drawing lives here once. Everything is
/// returned as `flutter_map` layer widgets, to be dropped into a [FlutterMap]'s
/// `children` in the usual order — line first, pins on top.
class TrailLayers {
  const TrailLayers._();

  static List<LatLng> points(VisitTrack track) =>
      [for (final l in track.logs) LatLng(l.latitude, l.longitude)];

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
    double strokeWidth = 4.5,
    List<LatLng>? path,
  }) {
    final pts = path ?? points(track);
    if (pts.length < 2) return const SizedBox.shrink();
    final color = context.colors.primary;
    return PolylineLayer(
      polylines: [
        Polyline(
          points: pts,
          strokeWidth: strokeWidth,
          color: color,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      ],
    );
  }

  /// A dot on every intermediate fix, so it is visible where the device
  /// actually sampled rather than just the line interpolated between them.
  ///
  /// Suppressed above [maxDots] points: past that the dots merge into a fat
  /// band that hides the line, and a long visit can carry hundreds of markers
  /// whose layout cost is paid on every pan.
  static Widget vertexDots(
    BuildContext context,
    VisitTrack track, {
    int maxDots = 60,
    double size = 9,
  }) {
    final logs = track.logs;
    if (logs.length < 3 || logs.length > maxDots) {
      return const SizedBox.shrink();
    }
    final color = context.colors.primary;
    return MarkerLayer(
      markers: [
        for (final l in logs)
          if (!l.isStart && !l.isEnd)
            Marker(
              point: LatLng(l.latitude, l.longitude),
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 1.5),
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
    double size = 34,
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
          width: size + 6,
          height: size + 6,
          child: MapPin.icon(
            icon: Symbols.trip_origin,
            color: Colors.green.shade600,
            size: size,
            tooltip: s.trailPointStart,
          ),
        ),
        if (logs.length > 1 && !identical(first, last))
          Marker(
            point: LatLng(last.latitude, last.longitude),
            width: size + 18,
            height: size + 18,
            child: live
                ? _LivePin(size: size, tooltip: s.trailLive)
                : MapPin.icon(
                    icon: Symbols.flag,
                    color: Colors.deepOrangeAccent.shade200,
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

  @override
  Widget build(BuildContext context) {
    final color = context.colors.primary;
    // AmbientPulse rather than a free-running controller: it rests between
    // beats instead of rebuilding this subtree every frame for as long as the
    // screen stays open. The same reasoning as the geofence ring on the visit
    // map card.
    return AmbientPulse(
      period: const Duration(milliseconds: 1600),
      rest: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (_, beat) => AnimatedBuilder(
        animation: beat,
        builder: (_, __) {
          final t = beat.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * (0.7 + t * 0.9),
                height: size * (0.7 + t * 0.9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: (1 - t) * 0.28),
                ),
              ),
              MapPin.icon(
                icon: Symbols.navigation,
                color: color,
                size: size * 0.8,
                tooltip: tooltip,
              ),
            ],
          );
        },
      ),
    );
  }
}
