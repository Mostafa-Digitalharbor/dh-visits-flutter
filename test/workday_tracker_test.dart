// Whole-workday route: what must hold end to end, with the native capture
// service and the server replaced by in-memory stand-ins.
//
// * One work day on the server per day, every point in fix order, the visit
//   portion attributed to its visit AND delivered to that visit's own trail.
// * Offline: nothing lost, nothing uploaded twice when a response goes missing.
// * Restart: the same work day resumes; no second session is ever created.
// * End: capture stops first, and not one point is recorded afterwards.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
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

/// The Android foreground service: a journal that only accepts fixes while
/// capture is active, stamped with the running visit.
class _Channel extends WorkdayLocationChannel {
  final List<CapturedFix> journal = [];
  bool active = false;
  bool running = false;
  String? session;
  int? visitId;
  int starts = 0;
  (double?, double?)? seed;
  (double, Duration, double)? sampling;
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
    active = true;
    running = true;
    seed = (seedLatitude, seedLongitude);
    sampling = (minDistanceMeters, minInterval, maxAccuracyMeters);
    session = sessionUid;
    this.visitId = visitId;
    starts++;
  }

  @override
  Future<void> stop() async {
    active = false;
    running = false;
  }

  @override
  Future<void> setVisit(int? visitId, DateTime since) async {
    this.visitId = visitId;
  }

  @override
  Future<({bool active, bool running})> status() async =>
      (active: active, running: running);

  @override
  Future<List<CapturedFix>> read({int max = 500}) async =>
      journal.take(max).toList();

  @override
  Future<void> ack(int throughSeq) async =>
      journal.removeWhere((f) => f.seq <= throughSeq);

  /// A location update reaching the service. False when it was ignored.
  bool capture(double lat, double lng) {
    if (!active) return false;
    journal.add(CapturedFix(
      seq: ++_seq,
      deviceTime: DateTime.now().toUtc(),
      latitude: lat,
      longitude: lng,
      sessionUid: session!,
      visitId: visitId,
    ));
    return true;
  }
}

class _StoredSession {
  final int id;
  final String clientUid;
  final DateTime startedAt;
  String state = 'active';
  _StoredSession(this.id, this.clientUid, this.startedAt);

  WorkSession toModel() => WorkSession(
        id: id,
        clientUid: clientUid,
        startedAt: startedAt,
        state: state == 'active'
            ? WorkSessionState.active
            : WorkSessionState.completed,
      );
}

/// The Odoo work-day store, including its access rule: a point is accepted
/// only into an active session.
class _Server implements WorkdayRepository {
  final Map<int, _StoredSession> sessions = {};
  final List<({int session, WorkdayPoint point})> points = [];
  bool offline = false;
  bool supported = true;

  /// The next point create is stored but its response never arrives.
  bool loseNextResponse = false;
  int createSessionCalls = 0;

  void _net() {
    if (offline) throw ApiException(code: ApiErrorCode.network);
  }

  @override
  Future<bool> isSupported() async {
    _net();
    return supported;
  }

  @override
  Future<WorkSession?> activeSession(int uid) async {
    _net();
    for (final s in sessions.values) {
      if (s.state == 'active') return s.toModel();
    }
    return null;
  }

  @override
  Future<WorkSession?> sessionByClientUid(String clientUid) async {
    _net();
    for (final s in sessions.values) {
      if (s.clientUid == clientUid) return s.toModel();
    }
    return null;
  }

  @override
  Future<WorkSession?> readSession(int id) async {
    _net();
    return sessions[id]?.toModel();
  }

  @override
  Future<int> createSession({
    required String clientUid,
    required DateTime startedAt,
    int? employeeId,
    double? latitude,
    double? longitude,
    String? deviceId,
  }) async {
    _net();
    createSessionCalls++;
    final id = sessions.length + 1;
    sessions[id] = _StoredSession(id, clientUid, startedAt);
    return id;
  }

  @override
  Future<void> completeSession(
    int id, {
    required DateTime endedAt,
    double? latitude,
    double? longitude,
  }) async {
    _net();
    final s = sessions[id]!;
    if (s.state != 'active') {
      throw ApiException(
          code: ApiErrorCode.permissionDenied,
          odooName: 'odoo.exceptions.AccessError');
    }
    s.state = 'completed';
  }

  @override
  Future<List<int>> createPoints(
    int sessionId, {
    required List<WorkdayPoint> points,
    int? employeeId,
  }) async {
    _net();
    if (sessions[sessionId]?.state != 'active') {
      throw ApiException(
          code: ApiErrorCode.permissionDenied,
          odooName: 'odoo.exceptions.AccessError');
    }
    for (final p in points) {
      this.points.add((session: sessionId, point: p));
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw ApiException(code: ApiErrorCode.timeout);
    }
    return [for (var i = 0; i < points.length; i++) this.points.length - i];
  }

  @override
  Future<Set<String>> existingPointUids(List<String> uids) async {
    _net();
    return {
      for (final p in points)
        if (uids.contains(p.point.uid)) p.point.uid,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements SessionStorage {
  @override
  Future<Map<String, dynamic>?> getUser() async =>
      {'uid': 284, 'employee_id': 281};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location extends LocationService {
  int streamsOpened = 0;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<Position> watch({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) {
    streamsOpened++;
    return const Stream.empty();
  }
}

class _VisitApi implements VisitsRepository {
  final Map<int, List<TrailPoint>> received = {};

  @override
  Future<TrailFlushResult> logLocations(
      int visitId, List<TrailPoint> points) async {
    received.putIfAbsent(visitId, () => []).addAll(points);
    return TrailFlushResult(created: points.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rig {
  final WorkdayTracker day;
  final VisitTrailTracker visits;
  final _VisitApi visitApi;
  final _Location location;
  _Rig(this.day, this.visits, this.visitApi, this.location);

  void dispose() {
    day.dispose();
    visits.dispose();
  }
}

_Rig _rig(SharedPreferences prefs, _Server server, _Channel channel) {
  final connectivity = ConnectivityStatus();
  final location = _Location();
  final visitApi = _VisitApi();
  final visits = VisitTrailTracker(
    prefs: prefs,
    repository: visitApi,
    locationService: location,
    connectivity: connectivity,
  );
  final day = WorkdayTracker(
    prefs: prefs,
    repository: server,
    sessionStorage: _Session(),
    locationService: location,
    connectivity: connectivity,
    channel: channel,
    visitTracker: () => visits,
  );
  visits.feed = day;
  return _Rig(day, visits, visitApi, location);
}

/// Distinct fix times, so "oldest first" is unambiguous.
Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 3));

Future<void> _startDay(WorkdayTracker day) => day.startDay(
      latitude: 24.7000,
      longitude: 46.6000,
      notificationTitle: 'Workday tracking active',
      notificationText: 'Location tracking is currently running',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'start → movement → visit → movement → end: one server session, every '
      'point in order, the visit stretch also on the visit trail, nothing '
      'after the end', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server();
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);

    await _startDay(rig.day);
    expect(channel.active, isTrue);
    expect(rig.day.status.value.isActive, isTrue);

    await _tick();
    channel.capture(24.7010, 46.6010); // movement before the visit
    await _tick();
    channel.capture(24.7020, 46.6020);
    await rig.day.drain();

    await rig.visits.start(61);
    // One location source: the visit tracker opened no GPS stream of its own.
    expect(rig.location.streamsOpened, 0);
    await _tick();
    channel.capture(24.7030, 46.6030); // inside visit 61
    await _tick();
    channel.capture(24.7040, 46.6040);
    await rig.visits.stop(); // End visit: drains the capture and flushes

    await _tick();
    channel.capture(24.7050, 46.6050); // movement after the visit
    await _tick();
    final synced = await rig.day.endDay(latitude: 24.7060, longitude: 46.6060);

    expect(synced, isTrue);
    expect(channel.active, isFalse);
    expect(channel.capture(24.8, 46.8), isFalse,
        reason: 'capture must refuse fixes once the work day ended');
    expect(server.createSessionCalls, 1);
    expect(server.sessions[1]!.state, 'completed');

    final stored = [for (final p in server.points) p.point];
    expect(stored.map((p) => p.source.name),
        ['start', 'track', 'track', 'track', 'track', 'track', 'end']);
    expect(stored.map((p) => p.visitId), [null, null, null, 61, 61, null, null]);
    expect(stored.map((p) => p.point.latitude),
        [24.7000, 24.7010, 24.7020, 24.7030, 24.7040, 24.7050, 24.7060]);
    for (var i = 1; i < stored.length; i++) {
      expect(stored[i].point.loggedAt.isBefore(stored[i - 1].point.loggedAt),
          isFalse);
    }
    // The visit's own trail received exactly its two fixes.
    expect(rig.visitApi.received[61]!.map((p) => p.latitude), [24.7030, 24.7040]);
    expect(rig.day.status.value.pending, 0);
    expect(rig.day.status.value.isActive, isFalse);
    rig.dispose();
  });

  test('offline fixes wait on the device and upload once, even when a '
      'response is lost', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server();
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);
    await _startDay(rig.day);
    await rig.day.flushNow();
    expect(server.points, hasLength(1));

    server.offline = true;
    for (var i = 1; i <= 3; i++) {
      await _tick();
      channel.capture(24.70 + i / 1000, 46.60);
    }
    await rig.day.drain();
    await rig.day.flushNow(probe: true);
    expect(rig.day.status.value.pending, 3);
    expect(channel.journal, isEmpty, reason: 'taken over into the queue');

    server
      ..offline = false
      ..loseNextResponse = true;
    await rig.day.flushNow(); // stored, but the app never hears back
    expect(server.points, hasLength(4));
    expect(rig.day.status.value.pending, 3);

    await rig.day.flushNow(); // checks before resending
    expect(server.points, hasLength(4), reason: 'no duplicates');
    expect(rig.day.status.value.pending, 0);
    rig.dispose();
  });

  test('capture samples densely, treats the start position as recorded, and an '
      'app update with new sampling rules restarts a service still running',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server();
    final channel = _Channel();
    final first = _rig(prefs, server, channel);
    await _startDay(first.day);
    expect(channel.starts, 1);
    expect(channel.seed, (24.7000, 46.6000),
        reason: 'the start point is not recorded a second time by the service');
    expect(channel.sampling, (
      AppConstants.workdayMinDistanceMeters,
      AppConstants.workdayMinInterval,
      AppConstants.workdayMaxAccuracyMeters,
    ));
    expect(AppConstants.workdayMinDistanceMeters, lessThanOrEqualTo(15));
    expect(AppConstants.workdayMinInterval, lessThanOrEqualTo(const Duration(seconds: 10)));
    first.dispose();

    // Same rules, service alive: a restore leaves it alone.
    final same = _rig(prefs, server, channel);
    await same.day.restore(notificationTitle: 't', notificationText: 'x');
    expect(channel.starts, 1);
    same.dispose();

    // The previous version started it with its own (sparser) rules.
    await prefs.setString('workday_sampling_v1', '20.0|20000|100.0');
    final updated = _rig(prefs, server, channel);
    await updated.day.restore(notificationTitle: 't', notificationText: 'x');
    expect(channel.starts, 2, reason: 'running service restarted with new rules');
    expect(server.createSessionCalls, 1);
    updated.dispose();
  });

  test('an app restart resumes the same work day and never opens a second '
      'session', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server();
    final channel = _Channel();
    final first = _rig(prefs, server, channel);
    await _startDay(first.day);
    await first.day.flushNow();
    await _tick();
    channel.capture(24.7010, 46.6010);
    first.dispose();
    channel.running = false; // the process died; the journal survived

    final second = _rig(prefs, server, channel);
    await second.day.restore(
        notificationTitle: 'Workday tracking active',
        notificationText: 'Location tracking is currently running');
    expect(second.day.status.value.isActive, isTrue);
    expect(channel.starts, 2, reason: 'capture restarted');
    await _tick();
    channel.capture(24.7020, 46.6020);
    await second.day.drain();
    await second.day.flushNow();

    expect(server.createSessionCalls, 1);
    expect(server.points.map((p) => p.session).toSet(), {1});
    expect(server.points.map((p) => p.point.point.latitude),
        [24.7000, 24.7010, 24.7020]);
    second.dispose();
  });

  test('a reinstall in the middle of a day never reuses a fix uid the server '
      'already holds', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server();
    final first = _rig(prefs, server, _Channel());
    await _startDay(first.day);
    await _tick();
    final oldChannel = first.day.channel as _Channel;
    oldChannel.capture(24.7010, 46.6010); // journal seq 1
    await first.day.drain();
    await first.day.flushNow();
    first.dispose();

    // App data cleared: local days, queue and journal position are gone, and
    // the new install's journal numbers its fixes from 1 again.
    await prefs.clear();
    final channel = _Channel();
    final second = _rig(prefs, server, channel);
    await second.day.restore(notificationTitle: 't', notificationText: 'x');
    await _tick();
    channel.capture(24.7020, 46.6020); // journal seq 1 again
    await second.day.drain();
    await second.day.flushNow();

    final uids = server.points.map((p) => p.point.uid).toList();
    expect(uids.toSet().length, uids.length, reason: 'uids stay unique: $uids');
    expect(server.points.map((p) => p.point.point.latitude),
        containsAll([24.7010, 24.7020]),
        reason: 'the fix after the reinstall is stored, not dropped');
    expect(server.createSessionCalls, 1);
    second.dispose();
  });

  test('a work day open on the server is adopted, not duplicated', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server()
      ..sessions[7] = _StoredSession(7, 'wd-other-device', DateTime.utc(2026, 9, 13, 8));
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);

    await rig.day.restore(notificationTitle: 't', notificationText: 'x');
    expect(rig.day.status.value.isActive, isTrue);
    expect(channel.session, 'wd-other-device');

    await _startDay(rig.day); // a Start tap now changes nothing
    await _tick();
    channel.capture(24.7010, 46.6010);
    await rig.day.drain();
    await rig.day.flushNow();
    expect(server.createSessionCalls, 0);
    expect(server.points.single.session, 7);
    rig.dispose();
  });

  test('a restored work day records nothing until this install has agreed to '
      'the disclosure', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server()
      ..sessions[7] = _StoredSession(7, 'wd-other-device', DateTime.utc(2026, 9, 13, 8));
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);

    await rig.day.restore(
      notificationTitle: 't',
      notificationText: 'x',
      beforeCapture: () async => false,
    );
    expect(rig.day.status.value.isActive, isTrue, reason: 'the day stays open');
    expect(rig.day.status.value.capturing, isFalse);
    expect(channel.starts, 0, reason: 'no background capture without agreement');

    await rig.day.restore(
      notificationTitle: 't',
      notificationText: 'x',
      beforeCapture: () async => true,
    );
    expect(rig.day.status.value.capturing, isTrue);
    expect(channel.starts, 1);
    expect(channel.session, 'wd-other-device');
    expect(server.createSessionCalls, 0);
    rig.dispose();
  });

  test('no app resume starts capture while the disclosure is pending or after '
      'it was declined', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server()
      ..sessions[7] = _StoredSession(7, 'wd-other-device', DateTime.utc(2026, 9, 13, 8));
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);

    await rig.day.restore(
      notificationTitle: 't',
      notificationText: 'x',
      beforeCapture: () async {
        // A permission prompt closing resumes the app while the user is still
        // reading the disclosure.
        rig.day.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _tick();
        expect(channel.starts, 0, reason: 'nothing starts before the answer');
        return false;
      },
    );
    rig.day.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _tick();
    expect(channel.starts, 0, reason: 'a declined disclosure holds across resumes');
    expect(rig.day.status.value.isActive, isTrue);

    // Retry on the bar, after agreeing there.
    await rig.day.restore(notificationTitle: 't', notificationText: 'x');
    expect(channel.starts, 1);
    rig.day.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _tick();
    expect(channel.starts, 1, reason: 'running capture is left alone');
    rig.dispose();
  });

  test('a point the server refuses for good is dropped and reported', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server();
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);
    final dropped = <int>[];
    final sub = rig.day.onPointsDropped.listen(dropped.add);
    await _startDay(rig.day);
    await rig.day.flushNow();

    server.sessions[1]!.state = 'completed'; // closed from elsewhere
    await _tick();
    channel.capture(24.7010, 46.6010);
    await rig.day.drain();
    await rig.day.flushNow();
    await Future<void>.delayed(Duration.zero);

    expect(dropped, [1]);
    expect(rig.day.status.value.pending, 0);
    await sub.cancel();
    rig.dispose();
  });

  test('a server without the work-day store refuses Start and captures '
      'nothing', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = _Server()..supported = false;
    final channel = _Channel();
    final rig = _rig(prefs, server, channel);

    await expectLater(
      _startDay(rig.day),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.notSupported)),
    );
    expect(channel.starts, 0);
    expect(rig.day.status.value.phase, WorkdayPhase.unsupported);
    rig.dispose();
  });

  group('WorkdayRoute', () {
    Map<String, dynamic> row(int id, int minute, double lat, Object visit,
            [String source = 'track']) =>
        {
          'id': id,
          'x_session_id': [3, 'WD'],
          'x_visit_id': visit,
          'x_logged_at': '2026-09-13 08:${minute.toString().padLeft(2, '0')}:00',
          'x_latitude': lat,
          'x_longitude': 46.6,
          'x_accuracy': 5.0,
          'x_altitude': 0.0,
          'x_speed': 0.0,
          'x_heading': 0.0,
          'x_device_id': false,
          'x_source': source,
        };

    final session = WorkSession(
      id: 3,
      startedAt: DateTime.utc(2026, 9, 13, 8),
      state: WorkSessionState.completed,
    );

    test('splits the day into movement and per-visit stretches, in order', () {
      final route = WorkdayRoute.fromApi(session, [
        row(1, 0, 24.700, false, 'start'),
        row(2, 5, 24.701, false),
        row(3, 10, 24.702, [61, 'VIS/2026/00061']),
        row(4, 15, 24.703, [61, 'VIS/2026/00061']),
        row(5, 20, 24.704, false),
        row(6, 25, 24.705, [62, 'VIS/2026/00062']),
        row(7, 30, 24.706, false, 'end'),
      ]);

      expect(route.logs, hasLength(7));
      expect(route.logs.first.isStart, isTrue);
      expect(route.logs.last.isEnd, isTrue);
      expect(route.logs.first.loggedAt, DateTime.utc(2026, 9, 13, 8));
      expect(route.logs[1].deviceId, isNull, reason: 'Odoo false is absent');
      expect(route.segments, const [
        RouteSegment(visitId: null, start: 0, end: 1),
        RouteSegment(visitId: 61, start: 2, end: 3),
        RouteSegment(visitId: null, start: 4, end: 4),
        RouteSegment(visitId: 62, start: 5, end: 5),
        RouteSegment(visitId: null, start: 6, end: 6),
      ]);
      expect(route.visitSegments.map((s) => s.visitId), [61, 62]);
      expect(route.visitRefs, {61: 'VIS/2026/00061', 62: 'VIS/2026/00062'});
      expect(route.distanceKm, closeTo(0.667, 0.01));
    });

    test('a session row with Odoo false values parses', () {
      final s = WorkSession.tryFromApi({
        'id': 9,
        'x_client_uid': false,
        'x_employee_id': [281, 'Adel Attendee'],
        'x_started_at': '2026-09-13 08:30:00',
        'x_ended_at': false,
        'x_state': 'active',
        'x_start_latitude': 0.0,
        'x_start_longitude': 0.0,
        'x_end_latitude': 0.0,
        'x_end_longitude': 0.0,
      })!;
      expect(s.isActive, isTrue);
      expect(s.clientUid, isNull);
      expect(s.employeeId, 281);
      expect(s.endedAt, isNull);
      expect(s.startLatitude, isNull);
      expect(s.startedAt, DateTime.utc(2026, 9, 13, 8, 30));
    });
  });
}
