import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../utils/distance.dart';
import 'route_geometry.dart';

/// Turns a stretch of recorded GPS fixes into the road geometry travelled
/// between each consecutive pair.
abstract class MapMatcher {
  /// Identifies the service and its settings in cache keys, so geometry
  /// matched by one server is never served for another.
  String get cacheId;

  /// Most fixes accepted in one [match] call.
  int get maxPoints;

  /// One entry per edge (`points.length - 1`): the road geometry between fix
  /// `i` and fix `i + 1`, or null where there is no trustworthy road match.
  ///
  /// Throws [MapMatchingException] when the service could not answer.
  Future<List<List<LatLng>?>> match(List<TracePoint> points);
}

class MapMatchingException implements Exception {
  final String message;

  /// Worth trying again later (network, rate limit, server error), as opposed
  /// to a request the service will never accept.
  final bool retryable;

  const MapMatchingException(this.message, {this.retryable = false});

  @override
  String toString() => 'MapMatchingException($message, retryable: $retryable)';
}

/// Map matching with the OSRM `match` service
/// (http://project-osrm.org/docs/v5.24.0/api/#match-service), which works on
/// OpenStreetMap — the same data as the app's map tiles, so matched lines sit
/// on the roads the user actually sees.
///
/// Input is the recorded trace itself, in order, with each fix's accuracy as
/// its search radius, its relative time, and its heading while moving. OSRM
/// returns the most likely road path through them (a hidden Markov model over
/// candidate road positions), split where it cannot connect the fixes.
///
/// A match is only accepted edge by edge, and only when it is believable:
/// both fixes snapped close to where they were recorded, the road path is not
/// a long detour compared with the distance actually covered, and it does not
/// imply an impossible speed. Everything else stays a straight line between
/// the recorded positions — movement off the road network is drawn as
/// recorded, never forced onto some nearby street.
class OsrmMapMatcher implements MapMatcher {
  final String baseUrl;
  final String profile;
  final Dio _dio;
  final int _maxPoints;

  /// Pause between the sub-requests of a trace split because the server
  /// refused its size (see [match]).
  final Duration splitSpacing;

  OsrmMapMatcher({
    required String baseUrl,
    this.profile = 'driving',
    Dio? dio,
    String? userAgent,
    int? maxPoints,
    this.splitSpacing = const Duration(milliseconds: 1100),
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _maxPoints = maxPoints ??
            (Uri.tryParse(baseUrl)?.host == publicServerHost
                ? publicServerMaxPoints
                : chunkPoints),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {if (userAgent != null) 'User-Agent': userAgent},
            ));

  /// Coordinates per request for a self-hosted server: under osrm-routed's
  /// default `--max-matching-size` of 100, and a GET URL of a few kilobytes.
  static const int chunkPoints = 90;

  /// The public demo server refuses a match of more than 10 coordinates
  /// ("TooBig: Too many trace coordinates").
  static const String publicServerHost = 'router.project-osrm.org';
  static const int publicServerMaxPoints = 10;

  /// The public server refuses larger search radii ("TooBig").
  static const double maxRadiusMeters = 40;
  static const double minRadiusMeters = 8;

  /// Assumed accuracy for a fix that reported none.
  static const double defaultAccuracyMeters = 15;

  /// A heading is only passed on while moving at least this fast; below it
  /// the platform's bearing is noise.
  static const double headingMinSpeed = 3;

  /// A fix snapped further than this from where it was recorded is not on the
  /// matched road (scaled up for a fix that reported poor accuracy).
  static const double maxSnapMeters = 20;
  static const double maxSnapMetersCeiling = 60;

  /// A road path longer than `factor × straight distance + slack` between two
  /// fixes is a detour the device did not make (a U-turn routed round a block,
  /// a jump to a parallel road).
  static const double maxDetourFactor = 2.0;
  static const double detourSlackMeters = 60;

  /// Faster than this between two fixes is not a real road path (~250 km/h).
  static const double maxSpeedMps = 70;

  @override
  String get cacheId => 'osrm|$baseUrl|$profile';

  @override
  int get maxPoints => _maxPoints;

  /// The request for [points], built by hand: OSRM's list separators (`;`,
  /// `,`) must reach it literally.
  String buildUrl(List<TracePoint> points) {
    final coords = [
      for (final p in points)
        '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
    ].join(';');
    final radiuses = [
      for (final p in points)
        (p.accuracy ?? defaultAccuracyMeters)
            .clamp(minRadiusMeters, maxRadiusMeters)
            .round(),
    ].join(';');
    // Relative seconds: OSRM needs the spacing, not the wall-clock time of
    // the employee's day. Strictly increasing, as it requires.
    final t0 = points.first.time.millisecondsSinceEpoch ~/ 1000;
    final times = <int>[];
    for (final p in points) {
      var t = p.time.millisecondsSinceEpoch ~/ 1000 - t0;
      if (times.isNotEmpty && t <= times.last) t = times.last + 1;
      times.add(t);
    }
    final bearings = [
      for (final p in points)
        (p.heading != null && (p.speed ?? 0) >= headingMinSpeed)
            ? '${(p.heading!.round() % 360 + 360) % 360},60'
            : '',
    ];
    final withBearings = bearings.any((b) => b.isNotEmpty);
    return '$baseUrl/match/v1/$profile/$coords'
        '?overview=false&steps=true&geometries=geojson&gaps=split&tidy=false'
        '&radiuses=$radiuses&timestamps=${times.join(';')}'
        '${withBearings ? '&bearings=${bearings.join(';')}' : ''}';
  }

  @override
  Future<List<List<LatLng>?>> match(List<TracePoint> points) async {
    if (points.length < 2) return const [];
    final Response<dynamic> res;
    try {
      res = await _dio.get<dynamic>(
        buildUrl(points),
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw MapMatchingException('request failed (${e.type.name})',
          retryable: true);
    }
    final status = res.statusCode ?? 0;
    final body = res.data;
    final code = body is Map ? body['code'] : null;
    // No road network near the trace: a real answer, and a final one.
    if (code == 'NoMatch' || code == 'NoSegment') {
      return List<List<LatLng>?>.filled(points.length - 1, null);
    }
    // The server's trace limit is below what was sent: match the two halves,
    // which share their middle fix, so the edges still line up one to one.
    final message = body is Map ? '${body['message'] ?? ''}' : '';
    if (code == 'TooBig' && points.length > 2 && message.contains('coordinates')) {
      final mid = points.length ~/ 2;
      final left = await match(points.sublist(0, mid + 1));
      if (splitSpacing > Duration.zero) await Future<void>.delayed(splitSpacing);
      final right = await match(points.sublist(mid));
      return [...left, ...right];
    }
    if (status == 429 || status >= 500) {
      throw MapMatchingException('HTTP $status', retryable: true);
    }
    if (code != 'Ok' || body is! Map) {
      throw MapMatchingException(
          '${code ?? 'HTTP $status'} ${body is Map ? body['message'] ?? '' : ''}');
    }
    return parse(Map<String, dynamic>.from(body), points);
  }

  /// Road geometry per edge from an OSRM `match` response for [points].
  static List<List<LatLng>?> parse(
    Map<String, dynamic> body,
    List<TracePoint> points,
  ) {
    final n = points.length;
    final out = List<List<LatLng>?>.filled(n < 2 ? 0 : n - 1, null);
    final tracepoints = body['tracepoints'];
    final matchings = body['matchings'];
    if (tracepoints is! List || matchings is! List || tracepoints.length != n) {
      return out;
    }
    for (var i = 0; i < n - 1; i++) {
      final a = tracepoints[i];
      final b = tracepoints[i + 1];
      // A null tracepoint could not be matched: both its edges stay raw.
      if (a is! Map || b is! Map) continue;
      final ma = _int(a['matchings_index']);
      final wa = _int(a['waypoint_index']);
      if (ma == null ||
          wa == null ||
          ma != _int(b['matchings_index']) ||
          _int(b['waypoint_index']) != wa + 1 ||
          ma >= matchings.length) {
        continue; // different matchings: OSRM could not connect them
      }
      if (!_snapped(a, points[i]) || !_snapped(b, points[i + 1])) continue;
      final matching = matchings[ma];
      final legs = matching is Map ? matching['legs'] : null;
      if (legs is! List || wa >= legs.length || legs[wa] is! Map) continue;
      final leg = legs[wa] as Map;
      // A U-turn between two consecutive fixes is the router doubling back
      // to reach the other carriageway (a spike down the road and back), not
      // something recorded — keep the straight line between the fixes.
      if (_hasUturn(leg)) continue;
      final line = _legLine(leg, a, b);
      if (line == null) continue;

      final legMeters = (leg['distance'] as num?)?.toDouble() ?? _length(line);
      final straight = haversineMeters(points[i].latitude, points[i].longitude,
          points[i + 1].latitude, points[i + 1].longitude);
      if (legMeters > straight * maxDetourFactor + detourSlackMeters) continue;
      final seconds =
          points[i + 1].time.difference(points[i].time).inMilliseconds / 1000;
      if (seconds > 0 && legMeters / seconds > maxSpeedMps) continue;
      out[i] = line;
    }
    return out;
  }

  static bool _hasUturn(Map leg) {
    final steps = leg['steps'];
    if (steps is! List) return false;
    for (final step in steps.whereType<Map>()) {
      final maneuver = step['maneuver'];
      if (maneuver is! Map) continue;
      final type = maneuver['type'];
      if (type == 'depart' || type == 'arrive') continue;
      if (maneuver['modifier'] == 'uturn' || type == 'uturn') return true;
    }
    return false;
  }

  static bool _snapped(Map tracepoint, TracePoint fix) {
    final distance = (tracepoint['distance'] as num?)?.toDouble();
    if (distance == null) return false;
    final allowed = ((fix.accuracy ?? defaultAccuracyMeters) * 1.5)
        .clamp(maxSnapMeters, maxSnapMetersCeiling);
    return distance <= allowed;
  }

  /// The leg's steps joined into one line from the first fix's road position
  /// to the second's.
  static List<LatLng>? _legLine(Map leg, Map from, Map to) {
    final line = <LatLng>[];
    void add(LatLng p) {
      if (line.isNotEmpty &&
          line.last.latitude == p.latitude &&
          line.last.longitude == p.longitude) {
        return;
      }
      line.add(p);
    }

    final steps = leg['steps'];
    if (steps is List) {
      for (final step in steps.whereType<Map>()) {
        final geometry = step['geometry'];
        final coords = geometry is Map ? geometry['coordinates'] : null;
        if (coords is! List) continue;
        for (final c in coords) {
          final p = _lngLat(c);
          if (p != null) add(p);
        }
      }
    }
    if (line.length < 2) {
      // No movement along the road (both fixes on the same spot of it).
      final a = _lngLat(from['location']);
      final b = _lngLat(to['location']);
      if (a == null || b == null) return null;
      line
        ..clear()
        ..add(a)
        ..add(b);
    }
    return line;
  }

  static LatLng? _lngLat(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final lng = raw[0];
    final lat = raw[1];
    if (lng is! num || lat is! num) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  static double _length(List<LatLng> line) {
    var m = 0.0;
    for (var i = 1; i < line.length; i++) {
      m += haversineMeters(line[i - 1].latitude, line[i - 1].longitude,
          line[i].latitude, line[i].longitude);
    }
    return m;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;
}
