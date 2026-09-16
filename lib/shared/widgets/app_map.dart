import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/design/app_colors.dart';
import '../../app/design/app_dimens.dart';
import '../../core/constants.dart';
import '../extensions/context_extensions.dart';
import 'app_map_attribution.dart';
import 'app_map_tile_layer.dart';

/// The app's map frame: themed backdrop, OpenStreetMap tiles, the caller's
/// layers, the mandatory OSM credit, and the dark-mode dimming — in the order
/// every map needs them.
///
/// Five screens assembled this stack by hand and had drifted: one forgot the
/// backdrop, one dimmed with a different alpha, one blocked taps on the credit
/// link. Build maps through this instead.
class AppMap extends StatelessWidget {
  final MapController? controller;

  /// Layers drawn over the tiles (polylines, circles, markers), bottom first.
  final List<Widget> layers;

  /// Widgets stacked over the map itself — FABs, chips, legends. Use
  /// `PositionedDirectional` so they mirror in Arabic.
  final List<Widget> overlays;

  final LatLng initialCenter;
  final double initialZoom;
  final CameraFit? initialCameraFit;

  /// False for a static preview inside a scrolling page: the page scrolls
  /// instead of the map panning.
  final bool interactive;
  final void Function(TapPosition, LatLng)? onTap;

  final Alignment attributionAlignment;
  final int panBuffer;
  final int keepBuffer;
  final TileBuilder? tileBuilder;

  /// Darkens the whole map in dark mode. Off for maps that tint their tiles
  /// themselves through [tileBuilder].
  final bool dimInDarkMode;

  const AppMap({
    super.key,
    this.controller,
    required this.initialCenter,
    this.initialZoom = AppConstants.defaultMapZoom,
    this.initialCameraFit,
    this.layers = const [],
    this.overlays = const [],
    this.interactive = true,
    this.onTap,
    this.attributionAlignment = Alignment.bottomRight,
    this.panBuffer = 1,
    this.keepBuffer = 2,
    this.tileBuilder,
    this.dimInDarkMode = true,
  });

  /// The fallback centre when a screen has no coordinate at all.
  static const fallbackCenter =
      LatLng(AppConstants.mapFallbackLat, AppConstants.mapFallbackLng);

  /// Below this span (degrees) the points are one place, and fitting them
  /// would zoom past the tiles.
  static const double _minFitSpan = 1e-4;

  /// A camera fit that frames [points], or null when they don't span an area:
  /// `CameraFit` on a single distinct point produces an infinite zoom (NaN
  /// camera, blank map). Callers then fall back to a centre and a fixed zoom.
  static CameraFit? fitOrNull(
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(Insets.x12),
    double? maxZoom,
  }) {
    if (points.length < 2) return null;
    final bounds = LatLngBounds.fromPoints(points);
    final latSpan = bounds.north - bounds.south;
    final lngSpan = bounds.east - bounds.west;
    if (latSpan < _minFitSpan && lngSpan < _minFitSpan) return null;
    return CameraFit.bounds(bounds: bounds, padding: padding, maxZoom: maxZoom);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            initialCameraFit: initialCameraFit,
            minZoom: AppConstants.mapMinZoom,
            maxZoom: AppConstants.mapMaxZoom,
            backgroundColor: AppColors.mapBackground(isDark),
            onTap: onTap,
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            AppMapTileLayer(
              maxZoom: AppConstants.mapMaxZoom,
              panBuffer: panBuffer,
              keepBuffer: keepBuffer,
              tileBuilder: tileBuilder,
            ),
            ...layers,
            AppMapAttribution(alignment: attributionAlignment),
          ],
        ),
        if (isDark && dimInDarkMode)
          const IgnorePointer(
            child: ColoredBox(
              color: Color.fromRGBO(0, 0, 0, Alphas.mapDim),
            ),
          ),
        ...overlays,
      ],
    );
  }
}
