import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/odoo_rpc.dart';
import '../../../core/constants.dart';
import '../../visits/data/visits_repository.dart';
import 'models/workday_models.dart';

/// Where a server keeps the whole-workday route.
enum WorkdayBackend {
  /// The `dh_workday_tracking` module: dedicated `/api/workday/*` routes with
  /// server-side rules (one active day per employee, no point after the end,
  /// append-only points, idempotent uploads). The production backend.
  api,

  /// Temporary no-code models `x_dh_work_session` / `x_dh_work_location`
  /// written through `call_kw`. Exists only on the dummy development server;
  /// kept so that server keeps working until the module is installed there.
  legacyModels,
}

/// Server side of the whole-workday route.
///
/// `dh_visit_management` stores GPS only per visit (`dh.visit.location.log`
/// requires a `visit_id`), so the movement between visits lives in a work day
/// of its own. Which store a server has is detected once per server
/// ([backend]): the dedicated API wherever `/api/workday/*` exists, the legacy
/// no-code models otherwise. Every method keeps the same meaning on both, so
/// `WorkdayTracker` does not know which one it is talking to.
///
/// Access is enforced by the server, never by this class. See
/// docs/WORKDAY_TRACKING.md for the models, the API and the rules.
class WorkdayRepository {
  final ApiClient api;
  WorkdayRepository({required this.api});

  static const String sessionModel = AppConstants.workSessionModel;
  static const String locationModel = AppConstants.workLocationModel;

  WorkdayBackend? _backend;
  String? _backendFor;

  /// Points already returned by [sessionsForDay], so the [readRoute] that
  /// follows it costs no second request.
  final Map<int, List<dynamic>> _dayPoints = {};

  /// Odoo answers `call_kw` on a model that doesn't exist with a werkzeug
  /// `NotFound` (older versions: a `KeyError`) inside an HTTP 200.
  static bool isMissingModel(ApiException e) =>
      e.odooName == 'werkzeug.exceptions.NotFound' ||
      e.odooName == 'builtins.KeyError';

  /// A route the server does not have: Odoo answers with its HTML 404 page
  /// (`notSupported` from [ApiClient]) or a bare 404.
  static bool _isMissingRoute(ApiException e) =>
      e.odooName == 'werkzeug.exceptions.NotFound' ||
      (e.odooName == null &&
          (e.code == ApiErrorCode.notSupported ||
              e.code == ApiErrorCode.notFound));

  static bool _isTransient(ApiException e) =>
      e.code == ApiErrorCode.network ||
      e.code == ApiErrorCode.timeout ||
      e.code == ApiErrorCode.unauthorized;

  static String _utc(DateTime d) => VisitsRepository.formatOdooUtc(d);

  /// Which store the connected server has. Probed once per server URL; a
  /// probe that fails for a transient reason (offline) is not remembered.
  Future<WorkdayBackend> backend() async {
    final server = api.baseUrl;
    final known = _backend;
    if (known != null && _backendFor == server) return known;
    WorkdayBackend found;
    try {
      await api.jsonRpc(Endpoints.workdayActive);
      found = WorkdayBackend.api;
    } on ApiException catch (e) {
      if (_isMissingRoute(e)) {
        found = WorkdayBackend.legacyModels;
      } else if (_isTransient(e)) {
        rethrow;
      } else {
        // The route exists and refused this user (e.g. no employee record):
        // it is still the dedicated API.
        found = WorkdayBackend.api;
      }
    }
    _backend = found;
    _backendFor = server;
    _dayPoints.clear();
    return found;
  }

  Future<bool> get _useApi async => await backend() == WorkdayBackend.api;

  static Map<String, dynamic>? _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : null;

  static WorkSession? _sessionFrom(dynamic result) {
    final session = _map(_map(result)?['session']);
    return session == null ? null : WorkSession.tryFromWorkdayApi(session);
  }

  /// Whether this server has a work-day store at all.
  Future<bool> isSupported() async {
    if (await _useApi) return true;
    try {
      await api.searchCount(sessionModel, domain: const [
        ['id', '=', 0],
      ]);
      return true;
    } on ApiException catch (e) {
      if (isMissingModel(e)) return false;
      rethrow;
    }
  }

  Future<WorkSession?> _one(List<dynamic> domain) async {
    final rows = await api.searchRead(
      sessionModel,
      domain: domain,
      fields: WorkSession.fields,
      order: 'x_started_at desc, id desc',
      limit: 1,
    );
    return rows.isEmpty ? null : WorkSession.tryFromApi(rows.first);
  }

  /// The user's work day that is still open, if any.
  Future<WorkSession?> activeSession(int uid) async {
    if (await _useApi) {
      return _sessionFrom(await api.jsonRpc(Endpoints.workdayActive));
    }
    return _one([
      ['create_uid', '=', uid],
      ['x_state', '=', 'active'],
    ]);
  }

  Future<WorkSession?> sessionByClientUid(String clientUid) async {
    if (await _useApi) {
      return _sessionFrom(await api.jsonRpc(Endpoints.workdayGet,
          params: {'client_uid': clientUid}));
    }
    return _one([
      ['x_client_uid', '=', clientUid],
    ]);
  }

  /// Null when the session is gone or not readable by this user.
  Future<WorkSession?> readSession(int id) async {
    if (await _useApi) {
      return _sessionFrom(
          await api.jsonRpc(Endpoints.workdayGet, params: {'session_id': id}));
    }
    return _one([
      ['id', '=', id],
    ]);
  }

  /// Opens the work day on the server and returns its id. With the dedicated
  /// API this is idempotent on [clientUid], and when the employee already has
  /// an open day that day's id is returned instead of opening a second one.
  Future<int> createSession({
    required String clientUid,
    required DateTime startedAt,
    int? employeeId,
    double? latitude,
    double? longitude,
    String? deviceId,
  }) async {
    if (await _useApi) {
      // No employee id: the server derives it from the signed-in user.
      final session = _sessionFrom(await api.jsonRpc(Endpoints.workdayStart, params: {
        'client_uid': clientUid,
        'started_at': _utc(startedAt),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (deviceId != null) 'device_id': deviceId,
      }));
      if (session == null) {
        throw ApiException(
          code: ApiErrorCode.server,
          details: '${Endpoints.workdayStart} returned no session',
        );
      }
      return session.id;
    }
    final id = await api.createRecord(sessionModel, {
      'x_name': 'WD ${_utc(startedAt)}',
      'x_client_uid': clientUid,
      if (employeeId != null) 'x_employee_id': employeeId,
      'x_started_at': _utc(startedAt),
      'x_state': 'active',
      if (latitude != null) 'x_start_latitude': latitude,
      if (longitude != null) 'x_start_longitude': longitude,
      if (deviceId != null) 'x_device_id': deviceId,
    });
    if (id == null) {
      throw ApiException(
        code: ApiErrorCode.server,
        details: 'create $sessionModel returned no id',
      );
    }
    return id;
  }

  Future<void> completeSession(
    int id, {
    required DateTime endedAt,
    double? latitude,
    double? longitude,
  }) async {
    if (await _useApi) {
      // Ending a day that already is completed answers normally.
      await api.jsonRpc(Endpoints.workdayEnd, params: {
        'session_id': id,
        'ended_at': _utc(endedAt),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      return;
    }
    await api.writeRecord(sessionModel, [id], {
      'x_state': 'completed',
      'x_ended_at': _utc(endedAt),
      if (latitude != null) 'x_end_latitude': latitude,
      if (longitude != null) 'x_end_longitude': longitude,
    });
  }

  /// Uploads [points]. Returns normally only when every point is on the
  /// server afterwards (stored now, or already stored earlier).
  ///
  /// With the legacy models a create is all-or-nothing. With the dedicated
  /// API each point is judged on its own: the accepted ones are stored and a
  /// refusal of any is thrown as [ApiErrorCode.validation] — the caller then
  /// re-sends the batch point by point, where the stored ones come back as
  /// duplicates and only the refused one fails.
  Future<List<int>> createPoints(
    int sessionId, {
    required List<WorkdayPoint> points,
    int? employeeId,
  }) async {
    if (points.isEmpty) return const [];
    if (await _useApi) {
      final result = _map(await api.jsonRpc(Endpoints.workdayLogLocations, params: {
        'session_id': sessionId,
        'points': [
          for (final p in points)
            {
              'client_uid': p.uid,
              // The fix's own time on the server clock — never the upload time.
              'logged_at': _utc(p.point.loggedAt),
              'latitude': p.point.latitude,
              'longitude': p.point.longitude,
              if (p.point.accuracy != null) 'accuracy': p.point.accuracy,
              if (p.point.altitude != null) 'altitude': p.point.altitude,
              if (p.point.speed != null) 'speed': p.point.speed,
              if (p.point.heading != null) 'heading': p.point.heading,
              if (p.visitId != null) 'visit_id': p.visitId,
              if (p.point.deviceId != null) 'device_id': p.point.deviceId,
              'source': p.source.name,
            },
        ],
      }));
      final rejected = [
        for (final r in (result?['rejected'] as List?) ?? const [])
          if (r is Map) Map<String, dynamic>.from(r),
      ];
      if (rejected.isNotEmpty) {
        throw ApiException(
          code: ApiErrorCode.validation,
          serverMessage: rejected.first['error']?.toString(),
          odooName: 'odoo.exceptions.ValidationError',
          details: {'rejected': rejected},
        );
      }
      return const [];
    }
    final result = await api.callMethod(locationModel, 'create', args: [
      [
        for (final p in points)
          {
            'x_name': p.uid,
            'x_client_uid': p.uid,
            'x_session_id': sessionId,
            if (employeeId != null) 'x_employee_id': employeeId,
            'x_visit_id': p.visitId ?? false,
            // The fix's own time on the server clock — never the upload time.
            'x_logged_at': _utc(p.point.loggedAt),
            'x_latitude': p.point.latitude,
            'x_longitude': p.point.longitude,
            if (p.point.accuracy != null) 'x_accuracy': p.point.accuracy,
            if (p.point.altitude != null) 'x_altitude': p.point.altitude,
            if (p.point.speed != null) 'x_speed': p.point.speed,
            if (p.point.heading != null) 'x_heading': p.point.heading,
            if (p.point.deviceId != null) 'x_device_id': p.point.deviceId,
            'x_source': p.source.name,
          },
      ],
    ]);
    if (result is List) {
      return [for (final r in result) if (r is num) r.toInt()];
    }
    return result is num ? [result.toInt()] : const [];
  }

  /// Which of [uids] the server already holds. The dedicated API recognises
  /// re-sent points by their uid itself, so nothing needs checking first.
  Future<Set<String>> existingPointUids(List<String> uids) async {
    if (uids.isEmpty || await _useApi) return const {};
    final rows = await api.searchRead(
      locationModel,
      domain: [
        ['x_client_uid', 'in', uids],
      ],
      fields: const ['x_client_uid'],
    );
    return {
      for (final r in rows)
        if (r['x_client_uid'] is String) r['x_client_uid'] as String,
    };
  }

  /// The user's work days that overlap the local calendar day of [day]:
  /// started before it ends, and either still open or ended after it began.
  Future<List<WorkSession>> sessionsForDay(int uid, DateTime day) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    if (await _useApi) {
      // Without employee_id the server answers for the caller's own days.
      final result = _map(await api.jsonRpc(Endpoints.workdayTrack, params: {
        'date_from': _utc(from),
        'date_to': _utc(to),
      }));
      final sessions = <WorkSession>[];
      for (final raw in (result?['sessions'] as List?) ?? const []) {
        final json = _map(raw);
        final session = json == null ? null : WorkSession.tryFromWorkdayApi(json);
        if (session == null) continue;
        sessions.add(session);
        _dayPoints[session.id] = (json!['points'] as List?) ?? const [];
      }
      return sessions;
    }
    final rows = await api.searchRead(
      sessionModel,
      domain: [
        // Explicit even though the record rules already scope an employee to
        // their own rows: a manager can read everyone's, and this screen is
        // the user's own day only.
        ['create_uid', '=', uid],
        ['x_started_at', '<', _utc(to)],
        '|',
        ['x_state', '=', 'active'],
        ['x_ended_at', '>=', _utc(from)],
      ],
      fields: WorkSession.fields,
      order: 'x_started_at asc, id asc',
    );
    return [
      for (final r in rows) ?WorkSession.tryFromApi(r),
    ];
  }

  /// Every point of [session], oldest first, exactly as the server stores it.
  Future<WorkdayRoute> readRoute(WorkSession session) async {
    if (await _useApi) {
      final points = _dayPoints.remove(session.id) ??
          (_map(await api.jsonRpc(Endpoints.workdayTrack,
                  params: {'session_id': session.id}))?['points'] as List? ??
              const []);
      return WorkdayRoute.fromWorkdayApi(session, points);
    }
    final rows = await api.searchRead(
      locationModel,
      domain: [
        ['x_session_id', '=', session.id],
      ],
      fields: WorkdayRoute.pointFields,
      order: 'x_logged_at asc, id asc',
    );
    return WorkdayRoute.fromApi(session, rows);
  }
}
