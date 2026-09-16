import 'package:equatable/equatable.dart';

import '../../../../core/api/odoo_parse.dart';
import '../../../../core/map_matching/route_geometry.dart';

extension VisitLocationTrace on List<VisitLocationLog> {
  /// The points as the road matcher reads them — same coordinates, in the
  /// same (server) order. Drawing input only; nothing is written back.
  List<TracePoint> get trace => [
    for (final l in this)
      TracePoint(
        latitude: l.latitude,
        longitude: l.longitude,
        time: l.loggedAt,
        // Odoo stores an unreported accuracy as 0.
        accuracy: (l.accuracy ?? 0) > 0 ? l.accuracy : null,
        speed: l.speed,
        heading: l.heading,
      ),
  ];
}

/// Who wrote a point onto the trail.
///
/// Server-controlled: `start` and `end` are written by the Start/End actions
/// themselves, `manual` by a back-office edit in Odoo, and everything the app
/// posts is forced to `track` no matter what it sends. We parse it only to
/// render the endpoints of the thread differently from its middle.
enum TrailSource { start, track, end, manual, unknown }

TrailSource trailSourceFromWire(String? raw) {
  switch (raw) {
    case 'start':
      return TrailSource.start;
    case 'track':
      return TrailSource.track;
    case 'end':
      return TrailSource.end;
    case 'manual':
      return TrailSource.manual;
    default:
      return TrailSource.unknown;
  }
}

// Accuracy/altitude/speed/heading are read with `odooDouble`, not
// `odooCoord`: unlike coordinates they are legitimately zero — a stationary fix
// really does have `speed: 0`.

/// One GPS fix on a visit's trail (`dh.visit.location.log`).
///
/// The trail is **append-only**: there is no update or delete route, by design
/// — it is evidence of where the employee actually went, so the app can add to
/// it but never rewrite it.
class VisitLocationLog extends Equatable {
  final int id;
  final int? visitId;

  /// When the fix was taken **on the device**, not when it reached the server.
  /// The trail is ordered and measured by this, which is what lets a delayed
  /// offline flush land in its correct place in the path.
  final DateTime loggedAt;

  final double latitude;
  final double longitude;

  /// Metres of horizontal uncertainty (`0.0` when the device didn't report it).
  final double? accuracy;
  final double? altitude;

  /// Metres per second.
  final double? speed;

  /// Degrees clockwise from true north.
  final double? heading;

  /// Optional reverse-geocoded address for this point.
  final String? location;
  final String? deviceId;
  final TrailSource source;

  const VisitLocationLog({
    required this.id,
    required this.loggedAt,
    required this.latitude,
    required this.longitude,
    this.visitId,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.location,
    this.deviceId,
    this.source = TrailSource.unknown,
  });

  bool get isStart => source == TrailSource.start;
  bool get isEnd => source == TrailSource.end;

  /// Speed in km/h, or null when the device reported none.
  double? get speedKmh => speed == null ? null : speed! * 3.6;

  /// Parses a point from `/api/visit/track`, `/api/visit/log_location` or the
  /// `logs` array of a batch flush. Returns null when the payload carries no
  /// usable coordinate or timestamp — a half-formed point must not become a
  /// (0, 0) vertex that drags the drawn path into the Gulf of Guinea.
  static VisitLocationLog? tryFromApi(Map<String, dynamic> json) {
    final lat = odooDouble(json['latitude']);
    final lng = odooDouble(json['longitude']);
    final at = parseOdooUtc(json['logged_at']);
    if (lat == null || lng == null || at == null) return null;
    if (!isValidLatLng(lat, lng)) return null;
    return VisitLocationLog(
      id: odooInt(json['id']) ?? 0,
      visitId: odooInt(json['visit_id']),
      loggedAt: at,
      latitude: lat,
      longitude: lng,
      accuracy: odooDouble(json['accuracy']),
      altitude: odooDouble(json['altitude']),
      speed: odooDouble(json['speed']),
      heading: odooDouble(json['heading']),
      location: odooString(json['location']),
      deviceId: odooString(json['device_id']),
      source: trailSourceFromWire(odooString(json['source'])),
    );
  }

  @override
  List<Object?> get props => [id, loggedAt, latitude, longitude, source];
}

/// A whole trail as returned by `/api/visit/track`: the ordered points plus the
/// server's own counters.
///
/// The counters come from the server rather than being recomputed here on
/// purpose — [logs] may be a paged or date-filtered slice, while
/// [locationLogCount] and [trackedDistanceKm] always describe the full trail.
class VisitTrack extends Equatable {
  final int visitId;
  final int locationLogCount;
  final double trackedDistanceKm;
  final List<VisitLocationLog> logs;

  const VisitTrack({
    required this.visitId,
    this.locationLogCount = 0,
    this.trackedDistanceKm = 0.0,
    this.logs = const [],
  });

  static const VisitTrack empty = VisitTrack(visitId: 0);

  bool get isEmpty => logs.isEmpty;

  /// At least two points are needed before there is a line to draw.
  bool get hasPath => logs.length > 1;

  DateTime? get firstFixAt => logs.isEmpty ? null : logs.first.loggedAt;
  DateTime? get lastFixAt => logs.isEmpty ? null : logs.last.loggedAt;

  /// Wall-clock time spanned by the points we hold.
  Duration? get span {
    if (logs.length < 2) return null;
    final d = logs.last.loggedAt.difference(logs.first.loggedAt);
    return d.isNegative ? null : d;
  }

  /// Average speed over the trail in km/h, or null when it can't be derived.
  double? get averageSpeedKmh {
    final s = span;
    if (s == null || s.inSeconds <= 0 || trackedDistanceKm <= 0) return null;
    return trackedDistanceKm / (s.inSeconds / 3600);
  }

  factory VisitTrack.fromApi(Map<String, dynamic> json) {
    final logs = _parseLogs(json['logs']);
    // Kept exactly in the order the server returned. The server files the
    // trail by `logged_at` ("always oldest first") and that order *is* the
    // route — the polyline is drawn straight through it. Re-sorting here used
    // to be a no-op at best; at worst Dart's unstable sort reshuffled points
    // sharing a timestamp (a Start and the first fix in the same second) and
    // the client drew a different path from the one the server measured.
    return VisitTrack(
      visitId: odooInt(json['visit_id']) ?? 0,
      locationLogCount: odooInt(json['location_log_count']) ?? logs.length,
      trackedDistanceKm: odooDouble(json['tracked_distance_km']) ?? 0.0,
      logs: logs,
    );
  }

  @override
  List<Object?> get props => [
    visitId,
    locationLogCount,
    trackedDistanceKm,
    logs,
  ];
}

/// A fix captured on the device and not yet accepted by the server.
///
/// This is the unit the offline buffer persists, so it has to survive a JSON
/// round-trip through SharedPreferences unchanged.
class TrailPoint extends Equatable {
  final double latitude;
  final double longitude;
  final DateTime loggedAt;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String? location;
  final String? deviceId;

  const TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.loggedAt,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.location,
    this.deviceId,
  });

  /// The wire shape of one point inside `points[]`.
  ///
  /// `logged_at` is always sent even though the server would default it to
  /// "now": the whole point of the buffer is that a fix taken in a dead zone
  /// keeps its real time when it is flushed an hour later.
  Map<String, dynamic> toApi({required String Function(DateTime) formatUtc}) =>
      {
        'latitude': latitude,
        'longitude': longitude,
        'logged_at': formatUtc(loggedAt),
        if (accuracy != null) 'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (location != null) 'location': location,
        if (deviceId != null) 'device_id': deviceId,
      };

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'at': loggedAt.toUtc().toIso8601String(),
    if (accuracy != null) 'acc': accuracy,
    if (altitude != null) 'alt': altitude,
    if (speed != null) 'spd': speed,
    if (heading != null) 'hdg': heading,
    if (location != null) 'loc': location,
    if (deviceId != null) 'dev': deviceId,
  };

  static TrailPoint? tryFromJson(Map<String, dynamic> j) {
    final lat = odooDouble(j['lat']);
    final lng = odooDouble(j['lng']);
    final at = DateTime.tryParse(odooString(j['at']) ?? '');
    if (lat == null || lng == null || at == null) return null;
    return TrailPoint(
      latitude: lat,
      longitude: lng,
      loggedAt: at.toUtc(),
      accuracy: odooDouble(j['acc']),
      altitude: odooDouble(j['alt']),
      speed: odooDouble(j['spd']),
      heading: odooDouble(j['hdg']),
      location: odooString(j['loc']),
      deviceId: odooString(j['dev']),
    );
  }

  @override
  List<Object?> get props => [latitude, longitude, loggedAt];
}

/// One point the server refused inside a batch, identified by its position in
/// the `points` array that was sent.
class RejectedPoint {
  /// Index into the request's `points` array — this is what lets the caller
  /// drop exactly the accepted points from its local queue.
  final int index;

  /// The server's human-readable reason, already translated.
  final String error;

  const RejectedPoint({required this.index, required this.error});
}

/// The outcome of a batch flush (`/api/visit/log_locations`).
class TrailFlushResult {
  final int created;
  final List<VisitLocationLog> logs;
  final List<RejectedPoint> rejected;
  final int locationLogCount;
  final double trackedDistanceKm;

  const TrailFlushResult({
    this.created = 0,
    this.logs = const [],
    this.rejected = const [],
    this.locationLogCount = 0,
    this.trackedDistanceKm = 0.0,
  });

  factory TrailFlushResult.fromApi(Map<String, dynamic> json) {
    final logs = _parseLogs(json['logs']);
    final rejected = [
      for (final raw in odooList(json['rejected']))
        if (odooMap(raw) case final m? when odooInt(m['index']) != null)
          RejectedPoint(
            index: odooInt(m['index'])!,
            error: odooString(m['error']) ?? '',
          ),
    ];
    return TrailFlushResult(
      created: odooInt(json['created']) ?? logs.length,
      logs: logs,
      rejected: rejected,
      locationLogCount: odooInt(json['location_log_count']) ?? 0,
      trackedDistanceKm: odooDouble(json['tracked_distance_km']) ?? 0.0,
    );
  }
}

/// The usable points of a `logs` array, in the order the server sent them. A
/// half-formed point is dropped on its own (see [VisitLocationLog.tryFromApi]).
List<VisitLocationLog> _parseLogs(dynamic raw) => [
  for (final item in odooList(raw))
    if (odooMap(item) case final m?)
      if (VisitLocationLog.tryFromApi(m) case final log?) log,
];
