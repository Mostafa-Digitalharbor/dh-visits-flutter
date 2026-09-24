import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/app/theme.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/map_matching/route_geometry.dart';
import 'package:location_gps/core/map_matching/route_matcher.dart';
import 'package:location_gps/core/utils/app_number.dart';
import 'package:location_gps/features/route/bloc/day_trails_cubit.dart';
import 'package:location_gps/features/route/view/route_map.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/shared/widgets/widgets.dart';

import '../../widgets/widget_harness.dart';
import '../feature_fakes.dart';

List<Visit> _stops(int n) => [
      for (var i = 0; i < n; i++)
        Visit(
          id: 200 + i,
          partnerName: LongText.arabicCompany,
          scheduledDatetime: fixtureDay.add(Duration(hours: i)),
          latitude: 24.68 + i * 0.006,
          longitude: 46.64 + (i.isEven ? 0.01 : -0.01),
        ),
    ];

List<LatLng> _pointsOf(List<Visit> stops) =>
    [for (final v in stops) LatLng(v.latitude!, v.longitude!)];

DayTrail _trail(int visitId, int fixes) => DayTrail(
      visit: Visit(id: visitId, partnerName: 'Acme', startDatetime: fixtureDay),
      track: VisitTrack(
        visitId: visitId,
        locationLogCount: fixes,
        logs: trailLogs(fixes),
      ),
    );

List<RouteGeometry> _rawGeometries(List<DayTrail> trails) =>
    [for (final t in trails) RouteGeometry.raw(t.track.logs.trace)];

/// A geometry whose every edge follows a detour, so "roads" and "raw" lines
/// are told apart by their vertex count.
RouteGeometry _roadGeometry(DayTrail trail) {
  final fixes = latLngs(trail.track.logs);
  return RouteGeometry.fromRoads(fixes, [
    for (var i = 0; i < fixes.length - 1; i++)
      [
        fixes[i],
        LatLng(fixes[i].latitude, fixes[i + 1].longitude),
        fixes[i + 1],
      ],
  ]);
}

Widget _map({
  List<Visit>? stops,
  int nextIndex = 0,
  double km = 12.4,
  List<DayTrail> trails = const [],
  List<RouteGeometry>? geometries,
  RouteLineMode mode = RouteLineMode.roads,
  ValueChanged<RouteLineMode>? onLineMode,
  Key? key,
}) {
  final s = stops ?? _stops(3);
  return RouteMap(
    key: key,
    stops: s,
    points: _pointsOf(s),
    nextIndex: nextIndex,
    stopsKm: km,
    trails: trails,
    trailGeometries: geometries ?? _rawGeometries(trails),
    lineMode: mode,
    onLineMode: onLineMode ?? (_) {},
  );
}

MapCamera _camera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(MarkerLayer).first));

void _enableMatching() {
  sl.registerSingleton<RouteMatcher>(RouteMatcher(matcher: NoRoadMatcher()));
}

void main() {
  setUpAll(initHarness);
  tearDown(() => sl.reset());

  group('RouteMap layout', () {
    testMapOnEverySurface(
      'a busy day: 12 stops, three trails, summary chip and line toggle',
      (s) {
        if (!sl.isRegistered<RouteMatcher>()) _enableMatching();
        final trails = [_trail(1, 6), _trail(2, 1), _trail(3, 9)];
        return _map(stops: _stops(12), nextIndex: 4, km: 1234.5, trails: trails);
      },
      verify: (tester, s) async {
        final t = l10n(s.locale);
        final summary = '${t.routeStopsCount(12)}${t.commonListSeparator}'
            '${AppNumber.km(t, 1234.5)}';
        expect(find.text(summary), findsOneWidget);
        expect(find.byType(RouteLineToggle), findsOneWidget);

        // The chip and the toggle share the top edge without overlapping.
        final chip = tester.getRect(find
            .ancestor(of: find.text(summary), matching: find.byType(Container))
            .first);
        final toggle = tester.getRect(find.byType(RouteLineToggle));
        final map = tester.getRect(find.byType(RouteMap));
        expect(chip.overlaps(toggle), isFalse);
        expect(chip.width, greaterThanOrEqualTo(40),
            reason: 'the chip keeps room for its glyph and an ellipsis');
        expect(map.contains(chip.topLeft) && map.contains(chip.bottomRight),
            isTrue);
        expect(
            map.contains(toggle.topLeft) && map.contains(toggle.bottomRight),
            isTrue);

        // Every stop is framed: one numbered pin each, one "next".
        final pins =
            tester.widgetList<StopNumberPin>(find.byType(StopNumberPin));
        expect(pins.map((p) => p.number), [for (var i = 1; i <= 12; i++) i]);
        expect(pins.where((p) => p.isNext).map((p) => p.number), [5]);

        // The camera actually frames the day rather than the whole world.
        final zoom = _camera(tester).zoom;
        expect(zoom.isFinite, isTrue);
        expect(zoom, greaterThan(AppConstants.mapMinZoom + 3));

        // Capped against the screen so the list below keeps its share.
        expect(
          tester.getSize(find.byType(RouteMap)).height,
          moreOrLessEquals(
            s.size.height * RouteMapStyle.maxScreenShare < CompSz.routeMapMax
                ? s.size.height * RouteMapStyle.maxScreenShare
                : CompSz.routeMapMax,
          ),
        );
      },
    );

    testMapOnEverySurface(
      'an empty day: no chip, no toggle, the fallback centre',
      (s) => _map(stops: const []),
      verify: (tester, s) async {
        expect(find.byType(StopNumberPin), findsNothing);
        expect(find.byType(RouteLineToggle), findsNothing);
        expect(find.textContaining(l10n(s.locale).commonListSeparator),
            findsNothing);
        final map = tester.widget<AppMap>(find.byType(AppMap));
        expect(map.initialCenter, AppMap.fallbackCenter);
        expect(map.initialCameraFit, isNull);
      },
    );
  });

  group('RouteMap behaviour', () {
    testMapWidgets('draws the planned route only between two or more stops',
        (tester) async {
      await pumpSurface(tester, phoneEn, _map(stops: _stops(1)));
      expect(find.byType(PolylineLayer), findsOneWidget,
          reason: 'only the (empty) trails layer');

      final stops = _stops(4);
      await pumpSurface(tester, phoneEn, _map(stops: stops));
      final layers =
          tester.widgetList<PolylineLayer>(find.byType(PolylineLayer)).toList();
      expect(layers, hasLength(2));
      final planned = layers.first.polylines.single;
      expect(planned.points, _pointsOf(stops));
      expect(planned.color, AppColors.onMap);
      final context = tester.element(find.byType(RouteMap));
      expect(planned.borderColor, Theme.of(context).colorScheme.primary);
    });

    testMapWidgets('each trail is its own line in its own colour, never joined',
        (tester) async {
      final trails = [_trail(1, 3), _trail(2, 1), _trail(3, 4)];
      await pumpSurface(tester, phoneEn, _map(trails: trails));
      final recorded = tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .last
          .polylines;
      // The single-fix trail is a dot, not a line.
      expect(recorded, hasLength(2));
      expect(recorded[0].points, latLngs(trails[0].track.logs));
      expect(recorded[0].color, AppColors.routePaletteAt(0));
      expect(recorded[1].points, latLngs(trails[2].track.logs));
      expect(recorded[1].color, AppColors.routePaletteAt(2));
    });

    testMapWidgets('roads mode draws the matched geometry, raw the fixes',
        (tester) async {
      final trail = _trail(1, 3);
      final roads = _roadGeometry(trail);
      await pumpSurface(
        tester,
        phoneEn,
        _map(trails: [trail], geometries: [roads]),
      );
      List<LatLng> drawn() => tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .last
          .polylines
          .single
          .points;
      expect(drawn(), roads.path());
      expect(drawn(), hasLength(5));

      await pumpSurface(
        tester,
        phoneEn,
        _map(trails: [trail], geometries: [roads], mode: RouteLineMode.raw),
      );
      expect(drawn(), latLngs(trail.track.logs));
    });

    testMapWidgets('geometries still loading fall back to the fixes',
        (tester) async {
      final trails = [_trail(1, 3), _trail(2, 3)];
      await pumpSurface(
        tester,
        phoneEn,
        _map(trails: trails, geometries: [_roadGeometry(trails[0])]),
      );
      final lines = tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .last
          .polylines;
      expect(lines[0].points, hasLength(5));
      expect(lines[1].points, latLngs(trails[1].track.logs));
    });

    testMapWidgets('trail ends are capped: start green, end in trail colour',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _map(stops: const [], trails: [_trail(1, 4), _trail(2, 1)]),
      );
      final dots = tester
          .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(MarkerLayer),
            matching: find.byType(DecoratedBox),
          ))
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();
      expect(dots, [
        AppColors.routeStart,
        AppColors.routePaletteAt(0),
        AppColors.routeStart, // a single fix gets only its start dot
      ]);
    });

    testMapWidgets('a trail with no fixes is skipped, not a crash',
        (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        _map(trails: [_trail(1, 0), _trail(2, 3)]),
      );
      expectCleanLayout(tester);
      expect(
        tester
            .widgetList<PolylineLayer>(find.byType(PolylineLayer))
            .last
            .polylines,
        hasLength(1),
      );
    });

    testMapWidgets('the toggle needs an enabled matcher', (tester) async {
      final trails = [_trail(1, 4)];
      await pumpSurface(tester, phoneEn, _map(trails: trails));
      expect(find.byType(RouteLineToggle), findsNothing,
          reason: 'no matcher registered');

      sl.registerSingleton<RouteMatcher>(RouteMatcher(matcher: null));
      await pumpSurface(tester, phoneEn, _map(trails: trails, key: UniqueKey()));
      expect(find.byType(RouteLineToggle), findsNothing,
          reason: 'matching disabled');
    });

    testMapWidgets('the toggle needs a trail with a line to switch',
        (tester) async {
      _enableMatching();
      await pumpSurface(tester, phoneEn, _map(trails: [_trail(1, 1)]));
      expect(find.byType(RouteLineToggle), findsNothing);

      await pumpSurface(
          tester, phoneEn, _map(trails: [_trail(1, 1), _trail(2, 2)]));
      expect(find.byType(RouteLineToggle), findsOneWidget);
    });

    testMapWidgets('switching the line reports the new mode once',
        (tester) async {
      _enableMatching();
      final modes = <RouteLineMode>[];
      await pumpSurface(
        tester,
        phoneEn,
        _map(trails: [_trail(1, 3)], onLineMode: modes.add),
      );
      await tester.tap(find.text(l10n(english).routeLineGps));
      await tester.pump();
      expect(modes, [RouteLineMode.raw]);

      // The selected segment does nothing.
      await tester.tap(find.text(l10n(english).routeLineRoads));
      await tester.pump();
      expect(modes, [RouteLineMode.raw]);
    });

    testMapWidgets('the toggle reports matching state', (tester) async {
      _enableMatching();
      final trail = _trail(1, 3);
      final pending = RouteGeometry.raw(trail.track.logs.trace, pending: true);
      await pumpSurface(
        tester,
        phoneAr,
        _map(trails: [trail], geometries: [pending]),
      );
      final toggle =
          tester.widget<RouteLineToggle>(find.byType(RouteLineToggle));
      expect(toggle.pending, isTrue);
      expect(toggle.unmatched, isFalse);
      expect(find.text(l10n(arabic).routeLineMatching), findsOneWidget);

      await pumpSurface(
        tester,
        phoneAr,
        _map(
          trails: [trail],
          geometries: [RouteGeometry.raw(trail.track.logs.trace)],
        ),
      );
      expect(
        tester.widget<RouteLineToggle>(find.byType(RouteLineToggle)).unmatched,
        isTrue,
      );
    });

    testMapWidgets('the toggle sits at the end edge, the chip at the start',
        (tester) async {
      _enableMatching();
      for (final s in const [phoneEn, phoneAr]) {
        await pumpSurface(tester, s, _map(trails: [_trail(1, 3)]));
        final chip = tester.getCenter(find.textContaining(
            l10n(s.locale).routeStopsCount(3)));
        final toggle = tester.getCenter(find.byType(RouteLineToggle));
        expect(chip.dx < toggle.dx, s == phoneEn, reason: s.name);
      }
    });

    testMapWidgets('the gap between chip and toggle leaves the map touchable',
        (tester) async {
      _enableMatching();
      await pumpSurface(tester, phoneEn, _map(trails: [_trail(1, 3)]));
      final chip = tester.getRect(find
          .ancestor(
            of: find.textContaining(l10n(english).routeStopsCount(3)),
            matching: find.byType(Container),
          )
          .first);
      final toggle = tester.getRect(find.byType(RouteLineToggle));
      expect(toggle.left - chip.right, greaterThan(8));
      final gap = Offset((chip.right + toggle.left) / 2, chip.center.dy);
      final row = tester.renderObject(find
          .ancestor(of: find.byType(RouteLineToggle), matching: find.byType(Row))
          .first);
      final hit = HitTestResult();
      tester.binding.hitTestInView(hit, gap, tester.view.viewId);
      expect(hit.path.any((e) => e.target == row), isFalse);
      expect(
        hit.path.any((e) =>
            e.target == tester.renderObject(find.byType(FlutterMap))),
        isTrue,
      );
    });

    testMapWidgets('growing a trail keeps the camera; a new stop refits it',
        (tester) async {
      final stops = _stops(3);
      await pumpSurface(
          tester, phoneEn, _map(stops: stops, trails: [_trail(1, 2)]));
      final before = tester.widget<AppMap>(find.byType(AppMap)).key;

      await pumpSurface(
          tester, phoneEn, _map(stops: stops, trails: [_trail(1, 5)]));
      expect(tester.widget<AppMap>(find.byType(AppMap)).key, before);

      await pumpSurface(tester, phoneEn,
          _map(stops: _stops(4), trails: [_trail(1, 5)]));
      expect(tester.widget<AppMap>(find.byType(AppMap)).key, isNot(before));

      await pumpSurface(tester, phoneEn,
          _map(stops: _stops(4), trails: [_trail(1, 5), _trail(9, 2)]));
      expect(tester.widget<AppMap>(find.byType(AppMap)).key, isNot(before));
    });

    testMapWidgets('nextIndex -1 marks no stop as next', (tester) async {
      await pumpSurface(tester, phoneEn, _map(nextIndex: -1));
      expect(
        tester
            .widgetList<StopNumberPin>(find.byType(StopNumberPin))
            .where((p) => p.isNext),
        isEmpty,
      );
    });

    testMapWidgets('the summary chip is ink with a route glyph',
        (tester) async {
      await pumpSurface(tester, phoneEn, _map());
      final t = l10n(english);
      final text = '${t.routeStopsCount(3)}${t.commonListSeparator}'
          '${AppNumber.km(t, 12.4)}';
      final label = tester.widget<Text>(find.text(text));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.style?.color, AppColors.onMap);
      final chip = tester.widget<Container>(find
          .ancestor(of: find.text(text), matching: find.byType(Container))
          .first);
      expect((chip.decoration! as BoxDecoration).color, AppColors.ink);
    });
  });

  group('StopNumberPin', () {
    testOnEverySurface(
      'a row of pins up to three digits',
      (s) => Wrap(
        children: [
          for (final n in [1, 9, 10, 99, 100, 999])
            SizedBox.square(
              dimension: RouteMapStyle.stopPin,
              child: StopNumberPin(number: n, isNext: n == 10),
            ),
        ],
      ),
      verify: (tester, s) async {
        expect(find.text('999'), findsOneWidget);
      },
    );

    testWidgets('the next stop wears the brand gradient', (tester) async {
      await pumpSurface(
        tester,
        phoneAr,
        const Center(child: StopNumberPin(number: 3, isNext: true)),
      );
      final pin = tester.widget<MapPin>(find.byType(MapPin));
      final context = tester.element(find.byType(StopNumberPin));
      expect(pin.gradient, context.x.avatarGradient);
      expect(pin.color, isNull);
      expect(pin.size, RouteMapStyle.stopPin);
      expect(pin.borderWidth, RouteMapStyle.pinRing);
      expect(find.text('3'), findsOneWidget, reason: 'Latin digits in Arabic');
    });

    testWidgets('other stops are ink', (tester) async {
      await pumpSurface(
        tester,
        phoneEn,
        const Center(child: StopNumberPin(number: 1234, isNext: false)),
      );
      final pin = tester.widget<MapPin>(find.byType(MapPin));
      expect(pin.gradient, isNull);
      expect(pin.color, AppColors.ink);
      expect(find.text('1,234'), findsOneWidget);
    });
  });
}
