import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/core/di/service_locator.dart';
import 'package:location_gps/core/map_matching/osrm_map_matcher.dart';
import 'package:location_gps/core/map_matching/route_geometry.dart';
import 'package:location_gps/core/map_matching/route_matcher.dart';
import 'package:location_gps/shared/widgets/matched_route_builder.dart';

import 'widget_harness.dart';

final DateTime _t0 = DateTime.utc(2026, 9, 13, 12);

/// A trace heading east along [lat], one fix every ~50 m and 5 s.
List<TracePoint> _trace(int n, {double lat = 24.7, int startSecond = 0}) => [
      for (var i = 0; i < n; i++)
        TracePoint(
          latitude: lat,
          longitude: 46.67 + i * 50 / 101000,
          time: _t0.add(Duration(seconds: startSecond + 5 * i)),
          accuracy: 5,
        ),
    ];

/// Stand-in matching service (the same seam `route_matching_test.dart`
/// uses): every edge "matched" through a midpoint bent 3 m north. [gate], when
/// set, holds every answer until it completes.
class _FakeMatcher implements MapMatcher {
  _FakeMatcher({this.size = 50});
  final int size;
  final List<int> requestSizes = [];
  Completer<void>? gate;
  MapMatchingException? failWith;

  @override
  String get cacheId => 'fake';

  @override
  int get maxPoints => size;

  @override
  Future<List<List<LatLng>?>> match(List<TracePoint> points) async {
    requestSizes.add(points.length);
    final g = gate;
    if (g != null) await g.future;
    if (failWith != null) throw failWith!;
    return [
      for (var i = 0; i < points.length - 1; i++)
        [
          points[i].latLng,
          LatLng(
            (points[i].latitude + points[i + 1].latitude) / 2 + 0.00003,
            (points[i].longitude + points[i + 1].longitude) / 2,
          ),
          points[i + 1].latLng,
        ],
    ];
  }
}

RouteMatcher _routeMatcher(MapMatcher? m) =>
    RouteMatcher(matcher: m, requestSpacing: Duration.zero);

/// Records every geometry list the builder is handed (copied: the widget
/// updates its list in place).
class _Probe {
  final List<List<RouteGeometry>> builds = [];
  List<RouteGeometry> get last => builds.last;

  static String describe(List<RouteGeometry> g) => [
        for (final x in g) '${x.source.name}${x.pending ? '…' : ''}',
      ].join(',');
}

/// A host whose traces can be swapped with [_HostState.show].
class _Host extends StatefulWidget {
  final List<List<TracePoint>> initial;
  final _Probe probe;
  final RouteMatcher? matcher;
  const _Host(this.initial, this.probe, {this.matcher, super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<List<TracePoint>> traces = widget.initial;

  void show(List<List<TracePoint>> next) => setState(() => traces = next);

  @override
  Widget build(BuildContext context) => MatchedRouteBuilder(
        traces: traces,
        matcher: widget.matcher,
        builder: (context, g) {
          widget.probe.builds.add(List.of(g));
          return Text(_Probe.describe(g));
        },
      );
}

final _hostKey = GlobalKey<_HostState>();

Future<void> _pumpHost(
  WidgetTester tester,
  List<List<TracePoint>> traces,
  _Probe probe, {
  RouteMatcher? matcher,
}) =>
    pumpSurface(
      tester,
      phoneEn,
      _Host(traces, probe, matcher: matcher, key: _hostKey),
      settle: Duration.zero,
    );

/// Lets the matcher's futures and the resulting rebuilds run.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  setUpAll(initHarness);
  tearDown(() => sl.reset());

  testOnEverySurface(
    'several raw traces render through the builder',
    (s) => MatchedRouteBuilder(
      traces: [_trace(12), _trace(1), const [], _trace(300, lat: 24.8)],
      builder: (context, geometries) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in geometries)
              Text(
                '${LongText.of(s)} — ${g.fixes.length} · ${g.source.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    ),
    verify: (tester, _) async {
      expect(find.textContaining('· raw'), findsNWidgets(4));
    },
  );

  group('without a road matcher', () {
    testWidgets('every trace is built raw, once, with nothing pending',
        (tester) async {
      expect(sl.isRegistered<RouteMatcher>(), isFalse);
      final probe = _Probe();
      final a = _trace(6);
      final b = _trace(3, lat: 24.9);
      await _pumpHost(tester, [a, b], probe);
      await _drain(tester);
      await tester.pump(const Duration(seconds: 5));

      expect(probe.builds, hasLength(1));
      final g = probe.last;
      expect(_Probe.describe(g), 'raw,raw');
      expect(g[0].fixes, [for (final p in a) p.latLng]);
      expect(g[1].fixes, [for (final p in b) p.latLng]);
      // Straight lines between the recorded fixes.
      expect(g[0].edges, hasLength(5));
      expect(g[0].edges.every((e) => e.length == 2), isTrue);
      expect(g[0].path(), g[0].fixes);
    });

    testWidgets('no traces builds an empty list', (tester) async {
      final probe = _Probe();
      await _pumpHost(tester, const [], probe);
      expect(probe.builds.single, isEmpty);
      expect(find.text(''), findsOneWidget);
    });

    testWidgets('a registered but disabled matcher also draws raw',
        (tester) async {
      sl.registerSingleton<RouteMatcher>(_routeMatcher(null));
      final probe = _Probe();
      await _pumpHost(tester, [_trace(6)], probe);
      await _drain(tester);
      expect(probe.builds, hasLength(1));
      expect(_Probe.describe(probe.last), 'raw');
    });
  });

  group('with a road matcher', () {
    testWidgets('draws raw at once, then rebuilds with the matched roads',
        (tester) async {
      final fake = _FakeMatcher();
      sl.registerSingleton<RouteMatcher>(_routeMatcher(fake));
      final probe = _Probe();
      await _pumpHost(tester, [_trace(6)], probe);

      // The first frame never waits for the network.
      expect(_Probe.describe(probe.builds.first), 'raw…');

      await _drain(tester);
      expect(_Probe.describe(probe.last), 'matched');
      expect(find.text('matched'), findsOneWidget);
      expect(fake.requestSizes, [6]);
      // The recorded fixes are untouched; only the line between them bends.
      expect(probe.last.single.fixes, [for (final p in _trace(6)) p.latLng]);
      expect(probe.last.single.edges.first, hasLength(3));
    });

    testWidgets('an explicit matcher wins over the registered one',
        (tester) async {
      final registered = _FakeMatcher();
      final explicit = _FakeMatcher();
      sl.registerSingleton<RouteMatcher>(_routeMatcher(registered));
      final probe = _Probe();
      await _pumpHost(tester, [_trace(4)], probe,
          matcher: _routeMatcher(explicit));
      await _drain(tester);
      expect(explicit.requestSizes, [4]);
      expect(registered.requestSizes, isEmpty);
      expect(_Probe.describe(probe.last), 'matched');
    });

    testWidgets('each trace resolves on its own; short traces never wait',
        (tester) async {
      final fake = _FakeMatcher();
      final probe = _Probe();
      await _pumpHost(
        tester,
        [_trace(5), _trace(1), const [], _trace(3, lat: 25)],
        probe,
        matcher: _routeMatcher(fake),
      );
      expect(_Probe.describe(probe.builds.first), 'raw…,raw,raw,raw…');
      await _drain(tester);
      expect(_Probe.describe(probe.last), 'matched,raw,raw,matched');
      expect(fake.requestSizes, [5, 3]);
    });

    testWidgets('a rebuild with the same fixes does not match again',
        (tester) async {
      final fake = _FakeMatcher();
      final probe = _Probe();
      await _pumpHost(tester, [_trace(6)], probe, matcher: _routeMatcher(fake));
      await _drain(tester);
      final builds = probe.builds.length;

      // New list instances, identical fixes: a pan, a zoom, a parent rebuild.
      for (var i = 0; i < 3; i++) {
        _hostKey.currentState!.show([_trace(6)]);
        await _drain(tester);
      }
      expect(fake.requestSizes, [6]);
      expect(probe.builds.length, builds + 3);
      // Kept, not reset to raw while it waits for nothing.
      expect(
        probe.builds.skip(builds).map(_Probe.describe),
        everyElement('matched'),
      );
    });

    testWidgets('a grown trace re-sends only its last stretch',
        (tester) async {
      final fake = _FakeMatcher(size: 5);
      final probe = _Probe();
      // 9 fixes in chunks of 5 sharing a fix: [0–4] and [4–8].
      await _pumpHost(tester, [_trace(9)], probe, matcher: _routeMatcher(fake));
      await _drain(tester);
      expect(fake.requestSizes, [5, 5]);
      expect(_Probe.describe(probe.last), 'matched');

      final before = probe.builds.length;
      _hostKey.currentState!.show([_trace(10)]);
      await tester.pump();
      // The two finished stretches come straight from the cache.
      final first = probe.builds[before].single;
      expect(first.pending, isTrue);
      expect(first.source, RouteGeometrySource.partial);
      expect(first.matchedEdges, 8);

      await _drain(tester);
      expect(fake.requestSizes, [5, 5, 2]);
      expect(_Probe.describe(probe.last), 'matched');
      expect(probe.last.single.edges, hasLength(9));
    });

    testWidgets("a fix's time is part of the trace: a shifted trace re-matches",
        (tester) async {
      final fake = _FakeMatcher();
      final probe = _Probe();
      await _pumpHost(tester, [_trace(4)], probe, matcher: _routeMatcher(fake));
      await _drain(tester);
      _hostKey.currentState!.show([_trace(4, startSecond: 60)]);
      await _drain(tester);
      // Same relative spacing, so the cache still answers — but the widget
      // did ask again rather than keep the old trace's geometry.
      expect(_Probe.describe(probe.last), 'matched');
      _hostKey.currentState!.show([_trace(4, lat: 24.5)]);
      await _drain(tester);
      expect(fake.requestSizes, [4, 4]);
      expect(probe.last.single.fixes.first.latitude, 24.5);
    });

    testWidgets('a trace matched once is drawn matched on the first frame',
        (tester) async {
      final fake = _FakeMatcher();
      final matcher = _routeMatcher(fake);
      final first = _Probe();
      await _pumpHost(tester, [_trace(6)], first, matcher: matcher);
      await _drain(tester);

      // A different screen showing the same trace.
      final second = _Probe();
      await pumpSurface(
        tester,
        phoneEn,
        _Host([_trace(6)], second, matcher: matcher),
        settle: Duration.zero,
      );
      expect(_Probe.describe(second.builds.first), 'matched');
      await _drain(tester);
      expect(second.builds, hasLength(1));
      expect(fake.requestSizes, [6]);
    });

    for (final retryable in [true, false]) {
      testWidgets(
          'a ${retryable ? 'transient' : 'refused'} failure settles on raw',
          (tester) async {
        final fake = _FakeMatcher()
          ..failWith = MapMatchingException('down', retryable: retryable);
        final probe = _Probe();
        await _pumpHost(tester, [_trace(6)], probe,
            matcher: _routeMatcher(fake));
        await _drain(tester);
        expect(_Probe.describe(probe.last), 'raw');
        expect(probe.last.single.pending, isFalse);
        expectCleanLayout(tester);
      });
    }

    testWidgets('a result for a trace no longer shown is dropped',
        (tester) async {
      final fake = _FakeMatcher()..gate = Completer<void>();
      final probe = _Probe();
      await _pumpHost(tester, [_trace(6)], probe, matcher: _routeMatcher(fake));
      await tester.pump();
      expect(_Probe.describe(probe.last), 'raw…');

      final other = _trace(6, lat: 25.3);
      _hostKey.currentState!.show([other]);
      await tester.pump();
      expect(probe.last.single.fixes.first.latitude, 25.3);

      fake.gate!.complete();
      await _drain(tester);
      // Only the trace on screen is ever drawn, and it ends up matched.
      for (final build in probe.builds.skip(2)) {
        expect(build.single.fixes.first.latitude, 25.3);
      }
      expect(_Probe.describe(probe.last), 'matched');
    });

    testWidgets('an answer arriving after dispose is ignored', (tester) async {
      final fake = _FakeMatcher()..gate = Completer<void>();
      final probe = _Probe();
      await _pumpHost(tester, [_trace(6)], probe, matcher: _routeMatcher(fake));
      await tester.pump();
      final builds = probe.builds.length;

      await pumpSurface(tester, phoneEn, const SizedBox(),
          settle: Duration.zero);
      fake.gate!.complete();
      await _drain(tester);

      expect(probe.builds, hasLength(builds));
      expect(tester.takeException(), isNull);
    });
  });
}
