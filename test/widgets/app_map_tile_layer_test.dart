import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/shared/widgets/app_map_tile_layer.dart';

import 'widget_harness.dart';

const _riyadh = LatLng(24.7136, 46.6753);
const _tileKey = 'tile';

/// A bare map around [layer], so the layer has a camera to read.
Widget _host(Widget layer, {double zoom = 3}) => FlutterMap(
  options: MapOptions(
    initialCenter: _riyadh,
    initialZoom: zoom,
    maxZoom: AppConstants.mapMaxZoom,
  ),
  children: [layer],
);

TileLayer _tileLayer(WidgetTester tester) =>
    tester.widget<TileLayer>(find.byType(TileLayer));

/// Wraps every tile in a keyed box and records which tile it is.
TileBuilder _recording(List<TileCoordinates> seen) => (context, tile, image) {
  seen.add(image.coordinates);
  return KeyedSubtree(key: const ValueKey(_tileKey), child: tile);
};

void main() {
  setUpAll(initHarness);

  group('AppMapTileLayer layout', () {
    testOnEverySurface(
      'fills a map on every surface',
      (s) => _host(const AppMapTileLayer(maxZoom: AppConstants.mapMaxZoom)),
      verify: (tester, s) async {
        expect(find.byType(TileLayer), findsOneWidget);
        expect(tester.getSize(find.byType(AppMapTileLayer)), s.size);
      },
    );
  });

  group('AppMapTileLayer configuration', () {
    testWidgets('serves OpenStreetMap tiles with the app settings', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _host(const AppMapTileLayer()));
      final layer = _tileLayer(tester);
      expect(layer.urlTemplate, AppConstants.mapTileUrl);
      expect(layer.maxNativeZoom, AppConstants.mapMaxNativeZoom);
      expect(layer.tileProvider, isA<NetworkTileProvider>());
      expectCleanLayout(tester);
    });

    testWidgets('identifies the app in the tile requests (OSM tile policy)', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _host(const AppMapTileLayer()));
      expect(
        _tileLayer(tester).tileProvider.headers['User-Agent'],
        'flutter_map (${AppConstants.mapUserAgent})',
      );
      expectCleanLayout(tester);
    });

    testWidgets('resolves a tile to the https OSM address', (tester) async {
      await pumpSurface(tester, phoneEn, _host(const AppMapTileLayer()));
      final layer = _tileLayer(tester);
      expect(
        layer.tileProvider.getTileUrl(const TileCoordinates(5, 7, 4), layer),
        'https://tile.openstreetmap.org/4/5/7.png',
      );
      expectCleanLayout(tester);
    });

    testWidgets('defaults: no zoom ceiling, buffers 1 and 2, no builder', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _host(const AppMapTileLayer()));
      final layer = _tileLayer(tester);
      expect(layer.maxZoom, double.infinity);
      expect(layer.panBuffer, 1);
      expect(layer.keepBuffer, 2);
      expect(layer.tileBuilder, isNull);
      expectCleanLayout(tester);
    });

    testWidgets('forwards maxZoom, buffers and the tile builder', (
      tester,
    ) async {
      final builder = _recording([]);
      await pumpSurface(
        tester,
        phoneEn,
        _host(
          AppMapTileLayer(
            maxZoom: 20,
            panBuffer: 0,
            keepBuffer: 4,
            tileBuilder: builder,
          ),
        ),
      );
      final layer = _tileLayer(tester);
      expect(layer.maxZoom, 20);
      expect(layer.panBuffer, 0);
      expect(layer.keepBuffer, 4);
      expect(layer.tileBuilder, same(builder));
      expectCleanLayout(tester);
    });
  });

  group('AppMapTileLayer rendering', () {
    testWidgets('lays out tiles for the visible area through the builder', (
      tester,
    ) async {
      final seen = <TileCoordinates>[];
      await pumpSurface(
        tester,
        phoneEn,
        _host(AppMapTileLayer(tileBuilder: _recording(seen)), zoom: 5),
      );
      expectCleanLayout(tester);
      expect(find.byKey(const ValueKey(_tileKey)), findsWidgets);
      expect(seen, isNotEmpty);
      expect(seen.map((c) => c.z).toSet(), {5});
    });

    testWidgets('past zoom 19 the last native tiles are upscaled', (
      tester,
    ) async {
      final seen = <TileCoordinates>[];
      await pumpSurface(
        tester,
        phoneEn,
        _host(
          AppMapTileLayer(
            maxZoom: AppConstants.mapMaxZoom,
            tileBuilder: _recording(seen),
          ),
          zoom: 21,
        ),
      );
      expectCleanLayout(tester);
      // Tiles are still drawn — no blank map at street-level zoom…
      expect(find.byKey(const ValueKey(_tileKey)), findsWidgets);
      // …and none is requested beyond what OSM serves.
      expect(seen, isNotEmpty);
      expect(
        seen.map((c) => c.z),
        everyElement(lessThanOrEqualTo(AppConstants.mapMaxNativeZoom)),
      );
    });

    testWidgets('beyond an explicit maxZoom no tiles are drawn', (
      tester,
    ) async {
      final seen = <TileCoordinates>[];
      await pumpSurface(
        tester,
        phoneEn,
        _host(
          AppMapTileLayer(maxZoom: 10, tileBuilder: _recording(seen)),
          zoom: 12,
        ),
      );
      expectCleanLayout(tester);
      expect(find.byKey(const ValueKey(_tileKey)), findsNothing);
      expect(seen, isEmpty);
    });

    testWidgets(
      'renders the same in dark mode (tinting is the caller\'s job)',
      (tester) async {
        final seen = <TileCoordinates>[];
        await pumpSurface(
          tester,
          surfaces[2],
          _host(AppMapTileLayer(tileBuilder: _recording(seen))),
        );
        expectCleanLayout(tester);
        expect(seen, isNotEmpty);
        expect(
          find.descendant(
            of: find.byType(AppMapTileLayer),
            matching: find.byType(ColorFiltered),
          ),
          findsNothing,
        );
      },
    );
  });
}
