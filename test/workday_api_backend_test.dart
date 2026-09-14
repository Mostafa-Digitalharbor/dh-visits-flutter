// The dedicated work-day backend (dh_workday_tracking, /api/workday/*):
//
// * WorkdayRepository detects it and never touches the temporary no-code
//   models on a server that has it; a server without it keeps the legacy path.
// * The tracker's guarantees hold over it unchanged: one server session, every
//   point once and in order, a lost response re-sent without duplicates, a
//   refused point dropped instead of blocking the day.
//
// The server is an in-memory stand-in with the module's contract; the real
// module runs the same scenarios in backend/dh_workday_tracking/tests.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/api/endpoints.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/location/workday_location_channel.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/storage/session_storage.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/features/workday/data/models/workday_models.dart';
import 'package:location_gps/features/workday/data/workday_repository.dart';
import 'package:location_gps/features/workday/data/workday_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `/api/workday/*` as dh_workday_tracking implements it.
class _Module implements ApiClient {
  bool installed = true;
  bool offline = false;
  bool loseNextLogResponse = false;
  double? refuseLatitude;

  final List<String> calls = [];
  final List<Map<String, dynamic>> paramsSeen = [];
  final Map<int, Map<String, dynamic>> sessions = {};
  final Map<int, List<Map<String, dynamic>>> points = {};

  @override
  String get baseUrl => 'https://odoo.test';

  int get callKwCalls => calls.where((c) => c == Endpoints.callKw).length;

  @override
  Future<dynamic> jsonRpc(String path, {Map<String, dynamic>? params}) async {
    calls.add(path);
    paramsSeen.add(params ?? const {});
    if (offline) throw ApiException.network();
    final p = params ?? const {};
    if (path == Endpoints.callKw) {
      return p['method'] == 'search_count' ? 0 : [];
    }
    if (!installed) {
      // What ApiClient makes of Odoo's HTML 404 page for an unknown route.
      throw ApiException(code: ApiErrorCode.notSupported, details: 'Endpoint $path is not deployed.');
    }
    switch (path) {
      case Endpoints.workdayActive:
        final open = sessions.values.where((s) => s['state'] == 'active');
        return {'session': open.isEmpty ? false : _withCount(open.first)};
      case Endpoints.workdayStart:
        final uid = p['client_uid'];
        for (final s in sessions.values) {
          if (s['client_uid'] == uid) return {'session': _withCount(s), 'created': false};
        }
        for (final s in sessions.values) {
          if (s['state'] == 'active') return {'session': _withCount(s), 'created': false};
        }
        final id = sessions.length + 1;
        sessions[id] = {
          'id': id,
          'client_uid': uid,
          'employee_id': 281,
          'started_at': (p['started_at'] as String).replaceFirst(' ', 'T'),
          'ended_at': false,
          'state': 'active',
          'start_latitude': p['latitude'] ?? 0.0,
          'start_longitude': p['longitude'] ?? 0.0,
          'end_latitude': 0.0,
          'end_longitude': 0.0,
        };
        points[id] = [];
        return {'session': _withCount(sessions[id]!), 'created': true};
      case Endpoints.workdayGet:
        Map<String, dynamic>? found;
        for (final s in sessions.values) {
          if (s['id'] == p['session_id'] || (p['client_uid'] != null && s['client_uid'] == p['client_uid'])) {
            found = s;
          }
        }
        return {'session': found == null ? false : _withCount(found)};
      case Endpoints.workdayLogLocations:
        final id = p['session_id'] as int;
        if (sessions[id]?['state'] != 'active') {
          throw ApiException(
            code: ApiErrorCode.validation,
            odooName: 'odoo.exceptions.UserError',
            serverMessage: 'The work day is completed; no position can be added to it.',
          );
        }
        final stored = points[id]!;
        final known = {for (final s in stored) s['client_uid']};
        var created = 0;
        final duplicates = <int>[];
        final rejected = <Map<String, dynamic>>[];
        final sent = (p['points'] as List).cast<Map<String, dynamic>>();
        for (var i = 0; i < sent.length; i++) {
          final point = sent[i];
          if (point['latitude'] == refuseLatitude) {
            rejected.add({'index': i, 'error': 'Latitude ${point['latitude']} is out of range (-90 to 90).'});
          } else if (!known.add(point['client_uid'])) {
            duplicates.add(i);
          } else {
            stored.add({...point, 'id': stored.length + 1, 'session_id': id, 'visit_name': false});
            created++;
          }
        }
        if (loseNextLogResponse) {
          loseNextLogResponse = false;
          throw ApiException.timeout();
        }
        return {'session_id': id, 'created': created, 'duplicates': duplicates, 'rejected': rejected};
      case Endpoints.workdayEnd:
        final s = sessions[p['session_id']]!;
        final already = s['state'] == 'completed';
        if (!already) {
          s
            ..['state'] = 'completed'
            ..['ended_at'] = (p['ended_at'] as String).replaceFirst(' ', 'T');
        }
        return {'session': _withCount(s), 'already_completed': already};
      case Endpoints.workdayTrack:
        Map<String, dynamic> withPoints(Map<String, dynamic> s) => {
              ..._withCount(s),
              'points': [
                for (final pt in points[s['id']]!)
                  {...pt, 'logged_at': (pt['logged_at'] as String).replaceFirst(' ', 'T')},
              ],
            };
        if (p['session_id'] != null) return withPoints(sessions[p['session_id']]!);
        return {'sessions': [for (final s in sessions.values) withPoints(s)]};
    }
    throw StateError('unexpected route $path');
  }

  Map<String, dynamic> _withCount(Map<String, dynamic> s) =>
      {...s, 'location_count': points[s['id']]?.length ?? 0};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel extends WorkdayLocationChannel {
  final List<CapturedFix> journal = [];
  bool active = false;
  bool running = false;
  String? session;
  int? visitId;
  int _seq = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> start({
    required String sessionUid,
    required double minDistanceMeters,
    required Duration minInterval,
    required double maxAccuracyMeters,
    required DateTime startedAt,
    required String title,
    required String text,
    int? visitId,
    DateTime? visitSince,
    double? seedLatitude,
    double? seedLongitude,
  }) async {
    active = running = true;
    session = sessionUid;
    this.visitId = visitId;
  }

  @override
  Future<void> stop() async => active = running = false;

  @override
  Future<void> setVisit(int? visitId, DateTime since) async => this.visitId = visitId;

  @override
  Future<({bool active, bool running})> status() async => (active: active, running: running);

  @override
  Future<List<CapturedFix>> read({int max = 500}) async => journal.take(max).toList();

  @override
  Future<void> ack(int throughSeq) async => journal.removeWhere((f) => f.seq <= throughSeq);

  void capture(double lat, double lng) {
    if (!active) return;
    journal.add(CapturedFix(
      seq: ++_seq,
      deviceTime: DateTime.now().toUtc(),
      latitude: lat,
      longitude: lng,
      accuracy: 6,
      sessionUid: session!,
      visitId: visitId,
    ));
  }
}

class _Session implements SessionStorage {
  @override
  Future<Map<String, dynamic>?> getUser() async => {'uid': 284, 'employee_id': 281};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location extends LocationService {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<Position> watch({LocationAccuracy accuracy = LocationAccuracy.high, int distanceFilter = 5}) =>
      const Stream.empty();
}

class _VisitApi implements VisitsRepository {
  final Map<int, List<TrailPoint>> received = {};

  @override
  Future<TrailFlushResult> logLocations(int visitId, List<TrailPoint> points) async {
    received.putIfAbsent(visitId, () => []).addAll(points);
    return TrailFlushResult(created: points.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkdayPoint _point(String uid, double lat, {int? visit}) => WorkdayPoint(
      uid: uid,
      sessionUid: 'wd-1',
      visitId: visit,
      source: WorkdayPointSource.track,
      point: TrailPoint(
        latitude: lat,
        longitude: 46.6,
        loggedAt: DateTime.now().toUtc(),
        accuracy: 5,
      ),
    );

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WorkdayRepository', () {
    test('uses /api/workday/* where it exists and never the no-code models', () async {
      final module = _Module();
      final repo = WorkdayRepository(api: module);

      expect(await repo.backend(), WorkdayBackend.api);
      expect(await repo.isSupported(), isTrue);
      expect(await repo.activeSession(284), isNull);
      final id = await repo.createSession(
        clientUid: 'wd-1',
        startedAt: DateTime.utc(2026, 9, 13, 8),
        employeeId: 281,
        latitude: 24.7,
        longitude: 46.6,
      );
      expect(id, 1);
      final startParams = module.paramsSeen[module.calls.lastIndexOf(Endpoints.workdayStart)];
      expect(startParams.containsKey('employee_id'), isFalse,
          reason: 'the server derives the employee from the signed-in user');
      expect((await repo.sessionByClientUid('wd-1'))!.id, 1);
      expect((await repo.readSession(1))!.isActive, isTrue);
      expect(module.callKwCalls, 0);
      expect(module.calls.where((c) => c == Endpoints.workdayActive).length, 2,
          reason: 'probed once, then one real call');
    });

    test('keeps the legacy no-code models where the module is not installed', () async {
      final module = _Module()..installed = false;
      final repo = WorkdayRepository(api: module);
      expect(await repo.backend(), WorkdayBackend.legacyModels);
      expect(await repo.isSupported(), isTrue);
      final call = module.paramsSeen.lastWhere((p) => p['method'] == 'search_count');
      expect(call['model'], 'x_dh_work_session');
    });

    test('an offline probe is retried, not remembered', () async {
      final module = _Module()..offline = true;
      final repo = WorkdayRepository(api: module);
      await expectLater(repo.backend(), throwsA(isA<ApiException>()));
      module.offline = false;
      expect(await repo.backend(), WorkdayBackend.api);
    });

    test('upload: re-sent points are fine; a refused point is thrown after the '
        'others are stored', () async {
      final module = _Module();
      final repo = WorkdayRepository(api: module);
      final id = await repo.createSession(clientUid: 'wd-1', startedAt: DateTime.now().toUtc());
      final batch = [_point('wd-1-1', 24.701), _point('wd-1-2', 24.702, visit: 61)];
      await repo.createPoints(id, points: batch);
      await repo.createPoints(id, points: batch); // response lost earlier: harmless
      expect(module.points[id], hasLength(2));
      expect(module.points[id]![1]['visit_id'], 61);
      expect(await repo.existingPointUids(['wd-1-1']), isEmpty,
          reason: 'the server dedupes; nothing to check first');

      module.refuseLatitude = 24.9;
      await expectLater(
        repo.createPoints(id, points: [_point('wd-1-3', 24.703), _point('wd-1-4', 24.9)]),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.validation)
            .having((e) => e.serverMessage, 'message', contains('out of range'))),
      );
      expect(module.points[id]!.map((p) => p['client_uid']), ['wd-1-1', 'wd-1-2', 'wd-1-3']);
    });

    test("today's route comes back in one request, points in order with visits", () async {
      final module = _Module();
      final repo = WorkdayRepository(api: module);
      final id = await repo.createSession(clientUid: 'wd-1', startedAt: DateTime.now().toUtc());
      await repo.createPoints(id, points: [_point('a', 24.701), _point('b', 24.702, visit: 61)]);
      await repo.completeSession(id, endedAt: DateTime.now().toUtc());
      await repo.completeSession(id, endedAt: DateTime.now().toUtc());

      final before = module.calls.length;
      final sessions = await repo.sessionsForDay(284, DateTime.now());
      final route = await repo.readRoute(sessions.single);
      expect(module.calls.length - before, 1);
      expect(sessions.single.state, WorkSessionState.completed);
      expect(route.logs.map((l) => l.latitude), [24.701, 24.702]);
      expect(route.logs.map((l) => l.visitId), [null, 61]);
      expect(route.segments.map((s) => s.visitId), [null, 61]);
    });
  });

  group('WorkdayTracker over the dedicated API', () {
    late _Module module;
    late _Channel channel;
    late WorkdayTracker day;
    late VisitTrailTracker visits;
    late _VisitApi visitApi;

    Future<void> build() async {
      final prefs = await SharedPreferences.getInstance();
      final connectivity = ConnectivityStatus();
      visitApi = _VisitApi();
      visits = VisitTrailTracker(
        prefs: prefs,
        repository: visitApi,
        locationService: _Location(),
        connectivity: connectivity,
      );
      day = WorkdayTracker(
        prefs: prefs,
        repository: WorkdayRepository(api: module),
        sessionStorage: _Session(),
        locationService: _Location(),
        connectivity: connectivity,
        channel: channel,
        visitTracker: () => visits,
      );
      visits.feed = day;
    }

    setUp(() async {
      module = _Module();
      channel = _Channel();
      await build();
    });

    tearDown(() {
      day.dispose();
      visits.dispose();
    });

    Future<void> startDay() => day.startDay(
        latitude: 24.7, longitude: 46.6, notificationTitle: 't', notificationText: 'x');

    test('a whole day: one session, every point once and in order, nothing '
        'after the end', () async {
      await startDay();
      await _tick();
      channel.capture(24.701, 46.601);
      await day.drain();
      await visits.start(61);
      await _tick();
      channel.capture(24.702, 46.602);
      await visits.stop();
      await _tick();
      channel.capture(24.703, 46.603);
      expect(await day.endDay(latitude: 24.704, longitude: 46.604), isTrue);

      expect(module.sessions, hasLength(1));
      expect(module.sessions[1]!['state'], 'completed');
      final stored = module.points[1]!;
      expect(stored.map((p) => p['source']), ['start', 'track', 'track', 'track', 'end']);
      expect(stored.map((p) => p['latitude']), [24.7, 24.701, 24.702, 24.703, 24.704]);
      expect(stored.map((p) => p['visit_id']), [null, null, 61, null, null]);
      expect(visitApi.received[61]!.map((p) => p.latitude), [24.702]);
      expect(module.callKwCalls, 0);
      channel.capture(24.8, 46.8);
      expect(channel.journal, isEmpty);
    });

    test('offline start, lost response and restart: still one session, no '
        'duplicate point', () async {
      module.offline = true;
      await startDay();
      await _tick();
      channel.capture(24.701, 46.601);
      await day.drain();
      await day.flushNow(probe: true);
      expect(module.sessions, isEmpty);

      module
        ..offline = false
        ..loseNextLogResponse = true;
      await day.flushNow(); // stored, but the response never arrives
      expect(module.points[1], hasLength(2));
      expect(day.status.value.pending, 2);

      day.dispose();
      visits.dispose();
      channel.running = false;
      await build(); // app restarted
      await day.restore(notificationTitle: 't', notificationText: 'x');
      await _tick();
      channel.capture(24.702, 46.602);
      await day.drain();
      await day.flushNow();

      expect(module.sessions, hasLength(1));
      expect(module.points[1]!.map((p) => p['latitude']), [24.7, 24.701, 24.702]);
      expect(day.status.value.pending, 0);
    });

    test('a day open on the server from another phone is adopted', () async {
      module.sessions[5] = {
        'id': 5,
        'client_uid': 'wd-other-phone',
        'employee_id': 281,
        'started_at': '2026-09-13T08:00:00',
        'ended_at': false,
        'state': 'active',
        'start_latitude': 0.0,
        'start_longitude': 0.0,
        'end_latitude': 0.0,
        'end_longitude': 0.0,
      };
      module.points[5] = [];
      await day.restore(notificationTitle: 't', notificationText: 'x');
      expect(channel.session, 'wd-other-phone');
      await _tick();
      channel.capture(24.701, 46.601);
      await day.drain();
      await day.flushNow();
      expect(module.sessions, hasLength(1));
      expect(module.points[5]!.single['latitude'], 24.701);
    });

    test('a point the server refuses is dropped and reported; the rest of the '
        'day still uploads and completes', () async {
      final dropped = <int>[];
      final sub = day.onPointsDropped.listen(dropped.add);
      module.refuseLatitude = 24.702;
      await startDay();
      for (final lat in [24.701, 24.702, 24.703]) {
        await _tick();
        channel.capture(lat, 46.6);
      }
      await day.drain();
      for (var i = 0; i < 6 && day.status.value.pending > 0; i++) {
        await day.flushNow();
      }
      expect(await day.endDay(latitude: 24.704, longitude: 46.604), isTrue);
      await Future<void>.delayed(Duration.zero);

      expect(dropped, [1]);
      expect(module.points[1]!.map((p) => p['latitude']), [24.7, 24.701, 24.703, 24.704]);
      expect(module.sessions[1]!['state'], 'completed');
      await sub.cancel();
    });
  });
}
