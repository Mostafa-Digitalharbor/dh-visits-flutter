import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/constants.dart';

/// Shared OpenStreetMap tile layer.
///
/// Every map in the app (dashboard, route, visit detail, visit trail) renders
/// the same tiles, so the URL / user-agent / max-native-zoom live in one place
/// ([AppConstants]) and are wrapped here. Use this instead of building a raw
/// [TileLayer] so the call-sites can never drift apart.
class AppMapTileLayer extends StatefulWidget {
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
  State<AppMapTileLayer> createState() => _AppMapTileLayerState();
}

class _AppMapTileLayerState extends State<AppMapTileLayer> {
  /// One provider for the layer's lifetime. [TileLayer] otherwise builds a new
  /// one (with its own HTTP client) on every rebuild, and disposes only the
  /// last. It also disposes this one, so this state must not.
  ///
  /// Silenced: a tile that fails to download (offline, a dead zone) is drawn
  /// transparent instead of being reported as a Flutter error — dozens of them
  /// per screen, on every pan, which buried real errors in the device log.
  late final TileProvider _tiles =
      NetworkTileProvider(silenceExceptions: true);

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      tileProvider: _tiles,
      urlTemplate: AppConstants.mapTileUrl,
      userAgentPackageName: AppConstants.mapUserAgent,
      maxNativeZoom: AppConstants.mapMaxNativeZoom,
      maxZoom: widget.maxZoom ?? double.infinity,
      panBuffer: widget.panBuffer,
      keepBuffer: widget.keepBuffer,
      tileBuilder: widget.tileBuilder,
    );
  }
}
