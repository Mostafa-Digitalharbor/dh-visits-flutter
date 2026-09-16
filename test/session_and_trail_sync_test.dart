// Session renewal and GPS-trail sync — the two halves of docs/API.md §7 that
// fail silently when they are wrong.
//
// * ApiClient: Odoo reports a dead session as HTTP 200 + `error` with
//   `odoo.http.SessionExpiredException`. The client must re-authenticate and
//   retry the call exactly once — never loop, never log in six times at once.
// * VisitTrailTracker: a `log_locations` batch is a *partial* success; accepted
//   points leave the buffer, and refused ones are handled by what they are.
// * ServerClock: the server validates `logged_at` against its own clock.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_gps/core/api/api_client.dart';
import 'package:location_gps/core/api/api_exceptions.dart';
import 'package:location_gps/core/constants.dart';
import 'package:location_gps/core/location/location_service.dart';
import 'package:location_gps/core/network/connectivity_status.dart';
import 'package:location_gps/core/network/server_clock.dart';
import 'package:location_gps/features/visits/data/models/visit_location_log.dart';
import 'package:location_gps/features/visits/data/visit_trail_tracker.dart';
import 'package:location_gps/features/visits/data/visits_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// ApiClient fakes
// ---------------------------------------------------------------------------

/// Answers each request from a script keyed by path, recording what was sent.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  /// `(path, nthCallToThisPath)` → JSON body.
  final Map<String, dynamic> Function(String path, int nth) respond;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final nth = paths.where((p) => p == options.path).length;
    return ResponseBody.fromString(
      jsonEncode(respond(options.path, nth)),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _odooError(String name, String message, {int code = 0}) => {
      'jsonrpc': '2.0',
      'id': null,
      'error': {
        'code': code,
        'message': 'Odoo Server Error',
        'data': {'name': name, 'message': message, 'debug': 'Traceback …'},
      },
    };

Map<String, dynamic> _expired() => _odooError(
    'odoo.http.SessionExpiredException', 'Session expired',
    code: 100);

Map<String, dynamic> _ok(Object result) =>
    {'jsonrpc': '2.0', 'id': null, 'result': result};

ApiClient _client(_ScriptedAdapter adapter) {
  final dir = Directory.systemTemp.createTempSync('cookies');
  final api = ApiClient(
    cookieJar: PersistCookieJar(storage: FileStorage('${dir.path}/')),
    baseUrl: 'https://odoo.test',
  );
  api.dio.httpClientAdapter = adapter;
  return api;
}

// ---------------------------------------------------------------------------
// Tracker fakes
// ---------------------------------------------------------------------------

class _Repo implements VisitsRepository {
  _Repo({this.verdict, this.delay = Duration.zero});

  /// Builds the server's answer for one batch.
  TrailFlushResult Function(List<TrailPoint> points)? verdict;
  final Duration delay;
  final List<List<TrailPoint>> flushes = [];

  @override
  Future<TrailFlushResult> logLocations(
      int visitId, List<TrailPoint> points) async {
    flushes.add(points);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return verdict?.call(points) ?? TrailFlushResult(created: points.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoLocation implements LocationService {
  @override
  Future<bool> ensurePermission() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VisitTrailTracker _tracker(SharedPreferences prefs, VisitsRepository repo,
        {ConnectivityStatus? connectivity}) =>
    VisitTrailTracker(
      prefs: prefs,
      repository: repo,
      locationService: _NoLocation(),
      connectivity: connectivity ?? ConnectivityStatus(),
      notificationLabels: () => (title: 'title', text: 'text'),
    );

/// Leaves points for [visitId] in the on-device buffer, as a dead zone during
/// that visit does, and returns the prefs holding them. Appends to what is
/// already buffered.
Future<SharedPreferences> _bufferedOffline(int visitId, List<DateTime> times) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(StorageKeys.trailBuffer);
  final buffer = raw == null ? <Object?>[] : jsonDecode(raw) as List<Object?>;
  for (var i = 0; i < times.length; i++) {
    buffer.add({
      'v': visitId,
      'n': 0,
      'p': TrailPoint(
        latitude: 24.70 + i / 100,
        longitude: 46.60,
        loggedAt: times[i].toUtc(),
      ).toJson(),
    });
  }
  await prefs.setString(StorageKeys.trailBuffer, jsonEncode(buffer));
  return prefs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient session renewal', () {
    test('re-authenticates and retries the refused call once', () async {
      final adapter = _ScriptedAdapter((path, nth) =>
          nth == 1 ? _expired() : _ok({'visits': <Object>[]}));
      final api = _client(adapter);
      var renewals = 0;
      api.reauthenticate = () async {
        renewals++;
        return true;
      };
      var loggedOut = 0;
      api.onUnauthorized.listen((_) => loggedOut++);

      final result = await api.jsonRpc('/api/visit/my');

      expect(result, {'visits': <Object>[]});
      expect(renewals, 1);
      expect(adapter.paths, ['/api/visit/my', '/api/visit/my']);
      await Future<void>.delayed(Duration.zero);
      expect(loggedOut, 0);
    });

    test('a second expiry is not retried again — no loop, logout instead',
        () async {
      final adapter = _ScriptedAdapter((path, nth) => _expired());
      final api = _client(adapter);
      var renewals = 0;
      api.reauthenticate = () async {
        renewals++;
        return true;
      };
      var loggedOut = 0;
      api.onUnauthorized.listen((_) => loggedOut++);

      await expectLater(
        api.jsonRpc('/api/visit/my'),
        throwsA(isA<ApiException>()
            .having((e) => e.isSessionExpired, 'isSessionExpired', isTrue)),
      );
      expect(renewals, 1);
      expect(adapter.paths, hasLength(2));
      await Future<void>.delayed(Duration.zero);
      expect(loggedOut, 1);
    });

    test('failed renewal does not retry and signs the user out', () async {
      final adapter = _ScriptedAdapter((path, nth) => _expired());
      final api = _client(adapter);
      api.reauthenticate = () async => false;
      var loggedOut = 0;
      api.onUnauthorized.listen((_) => loggedOut++);

      await expectLater(api.jsonRpc('/api/visit/get'), throwsA(isA<ApiException>()));
      expect(adapter.paths, ['/api/visit/get']);
      await Future<void>.delayed(Duration.zero);
      expect(loggedOut, 1);
    });

    test('a refused renewal is not repeated on every later call', () async {
      // Each attempt with dead credentials is a failed login on the server;
      // a handful in a row lock the account for everyone.
      final adapter = _ScriptedAdapter((path, nth) => _expired());
      final api = _client(adapter);
      var renewals = 0;
      api.reauthenticate = () async {
        renewals++;
        return false;
      };

      for (var i = 0; i < 3; i++) {
        await expectLater(api.jsonRpc('/api/visit/my'), throwsA(isA<ApiException>()));
      }
      expect(renewals, 1);

      // A real sign-in makes renewal possible again.
      api.sessionEstablished();
      await expectLater(api.jsonRpc('/api/visit/my'), throwsA(isA<ApiException>()));
      expect(renewals, 2);
    });

    test('a renewal that cannot reach the server keeps the session', () async {
      // Signing the rep out over a network blip would also stop the trail of
      // the visit in progress.
      final adapter = _ScriptedAdapter((path, nth) => _expired());
      final api = _client(adapter);
      var renewals = 0;
      api.reauthenticate = () async {
        renewals++;
        throw ApiException(code: ApiErrorCode.network);
      };
      var loggedOut = 0;
      api.onUnauthorized.listen((_) => loggedOut++);

      await expectLater(
        api.jsonRpc('/api/visit/log_locations'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.network)),
      );
      await expectLater(api.jsonRpc('/api/visit/my'), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
      expect(loggedOut, 0);
      expect(renewals, 2, reason: 'tried again on the next call');
    });

    test('concurrent expiries share a single re-login', () async {
      final adapter = _ScriptedAdapter(
          (path, nth) => nth == 1 ? _expired() : _ok({'ok': true}));
      final api = _client(adapter);
      var renewals = 0;
      api.reauthenticate = () async {
        renewals++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return true;
      };

      await Future.wait([
        api.jsonRpc('/api/visit/my'),
        api.jsonRpc('/api/visit/get'),
        api.jsonRpc('/api/visit/track'),
      ]);
      expect(renewals, 1);
    });

    test('a business error at HTTP 200 is surfaced, not retried', () async {
      final adapter = _ScriptedAdapter((path, nth) => _odooError(
          'odoo.exceptions.UserError',
          'The visit outcome is required before ending the visit.'));
      final api = _client(adapter);
      var renewals = 0;
      api.reauthenticate = () async {
        renewals++;
        return true;
      };

      await expectLater(
        api.jsonRpc('/api/visit/end'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.validation)
            .having((e) => e.odooName, 'odooName', 'odoo.exceptions.UserError')
            .having((e) => e.serverMessage, 'serverMessage',
                'The visit outcome is required before ending the visit.')),
      );
      expect(renewals, 0);
      expect(adapter.paths, hasLength(1));
    });

    test('an AccessError keeps its message for the user, never the trace', () {
      final e = ApiException.fromJson(_odooError(
          'odoo.exceptions.AccessError', 'You may not add positions to this visit.'));
      expect(e.code, ApiErrorCode.permissionDenied);
      expect(e.serverMessage, 'You may not add positions to this visit.');
      expect(e.serverMessage, isNot(contains('Traceback')),
          reason: 'debug is never in the message the UI renders');
      expect(e.toString(), isNot(contains('Traceback')),
          reason: 'nor in what a crash report serializes');
      expect(e.odooName, 'odoo.exceptions.AccessError');
    });
  });

  group('ServerClock', () {
    test('learns the offset from a Date header and maps fix times onto it', () {
      final clock = ServerClock();
      // Measured live: the device clock was 87 s ahead of the server.
      clock.observeHttpDate('Sun, 13 Sep 2026 08:47:00 GMT',
          receivedAt: DateTime.utc(2026, 9, 13, 8, 48, 27));

      expect(clock.offset.inMilliseconds, -86500);
      expect(clock.toServer(DateTime.utc(2026, 9, 13, 8, 48, 27)),
          DateTime.utc(2026, 9, 13, 8, 47, 0, 500));
    });

    test('ignores sub-second jitter and garbage headers', () {
      final clock = ServerClock();
      clock.observeHttpDate('Sun, 13 Sep 2026 08:47:00 GMT',
          receivedAt: DateTime.utc(2026, 9, 13, 8, 47, 0, 900));
      expect(clock.offset, Duration.zero);
      clock.observeHttpDate('not a date');
      expect(clock.offset, Duration.zero);
    });
  });

  group('VisitTrailTracker batch handling', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('accepted points leave, a permanently refused one is dropped and '
        'reported', () async {
      final now = DateTime.now();
      final prefs = await _bufferedOffline(52, [
        now.subtract(const Duration(minutes: 3)),
        now.subtract(const Duration(minutes: 2)),
        now.subtract(const Duration(minutes: 1)),
      ]);
      final repo = _Repo(
        verdict: (pts) => const TrailFlushResult(created: 2, rejected: [
          RejectedPoint(
              index: 1,
              error: 'A position cannot predate the start of the visit.'),
        ]),
      );
      final tracker = _tracker(prefs, repo);
      final dropped = <int>[];
      tracker.onPointsDropped.listen(dropped.add);

      await tracker.flushNow();

      expect(repo.flushes.single, hasLength(3));
      expect(tracker.pendingCount.value, 0);
      await Future<void>.delayed(Duration.zero);
      expect(dropped, [1]);
      tracker.dispose();
    });

    test('a point refused for being ahead of the server is kept for retry',
        () async {
      final now = DateTime.now();
      final prefs = await _bufferedOffline(52, [
        now.subtract(const Duration(minutes: 1)),
        now.add(const Duration(minutes: 10)),
      ]);
      final repo = _Repo(
        verdict: (pts) => TrailFlushResult(
          created: pts.length - 1,
          rejected: [
            for (var i = 0; i < pts.length; i++)
              if (pts[i].loggedAt.isAfter(DateTime.now().toUtc()))
                RejectedPoint(
                    index: i, error: 'A position cannot be dated in the future.'),
          ],
        ),
      );
      final tracker = _tracker(prefs, repo);

      await tracker.flushNow();
      expect(tracker.pendingCount.value, 1,
          reason: 'only the future-dated fix stays; the accepted one left');
      expect(repo.flushes.single, hasLength(2));

      // Bounded: it is abandoned after the attempt limit rather than resent on
      // every tick forever.
      for (var i = 1; i < AppConstants.trailMaxFlushAttempts; i++) {
        await tracker.flushNow();
      }
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('flushNow waits for a flush already in flight', () async {
      // End awaits flushNow to get the route up before the visit closes. It
      // used to return immediately whenever a timer flush was mid-request.
      final prefs = await _bufferedOffline(52, [DateTime.now()]);
      final repo = _Repo(delay: const Duration(milliseconds: 80));
      final tracker = _tracker(prefs, repo);

      unawaited(tracker.flushNow());
      await tracker.flushNow();

      expect(tracker.pendingCount.value, 0);
      expect(repo.flushes, hasLength(1));
      tracker.dispose();
    });

    test('a probing flush still sends while connectivity reads offline',
        () async {
      // Connectivity only turns back to online after a request succeeds. A
      // tracker that never tried while "offline" deadlocked: the route stayed
      // on the device although the network had returned.
      final prefs = await _bufferedOffline(52, [DateTime.now()]);
      final offline = ConnectivityStatus()..markOffline();
      final repo = _Repo();
      final tracker = _tracker(prefs, repo, connectivity: offline);

      await tracker.flushNow();
      expect(repo.flushes, isEmpty, reason: 'a plain flush respects offline');

      await tracker.flushNow(probe: true);
      expect(repo.flushes, hasLength(1));
      expect(tracker.pendingCount.value, 0);
      tracker.dispose();
    });

    test('points of different visits never share a batch', () async {
      final now = DateTime.now();
      var prefs = await _bufferedOffline(52, [now]);
      prefs = await _bufferedOffline(53, [now, now.add(const Duration(seconds: 30))]);
      final sentFor = <int, int>{};
      final repo = _RecordingRepo(sentFor);
      final tracker = _tracker(prefs, repo);

      await tracker.flushNow();

      expect(sentFor, {52: 1, 53: 2});
      tracker.dispose();
    });
  });
}

class _RecordingRepo implements VisitsRepository {
  _RecordingRepo(this.sentFor);
  final Map<int, int> sentFor;

  @override
  Future<TrailFlushResult> logLocations(
      int visitId, List<TrailPoint> points) async {
    sentFor[visitId] = (sentFor[visitId] ?? 0) + points.length;
    return TrailFlushResult(created: points.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
