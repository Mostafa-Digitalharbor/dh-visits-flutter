import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/constants.dart';

/// Shared OpenStreetMap tile layer.
///
/// Every map in the app (dashboard, nearby, route, visit detail) renders the
/// same tiles, so the URL / user-agent / max-native-zoom live in one place
/// ([AppConstants]) and are wrapped here. Use this instead of building a raw
/// [TileLayer] so the four call-sites can never drift apart.
class AppMapTileLayer extends StatelessWidget {
  /// Upper bound the map will display. Defaults to [TileLayer]'s own
  /// (effectively unbounded) behavior; pass e.g. `22` for interactive maps
  /// that allow over-zooming past the native tile resolution.
  final double? maxZoom;

  /// Tiles to pre-load in a ring around the viewport. Larger values reduce
  /// blank squares while panning at the cost of more downloads.
  final int panBuffer;

  /// Tiles to retain outside the viewport before evicting them.
  final int keepBuffer;

  /// Optional per-tile builder — used for the dark-mode tint on the live map.
  final TileBuilder? tileBuilder;

  const AppMapTileLayer({
    super.key,
    this.maxZoom,
    this.panBuffer = 1,
    this.keepBuffer = 2,
    this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: AppConstants.mapTileUrl,
      userAgentPackageName: AppConstants.mapUserAgent,
      maxNativeZoom: AppConstants.mapMaxNativeZoom,
      maxZoom: maxZoom ?? double.infinity,
      panBuffer: panBuffer,
      keepBuffer: keepBuffer,
      tileBuilder: tileBuilder,
    );
  }
}
