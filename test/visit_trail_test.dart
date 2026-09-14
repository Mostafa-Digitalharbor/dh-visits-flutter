// The GPS trail: parsing what `/api/visit/track` returns, and the buffer that
// feeds `/api/visit/log_locations`.
//
// The buffer is where the interesting failures live. A fix is *field evidence*
// — where the employee actually was — so the two ways to lose one are both
// covered here: dropping a point the server never accepted, and keeping a point
// forever that it will never accept.
//
// Fakes are hand-rolled via noSuchMethod, matching visit_detail_cubit_test.
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/features/visits/data/models/visit.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements VisitsRepository {
  _FakeRepo({this.result, this.error});

  /// What the next flush returns. Rebuilt per call from [rejectIndices] so a
  /// test can describe the server's verdict rather than assemble the payload.
  TrailFlushResult? result;
  Object? error;

  final List<List<TrailPoint>> flushes = [];

  @override
  Future<TrailFlushResult> logLocations(int visitId, List<TrailPoint> points) async {
    flushes.add(points);
    if (error != null) throw error!;
    return result ?? TrailFlushResult(created: points.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocation implements LocationService {
  @override
  Future<bool> ensurePermission() async => false; // never opens a real stream

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VisitTrailTracker _tracker(SharedPreferences prefs, _FakeRepo repo,
    {ConnectivityStatus? connectivity}) {
  return VisitTrailTracker(
    prefs: prefs,
    repository: repo,
    locationService: _FakeLocation(),
    connectivity: connectivity ?? ConnectivityStatus(),
  );
}

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

  group('VisitTrailTracker buffer', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a manual point is flushed and then leaves the buffer', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo();
      final tracker = _tracker(prefs, repo);

      await tracker.addManualPoint(
          visitId: 52, latitude: 24.7, longitude: 46.6);

      expect(repo.flushes, hasLength(1));
      expect(repo.flushes.single, hasLength(1));
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('points survive a restart: a new tracker flushes what the old buffered',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final offline = ConnectivityStatus()..markOffline();
      final first = _FakeRepo();
      final tracker = _tracker(prefs, first, connectivity: offline);

      await tracker.addManualPoint(
          visitId: 52, latitude: 24.7, longitude: 46.6);
      expect(first.flushes, isEmpty, reason: 'offline — nothing should be sent');
      expect(tracker.pendingCount.value, 1);
      tracker.dispose();

      // The app is killed and comes back with the network up. The same prefs
      // instance stands in for the same device storage.
      final second = _FakeRepo();
      final revived = _tracker(prefs, second);
      expect(revived.pendingCount.value, 1,
          reason: 'the buffered fix must be read back off disk');

      await revived.flushNow();
      expect(second.flushes.single, hasLength(1));
      expect(revived.pendingCount.value, 0);
      revived.dispose();
    });

    test('a network failure keeps every point for the next attempt', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.network));
      final tracker = _tracker(prefs, repo);

      await tracker.addManualPoint(
          visitId: 52, latitude: 24.7, longitude: 46.6);

      expect(repo.flushes, hasLength(1));
      expect(tracker.pendingCount.value, 1,
          reason: 'a dead zone must not cost the rep their recorded path');

      // Network back: the same point goes out and clears.
      repo.error = null;
      await tracker.flushNow();
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('a point the server refuses individually is not retried forever',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo(
        result: const TrailFlushResult(
          created: 0,
          rejected: [
            RejectedPoint(index: 0, error: 'A position cannot predate the start'),
          ],
        ),
      );
      final tracker = _tracker(prefs, repo);

      await tracker.addManualPoint(
          visitId: 52, latitude: 24.7, longitude: 46.6);

      // Rejected by index → dropped, because re-sending it would be refused
      // identically forever.
      expect(tracker.pendingCount.value, 0);
      await tracker.flushNow();
      expect(repo.flushes, hasLength(1), reason: 'no pointless re-send');
      tracker.dispose();
    });

    test('a refused batch is retried, then abandoned after the attempt limit',
        () async {
      final prefs = await SharedPreferences.getInstance();
      // `UserError`-shaped: the whole call refused, not individual points. This
      // is what a Start still replaying from the offline queue looks like.
      final repo = _FakeRepo(error: ApiException(code: ApiErrorCode.validation));
      final tracker = _tracker(prefs, repo);

      await tracker.addManualPoint(
          visitId: 52, latitude: 24.7, longitude: 46.6);
      expect(tracker.pendingCount.value, 1,
          reason: 'the first refusal must not discard the fix — the visit may '
              'simply not have started server-side yet');

      for (var i = 1; i < AppConstants.trailMaxFlushAttempts; i++) {
        await tracker.flushNow();
      }
      expect(tracker.pendingCount.value, 0,
          reason: 'a genuinely impossible point is eventually abandoned rather '
              'than retried on every tick forever');
      tracker.dispose();
    });

    test('each visit flushes as its own batch', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _FakeRepo();
      final tracker = _tracker(prefs, repo);
      final offline = ConnectivityStatus()..markOffline();
      final buffering = _tracker(prefs, _FakeRepo(), connectivity: offline);

      await buffering.addManualPoint(
          visitId: 52, latitude: 24.7, longitude: 46.6);
      await buffering.addManualPoint(
          visitId: 53, latitude: 24.8, longitude: 46.7);
      buffering.dispose();

      await tracker.flushNow();

      expect(repo.flushes, hasLength(2),
          reason: 'log_locations takes one visit_id, so two visits cannot '
              'share a request');
      tracker.dispose();
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
