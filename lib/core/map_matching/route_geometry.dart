import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// One recorded GPS fix, as the road matcher reads it.
///
/// Built from the stored points (`VisitLocationLog`) and never written back:
/// the recorded coordinates stay the evidence; road geometry is only derived
/// from them for display.
class TracePoint {
  final double latitude;
  final double longitude;

  /// The fix's own time.
  final DateTime time;

  /// Metres of horizontal uncertainty, when the device reported it.
  final double? accuracy;

  /// Metres per second.
  final double? speed;

  /// Degrees clockwise from true north.
  final double? heading;

  const TracePoint({
    required this.latitude,
    required this.longitude,
    required this.time,
    this.accuracy,
    this.speed,
    this.heading,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}

enum RouteGeometrySource {
  /// Every stretch is drawn straight between the recorded fixes.
  raw,

  /// Some stretches follow matched roads, the rest the recorded fixes.
  partial,

  /// Every stretch follows matched roads.
  matched,
}

/// The line drawn for a GPS trace: for every pair of consecutive fixes, either
/// the road the matcher found between them or — where there is no trustworthy
/// match (no road nearby, matching unavailable, an implausible detour) — the
/// straight line between the two recorded positions.
///
/// [fixes] are the recorded positions, unchanged. Markers and camera fits keep
/// using those; only the line between them changes.
class RouteGeometry {
  final List<LatLng> fixes;

  /// `edges[i]` is drawn from fix `i` to fix `i + 1`.
  final List<List<LatLng>> edges;

  /// Whether `edges[i]` follows a matched road.
  final List<bool> matched;

  /// Road matching is still running for part of the trace.
  final bool pending;

  const RouteGeometry._(this.fixes, this.edges, this.matched, this.pending);

  /// The recorded fixes joined by straight lines.
  factory RouteGeometry.raw(List<TracePoint> trace, {bool pending = false}) =>
      RouteGeometry.fromRoads(
        [for (final p in trace) p.latLng],
        List<List<LatLng>?>.filled(math.max(0, trace.length - 1), null),
        pending: pending,
      );

  /// [roads] holds one entry per edge: the matched road geometry, or null to
  /// draw that edge straight between its fixes.
  factory RouteGeometry.fromRoads(
    List<LatLng> fixes,
    List<List<LatLng>?> roads, {
    bool pending = false,
  }) {
    assert(roads.length == math.max(0, fixes.length - 1));
    final edges = <List<LatLng>>[];
    final matched = <bool>[];
    for (var i = 0; i < roads.length; i++) {
      final road = roads[i];
      if (road != null && road.length >= 2) {
        edges.add(road);
        matched.add(true);
      } else {
        edges.add([fixes[i], fixes[i + 1]]);
        matched.add(false);
      }
    }
    return RouteGeometry._(List.unmodifiable(fixes), edges, matched, pending);
  }

  int get matchedEdges => matched.where((m) => m).length;

  RouteGeometrySource get source {
    final n = matchedEdges;
    if (n == 0) return RouteGeometrySource.raw;
    return n == edges.length
        ? RouteGeometrySource.matched
        : RouteGeometrySource.partial;
  }

  /// The line from fix [from] to fix [to] (inclusive; default: the last fix),
  /// following matched roads wherever there are any.
  List<LatLng> path([int from = 0, int? to]) {
    if (fixes.isEmpty) return const [];
    final last = math.min(to ?? fixes.length - 1, fixes.length - 1);
    if (last <= from) return [fixes[from]];
    final out = <LatLng>[];
    for (var i = from; i < last; i++) {
      for (final p in edges[i]) {
        if (out.isNotEmpty &&
            out.last.latitude == p.latitude &&
            out.last.longitude == p.longitude) {
          continue;
        }
        out.add(p);
      }
    }
    return out;
  }
}
