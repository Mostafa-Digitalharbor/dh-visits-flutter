import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/map_matching/route_geometry.dart';
import '../../../core/map_matching/route_matcher.dart';
import '../../../core/utils/app_number.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/widgets.dart';
import '../../visits/data/models/visit.dart';
import '../bloc/day_trails_cubit.dart';

/// Sizes of the marks drawn on the route map, and of the list rows that are
/// keyed to them. Map marks are fixed dp: they sit on tiles, not in text.
abstract final class RouteMapStyle {
  /// Most of the screen height the map may take, so the stop list below keeps
  /// its share in landscape. In portrait this is about [CompSz.routeMapMax].
  static const double maxScreenShare = 0.33;

  /// The planned route between stops: a white line with a primary casing.
  static const double plannedStroke = 3.0;
  static const double plannedCasing = 1.0;

  /// A visit's recorded trail.
  static const double recordedStroke = 4.0;

  /// The white casing that keeps a recorded line readable over any tile.
  static const double recordedCasing = 1.5;

  /// The dot capping each end of a visit trail.
  static const double trailEndDot = 16.0;
  static const double trailEndRing = 2.5;

  /// A numbered planned stop — on the map and in the timeline below it.
  static const double stopPin = 32.0;

  /// The white ring of the numbered pins.
  static const double pinRing = 2.0;
}

/// The day on a map: the planned stops, and the trail recorded during each
/// visit done today — each its own line. Nothing is recorded between visits,
/// so the trails are never joined.
class RouteMap extends StatelessWidget {
  final List<Visit> stops;

  /// [stops]' coordinates, same order.
  final List<LatLng> points;

  /// The stop to go to next (-1: all done).
  final int nextIndex;

  /// Straight-line length through [points], for the summary chip.
  final double stopsKm;
  final List<DayTrail> trails;

  /// Road-matched geometry of each of [trails], same order.
  final List<RouteGeometry> trailGeometries;
  final RouteLineMode lineMode;
  final ValueChanged<RouteLineMode> onLineMode;

  const RouteMap({
    super.key,
    required this.stops,
    required this.points,
    required this.nextIndex,
    required this.stopsKm,
    required this.trails,
    required this.trailGeometries,
    required this.lineMode,
    required this.onLineMode,
  });

  /// Rebuilds the map — and so re-fits the camera — only when *what* is shown
  /// changes (another stop or trail), never when a trail merely grows. Keying
  /// on the point count reset the user's pan and zoom every time a running
  /// visit's trail gained points.
  Key get _frameKey => ValueKey(Object.hashAll([
        for (final v in stops) v.id,
        for (final t in trails) t.visit.id,
      ]));

  @override
  Widget build(BuildContext context) {
    // The recorded fixes. Markers and the camera fit always use these.
    final trailPoints = [
      for (final t in trails)
        [for (final l in t.track.logs) LatLng(l.latitude, l.longitude)],
    ];
    // The lines: road-matched where a match exists, else the fixes joined.
    final roads = lineMode == RouteLineMode.roads;
    final trailLines = [
      for (var i = 0; i < trails.length; i++)
        roads && i < trailGeometries.length
            ? trailGeometries[i].path()
            : trailPoints[i],
    ];
    final matching = RouteLineToggle.stateOf(trailGeometries);
    final showToggle = (slMaybe<RouteMatcher>()?.enabled ?? false) &&
        trailPoints.any((p) => p.length > 1);
    // Every recorded vertex joins the planned stops in the camera fit, so a
    // route that wandered away from the customers still sits inside the frame.
    final allPoints = [
      ...points,
      for (final p in trailPoints) ...p,
    ];
    final margin = context.r(Insets.x3);
    final s = context.s;
    final String? summary = stops.isNotEmpty
        ? context.joinFacts(
            [s.routeStopsCount(stops.length), AppNumber.km(s, stopsKm)])
        : null;

    return SizedBox(
      // A flat height is most of a landscape viewport: the stop list below
      // would be squeezed to nothing. Capped against the screen instead.
      height: math.min(
        CompSz.routeMapMax,
        context.hp(RouteMapStyle.maxScreenShare),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          return AppMap(
            key: _frameKey,
            initialCenter:
                allPoints.isNotEmpty ? allPoints.first : AppMap.fallbackCenter,
            initialZoom: AppConstants.mapZoomRoute,
            initialCameraFit: AppMap.fitOrNull(
              allPoints,
              padding: _fitPadding(context, box.biggest),
            ),
            layers: [
              if (points.length > 1)
                PolylineLayer(polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: RouteMapStyle.plannedStroke,
                    color: AppColors.onMap,
                    borderStrokeWidth: RouteMapStyle.plannedCasing,
                    borderColor: context.colors.primary,
                  ),
                ]),
              // One polyline per visit, never joined.
              PolylineLayer(polylines: [
                for (var i = 0; i < trails.length; i++)
                  if (trailLines[i].length > 1)
                    _recorded(trailLines[i], AppColors.routePaletteAt(i)),
              ]),
              MarkerLayer(markers: [
                for (var i = 0; i < trails.length; i++)
                  // A trail with no fixes has no ends to cap (`.first` on it
                  // threw). The route cubit filters those out, but the list
                  // this widget takes does not promise it.
                  if (trailPoints[i].isNotEmpty) ...[
                    _dot(trailPoints[i].first, AppColors.routeStart),
                    if (trailPoints[i].length > 1)
                      _dot(trailPoints[i].last, AppColors.routePaletteAt(i)),
                  ],
                for (var i = 0; i < points.length; i++)
                  Marker(
                    point: points[i],
                    width: RouteMapStyle.stopPin,
                    height: RouteMapStyle.stopPin,
                    child: StopNumberPin(number: i + 1, isNext: i == nextIndex),
                  ),
              ]),
            ],
            overlays: [
              if (showToggle || summary != null)
                PositionedDirectional(
                  top: margin,
                  start: margin,
                  end: margin,
                  // One row: the chip ellipsizes into whatever the toggle
                  // leaves. Capping the chip at half the width was not enough
                  // — on a 320dp phone at the largest text size the toggle
                  // alone is wider than half, and the two overlapped (in
                  // Arabic the toggle also ran off the map's edge). The toggle
                  // now scales down only where even a minimal chip would not
                  // fit beside it. The row's empty space takes no touches.
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: summary == null
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (summary != null)
                        Flexible(child: _SummaryChip(text: summary)),
                      if (summary != null && showToggle)
                        SizedBox(width: margin),
                      if (showToggle)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _toggleMaxWidth(
                              box.maxWidth - margin * 2,
                              gap: margin,
                              besideSummary: summary != null,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.topEnd,
                            child: RouteLineToggle(
                              mode: lineMode,
                              onChanged: onLineMode,
                              pending: matching.pending,
                              unmatched: matching.unmatched,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The narrowest the summary chip gets beside the line toggle: its glyph
  /// and a few characters before the ellipsis.
  static const double _summaryMinWidth = 72.0;

  /// How wide the line toggle may be in a top bar [barWidth] wide.
  static double _toggleMaxWidth(
    double barWidth, {
    required double gap,
    required bool besideSummary,
  }) =>
      math.max(
        0.0,
        besideSummary ? barWidth - gap - _summaryMinWidth : barWidth,
      );

  /// Most of the map's width or height the camera-fit padding may take.
  static const double _maxFitPaddingShare = 0.5;

  /// The camera-fit padding: extra room at the top, where the summary chip
  /// overlays the map and a trail end dot was drawn underneath it.
  ///
  /// Shrunk where the map is too small for it. On a landscape phone the map is
  /// about 120dp tall and the padding was taller than that: flutter_map fitted
  /// the route into no space at all and zoomed out to the whole world.
  static EdgeInsets _fitPadding(BuildContext context, Size map) {
    final padding = EdgeInsets.fromLTRB(
      context.r(Insets.x12),
      context.r(Insets.x16 + Insets.x2),
      context.r(Insets.x12),
      context.r(Insets.x10),
    );
    double shrink(double total, double side) => side.isFinite
        ? math.min(1.0, side * _maxFitPaddingShare / total)
        : 1.0;
    final h = shrink(padding.horizontal, map.width);
    final v = shrink(padding.vertical, map.height);
    return EdgeInsets.fromLTRB(
      padding.left * h,
      padding.top * v,
      padding.right * h,
      padding.bottom * v,
    );
  }

  static Polyline _recorded(List<LatLng> points, Color color) => Polyline(
        points: points,
        strokeWidth: RouteMapStyle.recordedStroke,
        color: color,
        borderStrokeWidth: RouteMapStyle.recordedCasing,
        borderColor: AppColors.onMap,
      );

  static Marker _dot(LatLng point, Color color) => Marker(
        point: point,
        width: RouteMapStyle.trailEndDot,
        height: RouteMapStyle.trailEndDot,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: AppColors.onMap,
              width: RouteMapStyle.trailEndRing,
            ),
          ),
        ),
      );

}

/// A planned stop's number. The next stop wears the brand gradient; the rest
/// are ink.
class StopNumberPin extends StatelessWidget {
  final int number;
  final bool isNext;
  const StopNumberPin({super.key, required this.number, required this.isNext});

  @override
  Widget build(BuildContext context) => MapPin.label(
        text: AppNumber.whole(number),
        size: RouteMapStyle.stopPin,
        borderWidth: RouteMapStyle.pinRing,
        gradient: isNext ? context.x.avatarGradient : null,
        color: isNext ? null : AppColors.ink,
      );
}

class _SummaryChip extends StatelessWidget {
  final String text;
  const _SummaryChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: context.padSym(h: Insets.x3, v: Insets.x1h),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.route,
              size: context.r(IconSz.inline), color: AppColors.onMap),
          context.gapW(Insets.x1h),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onMap,
                fontSize: FontSz.sm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
