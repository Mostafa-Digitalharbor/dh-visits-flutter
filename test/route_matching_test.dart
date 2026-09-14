// Road-matched route display: raw GPS in, road geometry out — only where the
// match is believable, cached per unchanged stretch, raw on any failure.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_gps/core/map_matching/osrm_map_matcher.dart';
import 'package:location_gps/core/map_matching/route_geometry.dart';
import 'package:location_gps/core/map_matching/route_match_cache.dart';
import 'package:location_gps/core/map_matching/route_matcher.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';

final DateTime _t0 = DateTime.utc(2026, 9, 13, 12);

/// A trace heading east along latitude 24.7, one fix every [stepM] metres
/// (roughly) and 5 s.
List<TracePoint> _trace(int n, {double stepM = 50}) => [
      for (var i = 0; i < n; i++)
        TracePoint(
          latitude: 24.7,
          longitude: 46.67 + i * stepM / 101000,
          time: _t0.add(Duration(seconds: 5 * i)),
          accuracy: 5,
        ),
    ];

/// Stand-in matching service: every edge "matched" through a midpoint bent
/// 3 m north, so a matched edge is distinguishable from a raw one.
class _FakeMatcher implements MapMatcher {
  _FakeMatcher({this.size = 5});
  final int size;
  final List<int> requestSizes = [];
  MapMatchingException? failWith;
  bool noMatch = false;

  @override
  String get cacheId => 'fake';

  @override
  int get maxPoints => size;

  @override
  Future<List<List<LatLng>?>> match(List<TracePoint> points) async {
    requestSizes.add(points.length);
    if (failWith != null) throw failWith!;
    return [
      for (var i = 0; i < points.length - 1; i++)
        noMatch
            ? null
            : [
                points[i].latLng,
                LatLng((points[i].latitude + points[i + 1].latitude) / 2 + 0.00003,
                    (points[i].longitude + points[i + 1].longitude) / 2),
                points[i + 1].latLng,
              ],
    ];
  }
}

Map<String, dynamic> _tp(int matching, int waypoint, double lng, double lat,
        {double distance = 2}) =>
    {
      'matchings_index': matching,
      'waypoint_index': waypoint,
      'distance': distance,
      'location': [lng, lat],
    };

Map<String, dynamic> _leg(List<List<double>> coords, double distance) => {
      'distance': distance,
      'steps': [
        {
          'geometry': {'coordinates': coords}
        },
        {
          'geometry': {
            'coordinates': [coords.last, coords.last]
          }
        },
      ],
    };

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Object body;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.uri);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// An OSRM server with a small trace limit: refuses larger requests with
/// TooBig, matches smaller ones straight along the given fixes.
class _LimitedOsrm implements HttpClientAdapter {
  _LimitedOsrm({required this.limit});
  final int limit;
  final List<int> sizes = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final coords = [
      for (final c in options.uri.pathSegments.last.split(';'))
        [for (final v in c.split(',')) double.parse(v)],
    ];
    sizes.add(coords.length);
    final tooBig = coords.length > limit;
    final Object body = tooBig
        ? {'code': 'TooBig', 'message': 'Too many trace coordinates'}
        : {
            'code': 'Ok',
            'tracepoints': [
              for (var i = 0; i < coords.length; i++)
                {
                  'matchings_index': 0,
                  'waypoint_index': i,
                  'distance': 1.0,
                  'location': coords[i],
                },
            ],
            'matchings': [
              {
                'legs': [
                  for (var i = 0; i < coords.length - 1; i++)
                    {
                      'distance': 1.0,
                      'steps': [
                        {
                          'geometry': {
                            'coordinates': [coords[i], coords[i + 1]]
                          }
                        },
                      ],
                    },
                ],
              },
            ],
          };
    return ResponseBody.fromString(jsonEncode(body), tooBig ? 400 : 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('OsrmMapMatcher.parse', () {
    // Three fixes going east then turning south at a corner; the road path of
    // leg 1 goes round the corner through (46.6710, 24.7000).
    final pts = [
      TracePoint(latitude: 24.7000, longitude: 46.6700, time: _t0, accuracy: 5),
      TracePoint(
          latitude: 24.7000,
          longitude: 46.6705,
          time: _t0.add(const Duration(seconds: 5)),
          accuracy: 5),
      TracePoint(
          latitude: 24.6995,
          longitude: 46.6710,
          time: _t0.add(const Duration(seconds: 10)),
          accuracy: 5),
    ];
    Map<String, dynamic> body({
      List<Object?>? tracepoints,
      double leg1Distance = 100,
    }) =>
        {
          'code': 'Ok',
          'tracepoints': tracepoints ??
              [
                _tp(0, 0, 46.6700, 24.7000),
                _tp(0, 1, 46.6705, 24.7000),
                _tp(0, 2, 46.6710, 24.6995),
              ],
          'matchings': [
            {
              'legs': [
                _leg([
                  [46.6700, 24.7000],
                  [46.6705, 24.7000]
                ], 50),
                _leg([
                  [46.6705, 24.7000],
                  [46.6710, 24.7000],
                  [46.6710, 24.6995]
                ], leg1Distance),
              ],
            },
          ],
        };

    test('each edge takes the road geometry of its leg, corners included', () {
      final edges = OsrmMapMatcher.parse(body(), pts);
      expect(edges, hasLength(2));
      expect(edges[0], [const LatLng(24.7000, 46.6700), const LatLng(24.7000, 46.6705)]);
      expect(edges[1], [
        const LatLng(24.7000, 46.6705),
        const LatLng(24.7000, 46.6710), // the corner, absent from the raw fixes
        const LatLng(24.6995, 46.6710),
      ]);
    });

    test('an unmatched fix leaves both of its edges raw', () {
      final edges = OsrmMapMatcher.parse(
          body(tracepoints: [
            _tp(0, 0, 46.6700, 24.7000),
            null,
            _tp(0, 1, 46.6710, 24.6995),
          ]),
          pts);
      expect(edges, [null, null]);
    });

    test('fixes in different matchings are not joined by a road', () {
      final edges = OsrmMapMatcher.parse(
          body(tracepoints: [
            _tp(0, 0, 46.6700, 24.7000),
            _tp(0, 1, 46.6705, 24.7000),
            _tp(1, 0, 46.6710, 24.6995),
          ]),
          pts);
      expect(edges[0], isNotNull);
      expect(edges[1], isNull);
    });

    test('a fix snapped far from where it was recorded is not on that road', () {
      final edges = OsrmMapMatcher.parse(
          body(tracepoints: [
            _tp(0, 0, 46.6700, 24.7000),
            _tp(0, 1, 46.6705, 24.7000, distance: 45),
            _tp(0, 2, 46.6710, 24.6995),
          ]),
          pts);
      expect(edges, [null, null], reason: 'off-road movement stays as recorded');
    });

    test('a long detour between two close fixes is rejected', () {
      final edges = OsrmMapMatcher.parse(body(leg1Distance: 900), pts);
      expect(edges[0], isNotNull);
      expect(edges[1], isNull);
    });

    test('a U-turn spike between two fixes is not drawn as travelled', () {
      final b = body();
      final legs = ((b['matchings'] as List).first as Map)['legs'] as List;
      (legs[1] as Map)['steps'] = [
        {
          'maneuver': {'type': 'depart'},
          'geometry': {
            'coordinates': [
              [46.6705, 24.7000],
              [46.6705, 24.6990],
            ]
          },
        },
        {
          'maneuver': {'type': 'continue', 'modifier': 'uturn'},
          'geometry': {
            'coordinates': [
              [46.6705, 24.6990],
              [46.6710, 24.6995],
            ]
          },
        },
      ];
      final edges = OsrmMapMatcher.parse(b, pts);
      expect(edges[0], isNotNull);
      expect(edges[1], isNull);
    });

    test('an impossible speed is rejected', () {
      final fast = [
        pts[0],
        pts[1],
        TracePoint(
            latitude: pts[2].latitude,
            longitude: pts[2].longitude,
            time: pts[1].time.add(const Duration(milliseconds: 500)),
            accuracy: 5),
      ];
      expect(OsrmMapMatcher.parse(body(), fast)[1], isNull);
    });
  });

  group('OsrmMapMatcher request', () {
    test('sends the trace in order with accuracy radii, relative times and '
        'headings only while moving', () {
      final m = OsrmMapMatcher(baseUrl: 'https://osrm.test/');
      final url = m.buildUrl([
        TracePoint(latitude: 24.1, longitude: 46.1, time: _t0, accuracy: 3),
        TracePoint(
            latitude: 24.2,
            longitude: 46.2,
            time: _t0.add(const Duration(seconds: 7)),
            accuracy: 200,
            speed: 10,
            heading: 91.6),
        TracePoint(
            latitude: 24.3,
            longitude: 46.3,
            time: _t0.add(const Duration(seconds: 7)),
            speed: 0.5,
            heading: 10),
      ]);
      expect(url, startsWith('https://osrm.test/match/v1/driving/'
          '46.100000,24.100000;46.200000,24.200000;46.300000,24.300000?'));
      expect(url, contains('radiuses=8;40;15'));
      expect(url, contains('timestamps=0;7;8'));
      expect(url, contains('bearings=;92,60;'));
      expect(url, contains('gaps=split'));
    });

    test('NoMatch is a final answer: every edge raw', () async {
      final adapter = _Adapter(400, {'code': 'NoMatch', 'message': 'Could not match'});
      final m = OsrmMapMatcher(baseUrl: 'https://osrm.test', dio: Dio()..httpClientAdapter = adapter);
      expect(await m.match(_trace(3)), [null, null]);
    });

    test('requests are sized to the server: 10 fixes on the public demo '
        'server, 90 on a self-hosted one, or as configured', () {
      expect(OsrmMapMatcher(baseUrl: 'https://router.project-osrm.org').maxPoints, 10);
      expect(OsrmMapMatcher(baseUrl: 'https://osrm.company.test').maxPoints, 90);
      expect(
          OsrmMapMatcher(baseUrl: 'https://router.project-osrm.org', maxPoints: 50)
              .maxPoints,
          50);
    });

    test('a trace larger than the server accepts is split, not lost', () async {
      final server = _LimitedOsrm(limit: 3);
      final m = OsrmMapMatcher(
        baseUrl: 'https://osrm.test',
        dio: Dio()..httpClientAdapter = server,
        maxPoints: 90,
        splitSpacing: Duration.zero,
      );
      final trace = _trace(7);
      final edges = await m.match(trace);
      expect(edges, hasLength(6));
      expect(edges.every((e) => e != null), isTrue,
          reason: 'every edge matched through the smaller requests');
      // Sent with 6 decimals, so endpoints agree to within 1e-6 degrees.
      for (var i = 0; i < 6; i++) {
        expect(edges[i]!.first.latitude, closeTo(trace[i].latitude, 1e-6));
        expect(edges[i]!.first.longitude, closeTo(trace[i].longitude, 1e-6));
        expect(edges[i]!.last.longitude, closeTo(trace[i + 1].longitude, 1e-6));
      }
      expect(server.sizes.first, 7);
      expect(server.sizes.where((s) => s <= 3), isNotEmpty);
    });

    test('rate limiting and server errors are retryable failures', () async {
      for (final status in [429, 503]) {
        final m = OsrmMapMatcher(
            baseUrl: 'https://osrm.test',
            dio: Dio()..httpClientAdapter = _Adapter(status, {'message': 'busy'}));
        await expectLater(
          m.match(_trace(3)),
          throwsA(isA<MapMatchingException>().having((e) => e.retryable, 'retryable', true)),
        );
      }
    });
  });

  group('RouteGeometry', () {
    test('matched edges follow roads, the rest joins the recorded fixes', () {
      final trace = _trace(4);
      final fixes = [for (final p in trace) p.latLng];
      final bend = LatLng(24.70003, fixes[1].longitude + 0.0001);
      final g = RouteGeometry.fromRoads(fixes, [
        null,
        [fixes[1], bend, fixes[2]],
        null,
      ]);
      expect(g.source, RouteGeometrySource.partial);
      expect(g.path(), [fixes[0], fixes[1], bend, fixes[2], fixes[3]]);
      expect(g.path(1, 2), [fixes[1], bend, fixes[2]]);
      expect(g.path(2, 2), [fixes[2]]);
      expect(g.fixes, fixes, reason: 'recorded positions are never changed');
    });
  });

  group('RouteMatcher', () {
    test('matches a trace chunk by chunk, sharing the boundary fix', () async {
      final fake = _FakeMatcher(size: 5);
      final matcher = RouteMatcher(matcher: fake, requestSpacing: Duration.zero);
      final trace = _trace(13);
      final g = await matcher.resolve(trace).last;
      expect(fake.requestSizes, [5, 5, 5]); // fixes 0-4, 4-8, 8-12
      expect(g.pending, isFalse);
      expect(g.source, RouteGeometrySource.matched);
      expect(g.edges, hasLength(12));
    });

    test('cached stretches are not requested again — rebuilds, reopens, or a '
        'trace that only grew', () async {
      final fake = _FakeMatcher(size: 5);
      final matcher = RouteMatcher(matcher: fake, requestSpacing: Duration.zero);
      final trace = _trace(9); // chunks 0-4, 4-8
      await matcher.resolve(trace).last;
      expect(fake.requestSizes, hasLength(2));

      expect(matcher.peek(trace).source, RouteGeometrySource.matched);
      expect(matcher.peek(trace).pending, isFalse);
      await matcher.resolve(trace).last;
      expect(fake.requestSizes, hasLength(2), reason: 'same points: all cached');

      // Two more fixes: only the new chunk 8-10 is sent.
      await matcher.resolve(_trace(11)).last;
      expect(fake.requestSizes, [5, 5, 3]);
    });

    test('a changed fix re-matches only its own chunk', () async {
      final fake = _FakeMatcher(size: 5);
      final matcher = RouteMatcher(matcher: fake, requestSpacing: Duration.zero);
      final trace = _trace(9);
      await matcher.resolve(trace).last;
      final moved = [...trace]..[6] = TracePoint(
          latitude: 24.7001,
          longitude: trace[6].longitude,
          time: trace[6].time,
          accuracy: 5);
      await matcher.resolve(moved).last;
      expect(fake.requestSizes, [5, 5, 5]);
    });

    test('service unavailable: the raw line is drawn, nothing is cached, and '
        'the service is left alone for a while', () async {
      var now = _t0;
      final fake = _FakeMatcher(size: 5)
        ..failWith = const MapMatchingException('offline', retryable: true);
      final matcher = RouteMatcher(
        matcher: fake,
        requestSpacing: Duration.zero,
        failureBackoff: const Duration(minutes: 1),
        now: () => now,
      );
      final trace = _trace(5);
      final g = await matcher.resolve(trace).last;
      expect(g.source, RouteGeometrySource.raw);
      expect(g.pending, isFalse);
      expect(g.path(), [for (final p in trace) p.latLng]);

      fake.failWith = null;
      await matcher.resolve(trace).last;
      expect(fake.requestSizes, hasLength(1), reason: 'backing off');

      now = now.add(const Duration(minutes: 2));
      final retried = await matcher.resolve(trace).last;
      expect(fake.requestSizes, hasLength(2));
      expect(retried.source, RouteGeometrySource.matched);
    });

    test('no road network nearby is remembered: raw, and not asked again', () async {
      final fake = _FakeMatcher(size: 5)..noMatch = true;
      final matcher = RouteMatcher(matcher: fake, requestSpacing: Duration.zero);
      final trace = _trace(5);
      expect((await matcher.resolve(trace).last).source, RouteGeometrySource.raw);
      await matcher.resolve(trace).last;
      expect(fake.requestSizes, hasLength(1));
    });

    test('disabled: raw, no requests', () async {
      final matcher = RouteMatcher(matcher: null);
      final trace = _trace(4);
      final events = await matcher.resolve(trace).toList();
      expect(events.single.source, RouteGeometrySource.raw);
    });

    test('the disk cache survives an app restart and is wiped on logout', () async {
      final dir = await Directory.systemTemp.createTemp('route_match_test');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final trace = _trace(5);
      final first = _FakeMatcher(size: 5);
      await RouteMatcher(
              matcher: first,
              cache: RouteMatchCache(directory: dir),
              requestSpacing: Duration.zero)
          .resolve(trace)
          .last;

      final second = _FakeMatcher(size: 5);
      final restarted = RouteMatcher(
          matcher: second,
          cache: RouteMatchCache(directory: dir),
          requestSpacing: Duration.zero);
      final g = await restarted.resolve(trace).last;
      expect(second.requestSizes, isEmpty);
      expect(g.source, RouteGeometrySource.matched);

      await restarted.clear();
      expect(await dir.exists(), isFalse);
    });
  });

  test('a stored trail becomes a trace without touching its coordinates', () {
    final logs = [
      VisitLocationLog(
          id: 1, loggedAt: _t0, latitude: 24.123456789, longitude: 46.987654321,
          accuracy: 0, speed: 4, heading: 90),
    ];
    final t = logs.trace.single;
    expect(t.latitude, 24.123456789);
    expect(t.longitude, 46.987654321);
    expect(t.accuracy, isNull, reason: 'Odoo stores "not reported" as 0');
    expect(t.heading, 90);
  });
}
