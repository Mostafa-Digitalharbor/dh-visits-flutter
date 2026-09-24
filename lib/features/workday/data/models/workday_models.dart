import 'package:equatable/equatable.dart';

import '../../../../core/utils/distance.dart';
import '../../../visits/data/models/visit.dart' show parseOdooUtc;
import '../../../visits/data/models/visit_location_log.dart';

// Odoo serialises unset values as `false` and unset floats as `0.0`.
double? _num(dynamic raw) => raw is num ? raw.toDouble() : null;

double? _coord(dynamic raw) {
  final v = _num(raw);
  return (v == null || v == 0.0) ? null : v;
}

String? _str(dynamic raw) {
  if (raw == null || raw == false) return null;
  final s = raw.toString().trim();
  return (s.isEmpty || s == 'false') ? null : s;
}

(int?, String?) _m2o(dynamic raw) {
  if (raw is List && raw.isNotEmpty && raw.first is num) {
    return ((raw.first as num).toInt(), raw.length > 1 ? _str(raw[1]) : null);
  }
  if (raw is num) return (raw.toInt(), null);
  return (null, null);
}

enum WorkSessionState { active, completed }

/// One employee work day on the server (`x_dh_work_session`): the envelope
/// every GPS point of the day belongs to, from "Start work day" to "End work
/// day". Visits happen *inside* it; they are not it.
class WorkSession extends Equatable {
  final int id;

  /// The id the app generated before the server knew about the session. Makes
  /// creation idempotent: a create whose response was lost is found again by
  /// this instead of being created twice.
  final String? clientUid;
  final int? employeeId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final WorkSessionState state;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;

  const WorkSession({
    required this.id,
    required this.startedAt,
    required this.state,
    this.clientUid,
    this.employeeId,
    this.endedAt,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
  });

  bool get isActive => state == WorkSessionState.active;

  static const List<String> fields = [
    'x_client_uid',
    'x_employee_id',
    'x_started_at',
    'x_ended_at',
    'x_state',
    'x_start_latitude',
    'x_start_longitude',
    'x_end_latitude',
    'x_end_longitude',
  ];

  static WorkSession? tryFromApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final startedAt = parseOdooUtc(json['x_started_at']);
    if (id == null || startedAt == null) return null;
    return WorkSession(
      id: id,
      clientUid: _str(json['x_client_uid']),
      employeeId: _m2o(json['x_employee_id']).$1,
      startedAt: startedAt,
      endedAt: parseOdooUtc(json['x_ended_at']),
      state: json['x_state'] == 'completed'
          ? WorkSessionState.completed
          : WorkSessionState.active,
      startLatitude: _coord(json['x_start_latitude']),
      startLongitude: _coord(json['x_start_longitude']),
      endLatitude: _coord(json['x_end_latitude']),
      endLongitude: _coord(json['x_end_longitude']),
    );
  }

  /// A work day as `/api/workday/*` returns it (`session` objects).
  static WorkSession? tryFromWorkdayApi(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final startedAt = parseOdooUtc(json['started_at']);
    if (id == null || startedAt == null) return null;
    return WorkSession(
      id: id,
      clientUid: _str(json['client_uid']),
      employeeId: (json['employee_id'] as num?)?.toInt(),
      startedAt: startedAt,
      endedAt: parseOdooUtc(json['ended_at']),
      state: json['state'] == 'completed'
          ? WorkSessionState.completed
          : WorkSessionState.active,
      startLatitude: _coord(json['start_latitude']),
      startLongitude: _coord(json['start_longitude']),
      endLatitude: _coord(json['end_latitude']),
      endLongitude: _coord(json['end_longitude']),
    );
  }

  @override
  List<Object?> get props => [id, state, startedAt, endedAt];
}

enum WorkdayPointSource { start, track, end }

/// A work-day fix waiting in the on-device upload queue.
///
/// The position itself reuses [TrailPoint], the unit the visit trail already
/// buffers, so both queues serialise a fix identically.
class WorkdayPoint extends Equatable {
  /// Stable per fix; sent as `x_client_uid` so a batch whose response was lost
  /// is recognised on the server instead of being uploaded twice.
  final String uid;

  /// The local work-day session ([WorkdayTracker]'s record uid) it belongs to.
  final String sessionUid;

  /// The visit that was running when the fix was taken, if any.
  final int? visitId;
  final WorkdayPointSource source;
  final TrailPoint point;

  /// Times the server refused the request carrying this point.
  final int attempts;

  /// A request carrying this point failed in a way that leaves it unknown
  /// whether the server stored it (timeout, dropped connection).
  final bool maybeSent;

  const WorkdayPoint({
    required this.uid,
    required this.sessionUid,
    required this.source,
    required this.point,
    this.visitId,
    this.attempts = 0,
    this.maybeSent = false,
  });

  WorkdayPoint withAttempt() => _copy(attempts: attempts + 1);
  WorkdayPoint markMaybeSent() => _copy(maybeSent: true);

  WorkdayPoint _copy({int? attempts, bool? maybeSent}) => WorkdayPoint(
        uid: uid,
        sessionUid: sessionUid,
        visitId: visitId,
        source: source,
        point: point,
        attempts: attempts ?? this.attempts,
        maybeSent: maybeSent ?? this.maybeSent,
      );

  Map<String, dynamic> toJson() => {
        'u': uid,
        's': sessionUid,
        if (visitId != null) 'v': visitId,
        'src': source.name,
        'n': attempts,
        if (maybeSent) 'ms': true,
        'p': point.toJson(),
      };

  static WorkdayPoint? tryFromJson(Map<String, dynamic> j) {
    final uid = j['u'];
    final session = j['s'];
    final raw = j['p'];
    if (uid is! String || session is! String || raw is! Map) return null;
    final point = TrailPoint.tryFromJson(Map<String, dynamic>.from(raw));
    if (point == null) return null;
    return WorkdayPoint(
      uid: uid,
      sessionUid: session,
      visitId: (j['v'] as num?)?.toInt(),
      source: WorkdayPointSource.values.firstWhere(
        (s) => s.name == j['src'],
        orElse: () => WorkdayPointSource.track,
      ),
      point: point,
      attempts: (j['n'] as num?)?.toInt() ?? 0,
      maybeSent: j['ms'] == true,
    );
  }

  @override
  List<Object?> get props => [uid, attempts, maybeSent];
}

/// A stretch of a work-day route: either one visit, or the movement between
/// visits ([visitId] null). [start] and [end] index into [WorkdayRoute.logs],
/// both inclusive.
class RouteSegment extends Equatable {
  final int? visitId;
  final int start;
  final int end;
  const RouteSegment({required this.visitId, required this.start, required this.end});

  bool get isVisit => visitId != null;
  int get length => end - start + 1;

  @override
  List<Object?> get props => [visitId, start, end];
}

/// A whole work day as stored on the server: the session plus every point of
/// it, oldest first. The authoritative daily route — including the movement
/// between visits that no visit trail contains.
class WorkdayRoute extends Equatable {
  final WorkSession session;
  final List<VisitLocationLog> logs;

  /// Visit reference (e.g. `VIS/2026/00061`) by visit id, as the server named
  /// the many2one on the points.
  final Map<int, String> visitRefs;

  const WorkdayRoute({
    required this.session,
    this.logs = const [],
    this.visitRefs = const {},
  });

  static const List<String> pointFields = [
    'x_session_id',
    'x_visit_id',
    'x_logged_at',
    'x_latitude',
    'x_longitude',
    'x_accuracy',
    'x_altitude',
    'x_speed',
    'x_heading',
    'x_device_id',
    'x_source',
  ];

  factory WorkdayRoute.fromApi(WorkSession session, List<Map<String, dynamic>> rows) {
    final logs = <VisitLocationLog>[];
    final refs = <int, String>{};
    for (final r in rows) {
      final lat = _num(r['x_latitude']);
      final lng = _num(r['x_longitude']);
      final at = parseOdooUtc(r['x_logged_at']);
      if (lat == null || lng == null || at == null) continue;
      if (lat.abs() > 90 || lng.abs() > 180) continue;
      final (visitId, visitRef) = _m2o(r['x_visit_id']);
      if (visitId != null && visitRef != null) refs[visitId] = visitRef;
      logs.add(VisitLocationLog(
        id: (r['id'] as num?)?.toInt() ?? 0,
        visitId: visitId,
        loggedAt: at,
        latitude: lat,
        longitude: lng,
        accuracy: _num(r['x_accuracy']),
        altitude: _num(r['x_altitude']),
        speed: _num(r['x_speed']),
        heading: _num(r['x_heading']),
        deviceId: _str(r['x_device_id']),
        source: trailSourceFromWire(_str(r['x_source'])),
      ));
    }
    // Kept in the server's order (`x_logged_at asc, id asc`), like a visit trail.
    return WorkdayRoute(session: session, logs: logs, visitRefs: refs);
  }

  /// A work day's `points` as `/api/workday/track` returns them, oldest first.
  factory WorkdayRoute.fromWorkdayApi(WorkSession session, List<dynamic> points) {
    final logs = <VisitLocationLog>[];
    final refs = <int, String>{};
    for (final raw in points.whereType<Map>()) {
      final p = Map<String, dynamic>.from(raw);
      final lat = _num(p['latitude']);
      final lng = _num(p['longitude']);
      final at = parseOdooUtc(p['logged_at']);
      if (lat == null || lng == null || at == null) continue;
      if (lat.abs() > 90 || lng.abs() > 180) continue;
      final visitId = (p['visit_id'] is num) ? (p['visit_id'] as num).toInt() : null;
      final visitRef = _str(p['visit_name']);
      if (visitId != null && visitRef != null) refs[visitId] = visitRef;
      logs.add(VisitLocationLog(
        id: (p['id'] as num?)?.toInt() ?? 0,
        visitId: visitId,
        loggedAt: at,
        latitude: lat,
        longitude: lng,
        accuracy: _num(p['accuracy']),
        altitude: _num(p['altitude']),
        speed: _num(p['speed']),
        heading: _num(p['heading']),
        deviceId: _str(p['device_id']),
        source: trailSourceFromWire(_str(p['source'])),
      ));
    }
    return WorkdayRoute(session: session, logs: logs, visitRefs: refs);
  }

  /// Consecutive runs of points sharing a visit (or sharing none).
  List<RouteSegment> get segments {
    final out = <RouteSegment>[];
    var from = 0;
    for (var i = 1; i <= logs.length; i++) {
      if (i == logs.length || logs[i].visitId != logs[from].visitId) {
        out.add(RouteSegment(visitId: logs[from].visitId, start: from, end: i - 1));
        from = i;
      }
    }
    return out;
  }

  List<RouteSegment> get visitSegments =>
      [for (final s in segments) if (s.isVisit) s];

  /// Path length through every point, in km.
  double get distanceKm {
    var m = 0.0;
    for (var i = 1; i < logs.length; i++) {
      m += haversineMeters(logs[i - 1].latitude, logs[i - 1].longitude,
          logs[i].latitude, logs[i].longitude);
    }
    return m / 1000;
  }

  @override
  List<Object?> get props => [session, logs];
}
