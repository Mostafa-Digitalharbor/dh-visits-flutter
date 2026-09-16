// The GPS trail: parsing what `/api/visit/track` returns, and the tracker
// that records a visit's route — only while the visit is in progress — and
// feeds `/api/visit/log_locations`.
//
// A fix is *field evidence* — where the employee actually was — so the ways
// to get it wrong are all covered here: recording outside a visit, attributing
// a fix to the wrong visit, dropping a point the server never accepted, and
// keeping a point forever that it will never accept.
//
// Fakes are hand-rolled via noSuchMethod, matching visit_detail_cubit_test.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/location/visit_location_channel.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/pending_actions_queue.dart';
import 'package:location_gps/core/network/server_clock.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visit_tracking_consent.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:location_gps/features/visits/domain/visit_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements VisitsRepository {
  _FakeRepo({this.result, this.error});

  /// What the next flush returns (all created when null).
  TrailFlushResult? result;
  Object? error;

  /// What `getVisit` throws, and what it answers per visit.
  Object? readError;
  final Map<int, Visit> visits = {};
  final List<int> reads = [];

  /// What `myRunningVisit` answers.
  Visit? running;

  final List<List<TrailPoint>> flushes = [];
  final List<int> flushVisits = [];

  @override
  Future<TrailFlushResult> logLocations(int visitId, List<TrailPoint> points) async {
    flushes.add(points);
    flushVisits.add(visitId);
    if (error != null) throw error!;
    return result ?? TrailFlushResult(created: points.length);
  }

  @override
  Future<Visit?> getVisit(int visitId) async {
    reads.add(visitId);
    if (readError != null) throw readError!;
    return visits[visitId];
  }

  @override
  Future<Visit?> myRunningVisit() async => running;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocation implements LocationService {
  _FakeLocation({this.permitted = true});
  final bool permitted;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Stream<Position> watch({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = LocationService.defaultDistanceFilterMeters,
  }) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Start = ({int visitId, DateTime since, double? seedLatitude});

/// The native capture: a config (active + visit) and a journal of fixes.
/// [record] appends whatever it is given, so the Dart-side guards are tested
/// on their own.
class _FakeChannel extends VisitLocationChannel {
  final List<_Start> starts = [];
  int stops = 0;
  bool active = false;
  bool running = false;
  int? visitId;
  final List<CapturedFix> journal = [];
  int _seq = 0;

  /// Simulates an acknowledgement lost on the way to the native side.
  bool dropAcks = false;

  @override
  bool get isAvailable => true;

  @override
  Future<void> start({
    required int visitId,
    required DateTime since,
    required double minDistanceMeters,
    required Duration minInterval,
    required double maxAccuracyMeters,
    required String title,
    required String text,
    double? seedLatitude,
    double? seedLongitude,
  }) async {
    starts.add((visitId: visitId, since: since, seedLatitude: seedLatitude));
    active = true;
    running = true;
    this.visitId = visitId;
  }

  @override
  Future<void> stop() async {
    stops++;
    active = false;
    running = false;
    visitId = null;
  }

  @override
  Future<CaptureStatus> status() async =>
      (active: active, running: running, visitId: active ? visitId : null);

  @override
  Future<List<CapturedFix>> read({int max = VisitLocationChannel.defaultReadBatch}) async =>
      journal.take(max).toList();

  @override
  Future<void> ack(int throughSeq) async {
    if (!dropAcks) journal.removeWhere((f) => f.seq <= throughSeq);
  }

  void record(int visitId, DateTime at, {double lat = 24.7, double lng = 46.6}) =>
      journal.add(CapturedFix(
        seq: ++_seq,
        deviceTime: at,
        latitude: lat,
        longitude: lng,
        visitId: visitId,
        accuracy: 5,
      ));
}

VisitTrailTracker _tracker(
  SharedPreferences prefs,
  _FakeRepo repo, {
  ConnectivityStatus? connectivity,
  _FakeChannel? channel,
  ServerClock? clock,
  PendingActionsQueue? queue,
  _FakeLocation? location,
  Future<String?> Function()? owner,
}) {
  return VisitTrailTracker(
    prefs: prefs,
    repository: repo,
    locationService: location ?? _FakeLocation(),
    connectivity: connectivity ?? ConnectivityStatus(),
    notificationLabels: () => (title: 'Visit tracking active', text: 'Recording'),
    channel: channel ?? _FakeChannel(),
    serverClock: clock,
    pendingActions: queue == null ? null : () => queue,
    ownerResolver: owner,
  );
}

PendingActionsQueue _queue(SharedPreferences prefs, _FakeRepo repo) =>
    PendingActionsQueue(
      prefs: prefs,
      repository: repo,
      connectivity: ConnectivityStatus()..markOffline(),
    );

Visit _visit(int id, String state) => Visit.fromApi({
      'id': id,
      'state': state,
      'start_datetime': '2026-09-16T10:00:00',
    });

TrailPoint _point(String iso, {double lat = 24.7, double lng = 46.6}) =>
    TrailPoint(
      latitude: lat,
      longitude: lng,
      loggedAt: DateTime.parse(iso).toUtc(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisitTrack.fromApi', () {
    test('keeps the server order, which is fix time rather than id', () {
      // Straight from the API doc: ids 39 and 38 arrived out of order in a
      // batch and the server filed them by fix time. The client draws the
      // polyline through `logs` exactly as returned.
      final track = VisitTrack.fromApi({
        'visit_id': 52,
        'location_log_count': 3,
        'tracked_distance_km': 9.311,
        'logs': [
          {'id': 36, 'logged_at': '2026-09-12T09:10:00', 'latitude': 24.71, 'longitude': 46.67},
          {'id': 39, 'logged_at': '2026-09-12T09:30:00', 'latitude': 24.745, 'longitude': 46.705},
          {'id': 38, 'logged_at': '2026-09-12T09:40:00', 'latitude': 24.76, 'longitude': 46.72},
        ],
      });

      expect(track.logs.map((l) => l.id), [36, 39, 38]);
      expect(track.trackedDistanceKm, 9.311);
      expect(track.hasPath, isTrue);
    });

    test('does not reshuffle points that share a timestamp', () {
      // A Start and the first fix can land in the same second. The server's
      // order between them is the route; an unstable local re-sort was free to
      // swap them.
      final track = VisitTrack.fromApi({
        'visit_id': 52,
        'logs': [
          for (var i = 1; i <= 12; i++)
            {'id': i, 'logged_at': '2026-09-12T09:10:00', 'latitude': 24.7 + i / 1000, 'longitude': 46.6, 'source': i == 1 ? 'start' : 'track'},
        ],
      });

      expect(track.logs.map((l) => l.id), [for (var i = 1; i <= 12; i++) i]);
    });

    test('parses API datetimes as UTC, including Odoo `false`', () {
      final track = VisitTrack.fromApi({
        'visit_id': 52,
        'logs': [
          {'id': 1, 'logged_at': '2026-09-12T09:10:01', 'latitude': 24.71, 'longitude': 46.67, 'device_id': false, 'location': false},
        ],
      });
      final log = track.logs.single;
      expect(log.loggedAt, DateTime.utc(2026, 9, 12, 9, 10, 1));
      expect(log.loggedAt.isUtc, isTrue);
      expect(log.deviceId, isNull);
    });

    test('drops a point with no usable coordinate or timestamp', () {
      // Odoo serialises unset values as `false`, and a half-formed point that
      // survived would become a (0,0) vertex dragging the drawn path into the
      // Gulf of Guinea.
      final track = VisitTrack.fromApi({
        'visit_id': 52,
        'logs': [
          {'id': 1, 'logged_at': '2026-09-12T09:10:00', 'latitude': 24.71, 'longitude': 46.67},
          {'id': 2, 'logged_at': false, 'latitude': 24.72, 'longitude': 46.68},
          {'id': 3, 'logged_at': '2026-09-12T09:20:00', 'latitude': 999.0, 'longitude': 46.68},
        ],
      });

      expect(track.logs.map((l) => l.id), [1]);
    });

    test('reads the counters the server reports, not the page it returned', () {
      // `logs` can be a limit/offset slice; the counters always describe the
      // whole trail, which is what the summary row must show.
      final track = VisitTrack.fromApi({
        'visit_id': 52,
        'location_log_count': 240,
        'tracked_distance_km': 31.4,
        'logs': [
          {'id': 1, 'logged_at': '2026-09-12T09:10:00', 'latitude': 24.71, 'longitude': 46.67},
        ],
      });

      expect(track.locationLogCount, 240);
      expect(track.logs, hasLength(1));
    });

    test('parses source and treats zero speed as a real reading', () {
      final track = VisitTrack.fromApi({
        'visit_id': 52,
        'logs': [
          {
            'id': 1,
            'logged_at': '2026-09-12T09:10:00',
            'latitude': 24.71,
            'longitude': 46.67,
            'speed': 0.0,
            'accuracy': 7.5,
            'source': 'start',
            'location': false,
          },
        ],
      });

      final log = track.logs.single;
      expect(log.source, TrailSource.start);
      expect(log.isStart, isTrue);
      // A stationary fix really does have speed 0 — unlike a coordinate, zero
      // here is data, not "unset".
      expect(log.speed, 0.0);
      expect(log.accuracy, 7.5);
      expect(log.location, isNull);
    });
  });

  group('TrailFlushResult.fromApi', () {
    test('keeps the rejected indices so the caller can prune its queue', () {
      final result = TrailFlushResult.fromApi({
        'created': 2,
        'logs': [
          {'id': 38, 'logged_at': '2026-09-12T09:40:00', 'latitude': 24.76, 'longitude': 46.72},
        ],
        'rejected': [
          {'index': 2, 'error': 'Latitude 999.0 is out of range (-90 to 90).'},
          {'index': 3, 'error': 'The position timestamp is not a valid date and time.'},
        ],
        'location_log_count': 4,
        'tracked_distance_km': 6.858,
      });

      expect(result.created, 2);
      expect(result.rejected.map((r) => r.index), [2, 3]);
      expect(result.trackedDistanceKm, 6.858);
    });
  });

  group('TrailPoint persistence', () {
    test('survives the JSON round trip the buffer puts it through', () {
      final point = TrailPoint(
        latitude: 24.7136,
        longitude: 46.6753,
        loggedAt: DateTime.utc(2026, 9, 12, 9, 20, 1),
        accuracy: 7.5,
        speed: 12.0,
        heading: 41.0,
        altitude: 612.0,
        deviceId: 'pixel-7',
      );

      final back = TrailPoint.tryFromJson(point.toJson())!;

      expect(back.latitude, point.latitude);
      expect(back.loggedAt, point.loggedAt);
      expect(back.accuracy, 7.5);
      expect(back.deviceId, 'pixel-7');
    });

    test('sends logged_at in Odoo\'s space-separated UTC form', () {
      final wire = _point('2026-09-12T09:20:01Z')
          .toApi(formatUtc: VisitsRepository.formatOdooUtc);

      expect(wire['logged_at'], '2026-09-12 09:20:01');
    });
  });

  group('VisitTrailTracker — records only while a visit is in progress', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        VisitTrackingConsent.key: true,
      });
      prefs = await SharedPreferences.getInstance();
    });

    test('nothing is captured or sent before a visit is started', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);

      // The phone moves: the native side records nothing without a config,
      // and the tracker never asked it to.
      await tracker.drain();
      await tracker.flushNow(probe: true);
      await tracker.verify(force: true);

      expect(channel.starts, isEmpty);
      expect(repo.flushes, isEmpty);
      expect(repo.reads, isEmpty,
          reason: 'with nothing recording there is nothing to verify');
      expect(tracker.isTracking, isFalse);
      tracker.dispose();
    });

    test('start captures the visit from its server start time', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final clock = ServerClock()..observeHttpDate(null);
      final tracker = _tracker(prefs, repo, channel: channel, clock: clock);
      final startedAt = DateTime.utc(2026, 9, 16, 10);

      await tracker.start(52, startedAt: startedAt, seedLatitude: 24.7, seedLongitude: 46.6);

      expect(channel.starts.single.visitId, 52);
      // Two seconds of slack past the server's stamp: fixes on the boundary
      // would only come back refused as "predates the start".
      expect(channel.starts.single.since, startedAt.add(const Duration(seconds: 2)));
      expect(channel.starts.single.seedLatitude, 24.7);
      expect(tracker.status.value.isRecording, isTrue);
      tracker.dispose();
    });

    test('fixes are uploaded with their real time and acknowledged', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52, startedAt: DateTime.utc(2026, 9, 16, 10));

      final t1 = DateTime.utc(2026, 9, 16, 10, 5);
      final t2 = DateTime.utc(2026, 9, 16, 10, 6);
      channel.record(52, t2, lat: 24.72);
      channel.record(52, t1, lat: 24.71);
      await tracker.drain();
      await tracker.flushNow();

      final sent = repo.flushes.single;
      expect(sent.map((p) => p.loggedAt), [t1, t2],
          reason: 'oldest first, each with its own fix time — not upload time');
      expect(repo.flushVisits.single, 52);
      expect(channel.journal, isEmpty, reason: 'acknowledged once buffered');
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('End stops capture first; no fix taken after it is ever sent',
        () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52, startedAt: DateTime.utc(2026, 9, 16, 10));

      final during = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      channel.record(52, during);
      await tracker.stop();

      expect(channel.stops, 1);
      expect(channel.active, isFalse);
      expect(tracker.isTracking, isFalse);
      expect(repo.flushes.single.single.loggedAt, during);

      // A fix that still reaches the journal after End (it cannot on a real
      // device — the config is re-read per fix — but the guard is in Dart too)
      // is discarded, and moving the phone starts nothing.
      channel.record(52, DateTime.now().toUtc().add(const Duration(seconds: 5)));
      await tracker.drain();
      await tracker.flushNow(probe: true);
      expect(repo.flushes, hasLength(1), reason: 'no new point after End');
      expect(channel.starts, hasLength(1), reason: 'capture never restarted');
      tracker.dispose();
    });

    test('points recorded offline during the visit upload after it ended',
        () async {
      final offline = ConnectivityStatus()..markOffline();
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.network));
      final channel = _FakeChannel();
      final tracker =
          _tracker(prefs, repo, channel: channel, connectivity: offline);
      await tracker.start(52, startedAt: DateTime.utc(2026, 9, 16, 10));

      final t1 = DateTime.now().toUtc().subtract(const Duration(minutes: 3));
      final t2 = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      channel.record(52, t1);
      channel.record(52, t2);
      await tracker.stop();
      expect(tracker.pendingCount.value, 2, reason: 'kept through the dead zone');

      repo.error = null;
      offline.markOnline();
      await tracker.flushNow();

      expect(repo.flushes.last.map((p) => p.loggedAt), [t1, t2]);
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('visit A and visit B never share points', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);

      await tracker.start(52, startedAt: DateTime.utc(2026, 9, 16, 9));
      channel.record(52, DateTime.now().toUtc().subtract(const Duration(minutes: 30)), lat: 24.5);
      await tracker.stop(flush: false);
      // Between the visits the phone moves; nothing is being captured.
      expect(channel.active, isFalse);

      await tracker.start(53, startedAt: DateTime.utc(2026, 9, 16, 10));
      channel.record(53, DateTime.now().toUtc().subtract(const Duration(minutes: 5)), lat: 25.5);
      await tracker.stop();

      expect(repo.flushVisits, containsAll(<int>[52, 53]));
      for (var i = 0; i < repo.flushes.length; i++) {
        final lat = repo.flushVisits[i] == 52 ? 24.5 : 25.5;
        expect(repo.flushes[i].every((p) => p.latitude == lat), isTrue,
            reason: 'visit ${repo.flushVisits[i]} got another visit\'s point');
      }
      tracker.dispose();
    });

    test('a capture journal that started over is still taken in', () async {
      // The native counter restarted below what was already taken (its
      // storage was reset, ours was not): its fixes are new, not replays.
      await prefs.setInt(StorageKeys.trailNativeSeq, 40);
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);
      channel.record(52, DateTime.now().toUtc().subtract(const Duration(seconds: 5)));

      await tracker.drain();
      await tracker.flushNow();

      expect(repo.flushes.expand((b) => b), hasLength(1));
      expect(channel.journal, isEmpty);
      tracker.dispose();
    });

    test('a replay after a lost acknowledgement is not taken twice',
        () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel()..dropAcks = true;
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);
      channel.record(52, DateTime.now().toUtc().subtract(const Duration(seconds: 5)));

      await tracker.drain();
      await tracker.flushNow();
      expect(channel.journal, hasLength(1), reason: 'the ack never arrived');
      // The next drain reads the same fix again.
      await tracker.drain();
      await tracker.flushNow();

      expect(repo.flushes.expand((b) => b), hasLength(1));
      tracker.dispose();
    });

    test('switching visits stops the previous capture first', () async {
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, _FakeRepo(), channel: channel);
      await tracker.start(52);
      await tracker.start(53);

      expect(channel.stops, 1);
      expect(channel.starts.map((s) => s.visitId), [52, 53]);
      expect(tracker.activeVisitId, 53);
      tracker.dispose();
    });

    test('restart: only a visit the server still has in progress resumes',
        () async {
      final channel = _FakeChannel();
      final repo = _FakeRepo();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);
      tracker.dispose();

      // Case A — still in progress: recording resumes.
      final revived = _tracker(prefs, repo, channel: channel..running = false);
      expect(revived.activeVisitId, 52, reason: 'marker read back off disk');
      await revived.resume(_visit(52, 'in_progress'));
      expect(channel.starts, hasLength(2));
      expect(channel.active, isTrue);
      revived.dispose();

      // Case B — done meanwhile (ended on another device): it stops.
      final again = _tracker(prefs, repo, channel: channel);
      await again.resume(null);
      expect(channel.active, isFalse);
      expect(again.isTracking, isFalse);
      expect(channel.starts, hasLength(2), reason: 'never restarted');
      again.dispose();
    });

    test('cold start: an app resume restarts nothing before the server answers',
        () async {
      final channel = _FakeChannel();
      final repo = _FakeRepo();
      final first = _tracker(prefs, repo, channel: channel);
      await first.start(52);
      first.dispose();
      channel.running = false;
      channel.active = false; // the process died; nothing is capturing

      final revived = _tracker(prefs, repo, channel: channel);
      revived.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(channel.starts, hasLength(1),
          reason: 'the marker alone must not restart capture');

      // The server says the visit is over.
      await revived.resume(null);
      expect(channel.starts, hasLength(1));
      expect(revived.isTracking, isFalse);
      revived.dispose();
    });

    test('a visit ended elsewhere keeps only the fixes taken before its end',
        () async {
      final channel = _FakeChannel();
      final serverEnd = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      final repo = _FakeRepo()
        ..visits[52] = Visit(id: 52, state: VisitState.done, endDatetime: serverEnd);
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);
      channel.record(52, serverEnd.subtract(const Duration(minutes: 1)), lat: 24.1);
      channel.record(52, serverEnd.add(const Duration(minutes: 1)), lat: 24.9);

      await tracker.resume(null);
      await tracker.flushNow();

      final sent = repo.flushes.expand((b) => b).toList();
      expect(sent.map((p) => p.latitude), [24.1],
          reason: 'the fix after the server-side end would only be refused');
      tracker.dispose();
    });

    test('verify uses the server end time too', () async {
      final channel = _FakeChannel();
      final serverEnd = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      final repo = _FakeRepo()..visits[52] = _visit(52, 'in_progress');
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);
      channel.record(52, serverEnd.subtract(const Duration(seconds: 30)), lat: 24.1);
      channel.record(52, serverEnd.add(const Duration(seconds: 30)), lat: 24.9);

      repo.visits[52] = Visit(id: 52, state: VisitState.done, endDatetime: serverEnd);
      await tracker.verify(force: true);
      await tracker.flushNow();

      expect(repo.flushes.expand((b) => b).map((p) => p.latitude), [24.1]);
      tracker.dispose();
    });

    for (final state in [
      'draft',
      'submitted',
      'approved',
      'rejected',
      'cancelled',
      'reschedule_requested',
      'done',
    ]) {
      test('a $state visit is never recorded', () async {
        final channel = _FakeChannel();
        final tracker = _tracker(prefs, _FakeRepo(), channel: channel);
        await tracker.resume(_visit(52, state));
        expect(channel.starts, isEmpty);
        expect(tracker.isTracking, isFalse);
        tracker.dispose();
      });
    }

    test('a visit whose End is queued offline is not restored', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final queue = _queue(prefs, repo);
      await queue.enqueue(52, {QueuedVisitActionFields.type: 'end'});
      final tracker = _tracker(prefs, repo, channel: channel, queue: queue);

      await tracker.resume(_visit(52, 'in_progress'));

      expect(channel.starts, isEmpty);
      tracker.dispose();
      queue.dispose();
    });

    test('a replayed offline Start begins recording only on the server\'s word',
        () async {
      final repo = _FakeRepo()..visits[52] = _visit(52, 'in_progress');
      final channel = _FakeChannel();
      final queue = _queue(prefs, repo);
      final tracker = _tracker(prefs, repo, channel: channel, queue: queue);

      await tracker.onQueuedStartSynced(52);
      expect(channel.starts.single.visitId, 52);
      await tracker.stop(flush: false);

      // The server still has it approved (the replay was refused): nothing.
      repo.visits[53] = _visit(53, 'approved');
      await tracker.onQueuedStartSynced(53);
      // An End for it is queued behind the Start: nothing either.
      await queue.enqueue(54, {QueuedVisitActionFields.type: 'end'});
      repo.visits[54] = _visit(54, 'in_progress');
      await tracker.onQueuedStartSynced(54);

      expect(channel.starts, hasLength(1));
      tracker.dispose();
      queue.dispose();
    });

    test('verify stops a visit the server no longer has in progress', () async {
      final repo = _FakeRepo()..visits[52] = _visit(52, 'in_progress');
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);

      await tracker.verify(force: true);
      expect(tracker.isTracking, isTrue);

      repo.visits[52] = _visit(52, 'cancelled');
      await tracker.verify(force: true);
      expect(tracker.isTracking, isFalse);
      expect(channel.active, isFalse);
      tracker.dispose();
    });

    test('verify keeps recording through a network failure', () async {
      final repo = _FakeRepo()
        ..readError = ApiException(code: ApiErrorCode.network);
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);

      await tracker.verify(force: true);

      expect(tracker.isTracking, isTrue);
      tracker.dispose();
    });

    test('no capture without the disclosure; retry after agreeing', () async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, _FakeRepo(), channel: channel);

      await tracker.start(52);
      expect(channel.starts, isEmpty);
      expect(tracker.status.value.paused, TrailPause.consent);

      await VisitTrackingConsent(prefs).accept();
      await tracker.retry();
      expect(channel.starts.single.visitId, 52);
      expect(tracker.status.value.isRecording, isTrue);
      tracker.dispose();
    });

    test('no capture without location access', () async {
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, _FakeRepo(),
          channel: channel, location: _FakeLocation(permitted: false));

      await tracker.start(52);

      expect(channel.starts, isEmpty);
      expect(tracker.status.value.paused, TrailPause.permission);
      tracker.dispose();
    });

    test('sign-out stops capture and uploads what was recorded', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      final tracker = _tracker(prefs, repo, channel: channel);
      await tracker.start(52);
      channel.record(52, DateTime.now().toUtc().subtract(const Duration(seconds: 30)));

      await tracker.suspend();

      expect(channel.active, isFalse);
      expect(repo.flushes.single, hasLength(1));
      expect(tracker.isTracking, isFalse);
      tracker.dispose();
    });

    test('offline at start-up: the local marker keeps recording, then the '
        'server decides', () async {
      final channel = _FakeChannel();
      final repo = _FakeRepo();
      final first = _tracker(prefs, repo, channel: channel);
      await first.start(52);
      first.dispose();
      channel.running = false;

      final offline = ConnectivityStatus()..markOffline();
      final revived = _tracker(prefs, repo, channel: channel, connectivity: offline);
      await revived.resumeUnverified();
      expect(channel.starts, hasLength(2), reason: 'capture brought back');

      // Network back: the server says the visit is over.
      repo.running = null;
      offline.markOnline();
      await pumpEventQueue();
      expect(revived.isTracking, isFalse);
      expect(channel.active, isFalse);
      revived.dispose();
    });

    test('another account\'s points are never sent', () async {
      final repo = _FakeRepo();
      final channel = _FakeChannel();
      var owner = 'server|7';
      final offline = ConnectivityStatus()..markOffline();
      final tracker = _tracker(prefs, repo,
          channel: channel, connectivity: offline, owner: () async => owner);
      await tracker.start(52);
      channel.record(52, DateTime.now().toUtc().subtract(const Duration(seconds: 30)));
      await tracker.stop();

      // Another account signs in on this phone, online.
      owner = 'server|8';
      offline.markOnline();
      await tracker.flushNow();
      expect(repo.flushes, isEmpty);
      expect(tracker.pendingCount.value, 1, reason: 'kept for its own account');

      owner = 'server|7';
      await tracker.flushNow();
      expect(repo.flushes.single, hasLength(1));
      tracker.dispose();
    });
  });

  group('VisitTrailTracker — log_locations results', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        VisitTrackingConsent.key: true,
      });
      prefs = await SharedPreferences.getInstance();
    });

    /// Buffers [times] for visit 52 through the native journal, offline.
    Future<VisitTrailTracker> buffered(
      _FakeRepo repo,
      List<DateTime> times,
    ) async {
      final channel = _FakeChannel();
      final offline = ConnectivityStatus()..markOffline();
      final tracker =
          _tracker(prefs, repo, channel: channel, connectivity: offline);
      await tracker.start(52, startedAt: DateTime.utc(2026, 9, 16, 9));
      for (final t in times) {
        channel.record(52, t, lat: 24 + t.minute / 100);
      }
      await tracker.drain();
      offline.markOnline();
      return tracker;
    }

    test('partial rejection drops only the refused points, by index', () async {
      final now = DateTime.now().toUtc();
      final times = [
        for (var i = 4; i >= 1; i--) now.subtract(Duration(minutes: i)),
      ];
      final repo = _FakeRepo(
        result: const TrailFlushResult(
          created: 2,
          rejected: [
            RejectedPoint(index: 1, error: 'Latitude 999.0 is out of range (-90 to 90).'),
            RejectedPoint(index: 3, error: 'The position timestamp is not a valid date and time.'),
          ],
        ),
      );
      final tracker = await buffered(repo, times);
      final dropped = <int>[];
      final sub = tracker.onPointsDropped.listen(dropped.add);

      await tracker.flushNow();
      await pumpEventQueue();

      expect(repo.flushes.single, hasLength(4));
      expect(tracker.pendingCount.value, 0,
          reason: 'accepted points leave; refused ones are not re-sent forever');
      expect(dropped, [2], reason: 'the rep is told about the gap');

      repo.result = null;
      await tracker.flushNow();
      expect(repo.flushes, hasLength(1), reason: 'accepted points not re-sent');
      await sub.cancel();
      tracker.dispose();
    });

    test('a point dated ahead of the server is kept and retried', () async {
      final future = DateTime.now().toUtc().add(const Duration(minutes: 10));
      final repo = _FakeRepo(
        result: const TrailFlushResult(
          created: 0,
          rejected: [RejectedPoint(index: 0, error: 'A position cannot be dated in the future.')],
        ),
      );
      final tracker = await buffered(repo, [future]);

      await tracker.flushNow();
      expect(tracker.pendingCount.value, 1);
      tracker.dispose();
    });

    test('a network failure keeps every point', () async {
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.network));
      final tracker = await buffered(
          repo, [DateTime.now().toUtc().subtract(const Duration(minutes: 1))]);

      await tracker.flushNow();
      expect(tracker.pendingCount.value, 1);

      repo.error = null;
      await tracker.flushNow();
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('an expired session keeps every point without using up attempts',
        () async {
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.unauthorized));
      final tracker = await buffered(
          repo, [DateTime.now().toUtc().subtract(const Duration(minutes: 1))]);

      for (var i = 0; i < AppConstants.trailMaxFlushAttempts + 2; i++) {
        await tracker.flushNow();
      }
      expect(tracker.pendingCount.value, 1);
      tracker.dispose();
    });

    test('a refused batch is retried, then abandoned after the attempt limit',
        () async {
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.validation));
      final tracker = await buffered(
          repo, [DateTime.now().toUtc().subtract(const Duration(minutes: 1))]);

      await tracker.flushNow();
      expect(tracker.pendingCount.value, 1,
          reason: 'the first refusal must not discard the fix');
      for (var i = 1; i < AppConstants.trailMaxFlushAttempts; i++) {
        await tracker.flushNow();
      }
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('points survive a restart and flush from the new process', () async {
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.network));
      final tracker = await buffered(
          repo, [DateTime.now().toUtc().subtract(const Duration(minutes: 1))]);
      await tracker.flushNow();
      tracker.dispose();

      final second = _FakeRepo();
      final revived = _tracker(prefs, second, channel: _FakeChannel());
      expect(revived.pendingCount.value, 1);
      await revived.flushNow();
      expect(second.flushes.single, hasLength(1));
      expect(revived.pendingCount.value, 0);
      revived.dispose();
    });

    test('points of a visit whose Start is still queued are held', () async {
      final repo = _FakeRepo();
      final queue = _queue(prefs, repo);
      final channel = _FakeChannel();
      await queue.enqueue(52, {QueuedVisitActionFields.type: 'start'});
      final tracker = _tracker(prefs, repo, channel: channel, queue: queue);
      await tracker.start(52);
      channel.record(52, DateTime.now().toUtc().subtract(const Duration(seconds: 10)));
      await tracker.drain();

      await tracker.flushNow();
      expect(repo.flushes, isEmpty);
      expect(tracker.pendingCount.value, 1);
      tracker.dispose();
      queue.dispose();
    });
  });

  group('Visit trail counters', () {
    test('are read off the REST payload', () {
      final visit = Visit.fromApi({
        'id': 52,
        'name': 'VIS/2026/00052',
        'state': 'done',
        'location_log_count': 5,
        'tracked_distance_km': 9.311,
        'last_location_datetime': '2026-09-12T09:55:04',
      });

      expect(visit.locationLogCount, 5);
      expect(visit.trackedDistanceKm, 9.311);
      expect(visit.hasTrail, isTrue);
      expect(visit.lastLocationDatetime, DateTime.utc(2026, 9, 12, 9, 55, 4));
    });

    test('a single logged point is not yet a path', () {
      final visit = Visit.fromApi({
        'id': 52,
        'state': 'in_progress',
        'location_log_count': 1,
      });

      expect(visit.hasTrail, isFalse,
          reason: 'one point is a marker; the trail UI needs two to draw a '
              'line between');
      expect(visit.isTrackingLive, isTrue);
    });
  });
}
