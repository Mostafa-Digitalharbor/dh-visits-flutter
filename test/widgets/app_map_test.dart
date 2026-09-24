import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/shared/widgets/app_map.dart';
import 'package:location_gps/shared/widgets/app_map_attribution.dart';
import 'package:location_gps/shared/widgets/app_map_tile_layer.dart';

import 'widget_harness.dart';

const _riyadh = LatLng(24.7136, 46.6753);
const _jeddah = LatLng(21.4858, 39.1925);
const _fab = Key('map-fab');
const _legend = Key('map-legend');

const _dimColor = Color.fromRGBO(0, 0, 0, Alphas.mapDim);
const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

Finder get _dim =>
    find.byWidgetPredicate((w) => w is ColoredBox && w.color == _dimColor);

FlutterMap _flutterMap(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap));

/// AppMap's own stack — the first one under it.
Stack _stack(WidgetTester tester) => tester.widget<Stack>(
  find.descendant(of: find.byType(AppMap), matching: find.byType(Stack)).first,
);

/// Records every URL the app asks the platform to open.
List<String> _mockLauncher(WidgetTester tester) {
  final launched = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_launcher, (call) async {
    if (call.method == 'launch') {
      launched.add((call.arguments as Map)['url'] as String);
      return true;
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_launcher, null));
  return launched;
}

/// Runs [body] with map-tile download failures filtered out.
///
/// The harness's `expectCleanLayout` forgives a tile failure, but only when it
/// is the *only* error: a fitted map first renders its unfitted camera (flutter_map
/// applies `initialCameraFit` after the first frame), prunes those tiles, and
/// their failed loads — no listener left — are reported together, merged into
/// one "Multiple exceptions" error that no longer names the tile URL. Real
/// layout errors still reach the harness's handler.
Future<void> _ignoringTileErrors(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if ('${details.exception}'.contains('tile.openstreetmap.org')) return;
    original?.call(details);
  };
  try {
    await body();
    // Let in-flight tile loads fail while the filter is still installed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  } finally {
    FlutterError.onError = original;
  }
}

Widget _map(
  Surface s, {
  MapController? controller,
  bool dimInDarkMode = true,
  bool interactive = true,
  CameraFit? fit,
  void Function(TapPosition, LatLng)? onTap,
  VoidCallback? onFab,
  Alignment attributionAlignment = Alignment.bottomRight,
}) => AppMap(
  controller: controller,
  initialCenter: _riyadh,
  initialCameraFit: fit,
  dimInDarkMode: dimInDarkMode,
  interactive: interactive,
  onTap: onTap,
  attributionAlignment: attributionAlignment,
  layers: [
    PolylineLayer(
      polylines: [
        Polyline(points: const [_riyadh, _jeddah], strokeWidth: 4),
      ],
    ),
    const MarkerLayer(
      markers: [
        Marker(point: _riyadh, child: Icon(Icons.location_on)),
        Marker(point: _jeddah, child: Icon(Icons.flag)),
      ],
    ),
  ],
  overlays: [
    PositionedDirectional(
      top: 12,
      start: 12,
      end: 72,
      child: Material(
        key: _legend,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${LongText.of(s)} — ${LongText.arabicPerson}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
    PositionedDirectional(
      bottom: 32,
      end: 12,
      child: FloatingActionButton.small(
        key: _fab,
        heroTag: null,
        tooltip: l10n(s.locale).commonRetry,
        onPressed: onFab ?? () {},
        child: const Icon(Icons.my_location),
      ),
    ),
  ],
);

void main() {
  setUpAll(initHarness);

  group('AppMap.fitOrNull', () {
    test('no points or a single point cannot be framed', () {
      expect(AppMap.fitOrNull(const []), isNull);
      expect(AppMap.fitOrNull(const [_riyadh]), isNull);
    });

    test('identical points are one place, not an area', () {
      expect(AppMap.fitOrNull(const [_riyadh, _riyadh]), isNull);
      expect(AppMap.fitOrNull(List.filled(50, _jeddah)), isNull);
    });

    test('a span below 1e-4° on both axes is one place', () {
      expect(
        AppMap.fitOrNull(const [LatLng(24, 46), LatLng(24.00005, 46.00009)]),
        isNull,
      );
      // GPS jitter around one spot, many samples.
      expect(
        AppMap.fitOrNull([
          for (var i = 0; i < 20; i++)
            LatLng(24 + (i % 3) * 0.00002, 46 - (i % 4) * 0.00002),
        ]),
        isNull,
      );
    });

    test('a span on either axis alone is enough', () {
      expect(
        AppMap.fitOrNull(const [LatLng(0, 0), LatLng(0.0002, 0)]),
        isNotNull,
      );
      expect(
        AppMap.fitOrNull(const [LatLng(0, 0), LatLng(0, 0.0002)]),
        isNotNull,
      );
    });

    test('exactly 1e-4° is already an area', () {
      expect(
        AppMap.fitOrNull(const [LatLng(0, 0), LatLng(0.0001, 0)]),
        isNotNull,
      );
    });

    test('a real span frames the bounding box with the default padding', () {
      final fit = AppMap.fitOrNull(const [_riyadh, _jeddah, LatLng(23, 45)]);
      expect(fit, isA<FitBounds>());
      final bounds = (fit! as FitBounds).bounds;
      expect(bounds.north, _riyadh.latitude);
      expect(bounds.south, _jeddah.latitude);
      expect(bounds.east, _riyadh.longitude);
      expect(bounds.west, _jeddah.longitude);
      expect((fit as FitBounds).padding, const EdgeInsets.all(Insets.x12));
      expect(fit.maxZoom, isNull);
    });

    test('padding and maxZoom are passed through', () {
      final fit =
          AppMap.fitOrNull(
                const [_riyadh, _jeddah],
                padding: const EdgeInsets.fromLTRB(1, 2, 3, 4),
                maxZoom: 15,
              )!
              as FitBounds;
      expect(fit.padding, const EdgeInsets.fromLTRB(1, 2, 3, 4));
      expect(fit.maxZoom, 15);
    });

    test('the input list is not modified', () {
      final points = [_jeddah, _riyadh];
      AppMap.fitOrNull(points);
      expect(points, [_jeddah, _riyadh]);
    });

    test('the fallback centre is the configured coordinate', () {
      expect(AppMap.fallbackCenter.latitude, AppConstants.mapFallbackLat);
      expect(AppMap.fallbackCenter.longitude, AppConstants.mapFallbackLng);
    });
  });

  group('AppMap layout', () {
    testOnEverySurface(
      'map with layers, a long legend and a FAB renders every part',
      (s) => _map(s),
      verify: (tester, s) async {
        expect(find.byType(FlutterMap), findsOneWidget);
        expect(find.byType(AppMapTileLayer), findsOneWidget);
        expect(find.byType(MarkerLayer), findsOneWidget);
        expect(find.byType(PolylineLayer), findsOneWidget);
        expect(find.byKey(_legend), findsOneWidget);
        expect(find.byKey(_fab), findsOneWidget);
        expect(find.byType(AppMapAttribution), findsOneWidget);
        expect(find.text(AppConstants.osmAttribution), findsOneWidget);
        // Dimmed in dark mode only.
        expect(
          _dim,
          s.brightness == Brightness.dark ? findsOneWidget : findsNothing,
        );
        // The map fills whatever it is given.
        expect(
          tester.getSize(find.byType(FlutterMap)),
          tester.getSize(find.byType(AppMap)),
        );
      },
    );

    for (final s in surfaces) {
      testWidgets('a map fitted to real points renders with a finite camera '
          '— $s', (tester) async {
        await _ignoringTileErrors(tester, () async {
          await pumpSurface(
            tester,
            s,
            _map(s, fit: AppMap.fitOrNull(const [_riyadh, _jeddah])),
          );
          expectCleanLayout(tester);
          final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
          expect(camera.zoom.isFinite, isTrue);
          expect(camera.center.latitude.isFinite, isTrue);
          expect(camera.visibleBounds.contains(_riyadh), isTrue);
          expect(camera.visibleBounds.contains(_jeddah), isTrue);
          expect(find.byKey(_fab), findsOneWidget);
          expectCleanLayout(tester);
        });
      });
    }
  });

  group('AppMap dark-mode dimming', () {
    final dark = surfaces[2];

    testWidgets('light mode draws no dim layer', (tester) async {
      await pumpSurface(tester, phoneEn, _map(phoneEn));
      expect(_dim, findsNothing);
      expectCleanLayout(tester);
    });

    testWidgets('dark mode dims the whole map, under the overlays', (
      tester,
    ) async {
      await pumpSurface(tester, dark, _map(dark));
      expectCleanLayout(tester);
      expect(_dim, findsOneWidget);
      expect(tester.getRect(_dim), tester.getRect(find.byType(AppMap)));
      expect(
        find.ancestor(of: _dim, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );

      // Order: map, then dim, then overlays — the chrome is never dimmed.
      final children = _stack(tester).children;
      expect(children.first, isA<FlutterMap>());
      expect(children[1], isA<IgnorePointer>());
      expect((children[1] as IgnorePointer).ignoring, isTrue);
      expect(children.skip(2), everyElement(isA<PositionedDirectional>()));
    });

    testWidgets('dimInDarkMode: false leaves a dark map undimmed', (
      tester,
    ) async {
      await pumpSurface(tester, dark, _map(dark, dimInDarkMode: false));
      expectCleanLayout(tester);
      expect(_dim, findsNothing);
      expect(_stack(tester).children[1], isA<PositionedDirectional>());
    });

    testWidgets('dimInDarkMode has no effect in light mode', (tester) async {
      await pumpSurface(tester, phoneEn, _map(phoneEn, dimInDarkMode: false));
      expectCleanLayout(tester);
      expect(_dim, findsNothing);
    });

    testWidgets('the dim layer lets taps through to the map', (tester) async {
      final taps = <LatLng>[];
      await pumpSurface(
        tester,
        dark,
        _map(dark, onTap: (_, point) => taps.add(point)),
      );
      await tester.tapAt(tester.getCenter(find.byType(AppMap)));
      await tester.pump(const Duration(milliseconds: 500));
      expectCleanLayout(tester);
      expect(taps, hasLength(1));
      expect(taps.single.latitude, closeTo(_riyadh.latitude, 1e-3));
      expect(taps.single.longitude, closeTo(_riyadh.longitude, 1e-3));
    });

    testWidgets('overlays stay tappable above the dim layer', (tester) async {
      var presses = 0;
      await pumpSurface(tester, dark, _map(dark, onFab: () => presses++));
      await tester.tap(find.byKey(_fab));
      await tester.pump(const Duration(milliseconds: 500));
      expectCleanLayout(tester);
      expect(presses, 1);
    });

    testWidgets('the credit badge stays tappable above the dim layer', (
      tester,
    ) async {
      final launched = _mockLauncher(tester);
      final mapTaps = <LatLng>[];
      await pumpSurface(
        tester,
        dark,
        _map(dark, onTap: (_, p) => mapTaps.add(p)),
      );
      await tester.tap(find.text(AppConstants.osmAttribution));
      await tester.pump(const Duration(milliseconds: 500));
      expectCleanLayout(tester);
      expect(launched, [AppConstants.osmCopyrightUrl]);
      expect(mapTaps, isEmpty, reason: 'the credit tap also hit the map');
    });
  });

  group('AppMap composition', () {
    testWidgets('options: centre, zoom bounds, background per theme', (
      tester,
    ) async {
      for (final s in [phoneEn, surfaces[2]]) {
        await pumpSurface(tester, s, _map(s));
        final options = _flutterMap(tester).options;
        expect(options.initialCenter, _riyadh);
        expect(options.initialZoom, AppConstants.defaultMapZoom);
        expect(options.minZoom, AppConstants.mapMinZoom);
        expect(options.maxZoom, AppConstants.mapMaxZoom);
        expect(
          options.backgroundColor,
          AppColors.mapBackground(s.brightness == Brightness.dark),
          reason: '$s',
        );
        expectCleanLayout(tester);
      }
    });

    testWidgets('interactive toggles every gesture on or off', (tester) async {
      await pumpSurface(tester, phoneEn, _map(phoneEn));
      expect(
        _flutterMap(tester).options.interactionOptions.flags,
        InteractiveFlag.all,
      );

      await pumpSurface(tester, phoneEn, _map(phoneEn, interactive: false));
      expect(
        _flutterMap(tester).options.interactionOptions.flags,
        InteractiveFlag.none,
      );
      expectCleanLayout(tester);
    });

    testWidgets('a static preview does not pan when dragged', (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      await pumpSurface(
        tester,
        phoneEn,
        _map(phoneEn, controller: controller, interactive: false),
      );
      final before = controller.camera.center;
      await tester.drag(find.byType(AppMap), const Offset(-150, 120));
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.camera.center, before);
      expectCleanLayout(tester);
    });

    testWidgets('an interactive map pans when dragged', (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      await pumpSurface(tester, phoneEn, _map(phoneEn, controller: controller));
      final before = controller.camera.center;
      await tester.drag(find.byType(AppMap), const Offset(-150, 120));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.camera.center, isNot(before));
      expectCleanLayout(tester);
    });

    testWidgets('children: tiles first, caller layers in order, credit last', (
      tester,
    ) async {
      await pumpSurface(tester, phoneEn, _map(phoneEn));
      final children = _flutterMap(tester).children;
      expect(children, hasLength(4));
      expect(children[0], isA<AppMapTileLayer>());
      expect(children[1], isA<PolylineLayer>());
      expect(children[2], isA<MarkerLayer>());
      expect(children[3], isA<AppMapAttribution>());
      expectCleanLayout(tester);
    });

    testWidgets('a map with no layers or overlays still has tiles and credit', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        phoneEn,
        const AppMap(initialCenter: AppMap.fallbackCenter),
      );
      final children = _flutterMap(tester).children;
      expect(children, hasLength(2));
      expect(children.first, isA<AppMapTileLayer>());
      expect(children.last, isA<AppMapAttribution>());
      expect(_stack(tester).children, hasLength(1));
      expectCleanLayout(tester);
    });

    testWidgets('tile options are forwarded to the tile layer', (tester) async {
      Widget tint(BuildContext _, Widget tile, TileImage __) => tile;
      await pumpSurface(
        tester,
        phoneEn,
        AppMap(
          initialCenter: _riyadh,
          panBuffer: 3,
          keepBuffer: 5,
          tileBuilder: tint,
        ),
      );
      final layer = tester.widget<AppMapTileLayer>(
        find.byType(AppMapTileLayer),
      );
      expect(layer.panBuffer, 3);
      expect(layer.keepBuffer, 5);
      expect(layer.tileBuilder, same(tint));
      expect(layer.maxZoom, AppConstants.mapMaxZoom);

      await pumpSurface(tester, phoneEn, const AppMap(initialCenter: _riyadh));
      final defaults = tester.widget<AppMapTileLayer>(
        find.byType(AppMapTileLayer),
      );
      expect(defaults.panBuffer, 1);
      expect(defaults.keepBuffer, 2);
      expect(defaults.tileBuilder, isNull);
      expectCleanLayout(tester);
    });

    testWidgets('the credit badge uses the requested corner', (tester) async {
      await pumpSurface(tester, phoneEn, _map(phoneEn));
      expect(
        tester
            .widget<AppMapAttribution>(find.byType(AppMapAttribution))
            .alignment,
        Alignment.bottomRight,
      );
      final map = tester.getRect(find.byType(AppMap));
      var badge = tester.getRect(find.text(AppConstants.osmAttribution));
      expect(badge.center.dx, greaterThan(map.center.dx));
      expect(badge.center.dy, greaterThan(map.center.dy));

      await pumpSurface(
        tester,
        phoneEn,
        _map(phoneEn, attributionAlignment: Alignment.bottomLeft),
      );
      badge = tester.getRect(find.text(AppConstants.osmAttribution));
      expect(badge.center.dx, lessThan(map.center.dx));
      expect(badge.center.dy, greaterThan(map.center.dy));
      expectCleanLayout(tester);
    });

    testWidgets('a controller is attached at the initial camera', (
      tester,
    ) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      await pumpSurface(tester, phoneEn, _map(phoneEn, controller: controller));
      expect(
        controller.camera.center.latitude,
        closeTo(_riyadh.latitude, 1e-9),
      );
      expect(
        controller.camera.center.longitude,
        closeTo(_riyadh.longitude, 1e-9),
      );
      expect(controller.camera.zoom, AppConstants.defaultMapZoom);
      expectCleanLayout(tester);
    });

    testWidgets('a fitted camera shows every point, within the zoom bounds', (
      tester,
    ) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      const points = [_riyadh, _jeddah];
      await _ignoringTileErrors(tester, () async {
        await pumpSurface(
          tester,
          phoneEn,
          _map(phoneEn, controller: controller, fit: AppMap.fitOrNull(points)),
        );
        expectCleanLayout(tester);
        final camera = controller.camera;
        expect(
          camera.zoom,
          inInclusiveRange(AppConstants.mapMinZoom, AppConstants.mapMaxZoom),
        );
        expect(camera.zoom, lessThan(AppConstants.defaultMapZoom));
        for (final p in points) {
          expect(camera.visibleBounds.contains(p), isTrue, reason: '$p');
        }
      });
    });

    testWidgets('a fit with maxZoom never zooms past it', (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      await _ignoringTileErrors(tester, () async {
        await pumpSurface(
          tester,
          phoneEn,
          _map(
            phoneEn,
            controller: controller,
            // Two points 20m apart would otherwise fit at a street-level zoom.
            fit: AppMap.fitOrNull(const [
              LatLng(24.7136, 46.6753),
              LatLng(24.7138, 46.6753),
            ], maxZoom: 14),
          ),
        );
        expectCleanLayout(tester);
        expect(controller.camera.zoom, lessThanOrEqualTo(14));
      });
    });

    testWidgets('the fallback path (no fit) keeps the fixed zoom', (
      tester,
    ) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      await pumpSurface(
        tester,
        phoneEn,
        _map(
          phoneEn,
          controller: controller,
          fit: AppMap.fitOrNull(const [_riyadh, _riyadh]),
        ),
      );
      expect(controller.camera.zoom, AppConstants.defaultMapZoom);
      expect(controller.camera.zoom.isFinite, isTrue);
      expectCleanLayout(tester);
    });

    testWidgets('directional overlays mirror in Arabic', (tester) async {
      Future<Rect> fab(Surface s) async {
        await pumpSurface(tester, s, _map(s));
        return tester.getRect(find.byKey(_fab));
      }

      final map = Rect.fromLTWH(0, 0, phoneEn.size.width, phoneEn.size.height);
      final en = await fab(phoneEn);
      final ar = await fab(phoneAr);
      expect(en.center.dx, greaterThan(map.center.dx));
      expect(ar.center.dx, lessThan(map.center.dx));
      expect(en.right, moreOrLessEquals(map.width - ar.left));
      expectCleanLayout(tester);
    });
  });
}
